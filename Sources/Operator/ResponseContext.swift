/// The context available to middleware after an LLM response.
///
/// Middleware can inspect the response text and thinking, and modify
/// tool calls before they are processed by the agent loop.
///
/// Text and thinking content are read-only because they have already
/// been streamed to consumers by the time `afterResponse` runs.
/// To suppress output, middleware should throw to stop the agent.
public struct ResponseContext: Friendly {
    /// The text content of the LLM's response, if any.
    ///
    /// Read-only — text has already been streamed to consumers as
    /// incremental deltas before `afterResponse` middleware runs.
    public let responseText: String?

    /// Extended thinking or reasoning content from the LLM, if any.
    ///
    /// Read-only — thinking has already been streamed to consumers as
    /// incremental deltas before `afterResponse` middleware runs.
    public let thinking: String?

    /// The tool calls parsed from the LLM's response.
    ///
    /// Middleware may modify this array to filter or adjust tool calls.
    public var toolCalls: [ToolRequest]

    /// Creates a response context with the given text, thinking, and tool calls.
    public init(responseText: String? = nil, thinking: String? = nil, toolCalls: [ToolRequest] = []) {
        self.responseText = responseText
        self.thinking = thinking
        self.toolCalls = toolCalls
    }
}
