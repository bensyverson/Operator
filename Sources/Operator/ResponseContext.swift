/// The context available to middleware after an LLM response.
///
/// Middleware can inspect or modify the response text and tool calls
/// before they are processed by the agent loop.
public struct ResponseContext: Friendly {
    /// The text content of the LLM's response, if any.
    public var responseText: String?

    /// Extended thinking or reasoning content from the LLM, if any.
    public var thinking: String?

    /// The tool calls parsed from the LLM's response.
    public var toolCalls: [ToolRequest]

    /// Creates a response context with the given text, thinking, and tool calls.
    public init(responseText: String? = nil, thinking: String? = nil, toolCalls: [ToolRequest] = []) {
        self.responseText = responseText
        self.thinking = thinking
        self.toolCalls = toolCalls
    }
}
