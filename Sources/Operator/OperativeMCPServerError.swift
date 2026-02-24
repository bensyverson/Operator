import Foundation

/// Errors that can occur when working with an ``OperativeMCPServer``.
public enum OperativeMCPServerError: Error, LocalizedError, Sendable {
    /// The server is already running.
    case alreadyRunning

    /// The server is not running.
    case notRunning

    /// A required parameter was missing from the tool call.
    case missingRequiredParameter(String)

    /// The requested session was not found.
    case sessionNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "The MCP server is already running."
        case .notRunning:
            "The MCP server is not running."
        case let .missingRequiredParameter(name):
            "Missing required parameter: \(name)"
        case let .sessionNotFound(id):
            "Session not found: \(id)"
        }
    }
}
