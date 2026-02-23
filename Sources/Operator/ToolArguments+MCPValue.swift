import Foundation
import MCP

extension ToolArguments {
    /// Converts the raw JSON arguments into MCP `Value` entries.
    ///
    /// This leverages both types' `Codable` conformance: the raw JSON bytes
    /// are decoded directly as `[String: MCP.Value]`.
    ///
    /// - Returns: A dictionary mapping argument names to their ``MCP/Value`` representations.
    /// - Throws: If the raw data cannot be decoded.
    func toMCPValues() throws -> [String: MCP.Value] {
        try JSONDecoder().decode([String: MCP.Value].self, from: rawData)
    }
}
