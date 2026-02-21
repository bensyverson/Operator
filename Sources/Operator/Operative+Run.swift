import Foundation
import LLM

extension Operative {
    /// Runs the agent loop with the given user message.
    ///
    /// Returns an ``OperationStream`` that emits ``Operation`` events
    /// as the agent works. The stream ends with either
    /// ``Operation/completed(_:)`` or ``Operation/stopped(_:)``.
    ///
    /// - Parameter userMessage: The user's input message.
    /// - Returns: A stream of operation events.
    public func run(_ userMessage: String) -> OperationStream {
        var config = configuration
        config.tools = toolDefinitions.isEmpty ? nil : toolDefinitions

        let conversation = LLM.Conversation(
            systemPrompt: systemPrompt,
            messages: [
                LLM.OpenAICompatibleAPI.ChatMessage(content: userMessage, role: .user),
            ],
            configuration: config
        )

        return runLoop(with: conversation)
    }

    /// Continues the agent loop from a previous conversation.
    ///
    /// Use this to build multi-turn interactions: pass the ``OperativeResult/conversation``
    /// from a previous run along with the next user message. The agent resumes with
    /// full conversation history and a fresh budget.
    ///
    /// ```swift
    /// let result1 = try await operative.run("Store my name as Alice").result()
    /// let result2 = try await operative.run("What's my name?", continuing: result1.conversation).result()
    /// ```
    ///
    /// - Parameters:
    ///   - userMessage: The next user message.
    ///   - conversation: The conversation from a previous ``OperativeResult``.
    /// - Returns: A stream of operation events.
    public func run(_ userMessage: String, continuing conversation: LLM.Conversation) -> OperationStream {
        var continued = conversation
        continued.messages.append(
            LLM.OpenAICompatibleAPI.ChatMessage(content: userMessage, role: .user)
        )
        // Ensure tools are still present in the configuration
        if continued.configuration.tools == nil, !toolDefinitions.isEmpty {
            continued.configuration.tools = toolDefinitions
        }
        return runLoop(with: continued)
    }

    // MARK: - Private

    private func runLoop(with initialConversation: LLM.Conversation) -> OperationStream {
        OperationStream { continuation in
            Task {
                await executeLoop(conversation: initialConversation, continuation: continuation)
                continuation.finish()
            }
        }
    }

