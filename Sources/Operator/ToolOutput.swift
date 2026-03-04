import Foundation
import LLM

/// The result returned by a tool after execution.
///
/// Can be constructed from a plain string, an array of lines, multimodal
/// content parts, or by JSON-encoding an `Encodable` value.
/// Use ``stop(reason:)`` to signal that the Operative should stop after
/// processing this result.
public struct ToolOutput: Friendly {
    /// The content parts of the tool result.
    public let content: [ContentPart]

    /// Whether this output signals the Operative to stop.
    public let shouldStop: Bool

    /// The joined text content of this output, or `nil` if there are no text parts.
    public var textContent: String? {
        let texts = content.compactMap(\.textContent)
        return texts.isEmpty ? nil : texts.joined()
    }

    /// Creates a tool output from multimodal content parts.
    public init(_ parts: [ContentPart]) {
        content = parts
        shouldStop = false
    }

    /// Creates a tool output from a plain string.
    public init(_ text: String) {
        content = [.text(text)]
        shouldStop = false
    }

    /// Creates a tool output by joining lines with newlines.
    public init(_ lines: [String]) {
        content = [.text(lines.joined(separator: "\n"))]
        shouldStop = false
    }

    /// Creates a tool output by JSON-encoding an `Encodable` value.
    public init(encoding value: some Encodable) throws {
        let data = try JSONEncoder().encode(value)
        content = [.text(String(decoding: data, as: UTF8.self))]
        shouldStop = false
    }

    /// Creates a tool output that signals the Operative to stop.
    public static func stop(reason: String) -> ToolOutput {
        ToolOutput(content: [.text(reason)], shouldStop: true)
    }

    /// Private memberwise init for stop factory.
    private init(content: [ContentPart], shouldStop: Bool) {
        self.content = content
        self.shouldStop = shouldStop
    }
}
