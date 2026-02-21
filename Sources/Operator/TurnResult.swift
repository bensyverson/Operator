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

    /// Creates a turn result with the given usage, tool call count, and cumulative usage.
    public init(usage: TokenUsage, toolCallCount: Int, cumulativeUsage: TokenUsage) {
        self.usage = usage
        self.toolCallCount = toolCallCount
        self.cumulativeUsage = cumulativeUsage
    }
}
