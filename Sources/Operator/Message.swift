import Foundation
import LLM

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

    /// The content parts of the message.
    ///
    /// A message may contain text, images, PDFs, or any combination.
    /// Use ``textContent`` for a convenience accessor that joins all text parts.
    public var content: [ContentPart]

    /// The tool call ID this message responds to, if this is a tool result.
    public var toolCallId: String?

    /// The tool calls requested by the assistant, if any.
    ///
    /// Preserving this field ensures that assistant messages with tool calls
    /// survive middleware round-trips without data loss.
    public var toolCalls: [ToolCallInfo]?

    /// Creates a message with the given role, content parts, and optional tool metadata.
    public init(
        role: Role,
        content: [ContentPart] = [],
        toolCallId: String? = nil,
        toolCalls: [ToolCallInfo]? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }

    /// Creates a message with text content.
    ///
    /// This convenience initializer wraps a string into a single ``ContentPart/text(_:)``
    /// part, or produces an empty content array if `nil` is passed.
    public init(
        role: Role,
        content: String?,
        toolCallId: String? = nil,
        toolCalls: [ToolCallInfo]? = nil
    ) {
        self.role = role
        self.content = content.map { [.text($0)] } ?? []
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }

    /// The joined text content of this message, or `nil` if there are no text parts.
    public var textContent: String? {
        let texts = content.compactMap(\.textContent)
        return texts.isEmpty ? nil : texts.joined()
    }

    /// Whether this message contains any media (images, PDFs, etc.).
    public var hasMedia: Bool {
        content.contains { $0.isMedia }
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
