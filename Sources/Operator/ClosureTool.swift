import Foundation
import LLM

/// A closure-based tool implementation created via the ``Tool(name:description:input:execute:)``
/// and ``Tool(name:description:execute:)`` factory functions.
public struct ClosureTool<Input: ToolInput>: ToolProvider {
    public let definition: ToolDefinition
    private let execute: @Sendable (Input) async throws -> ToolOutput

    init(
        definition: ToolDefinition,
        execute: @escaping @Sendable (Input) async throws -> ToolOutput
    ) {
        self.definition = definition
        self.execute = execute
    }

    public func call(arguments: ToolArguments) async throws -> ToolOutput {
        let input: Input
        do {
            input = try JSONDecoder().decode(Input.self, from: arguments.rawData)
        } catch let error as DecodingError {
            throw ToolError(
                message: Self.describeDecodingError(error, schema: definition.function),
                underlyingError: error
            )
        }
        return try await execute(input)
    }

    /// Builds a human-readable message from a `DecodingError`, using the tool's schema
    /// to list expected parameters so the LLM can self-correct.
    static func describeDecodingError(
        _ error: DecodingError,
        schema: FunctionDefinition
    ) -> String {
        let paramSummary = Self.parameterSummary(schema: schema)

        switch error {
        case let .keyNotFound(key, _):
            return "Missing required parameter '\(key.stringValue)'. \(schema.name) expects: \(paramSummary)."
        case let .typeMismatch(expectedType, context):
            let paramName = context.codingPath.last?.stringValue ?? "unknown"
            return "Wrong type for parameter '\(paramName)': expected \(expectedType). \(schema.name) expects: \(paramSummary)."
        case let .valueNotFound(_, context):
            let paramName = context.codingPath.last?.stringValue ?? "unknown"
            return "Null value for parameter '\(paramName)'. \(schema.name) expects: \(paramSummary)."
        case let .dataCorrupted(context):
            return "Malformed arguments: \(context.debugDescription). \(schema.name) expects: \(paramSummary)."
        @unknown default:
            return "Invalid arguments for \(schema.name). Expected: \(paramSummary)."
        }
    }

    /// Builds a summary like `path (string, required), content (string, required)` from the tool schema.
    private static func parameterSummary(schema: FunctionDefinition) -> String {
        guard let properties = schema.parameters.properties, !properties.isEmpty else {
            return "no parameters"
        }
        let requiredSet = Set(schema.parameters.required ?? [])
        let entries: [String] = properties.keys.sorted().map { key in
            let prop = properties[key]!
            let typeLabel = prop.type.rawValue
            let requiredLabel = requiredSet.contains(key) ? "required" : "optional"
            return "\(key) (\(typeLabel), \(requiredLabel))"
        }
        return entries.joined(separator: ", ")
    }
}

// MARK: - Empty Input

/// A ``ToolInput`` with no parameters, used by no-input tools.
struct EmptyToolInput: ToolInput {
    static var paramDescriptions: [String: String] {
        [:]
    }
}

// MARK: - Factory Functions

/// Creates a closure-based tool with typed input.
///
/// The parameter schema is automatically extracted from the ``ToolInput`` type.
///
/// ```swift
/// try Tool(
///     name: "readFile",
///     description: "Read the contents of a file",
///     input: ReadFileInput.self
/// ) { input in
///     let content = try String(contentsOfFile: input.path, encoding: .utf8)
///     return ToolOutput(content)
/// }
/// ```
///
/// - Parameters:
///   - name: The tool name the LLM will use to invoke it.
///   - description: Human-readable description of what the tool does.
///   - input: The ``ToolInput`` type defining the tool's parameters.
///   - execute: The closure to run when the LLM calls this tool.
/// - Returns: A ``ToolProvider`` ready for use in a ``ToolGroup``.
/// - Throws: ``SchemaExtractionError`` if ``ToolInput/paramDescriptions``
///   contains keys that don't match the type's properties.
public func Tool<Input: ToolInput>(
    name: String,
    description: String,
    input _: Input.Type,
    execute: @escaping @Sendable (Input) async throws -> ToolOutput
) throws -> any ToolProvider {
    let schema = try SchemaExtractingDecoder.extractSchema(from: Input.self)
    let definition = ToolDefinition(
        function: FunctionDefinition(
            name: name,
            description: description,
            parameters: schema
        )
    )
    return ClosureTool<Input>(definition: definition, execute: execute)
}

/// Creates a closure-based tool with no input parameters.
///
/// ```swift
/// Tool(name: "getCurrentTime", description: "Get the current date and time") {
///     ToolOutput(Date.now.formatted())
/// }
/// ```
///
/// - Parameters:
///   - name: The tool name the LLM will use to invoke it.
///   - description: Human-readable description of what the tool does.
///   - execute: The closure to run when the LLM calls this tool.
/// - Returns: A ``ToolProvider`` ready for use in a ``ToolGroup``.
public func Tool(
    name: String,
    description: String,
    execute: @escaping @Sendable () async throws -> ToolOutput
) -> any ToolProvider {
    let definition = ToolDefinition(
        function: FunctionDefinition(
            name: name,
            description: description,
            parameters: JSONSchema.object(properties: [:])
        )
    )
    return ClosureTool<EmptyToolInput>(definition: definition) { _ in
        try await execute()
    }
}