    private func executeLoop(
        conversation initialConversation: LLM.Conversation,
        continuation: OperationStream.Continuation
    ) async {
        var conversation = initialConversation

        var turnNumber = 0
        var cumulativeUsage = TokenUsage.zero
        let startTime = ContinuousClock.now

        while true {
            turnNumber += 1

            // 1. Check budget — turn limit
            if let maxTurns = budget.maxTurns, turnNumber > maxTurns {
                continuation.yield(.stopped(.turnLimitReached))
                return
            }

            // Check budget — token limit
            if let maxTokens = budget.maxTokens, cumulativeUsage.totalTokens >= maxTokens {
                continuation.yield(.stopped(.tokenBudgetExhausted))
                return
            }

            // Check budget — timeout
            if let timeout = budget.timeout, ContinuousClock.now - startTime >= timeout {
                continuation.yield(.stopped(.timeout))
                return
            }

            // Emit turn started
            let budgetRemaining = remainingBudget(
                turn: turnNumber,
                used: cumulativeUsage,
                startTime: startTime
            )
            continuation.yield(.turnStarted(TurnContext(
                turnNumber: turnNumber,
                budgetRemaining: budgetRemaining
            )))

            // 2. Pre-request middleware
            let messages = conversation.messages.map { Message(from: $0) }
            var requestContext = RequestContext(
                messages: messages,
                toolDefinitions: toolDefinitions
            )
            do {
                for mw in middleware {
                    try await mw.beforeRequest(&requestContext)
                }
            } catch {
                continuation.yield(.stopped(.explicitStop(reason: error.localizedDescription)))
                return
            }

            // Rebuild conversation messages from middleware-modified context
            conversation.messages = requestContext.messages.map { $0.toChatMessage() }
            if !requestContext.toolDefinitions.isEmpty {
                conversation.configuration.tools = requestContext.toolDefinitions
            }

            // 3. Call LLM (with timeout if budget specifies one)
            let response: LLMResponse
            do {
                if let timeout = budget.timeout {
                    let remaining = timeout - (ContinuousClock.now - startTime)
                    if remaining <= .zero {
                        continuation.yield(.stopped(.timeout))
                        return
                    }
                    let conversationSnapshot = conversation
                    response = try await withThrowingTaskGroup(of: LLMResponse.self) { group in
                        group.addTask {
                            try await self.llm.chat(conversation: conversationSnapshot)
                        }
                        group.addTask {
                            try await Task.sleep(for: remaining)
                            throw TimeoutError()
                        }
                        let result = try await group.next()!
                        group.cancelAll()
                        return result
                    }
                } else {
                    response = try await llm.chat(conversation: conversation)
                }
            } catch is TimeoutError {
                continuation.yield(.stopped(.timeout))
                return
            } catch {
                continuation.yield(.stopped(.explicitStop(reason: "LLM error: \(error.localizedDescription)")))
                return
            }

            cumulativeUsage = cumulativeUsage + response.usage
            conversation = response.conversation

            // 4. Post-response middleware
            var responseContext = ResponseContext(
                responseText: response.text,
                toolCalls: response.toolCalls
            )
            do {
                for mw in middleware {
                    try await mw.afterResponse(&responseContext)
                }
            } catch {
                continuation.yield(.stopped(.explicitStop(reason: error.localizedDescription)))
                return
            }

            // 5. Emit text if present
            if let text = responseContext.responseText, !text.isEmpty {
                continuation.yield(.text(text))
            }

            // 6. If no tool calls → completed
            let toolRequests = responseContext.toolCalls
            if toolRequests.isEmpty {
                let result = OperativeResult(
                    text: responseContext.responseText,
                    conversation: conversation,
                    usage: cumulativeUsage,
                    turnsUsed: turnNumber
                )
                continuation.yield(.turnCompleted(TurnResult(
                    usage: response.usage,
                    toolCallCount: 0,
                    cumulativeUsage: cumulativeUsage
                )))
                continuation.yield(.completed(result))
                return
            }

            // 7. Emit tools requested
            continuation.yield(.toolsRequested(toolRequests))

            // 8. Pre-tool-call middleware
            var toolCallContexts = toolRequests.map { req in
                ToolCallContext(
                    name: req.name,
                    arguments: req.arguments,
                    toolCallId: req.toolCallId
                )
            }
            for mw in middleware {
                try? await mw.beforeToolCalls(&toolCallContexts)
            }

            // 9. Separate approved vs rejected
            var approved = [ToolCallContext]()
            var rejections = [ToolRejection]()

            for ctx in toolCallContexts {
                switch ctx.decision {
                case .proceed, .modify:
                    approved.append(ctx)
                case let .reject(reason):
                    rejections.append(ToolRejection(
                        request: ToolRequest(
                            name: ctx.name,
                            arguments: ctx.arguments,
                            toolCallId: ctx.toolCallId
                        ),
                        reason: reason
                    ))
                }
            }

            if !rejections.isEmpty {
                continuation.yield(.toolsRejected(rejections))
            }

            // Add assistant tool call message to conversation
            let toolCalls: [LLM.OpenAICompatibleAPI.ToolCall] = toolRequests.map { req in
                LLM.OpenAICompatibleAPI.ToolCall(
                    id: req.toolCallId,
                    type: "function",
                    function: LLM.OpenAICompatibleAPI.FunctionCall(
                        name: req.name,
                        arguments: req.arguments
                    )
                )
            }

            // Only add assistant tool call message if not already present
            // (the LLM response conversation may already include it)
            let lastMessage = conversation.messages.last
            let assistantHasToolCalls = lastMessage?.role == .assistant && lastMessage?.tool_calls != nil
            if !assistantHasToolCalls {
                conversation = conversation.addingAssistantToolCallMessage(toolCalls)
            }

            // 10. Execute approved tools concurrently
            // Also add rejection results as tool messages so the LLM knows
            for rejection in rejections {
                conversation = conversation.addingToolResultMessage(
                    toolCallId: rejection.request.toolCallId,
                    content: "Tool call rejected: \(rejection.reason)"
                )
            }

            var shouldStop = false
            var stopReason = ""

            await withTaskGroup(of: ToolExecutionResult.self) { group in
                for ctx in approved {
                    let arguments: ToolArguments
                    switch ctx.decision {
                    case let .modify(modifiedArgs):
                        arguments = modifiedArgs
                    default:
                        do {
                            arguments = try ToolArguments(fromJSON: ctx.arguments)
                        } catch {
                            // If arguments can't be parsed, report as tool failure
                            let request = ToolRequest(
                                name: ctx.name,
                                arguments: ctx.arguments,
                                toolCallId: ctx.toolCallId
                            )
                            continuation.yield(.toolFailed(
                                request,
                                ToolError(message: "Invalid arguments: \(error.localizedDescription)", underlyingError: error)
                            ))
                            continue
                        }
                    }

                    guard let tool = toolRegistry[ctx.name] else {
                        let request = ToolRequest(
                            name: ctx.name,
                            arguments: ctx.arguments,
                            toolCallId: ctx.toolCallId
                        )
                        let error = OperativeError.duplicateToolName(ctx.name)
                        continuation.yield(.toolFailed(
                            request,
                            ToolError(message: "Unknown tool: \(ctx.name)", underlyingError: error)
                        ))
                        continue
                    }

                    let toolCallId = ctx.toolCallId
                    let name = ctx.name
                    let rawArguments = ctx.arguments
                    let capturedArgs = arguments
                    group.addTask {
                        let request = ToolRequest(
                            name: name,
                            arguments: rawArguments,
                            toolCallId: toolCallId
                        )
                        do {
                            let output = try await tool.call(arguments: capturedArgs)
                            return ToolExecutionResult(
                                request: request,
                                outcome: .success(output)
                            )
                        } catch {
                            return ToolExecutionResult(
                                request: request,
                                outcome: .failure(error)
                            )
                        }
                    }
                }

                for await result in group {
                    switch result.outcome {
                    case let .success(output):
                        continuation.yield(.toolCompleted(result.request, output))
                        conversation = conversation.addingToolResultMessage(
                            toolCallId: result.request.toolCallId,
                            content: output.content
                        )
                        if output.shouldStop {
                            shouldStop = true
                            stopReason = output.content
                        }
                    case let .failure(error):
                        // Run error middleware
                        let toolCallContext = ToolCallContext(
                            name: result.request.name,
                            arguments: result.request.arguments,
                            toolCallId: result.request.toolCallId
                        )
                        var recovery = ToolErrorRecovery.feedbackToLLM(error.localizedDescription)
                        for mw in middleware {
                            if let r = try? await mw.onToolError(error, context: toolCallContext) {
                                recovery = r
                            }
                        }

                        switch recovery {
                        case let .feedbackToLLM(message):
                            let toolError = ToolError(message: message, underlyingError: error)
                            continuation.yield(.toolFailed(result.request, toolError))
                            conversation = conversation.addingToolResultMessage(
                                toolCallId: result.request.toolCallId,
                                content: "Error: \(message)"
                            )
                        case .throw:
                            continuation.yield(.stopped(.explicitStop(reason: error.localizedDescription)))
                            shouldStop = true
                            return
                        }
                    }
                }
            }

            if shouldStop {
                if !stopReason.isEmpty {
                    continuation.yield(.stopped(.explicitStop(reason: stopReason)))
                }
                return
            }

            // 11. Emit turn completed
            continuation.yield(.turnCompleted(TurnResult(
                usage: response.usage,
                toolCallCount: toolRequests.count,
                cumulativeUsage: cumulativeUsage
            )))

            // Loop continues to next turn
        }
    }

    /// Computes the remaining budget given current usage.
    private func remainingBudget(
        turn: Int,
        used: TokenUsage,
        startTime: ContinuousClock.Instant
    ) -> Budget {
        Budget(
            maxTurns: budget.maxTurns.map { $0 - turn + 1 },
            maxTokens: budget.maxTokens.map { $0 - used.totalTokens },
            maxTokensPerTurn: budget.maxTokensPerTurn,
            timeout: budget.timeout.map { timeout in
                let elapsed = ContinuousClock.now - startTime
                let remaining = timeout - elapsed
                return remaining > .zero ? remaining : .zero
            }
        )
    }
}

// MARK: - Internal types

/// Result of executing a single tool, used for concurrent collection.
private struct ToolExecutionResult: Sendable {
    let request: ToolRequest
    let outcome: Result<ToolOutput, any Error>
}

/// Sentinel error for timeout detection.
private struct TimeoutError: Error {}
