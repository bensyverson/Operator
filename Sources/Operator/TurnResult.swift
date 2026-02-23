import LLM

/// Summary of what happened during a single agent loop turn.
///
/// Carried by ``Operation/turnCompleted(_:)``.
public struct TurnResult: Friendly {
    /// Token counts for this turn.
    public let usage: TokenUsage

    /// How many tools were called (including rejected).
    public let toolCallCount: Int

    /// Running total of token usage across all turns so far.
    public let cumulativeUsage: TokenUsage

    /// The conversation state at the end of this turn.
    ///
    /// Includes the full message history up to and including this turn's
    /// assistant response and any tool results. Useful for context transfer
    /// when spawning child agents mid-execution.
    public let conversation: LLM.Conversation

    /// Creates a turn result with the given usage, tool call count, cumulative usage, and conversation.
    public init(
        usage: TokenUsage,
        toolCallCount: Int,
        cumulativeUsage: TokenUsage,
        conversation: LLM.Conversation
    ) {
        self.usage = usage
        self.toolCallCount = toolCallCount
        self.cumulativeUsage = cumulativeUsage
        self.conversation = conversation
    }
}
