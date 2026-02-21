import Foundation

/// A message in a conversation, wrapping the essential fields without
/// exposing LLM wire types.
///
/// Operator uses `Message` internally for middleware contexts.
/// Conversion to and from ``LLM/OpenAICompatibleAPI/ChatMessage``
/// is handled by the Operative.
public struct Message: Friendly {
    /// The role of the message sender.
    public enum Role: String, Friendly {
        /// A system-level instruction.
        case system
        /// A user-provided message.
        case user
        /// An assistant (LLM) response.
        case assistant
        /// A tool result.
        case tool
    }

    /// The role of the message sender.
    public var role: Role

    /// The text content of the message, if any.
    public var content: String?

    /// The tool call ID this message responds to, if this is a tool result.
    public var toolCallId: String?

    /// The tool calls requested by the assistant, if any.
    ///
    /// Preserving this field ensures that assistant messages with tool calls
    /// survive middleware round-trips without data loss.
    public var toolCalls: [ToolCallInfo]?

    /// Creates a message with the given role, content, and optional tool call ID.
    public init(role: Role, content: String? = nil, toolCallId: String? = nil, toolCalls: [ToolCallInfo]? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }

    /// Preserved tool call information from an assistant message.
    public struct ToolCallInfo: Friendly {
        /// The unique ID for this tool call.
        public var id: String
        /// The tool name.
        public var name: String
        /// The JSON-encoded arguments.
        public var arguments: String

        public init(id: String, name: String, arguments: String) {
            self.id = id
            self.name = name
            self.arguments = arguments
        }
    }
}
