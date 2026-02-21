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

    /// Creates a message with the given role, content, and optional tool call ID.
    public init(role: Role, content: String? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
    }
}
