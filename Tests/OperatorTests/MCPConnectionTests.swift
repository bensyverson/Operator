import Foundation
import LLM
import MCP
@testable import Operator
import Testing

/// Creates a connected MCP client/server pair for testing.
///
/// The server is configured with the given tools and a handler that
/// dispatches tool calls to the provided closure.
private func createTestEnvironment(
    tools: [Tool],
    handler: @escaping @Sendable (String, [String: MCP.Value]?) async throws -> [Tool.Content]
) async throws -> (connection: MCPConnection, server: MCP.Server) {
    let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()

    let server = MCP.Server(
        name: "test-server",
        version: "1.0.0",
        capabilities: MCP.Server.Capabilities(tools: MCP.Server.Capabilities.Tools())
    )

    await server.withMethodHandler(ListTools.self) { _ in
        ListTools.Result(tools: tools)
    }

    await server.withMethodHandler(CallTool.self) { params in
        let content = try await handler(params.name, params.arguments)
        return CallTool.Result(content: content)
    }

    try await server.start(transport: serverTransport)

    let connection = MCPConnection(
        name: "test",
        transport: .custom(clientTransport)
    )

    return (connection, server)
}

@Suite("MCP Connection Lifecycle")
struct MCPConnectionLifecycleTests {
    @Test("Connect and disconnect")
    func connectAndDisconnect() async throws {
        let (connection, server) = try await createTestEnvironment(tools: [], handler: { _, _ in [] })
        try await connection.connect()
        await connection.disconnect()
        await server.stop()
    }

    @Test("Disconnect is idempotent")
    func disconnectIdempotent() async throws {
        let (connection, server) = try await createTestEnvironment(tools: [], handler: { _, _ in [] })
        try await connection.connect()
        await connection.disconnect()
        await connection.disconnect() // Should not throw
        await server.stop()
    }

    @Test("Operables before connect throws")
    func operablesBeforeConnect() async throws {
        let (clientTransport, _) = await InMemoryTransport.createConnectedPair()
        let connection = MCPConnection(
            name: "test",
            transport: .custom(clientTransport)
        )

        await #expect(throws: MCPConnectionError.self) {
            _ = try await connection.operables()
        }
    }

    @Test("Lists tools as operables")
    func listsToolsAsOperables() async throws {
        let tools: [Tool] = [
            Tool(
                name: "greet",
                description: "Say hello",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "name": .object(["type": .string("string")]),
                    ]),
                    "required": .array([.string("name")]),
                ])
            ),
            Tool(
                name: "add",
                description: "Add two numbers",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "a": .object(["type": .string("integer")]),
                        "b": .object(["type": .string("integer")]),
                    ]),
                    "required": .array([.string("a"), .string("b")]),
                ])
            ),
        ]

        let (connection, server) = try await createTestEnvironment(tools: tools, handler: { _, _ in [] })
        try await connection.connect()

        let operables: [any Operable] = try await connection.operables()
        #expect(operables.count == 1)

        let group: ToolGroup = operables[0].toolGroup
        #expect(group.name == "test")
        #expect(group.tools.count == 2)

        let toolNames: [String] = group.tools.map(\.definition.function.name)
        #expect(toolNames.contains("greet"))
        #expect(toolNames.contains("add"))

        await connection.disconnect()
        await server.stop()
    }
}

