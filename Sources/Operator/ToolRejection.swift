/// A tool call that was blocked by middleware.
///
/// Emitted via ``Operation/toolsRejected(_:)`` when
/// ``Middleware/beforeToolCalls(_:)`` sets a tool call's
/// decision to ``ToolCallDecision/reject(reason:)``.
public struct ToolRejection: Friendly {
    /// The original tool call that was rejected.
    public let request: ToolRequest

    /// Why the tool call was blocked.
    public let reason: String

    /// Creates a tool rejection for the given request and reason.
    public init(request: ToolRequest, reason: String) {
        self.request = request
        self.reason = reason
    }
}
