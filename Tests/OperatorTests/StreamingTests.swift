import Foundation
import LLM
@testable import Operator
import Testing

/// Avoid ambiguity with Foundation.Operation (NSOperation)
private typealias Op = Operator.Operation

// MARK: - Test Helpers

/// Collects all operations from a stream.
private func collectOperations(_ stream: OperationStream) async -> [Op] {
    var ops = [Op]()
    for await op in stream {
        ops.append(op)
    }
    return ops
}

/// A simple Operable for streaming tests.
private struct StreamTestOperable: Operable {
    let toolGroup: ToolGroup
}

private struct StreamEchoInput: ToolInput {
    let message: String
    static var paramDescriptions: [String: String] {
        ["message": "The message to echo"]
    }
}

// MARK: - Streaming Tests

@Suite("Streaming")
struct StreamingTests {
    @Test("Multiple text deltas arrive as separate .text operations")
    func multipleTextDeltas() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("Hello world!"),
        ])
        // Split text into 3-character chunks
        mock.textChunkSize = 3

        let operative = try Operative(
            name: "streamer",
            description: "test",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Hi"))

        // Filter to just .text operations
        let textOps = ops.compactMap { op -> String? in
            if case let .text(chunk) = op { return chunk }
            return nil
        }

        // "Hello world!" in 3-char chunks: "Hel", "lo ", "wor", "ld!"
        #expect(textOps == ["Hel", "lo ", "wor", "ld!"])

        // The combined text should reconstruct the original
        #expect(textOps.joined() == "Hello world!")
    }

    @Test("Thinking deltas precede text deltas in the operation stream")
    func thinkingBeforeText() async throws {
        let mock = MockLLMService(responses: [
            .withThinking("Let me think", text: "The answer"),
        ])
        mock.textChunkSize = 5

        let operative = try Operative(
            name: "thinker",
            description: "test",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Think"))

        // Collect thinking and text operations with their order
        var thinkingIndices = [Int]()
        var textIndices = [Int]()
        for (i, op) in ops.enumerated() {
            switch op {
            case .thinking:
                thinkingIndices.append(i)
            case .text:
                textIndices.append(i)
            default:
                break
            }
        }

        // All thinking should come before all text
        #expect(!thinkingIndices.isEmpty, "Should have thinking operations")
        #expect(!textIndices.isEmpty, "Should have text operations")

        let lastThinkingIndex = try #require(thinkingIndices.max())
        let firstTextIndex = try #require(textIndices.min())
        #expect(lastThinkingIndex < firstTextIndex, "Thinking should precede text")
    }

    @Test("afterResponse middleware runs after streaming and can detect secrets")
    func middlewareAfterStreaming() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("The secret is sk-abc123"),
        ])

        let filter = ContentFilter(
            blockedPatterns: [],
            secrets: ["sk-abc123"]
        )

        let operative = try Operative(
            name: "filtered",
            description: "test",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 10),
            middleware: [filter]
        )

        let ops = await collectOperations(operative.run("Tell me the secret"))

        // Text should have been streamed before the filter ran
        let hasText = ops.contains { op in
            if case .text = op { return true }
            return false
        }
        #expect(hasText, "Text should have been streamed before middleware stopped it")

        // But the stream should end with .stopped due to secret detection
        let lastOp = ops.last
        if case let .stopped(reason) = lastOp {
            if case .explicitStop = reason {
                // Expected — middleware detected the secret
            } else {
                Issue.record("Expected explicitStop, got \(reason)")
            }
        } else {
            Issue.record("Expected stopped, got \(String(describing: lastOp))")
        }
    }

    @Test("Timeout during streaming stops the operative")
    func timeoutDuringStreaming() async throws {
        // Create a mock that delays before returning
        let delayMock = DelayingMockLLMService(
            response: .textOnly("Slow response"),
            delay: .seconds(5)
        )

        let operative = try Operative(
            name: "timeout-test",
            description: "test",
            llm: delayMock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(timeout: .milliseconds(50))
        )

        let ops = await collectOperations(operative.run("Wait"))

        let lastOp = ops.last
        if case let .stopped(reason) = lastOp {
            #expect(reason == .timeout)
        } else {
            Issue.record("Expected stopped(.timeout), got \(String(describing: lastOp))")
        }
    }

    @Test("Multi-chunk text followed by tool calls works correctly")
    func textAndToolCallsStreamed() async throws {
        let toolCall = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"hello\"}",
            toolCallId: "tc-1"
        )

        let mock = MockLLMService(responses: [
            .withToolCalls([toolCall], text: "Calling echo"),
            .textOnly("Done"),
        ])
        mock.textChunkSize = 4

        let echoTool = try Tool(name: "echo", description: "Echo", input: StreamEchoInput.self) { input in
            ToolOutput(input.message)
        }
        let operable = StreamTestOperable(toolGroup: ToolGroup(name: "test", tools: [echoTool]))

        let operative = try Operative(
            name: "tool-streamer",
            description: "test",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Echo something"))

        // Should have text chunks from first response
        let textOps = ops.compactMap { op -> String? in
            if case let .text(chunk) = op { return chunk }
            return nil
        }

        // "Calling echo" in 4-char chunks + "Done" in 4-char chunks
        #expect(textOps.contains("Call"))
        #expect(textOps.joined().contains("Calling echo"))
        #expect(textOps.joined().contains("Done"))

        // Should have tool events
        let hasToolsRequested = ops.contains { op in
            if case .toolsRequested = op { return true }
            return false
        }
        #expect(hasToolsRequested, "Should have toolsRequested event")

        // Should end with completed
        let lastOp = ops.last
        if case .completed = lastOp {
            // Expected
        } else {
            Issue.record("Expected completed, got \(String(describing: lastOp))")
        }
    }
}

// MARK: - Delaying Mock

/// A mock LLM service that introduces a delay before yielding events,
/// useful for testing timeout behavior.
private final class DelayingMockLLMService: LLMService, @unchecked Sendable {
    let response: LLMResponse
    let delay: Duration

    init(response: LLMResponse, delay: Duration) {
        self.response = response
        self.delay = delay
    }

    func chat(conversation _: LLM.Conversation) -> AsyncThrowingStream<LLM.StreamEvent, Error> {
        let capturedResponse = response
        let capturedDelay = delay
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await Task.sleep(for: capturedDelay)

                    if let text = capturedResponse.text {
                        continuation.yield(.textDelta(text))
                    }

                    let conversationResponse = LLM.ConversationResponse(
                        text: capturedResponse.text,
                        thinking: capturedResponse.thinking,
                        toolCalls: [],
                        conversation: capturedResponse.conversation,
                        rawResponse: LLM.OpenAICompatibleAPI.ChatCompletionResponse()
                    )
                    continuation.yield(.completed(conversationResponse))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
