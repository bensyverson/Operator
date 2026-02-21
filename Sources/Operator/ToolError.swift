/// An error that occurred during tool execution.
///
/// Wraps the error message and the underlying error for inspection.
/// Cannot conform to `Equatable`/`Hashable`/`Codable` because
/// it holds `any Error`, so it conforms to `Error & Sendable` only.
public struct ToolError: Error, Sendable {
    /// A human-readable description of the error.
    public let message: String

    /// The original error thrown by the tool.
    public let underlyingError: any Error

    /// Creates a tool error with a message and the original error.
    public init(message: String, underlyingError: any Error) {
        self.message = message
        self.underlyingError = underlyingError
    }
}
