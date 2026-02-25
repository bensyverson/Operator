import LLM

/// The context available to middleware before an LLM request.
///
/// Middleware can modify messages (e.g. filtering content) or
/// throw to abort the request entirely.
public struct RequestContext: Friendly {
    /// The messages that will be sent to the LLM.
    public var messages: [Message]

    /// The tool definitions that will accompany the request.
    public var toolDefinitions: [ToolDefinition]

    /// Active pressure signals, if any.
    ///
    /// Middleware can inspect this in ``Middleware/beforeRequest(_:)`` to react
    /// to context or budget pressure (e.g., triggering compaction).
    public var pressure: [PressureInfo]

    /// Creates a request context with the given messages, tool definitions, and pressure signals.
    public init(
        messages: [Message],
        toolDefinitions: [ToolDefinition],
        pressure: [PressureInfo] = []
    ) {
        self.messages = messages
        self.toolDefinitions = toolDefinitions
        self.pressure = pressure
    }
}
