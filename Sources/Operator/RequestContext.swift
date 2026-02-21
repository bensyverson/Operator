import LLM

/// The context available to middleware before an LLM request.
///
/// Middleware can modify messages (e.g. filtering content) or
/// throw to abort the request entirely.
public struct RequestContext: Friendly {
    /// The messages that will be sent to the LLM.
    public var messages: [Message]

    /// The tool definitions that will accompany the request.
    public var toolDefinitions: [LLM.OpenAICompatibleAPI.ToolDefinition]

    /// Creates a request context with the given messages and tool definitions.
    public init(
        messages: [Message],
        toolDefinitions: [LLM.OpenAICompatibleAPI.ToolDefinition]
    ) {
        self.messages = messages
        self.toolDefinitions = toolDefinitions
    }
}
