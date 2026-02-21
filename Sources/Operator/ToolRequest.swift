/// A tool call requested by the LLM.
///
/// Represents the LLM's intent to call a tool. Used in
/// ``Operation/toolsRequested(_:)`` and as a key in tool
/// completion/failure events.
public struct ToolRequest: Friendly {
    /// The name of the tool to call.
    public let name: String

    /// The raw arguments string from the LLM.
    public let arguments: String

    /// The unique identifier for this tool call.
    public let toolCallId: String

    /// Creates a tool request with the given name, arguments, and call ID.
    public init(name: String, arguments: String, toolCallId: String) {
        self.name = name
        self.arguments = arguments
        self.toolCallId = toolCallId
    }
}
