/// The context available to middleware after an LLM response.
///
/// Middleware can inspect or modify the response text and tool calls
/// before they are processed by the agent loop.
public struct ResponseContext: Friendly {
    /// The text content of the LLM's response, if any.
    public var responseText: String?

    /// The tool calls parsed from the LLM's response.
    public var toolCalls: [ToolRequest]

    public init(responseText: String? = nil, toolCalls: [ToolRequest] = []) {
        self.responseText = responseText
        self.toolCalls = toolCalls
    }
}
