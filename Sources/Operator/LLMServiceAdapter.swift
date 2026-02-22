import LLM

/// Internal adapter that wraps an ``LLM`` actor to conform to ``LLMService``.
///
/// Users never interact with this type directly. The ``Operative``
/// convenience initializer that accepts an ``LLM`` instance creates
/// one automatically.
struct LLMServiceAdapter: LLMService {
    private let llm: LLM

    init(_ llm: LLM) {
        self.llm = llm
    }

    func chat(conversation: LLM.Conversation) async throws -> LLMResponse {
        let response: LLM.ConversationResponse = try await llm.chat(conversation: conversation)
        return LLMResponse(
            text: response.text,
            thinking: response.thinking,
            toolCalls: response.toolCalls.map { ToolRequest(from: $0) },
            usage: TokenUsage.from(response.rawResponse.usage),
            conversation: response.conversation
        )
    }
}
