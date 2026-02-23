import Foundation
import LLM
import MCP

extension MCP.Value {
    /// Converts an MCP `Value` containing a JSON Schema representation into
    /// an ``LLM/OpenAICompatibleAPI/JSONSchema`` instance.
    ///
    /// This leverages both types' `Codable` conformance: the `Value` is encoded
    /// to JSON bytes, then decoded as `JSONSchema`. Unsupported JSON Schema features
    /// (such as `oneOf`, `anyOf`, `format`, `pattern`, etc.) are silently ignored
    /// because `JSONSchema` has no matching `CodingKeys` for them.
    ///
    /// - Returns: A ``LLM/OpenAICompatibleAPI/JSONSchema`` representing the same schema.
    /// - Throws: If the value cannot be encoded or decoded as a valid `JSONSchema`.
    func toJSONSchema() throws -> LLM.OpenAICompatibleAPI.JSONSchema {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(LLM.OpenAICompatibleAPI.JSONSchema.self, from: data)
    }
}