@Suite("MCP Tool Proxy")
struct MCPToolProxyCallTests {
    @Test("Forwards arguments and returns text result")
    func forwardsArgumentsAndReturnsResult() async throws {
        nonisolated(unsafe) var receivedName: String?
        nonisolated(unsafe) var receivedArgs: [String: MCP.Value]?

        let tools: [Tool] = [
            Tool(
                name: "greet",
                description: "Say hello",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "name": .object(["type": .string("string")]),
                    ]),
                    "required": .array([.string("name")]),
                ])
            ),
        ]

        let (connection, server) = try await createTestEnvironment(tools: tools) { name, args in
            receivedName = name
            receivedArgs = args
            return [.text("Hello, Alice!")]
        }

        try await connection.connect()
        let operables: [any Operable] = try await connection.operables()
        let tool: any ToolProvider = operables[0].toolGroup.tools[0]

        let args = try ToolArguments(fromJSON: #"{"name": "Alice"}"#)
        let output: ToolOutput = try await tool.call(arguments: args)

        #expect(output.content == "Hello, Alice!")
        #expect(receivedName == "greet")
        #expect(receivedArgs?["name"] == .string("Alice"))

        await connection.disconnect()
        await server.stop()
    }

    @Test("Handles tool with no arguments")
    func handlesNoArguments() async throws {
        let tools: [Tool] = [
            Tool(
                name: "ping",
                description: "Ping the server",
                inputSchema: .object([
                    "type": .string("object"),
                ])
            ),
        ]

        let (connection, server) = try await createTestEnvironment(tools: tools) { _, _ in
            [.text("pong")]
        }

        try await connection.connect()
        let operables: [any Operable] = try await connection.operables()
        let tool: any ToolProvider = operables[0].toolGroup.tools[0]

        let args = try ToolArguments(fromJSON: #"{}"#)
        let output: ToolOutput = try await tool.call(arguments: args)
        #expect(output.content == "pong")

        await connection.disconnect()
        await server.stop()
    }

    @Test("Handles multi-content response")
    func handlesMultiContentResponse() async throws {
        let tools: [Tool] = [
            Tool(
                name: "report",
                description: "Generate a report",
                inputSchema: .object(["type": .string("object")])
            ),
        ]

        let (connection, server) = try await createTestEnvironment(tools: tools) { _, _ in
            [
                .text("Report summary:"),
                .text("- Item 1"),
                .text("- Item 2"),
            ]
        }

        try await connection.connect()
        let operables: [any Operable] = try await connection.operables()
        let tool: any ToolProvider = operables[0].toolGroup.tools[0]

        let args = try ToolArguments(fromJSON: #"{}"#)
        let output: ToolOutput = try await tool.call(arguments: args)
        #expect(output.content == "Report summary:\n- Item 1\n- Item 2")

        await connection.disconnect()
        await server.stop()
    }

    @Test("Handles error result from MCP tool")
    func handlesErrorResult() async throws {
        let tools: [Tool] = [
            Tool(
                name: "fail",
                description: "A tool that fails",
                inputSchema: .object(["type": .string("object")])
            ),
        ]

        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()

        let server = MCP.Server(
            name: "test-server",
            version: "1.0.0",
            capabilities: MCP.Server.Capabilities(tools: MCP.Server.Capabilities.Tools())
        )

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { _ in
            CallTool.Result(content: [.text("Something went wrong")], isError: true)
        }

        try await server.start(transport: serverTransport)

        let connection = MCPConnection(name: "test", transport: .custom(clientTransport))
        try await connection.connect()

        let operables: [any Operable] = try await connection.operables()
        let tool: any ToolProvider = operables[0].toolGroup.tools[0]

        let args = try ToolArguments(fromJSON: #"{}"#)
        await #expect(throws: MCPConnectionError.self) {
            _ = try await tool.call(arguments: args)
        }

        await connection.disconnect()
        await server.stop()
    }

    @Test("Schema conversion produces correct tool definition")
    func schemaConversionProducesCorrectDefinition() async throws {
        let tools: [Tool] = [
            Tool(
                name: "search",
                description: "Search for items",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "query": .object([
                            "type": .string("string"),
                            "description": .string("Search query"),
                        ]),
                        "limit": .object([
                            "type": .string("integer"),
                            "description": .string("Max results"),
                        ]),
                    ]),
                    "required": .array([.string("query")]),
                ])
            ),
        ]

        let (connection, server) = try await createTestEnvironment(tools: tools) { _, _ in [] }
        try await connection.connect()

        let operables: [any Operable] = try await connection.operables()
        let tool: any ToolProvider = operables[0].toolGroup.tools[0]
        let def: LLM.OpenAICompatibleAPI.ToolDefinition = tool.definition

        #expect(def.function.name == "search")
        #expect(def.function.description == "Search for items")
        #expect(def.function.parameters.type == .object)
        #expect(def.function.parameters.properties?["query"]?.type == .string)
        #expect(def.function.parameters.properties?["query"]?.description == "Search query")
        #expect(def.function.parameters.properties?["limit"]?.type == .integer)
        #expect(def.function.parameters.required == ["query"])

        await connection.disconnect()
        await server.stop()
    }

    @Test("Multiple arguments are forwarded correctly")
    func multipleArgumentsForwarded() async throws {
        nonisolated(unsafe) var capturedArgs: [String: MCP.Value]?

        let tools: [Tool] = [
            Tool(
                name: "add",
                description: "Add numbers",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "a": .object(["type": .string("integer")]),
                        "b": .object(["type": .string("integer")]),
                    ]),
                    "required": .array([.string("a"), .string("b")]),
                ])
            ),
        ]

        let (connection, server) = try await createTestEnvironment(tools: tools) { _, args in
            capturedArgs = args
            let a = args?["a"]?.intValue ?? 0
            let b = args?["b"]?.intValue ?? 0
            return [.text("\(a + b)")]
        }

        try await connection.connect()
        let operables: [any Operable] = try await connection.operables()
        let tool: any ToolProvider = operables[0].toolGroup.tools[0]

        let args = try ToolArguments(fromJSON: #"{"a": 3, "b": 4}"#)
        let output: ToolOutput = try await tool.call(arguments: args)

        #expect(output.content == "7")
        #expect(capturedArgs?["a"] == .int(3))
        #expect(capturedArgs?["b"] == .int(4))

        await connection.disconnect()
        await server.stop()
    }
}
