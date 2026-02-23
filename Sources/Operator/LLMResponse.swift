import LLM

/// Normalized LLM response used internally by the agent loop.
///
/// Contains the response text, parsed tool calls, token usage,
/// and the updated conversation with the assistant's message appended.
/// Built from the `.completed` event of a ``LLM/StreamEvent`` stream.
struct LLMResponse: Sendable {
    /// The text content of the response, if any.
    let text: String?

    /// Extended thinking or reasoning content, if any.
    let thinking: String?

    /// Tool calls requested by the LLM.
    let toolCalls: [ToolRequest]

    /// Token usage for this request.
    let usage: TokenUsage

    /// The conversation with the assistant's response appended.
    let conversation: LLM.Conversation

    /// Creates an LLM response from a completed conversation response.
    init(from response: LLM.ConversationResponse) {
        text = response.text
        thinking = response.thinking
        toolCalls = response.toolCalls.map { ToolRequest(from: $0) }
        usage = TokenUsage.from(response.rawResponse.usage)
        conversation = response.conversation
    }

    /// Creates an LLM response with explicit values (used by tests).
    init(
        text: String?,
        thinking: String? = nil,
        toolCalls: [ToolRequest],
        usage: TokenUsage,
        conversation: LLM.Conversation
    ) {
        self.text = text
        self.thinking = thinking
        self.toolCalls = toolCalls
        self.usage = usage
        self.conversation = conversation
    }
}
