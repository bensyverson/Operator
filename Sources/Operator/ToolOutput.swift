import Foundation
import LLM

/// The result returned by a tool after execution.
///
/// Can be constructed from a plain string, an array of lines, or by
/// JSON-encoding an `Encodable` value. Use ``stop(reason:)`` to signal
/// that the Operative should stop after processing this result.
public struct ToolOutput: Friendly {
    /// The string content of the tool result.
    public let content: String

    /// Whether this output signals the Operative to stop.
    public let shouldStop: Bool

    /// Creates a tool output from a plain string.
    public init(_ text: String) {
        content = text
        shouldStop = false
    }

    /// Creates a tool output by joining lines with newlines.
    public init(_ lines: [String]) {
        content = lines.joined(separator: "\n")
        shouldStop = false
    }

    /// Creates a tool output by JSON-encoding an `Encodable` value.
    public init(encoding value: some Encodable) throws {
        let data = try JSONEncoder().encode(value)
        content = String(decoding: data, as: UTF8.self)
        shouldStop = false
    }

    /// Creates a tool output that signals the Operative to stop.
    public static func stop(reason: String) -> ToolOutput {
        ToolOutput(content: reason, shouldStop: true)
    }

    /// Private memberwise init for stop factory
    private init(content: String, shouldStop: Bool) {
        self.content = content
        self.shouldStop = shouldStop
    }
}
