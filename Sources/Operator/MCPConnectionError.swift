import Foundation

/// Errors that can occur when working with an ``MCPConnection``.
public enum MCPConnectionError: Error, LocalizedError, Sendable {
    /// The connection has not been established yet.
    ///
    /// Call ``MCPConnection/connect()`` before attempting to list tools
    /// or perform other operations.
    case notConnected

    /// The connection has already been established.
    case alreadyConnected

    /// An MCP tool call reported an error.
    case toolCallFailed(toolName: String, message: String)

    /// The MCP server returned a tool schema that could not be converted.
    case schemaConversionFailed(toolName: String, underlyingError: any Error)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            "MCP connection has not been established. Call connect() first."
        case .alreadyConnected:
            "MCP connection is already established."
        case let .toolCallFailed(name, message):
            "MCP tool '\(name)' returned an error: \(message)"
        case let .schemaConversionFailed(name, error):
            "Failed to convert schema for MCP tool '\(name)': \(error.localizedDescription)"
        }
    }
}
