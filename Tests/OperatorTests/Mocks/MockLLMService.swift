import LLM
@testable import Operator

/// A mock LLM service that returns scripted responses in order.
final class MockLLMService: LLMService, @unchecked Sendable {
    var responses: [LLMResponse]
    var callCount = 0
    var receivedConversations: [LLM.Conversation] = []

    init(responses: [LLMResponse]) {
        self.responses = responses
    }

    func chat(conversation: LLM.Conversation) async throws -> LLMResponse {
        receivedConversations.append(conversation)
        guard callCount < responses.count else {
            fatalError("MockLLMService: no more responses (call \(callCount + 1), only \(responses.count) responses)")
        }
        let response = responses[callCount]
        callCount += 1
        return response
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
