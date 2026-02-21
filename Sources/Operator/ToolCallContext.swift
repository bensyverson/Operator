/// The context for a single tool call during middleware evaluation.
///
/// Middleware can modify the ``decision`` to approve, modify, or
/// reject the tool call. The ``attemptCount`` tracks how many times
/// this tool call has been attempted (starts at 1).
public struct ToolCallContext: Friendly {
    /// The name of the tool being called.
    public let name: String

    /// The raw arguments string from the LLM.
    public let arguments: String

    /// The unique identifier for this tool call.
    public let toolCallId: String

    /// The middleware's decision about this tool call.
    /// Defaults to ``ToolCallDecision/proceed``.
    public var decision: ToolCallDecision

    /// How many times this tool call has been attempted.
    /// Starts at 1, incremented by the Operative on retries.
    public var attemptCount: Int

    public init(
        name: String,
        arguments: String,
        toolCallId: String,
        decision: ToolCallDecision = .proceed,
        attemptCount: Int = 1
    ) {
        self.name = name
        self.arguments = arguments
        self.toolCallId = toolCallId
        self.decision = decision
        self.attemptCount = attemptCount
    }
}
