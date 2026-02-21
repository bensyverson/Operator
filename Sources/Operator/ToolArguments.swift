import Foundation
import LLM

/// Typed accessors over raw JSON tool arguments.
///
/// Stores the raw JSON bytes internally, decoding values on demand
/// via ``require(_:as:)`` and ``optional(_:as:)``.
public struct ToolArguments: Friendly {
    /// The raw JSON bytes of the arguments.
    public let rawData: Data

    /// Creates tool arguments from a JSON string.
    ///
    /// Validates that the string is valid JSON before storing.
    /// - Throws: If the string is not valid JSON.
    public init(fromJSON jsonString: String) throws {
        let data = Data(jsonString.utf8)
        // Validate it's a JSON object
        _ = try JSONSerialization.jsonObject(with: data, options: [])
        rawData = data
    }

    /// Gets a required argument value by key.
    ///
    /// - Parameters:
    ///   - key: The argument name.
    ///   - type: The expected type (inferred by default).
    /// - Returns: The decoded value.
    /// - Throws: If the key is missing or the value can't be decoded as `T`.
    public func require<T: Decodable>(_ key: String, as _: T.Type = T.self) throws -> T {
        let dict = try JSONDecoder().decode([String: JSONValue].self, from: rawData)
        guard let jsonValue = dict[key] else {
            throw ToolArgumentsError.missingKey(key)
        }
        let valueData = try JSONEncoder().encode(jsonValue)
        return try JSONDecoder().decode(T.self, from: valueData)
    }

    /// Gets an optional argument value by key.
    ///
    /// - Parameters:
    ///   - key: The argument name.
    ///   - type: The expected type (inferred by default).
    /// - Returns: The decoded value, or `nil` if the key is missing.
    public func optional<T: Decodable>(_ key: String, as type: T.Type = T.self) -> T? {
        try? require(key, as: type)
    }

    /// Errors that can occur when accessing tool arguments.
    public enum ToolArgumentsError: Error, LocalizedError {
        case missingKey(String)

        public var errorDescription: String? {
            switch self {
            case let .missingKey(key):
                "Required argument '\(key)' is missing"
            }
        }
    }
}
