import Foundation
import LLM
import MCP
@testable import Operator
import Testing

@Suite("OperativeMCPServer")
struct OperativeMCPServerTests {
    /// Creates a connected MCP server/client pair for testing.
    private func createTestPair(
        responses: [LLMResponse]
    ) async throws -> (server: OperativeMCPServer, client: MCP.Client) {
        let mockLLM = MockLLMService(responses: responses)
        let operative = try Operative(
            name: "TestAgent",
            description: "A test agent",
            llm: mockLLM,
            systemPrompt: "You are a test agent.",
            tools: [],
            budget: Budget(maxTurns: 10)
        )

        let mcpServer = OperativeMCPServer(operative: operative)
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()

        try await mcpServer.start(transport: serverTransport)

        let client = MCP.Client(name: "test-client", version: "1.0.0")
        try await client.connect(transport: clientTransport)

        return (mcpServer, client)
    }

    /// Parses JSON text content from CallTool response.
    private func parseJSON(from content: [Tool.Content]) throws -> [String: Any] {
        guard case let .text(jsonString) = content.first else {
            Issue.record("Expected text content")
            return [:]
        }
        let data: Data = jsonString.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    @Test("Lists single run tool")
    func listsRunTool() async throws {
        let (server, client) = try await createTestPair(responses: [])

        let (tools, _) = try await client.listTools()
        #expect(tools.count == 1)
        #expect(tools[0].name == "run")
        #expect(tools[0].description?.contains("TestAgent") == true)

        await client.disconnect()
        await server.stop()
    }

    @Test("Run returns text result and session ID")
    func runReturnsResult() async throws {
        let (server, client) = try await createTestPair(responses: [
            .textOnly("Hello from the agent!"),
        ])

        let (content, isError) = try await client.callTool(
            name: "run",
            arguments: ["message": .string("Hi there")]
        )

        #expect(isError != true)

        let json: [String: Any] = try parseJSON(from: content)
        #expect(json["text"] as? String == "Hello from the agent!")
        #expect((json["session_id"] as? String)?.isEmpty == false)
        #expect(json["usage"] != nil)

        await client.disconnect()
        await server.stop()
    }

    @Test("Multi-turn conversation with session ID")
    func multiTurnConversation() async throws {
        let conversation1 = LLM.Conversation(systemPrompt: "test")
        let conversation2 = LLM.Conversation(systemPrompt: "test")

        let (server, client) = try await createTestPair(responses: [
            .textOnly("First response", conversation: conversation1),
            .textOnly("Second response", conversation: conversation2),
        ])

        // First call - creates a session
        let (content1, _) = try await client.callTool(
            name: "run",
            arguments: ["message": .string("Hello")]
        )

        let json1: [String: Any] = try parseJSON(from: content1)
        let sessionID = try #require(json1["session_id"] as? String)

        // Second call - continues the session
        let (content2, isError2) = try await client.callTool(
            name: "run",
            arguments: [
                "message": .string("Follow up"),
                "session_id": .string(sessionID),
            ]
        )

        #expect(isError2 != true)

        let json2: [String: Any] = try parseJSON(from: content2)
        #expect(json2["text"] as? String == "Second response")
        #expect(json2["session_id"] as? String == sessionID)

        await client.disconnect()
        await server.stop()
    }

    @Test("Missing message parameter returns error")
    func missingMessageParameter() async throws {
        let (server, client) = try await createTestPair(responses: [])

        let (content, isError) = try await client.callTool(
            name: "run",
            arguments: [:]
        )

        #expect(isError == true)
        if case let .text(errorText) = content.first {
            #expect(errorText.contains("message"))
        }

        await client.disconnect()
        await server.stop()
    }

    @Test("Unknown session ID returns error")
    func unknownSessionID() async throws {
        let (server, client) = try await createTestPair(responses: [])

        let (content, isError) = try await client.callTool(
            name: "run",
            arguments: [
                "message": .string("Hello"),
                "session_id": .string("nonexistent-session"),
            ]
        )

        #expect(isError == true)
        if case let .text(errorText) = content.first {
            #expect(errorText.contains("nonexistent-session"))
        }

        await client.disconnect()
        await server.stop()
    }

    @Test("Unknown tool name returns error")
    func unknownToolName() async throws {
        let (server, client) = try await createTestPair(responses: [])

        let (content, isError) = try await client.callTool(
            name: "nonexistent_tool",
            arguments: ["message": .string("Hello")]
        )

        #expect(isError == true)
        if case let .text(errorText) = content.first {
            #expect(errorText.contains("nonexistent_tool"))
        }

        await client.disconnect()
        await server.stop()
    }
}
