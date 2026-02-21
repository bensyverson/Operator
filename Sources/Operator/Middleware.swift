/// A composable interception point in the agent loop.
///
/// Middleware provides four hooks corresponding to stages in the
/// agent loop. All methods have default no-op implementations,
/// so each middleware only handles the stages it cares about.
///
/// See <doc:Middleware> for detailed documentation and examples.
public protocol Middleware: Sendable {
    /// Transform or reject messages before they are sent to the LLM.
    ///
    /// Throw to abort the current turn entirely.
    func beforeRequest(_ context: inout RequestContext) async throws

    /// Transform or reject the LLM's response before it is processed.
    ///
    /// Throw to abort processing of this response.
    func afterResponse(_ context: inout ResponseContext) async throws

    /// Approve, modify, or reject tool calls before execution.
    ///
    /// Receives the full batch of tool calls from a single LLM response.
    /// Set each call's ``ToolCallContext/decision`` to control execution.
    func beforeToolCalls(_ calls: inout [ToolCallContext]) async throws

    /// Handle a tool execution error and return a recovery strategy.
    ///
    /// The default returns ``ToolErrorRecovery/feedbackToLLM(_:)``
    /// with the error's localized description.
    func onToolError(_ error: Error, context: ToolCallContext) async throws -> ToolErrorRecovery
}

// MARK: - Default implementations

public extension Middleware {
    func beforeRequest(_: inout RequestContext) async throws {}
    func afterResponse(_: inout ResponseContext) async throws {}
    func beforeToolCalls(_: inout [ToolCallContext]) async throws {}

    func onToolError(_ error: Error, context _: ToolCallContext) async throws -> ToolErrorRecovery {
        .feedbackToLLM(error.localizedDescription)
    }
}
