#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    import LLM

    @available(macOS 26.0, iOS 26.0, *)
    extension AppleIntelligenceService: ToolHandlingLLMService {
        func execute(
            conversation: Conversation,
            tools: [String: any ToolProvider],
            budget: Budget,
            middleware: [any Middleware],
            continuation: OperationStream.Continuation
        ) async {
            // 1. Build AFM tool proxies from bridgeable tools
            var afmTools = [any FoundationModels.Tool]()
            for (_, tool) in tools {
                if let bridgeable = tool as? AFMBridgeable {
                    let definition = tool.definition
                    let proxy = bridgeable.makeAFMProxy(
                        name: definition.function.name,
                        description: definition.function.description,
                        eventHandler: { operation in continuation.yield(operation) }
                    )
                    afmTools.append(proxy)
                }
                // Non-bridgeable tools are silently skipped.
            }

            // 2. Build instructions from system prompt + prior messages
            let priorMessages = conversation.messages.dropLast()
            var instructions = conversation.systemPrompt

            if !priorMessages.isEmpty {
                let transcript = ConversationFormatter.format(priorMessages)
                instructions += "\n\nConversation so far:\n" + transcript
            }

            // 3. Create session with tools
            let session = LanguageModelSession(
                tools: afmTools,
                instructions: instructions
            )

            // 4. Emit turn started
            continuation.yield(.turnStarted(TurnContext(
                turnNumber: 1,
                budgetRemaining: budget,
                pressure: []
            )))

            // 5. Call respond(to:) with timeout if budget specifies one
            let userMessage = conversation.messages.last?.textContent ?? ""

            do {
                // Extract the String content inside the task boundary to avoid
                // passing non-Sendable LanguageModelSession.Response across tasks.
                let responseText: String = if let timeout = budget.timeout {
                    try await withThrowingTaskGroup(of: String.self) { group in
                        group.addTask {
                            let response = try await session.respond(to: userMessage)
                            return response.content
                        }
                        group.addTask {
                            try await Task.sleep(for: timeout)
                            throw AFMTimeoutError()
                        }
                        let result = try await group.next()!
                        group.cancelAll()
                        return result
                    }
                } else {
                    try await session.respond(to: userMessage).content
                }

                // 6. Best-effort afterResponse middleware
                var responseContext = ResponseContext(
                    responseText: responseText,
                    thinking: nil,
                    toolCalls: []
                )
                for mw in middleware {
                    try? await mw.afterResponse(&responseContext)
                }

                // 7. Emit text, turn completed, and completed
                continuation.yield(.text(responseText))

                let updatedConversation = conversation.addingAssistantMessage(responseText)

                continuation.yield(.turnCompleted(TurnResult(
                    usage: TokenUsage.zero,
                    toolCallCount: 0,
                    cumulativeUsage: TokenUsage.zero,
                    conversation: updatedConversation
                )))

                continuation.yield(.completed(OperativeResult(
                    text: responseText,
                    conversation: updatedConversation,
                    usage: TokenUsage.zero,
                    turnsUsed: 1
                )))

            } catch is AFMTimeoutError {
                continuation.yield(.stopped(.timeout))
            } catch {
                continuation.yield(.stopped(.explicitStop(
                    reason: "Apple Intelligence error: \(error.localizedDescription)"
                )))
            }
        }
    }

    /// Sentinel error for timeout detection within AFM execution.
    private struct AFMTimeoutError: Error {}
#endif
