import Foundation

/// Errors thrown by the ``Operative`` or its convenience methods.
public enum OperativeError: Error, LocalizedError, Sendable {
    /// The Operative was stopped by a budget constraint or explicit signal.
    case stopped(StopReason)

    /// The operation stream ended without a terminal event.
    case unexpectedEnd

    /// Two or more tools share the same name.
    case duplicateToolName(String)

    /// The model requested a tool that is not in this agent's registry.
    case unknownTool(String)

    public var errorDescription: String? {
        switch self {
        case let .stopped(reason):
            "Operative stopped: \(reason)"
        case .unexpectedEnd:
            "Operation stream ended without a terminal event"
        case let .duplicateToolName(name):
            "Duplicate tool name: '\(name)'"
        case let .unknownTool(name):
            "Unknown tool '\(name)' — the model requested a tool that is not in this agent's registry."
        }
    }
}
