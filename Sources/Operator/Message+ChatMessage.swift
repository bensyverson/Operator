import LLM

/// Conversion between Operator's ``Message`` and LLM's wire-format ``ChatMessage``.
public extension Message {
    /// Creates a ``Message`` from an LLM wire-format ``ChatMessage``.
    ///
    /// Maps ChatMessage roles to Message roles and preserves content,
    /// tool call ID, and tool calls fields.
    init(from chatMessage: LLM.OpenAICompatibleAPI.ChatMessage) {
        let role: Role = switch chatMessage.role {
        case .system: .system
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        }
        let toolCalls: [ToolCallInfo]? = chatMessage.tool_calls?.map { call in
            ToolCallInfo(
                id: call.id,
                name: call.function.name,
                arguments: call.function.arguments
            )
        }
        self.init(
            role: role,
            content: chatMessage.content,
            toolCallId: chatMessage.tool_call_id,
            toolCalls: toolCalls
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
        let chatToolCalls: [LLM.OpenAICompatibleAPI.ToolCall]? = toolCalls?.map { info in
            LLM.OpenAICompatibleAPI.ToolCall(
                id: info.id,
                type: "function",
                function: LLM.OpenAICompatibleAPI.FunctionCall(
                    name: info.name,
                    arguments: info.arguments
                )
            )
        }
        return LLM.OpenAICompatibleAPI.ChatMessage(
            content: content,
            role: chatRole,
            tool_calls: chatToolCalls,
            tool_call_id: toolCallId
        )
    }
}
