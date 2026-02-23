#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    import LLM

    /// Wraps an Apple `FoundationModels.Tool` as an Operator ``ToolProvider``,
    /// allowing Apple-native tools to be used with any LLM (Claude, GPT, etc.)
    /// through Operator's agent loop.
    ///
    /// Two initializers are available:
    ///
    /// - ``init(tool:parameterSchema:)``: You provide the JSON Schema for
    ///   the tool's parameters explicitly.
    /// - ``init(tool:)``: Available when the tool's `Arguments` type also
    ///   conforms to ``ToolInput``, which lets Operator auto-extract the
    ///   schema via ``SchemaExtractingDecoder``.
    ///
    /// > Important: The tool's `Arguments` type must conform to `Decodable`
    /// > so that Operator can decode JSON arguments from the LLM into the
    /// > type the Apple tool expects. `@Generable` does **not** synthesize
    /// > `Decodable` automatically — add `Codable` conformance to your
    /// > `@Generable` struct (e.g. `@Generable struct MyArgs: Codable { … }`).
    ///
    /// See <doc:AppleIntelligence> for usage guidance.
    @available(macOS 26.0, iOS 26.0, *)
    public struct AppleToolAdapter<T: FoundationModels.Tool>: ToolProvider
        where T.Arguments: Decodable
    {
        /// The tool definition exposed to the LLM.
        public let definition: LLM.OpenAICompatibleAPI.ToolDefinition

        private let tool: T

        /// Creates an adapter with an explicit parameter schema.
        ///
        /// Use this initializer when the tool's `Arguments` type does not
        /// conform to ``ToolInput`` or when you want full control over the
        /// schema sent to the LLM.
        ///
        /// - Parameters:
        ///   - tool: The Apple `FoundationModels.Tool` to wrap.
        ///   - parameterSchema: The JSON Schema describing the tool's parameters.
        public init(tool: T, parameterSchema: LLM.OpenAICompatibleAPI.JSONSchema) {
            self.tool = tool
            definition = LLM.OpenAICompatibleAPI.ToolDefinition(
                function: LLM.OpenAICompatibleAPI.FunctionDefinition(
                    name: tool.name,
                    description: tool.description,
                    parameters: parameterSchema
                )
            )
        }

        /// Creates an adapter that auto-extracts the parameter schema.
        ///
        /// Available when `T.Arguments` conforms to both `Decodable` and
        /// ``ToolInput``. The schema is extracted via ``SchemaExtractingDecoder``.
        ///
        /// - Parameter tool: The Apple `FoundationModels.Tool` to wrap.
        /// - Throws: ``SchemaExtractionError`` if schema extraction fails.
        public init(tool: T) throws where T.Arguments: ToolInput {
            self.tool = tool
            let schema = try SchemaExtractingDecoder.extractSchema(from: T.Arguments.self)
            definition = LLM.OpenAICompatibleAPI.ToolDefinition(
                function: LLM.OpenAICompatibleAPI.FunctionDefinition(
                    name: tool.name,
                    description: tool.description,
                    parameters: schema
                )
            )
        }

        /// Decodes the LLM's JSON arguments and calls the Apple tool.
        ///
        /// - Parameter arguments: The raw JSON arguments from the LLM.
        /// - Returns: The tool's output as an Operator ``ToolOutput``.
        public func call(arguments: ToolArguments) async throws -> Operator.ToolOutput {
            let decoded = try JSONDecoder().decode(T.Arguments.self, from: arguments.rawData)
            let result = try await tool.call(arguments: decoded)
            return Operator.ToolOutput(String(describing: result))
        }
    }
#endif
