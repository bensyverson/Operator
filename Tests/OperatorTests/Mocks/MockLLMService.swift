import LLM
@testable import Operator

/// A mock LLM service that returns scripted responses in order.
///
/// Each scripted ``LLMResponse`` is wrapped in an ``AsyncThrowingStream``
/// that yields `.textDelta` / `.thinkingDelta` events before `.completed`.
final class MockLLMService: LLMService, @unchecked Sendable {
    var responses: [LLMResponse]
    var callCount = 0
    var receivedConversations: [LLM.Conversation] = []

    /// When non-nil, text is split into chunks of this size for streaming.
    /// When nil (default), text is emitted as a single delta.
    var textChunkSize: Int?

    init(responses: [LLMResponse]) {
        self.responses = responses
    }

    func chat(conversation: LLM.Conversation) -> AsyncThrowingStream<LLM.StreamEvent, Error> {
        receivedConversations.append(conversation)
        guard callCount < responses.count else {
            fatalError("MockLLMService: no more responses (call \(callCount + 1), only \(responses.count) responses)")
        }
        let response = responses[callCount]
        callCount += 1
        let chunkSize = textChunkSize

        return AsyncThrowingStream { continuation in
            // Emit thinking deltas first
            if let thinking = response.thinking, !thinking.isEmpty {
                if let size = chunkSize {
                    for chunk in thinking.chunked(into: size) {
                        continuation.yield(.thinkingDelta(chunk))
                    }
                } else {
                    continuation.yield(.thinkingDelta(thinking))
                }
            }

            // Emit text deltas
            if let text = response.text, !text.isEmpty {
                if let size = chunkSize {
                    for chunk in text.chunked(into: size) {
                        continuation.yield(.textDelta(chunk))
                    }
                } else {
                    continuation.yield(.textDelta(text))
                }
            }

            // Emit completed with a ConversationResponse
            let conversationResponse = LLM.ConversationResponse(
                text: response.text,
                thinking: response.thinking,
                toolCalls: response.toolCalls.map { req in
                    LLM.OpenAICompatibleAPI.ToolCall(
                        id: req.toolCallId,
                        type: "function",
                        function: LLM.OpenAICompatibleAPI.FunctionCall(
                            name: req.name,
                            arguments: req.arguments
                        )
                    )
                },
                conversation: response.conversation,
                rawResponse: LLM.OpenAICompatibleAPI.ChatCompletionResponse(
                    usage: LLM.OpenAICompatibleAPI.ChatCompletionResponse.Usage(
                        prompt_tokens: response.usage.promptTokens,
                        completion_tokens: response.usage.completionTokens,
                        total_tokens: response.usage.totalTokens
                    )
                )
            )
            continuation.yield(.completed(conversationResponse))
            continuation.finish()
        }
    }
}

// MARK: - Helpers

extension LLMResponse {
    /// Creates a text-only response with no tool calls.
    static func textOnly(
        _ text: String,
        usage: TokenUsage = TokenUsage(promptTokens: 10, completionTokens: 5, totalTokens: 15),
        conversation: LLM.Conversation = LLM.Conversation(systemPrompt: "test")
    ) -> LLMResponse {
        LLMResponse(
            text: text,
            toolCalls: [],
            usage: usage,
            conversation: conversation
        )
    }

    /// Creates a response with thinking content and text.
    static func withThinking(
        _ thinking: String,
        text: String,
        usage: TokenUsage = TokenUsage(promptTokens: 10, completionTokens: 5, totalTokens: 15),
        conversation: LLM.Conversation = LLM.Conversation(systemPrompt: "test")
    ) -> LLMResponse {
        LLMResponse(
            text: text,
            thinking: thinking,
            toolCalls: [],
            usage: usage,
            conversation: conversation
        )
    }

    /// Creates a response with tool calls and optional text.
    static func withToolCalls(
        _ toolCalls: [ToolRequest],
        text: String? = nil,
        usage: TokenUsage = TokenUsage(promptTokens: 10, completionTokens: 5, totalTokens: 15),
        conversation: LLM.Conversation = LLM.Conversation(systemPrompt: "test")
    ) -> LLMResponse {
        LLMResponse(
            text: text,
            toolCalls: toolCalls,
            usage: usage,
            conversation: conversation
        )
    }
}

// MARK: - String chunking

private extension String {
    func chunked(into size: Int) -> [String] {
        var chunks = [String]()
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[start ..< end]))
            start = end
        }
        return chunks
    }
}
