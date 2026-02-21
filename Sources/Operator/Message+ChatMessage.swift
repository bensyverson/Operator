import LLM

/// Conversion between Operator's ``Message`` and LLM's wire-format ``ChatMessage``.
public extension Message {
    /// Creates a ``Message`` from an LLM wire-format ``ChatMessage``.
    ///
    /// Maps ChatMessage roles to Message roles and preserves content
    /// and tool call ID fields.
    init(from chatMessage: LLM.OpenAICompatibleAPI.ChatMessage) {
        let role: Role = switch chatMessage.role {
        case .system: .system
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        }
        self.init(
            role: role,
            content: chatMessage.content,
            toolCallId: chatMessage.tool_call_id
        )
    }

    /// Converts this ``Message`` to an LLM wire-format ``ChatMessage``.
    func toChatMessage() -> LLM.OpenAICompatibleAPI.ChatMessage {
        let chatRole: LLM.OpenAICompatibleAPI.Role = switch role {
        case .system: .system
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        }
        return LLM.OpenAICompatibleAPI.ChatMessage(
            content: content,
            role: chatRole,
            tool_call_id: toolCallId
        )
    }
}
