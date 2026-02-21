import LLM

/// Conversion from LLM's wire-format ``ToolCall`` to Operator's ``ToolRequest``.
public extension ToolRequest {
    /// Creates a ``ToolRequest`` from an LLM wire-format ``ToolCall``.
    ///
    /// Maps the tool call's function name and arguments, preserving
    /// the call ID for correlation with tool results.
    init(from toolCall: LLM.OpenAICompatibleAPI.ToolCall) {
        self.init(
            name: toolCall.function.name,
            arguments: toolCall.function.arguments,
            toolCallId: toolCall.id
        )
    }
}
