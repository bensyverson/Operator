import LLM

/// Normalized LLM response used by the agent loop and orchestration layers.
///
/// Contains the response text, parsed tool calls, token usage,
/// and the updated conversation with the assistant's message appended.
/// Built from the `.completed` event of a ``LLM/StreamEvent`` stream.
public struct LLMResponse: Sendable {
    /// The text content of the response, if any.
    public let text: String?

    /// Extended thinking or reasoning content, if any.
    public let thinking: String?

    /// Tool calls requested by the LLM.
    public let toolCalls: [ToolRequest]

    /// Token usage for this request.
    public let usage: TokenUsage

    /// The conversation with the assistant's response appended.
    public let conversation: LLM.Conversation

    /// Creates an LLM response from a completed conversation response.
    public init(from response: LLM.ConversationResponse) {
        text = response.text
        thinking = response.thinking
        toolCalls = response.toolCalls.map { ToolRequest(from: $0) }
        usage = TokenUsage.from(response.rawResponse.usage)
        conversation = response.conversation
    }

    /// Creates an LLM response with explicit values.
    public init(
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
