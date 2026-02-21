import Foundation
import LLM

/// A single tool the LLM can call.
///
/// Conform to ``ToolProvider`` directly when you need full control over
/// the tool definition and execution logic. For most tools, use the
/// ``Tool(name:description:input:execute:)`` factory function instead.
///
/// See <doc:ToolsAndOperables> for usage guidance.
public protocol ToolProvider: Sendable {
    /// The LLM-facing definition: name, description, and parameter schema.
    var definition: LLM.OpenAICompatibleAPI.ToolDefinition { get }

    /// Executes the tool with the given arguments.
    ///
    /// - Parameter arguments: The decoded arguments from the LLM's tool call.
    /// - Returns: The result to feed back to the LLM.
    func call(arguments: ToolArguments) async throws -> ToolOutput
}
