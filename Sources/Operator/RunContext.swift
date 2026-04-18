/// Context passed to ``Middleware/afterRun(_:)`` when the agent's full
/// run completes (a final assistant response with no tool calls).
///
/// A "run" spans from one user message to the agent's final response;
/// a "turn" is one LLM-call iteration of the loop. A run may contain
/// many turns.
public struct RunContext: Friendly {
    /// All messages added to the conversation during this run, in order,
    /// starting from the user message that triggered it and ending with
    /// the final assistant response.
    public let messages: [Message]

    /// Concatenation of every `thinking` block emitted across the run,
    /// separated by double newlines. Empty string if no thinking occurred.
    public let thinking: String

    /// The final assistant text (may be `nil` if the last turn produced
    /// only tool calls, though in practice ``Middleware/afterRun(_:)``
    /// only fires on a no-tool-call terminal turn, so this is typically
    /// non-nil).
    public let finalText: String?

    /// Every tool call requested across the run, in order.
    public let toolCalls: [ToolRequest]

    /// Creates a run context with the given messages, thinking, final
    /// text, and tool calls.
    public init(
        messages: [Message],
        thinking: String,
        finalText: String?,
        toolCalls: [ToolRequest]
    ) {
        self.messages = messages
        self.thinking = thinking
        self.finalText = finalText
        self.toolCalls = toolCalls
    }
}
