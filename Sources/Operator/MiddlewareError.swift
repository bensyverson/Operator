import Foundation

/// Errors thrown by built-in middleware.
public enum MiddlewareError: Error, LocalizedError, Sendable {
    /// A known secret was detected in LLM output.
    case secretDetected

    /// A middleware explicitly rejected the request.
    case requestRejected(reason: String)

    public var errorDescription: String? {
        switch self {
        case .secretDetected:
            "A known secret was detected in the response"
        case let .requestRejected(reason):
            "Request rejected: \(reason)"
        }
    }
}
