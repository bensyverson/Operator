/// A discrete, observable moment in the agent's lifecycle.
///
/// The Operative emits an `AsyncSequence` of `Operation` values as it
/// runs. Operations are read-only — to change agent behavior, use
/// ``Middleware``.
///
/// Cannot conform to `Equatable`/`Codable` because some cases carry
/// ``ToolError`` which wraps `any Error`.
public enum Operation: Sendable {
    /// A new turn of the agent loop has started.
    case turnStarted(TurnContext)

    /// Extended thinking or reasoning content from the LLM.
    case thinking(String)

    /// Resource utilization pressure signal.
    case pressure(PressureInfo)

    /// A chunk of streamed text from the LLM.
    case text(String)

    /// The LLM requested one or more tool calls.
    case toolsRequested([ToolRequest])

    /// Middleware rejected one or more tool calls.
    case toolsRejected([ToolRejection])

    /// A tool finished executing successfully.
    case toolCompleted(ToolRequest, ToolOutput)

    /// A tool threw an error during execution.
    case toolFailed(ToolRequest, ToolError)

    /// A turn of the agent loop has completed.
    case turnCompleted(TurnResult)

    /// The agent finished naturally with a final result.
    case completed(OperativeResult)

    /// The agent was halted by a budget constraint or external signal.
    case stopped(StopReason)
}
