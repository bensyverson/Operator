/// Whether a tool call should proceed, be modified, or be rejected.
///
/// Middleware sets this on ``ToolCallContext/decision`` during
/// ``Middleware/beforeToolCalls(_:)``. The default is ``proceed``.
public enum ToolCallDecision: Friendly {
    /// Allow the tool call to proceed as-is.
    case proceed

    /// Allow the tool call with modified arguments.
    case modify(ToolArguments)

    /// Block the tool call. The reason is fed back to the LLM.
    case reject(reason: String)
}
