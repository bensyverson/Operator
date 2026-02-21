import LLM

/// Normalized LLM response, abstracting over provider differences.
///
/// Contains the response text, parsed tool calls, token usage,
/// and the updated conversation with the assistant's message appended.
public struct LLMResponse: Sendable {
    /// The text content of the response, if any.
    public let text: String?

    /// Tool calls requested by the LLM.
    public let toolCalls: [ToolRequest]

    /// Token usage for this request.
    public let usage: TokenUsage

    /// The conversation with the assistant's response appended.
    public let conversation: LLM.Conversation

    /// Creates an LLM response with the given text, tool calls, usage, and conversation.
    public init(
        text: String?,
        toolCalls: [ToolRequest],
        usage: TokenUsage,
        conversation: LLM.Conversation
    ) {
        self.text = text
        self.toolCalls = toolCalls
        self.usage = usage
        self.conversation = conversation
    }
}
