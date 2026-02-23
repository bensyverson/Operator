import Foundation
import LLM
import MCP

/// A ``ToolProvider`` that proxies calls to a single MCP tool through
/// an ``MCPConnection``.
///
/// Created internally by ``MCPConnection/operables()`` — not intended
/// for direct construction.
struct MCPToolProvider: ToolProvider {
    let definition: LLM.OpenAICompatibleAPI.ToolDefinition
    private let toolName: String
    private let connection: MCPConnection

    init(mcpTool: Tool, connection: MCPConnection) throws {
        toolName = mcpTool.name

        let schema: LLM.OpenAICompatibleAPI.JSONSchema = try mcpTool.inputSchema.toJSONSchema()

        let function = LLM.OpenAICompatibleAPI.FunctionDefinition(
            name: mcpTool.name,
            description: mcpTool.description ?? "",
            parameters: schema
        )

        definition = LLM.OpenAICompatibleAPI.ToolDefinition(function: function)
        self.connection = connection
    }

    func call(arguments: ToolArguments) async throws -> ToolOutput {
        try await connection.callTool(name: toolName, arguments: arguments)
    }
}
