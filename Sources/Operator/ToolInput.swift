import Foundation
import LLM

/// A Codable struct that defines tool parameters.
///
/// Operator auto-generates JSON Schema from the Codable structure
/// combined with the ``paramDescriptions`` dictionary. See
/// <doc:ToolInput> for how schema extraction works.
///
/// ```swift
/// struct SearchInput: ToolInput {
///     let query: String
///     let maxResults: Int?
///
///     static var paramDescriptions: [String: String] {
///         [
///             "query": "The search query",
///             "maxResults": "Maximum number of results to return",
///         ]
///     }
/// }
/// ```
public protocol ToolInput: Codable, Sendable {
    /// Human-readable descriptions for each parameter, keyed by property name.
    static var paramDescriptions: [String: String] { get }
}
