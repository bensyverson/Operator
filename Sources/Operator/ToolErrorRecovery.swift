/// How to recover when a tool throws an error during execution.
///
/// Returned by ``Middleware/onToolError(_:context:)``.
public enum ToolErrorRecovery: Friendly {
    /// Feed the error message back to the LLM as a tool result,
    /// allowing it to adapt or retry with different arguments.
    case feedbackToLLM(String)

    /// Propagate the error, halting the agent loop.
    case `throw`
}
