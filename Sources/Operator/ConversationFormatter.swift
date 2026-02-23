import LLM

/// Formats a sequence of ``LLM/OpenAICompatibleAPI/ChatMessage`` values
/// into a human-readable plain-text transcript.
///
/// This is used internally by ``AppleIntelligenceService`` to pass
/// conversation history to the on-device model as a single text block.
/// It is not behind `#if canImport(FoundationModels)` so it can be
/// unit tested on any platform.
enum ConversationFormatter {
    /// Formats chat messages into a plain-text transcript.
    ///
    /// Each message is rendered as `[Role]: content` on its own line.
    /// Messages with `nil` content and no tool calls are skipped.
    /// Assistant messages that contain tool calls but no text content
    /// are rendered as `[Assistant]: [Called tool: name]` or
    /// `[Assistant]: [Called tools: name1, name2]`.
    ///
    /// - Parameter messages: The messages to format.
    /// - Returns: A newline-separated transcript, or an empty string
    ///   if there are no formattable messages.
    static func format(_ messages: some Collection<LLM.OpenAICompatibleAPI.ChatMessage>) -> String {
        var lines: [String] = []

        for message in messages {
            let label = switch message.role {
            case .system: "System"
            case .user: "User"
            case .assistant: "Assistant"
            case .tool: "Tool Result"
            }

            // Assistant messages with tool calls but no text content
            if let toolCalls = message.tool_calls, !toolCalls.isEmpty, message.content == nil {
                let names = toolCalls.map(\.function.name)
                if names.count == 1 {
                    lines.append("[\(label)]: [Called tool: \(names[0])]")
                } else {
                    lines.append("[\(label)]: [Called tools: \(names.joined(separator: ", "))]")
                }
                continue
            }

            // Skip messages with no content
            guard let content = message.content else {
                continue
            }

            lines.append("[\(label)]: \(content)")
        }

        return lines.joined(separator: "\n")
    }
}
