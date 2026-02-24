import Foundation
import LLM
import MCP

/// Exposes an ``Operative`` as an MCP tool server.
///
/// `OperativeMCPServer` wraps an Operative and presents it as a single
/// MCP tool called `run`. External clients (Claude Desktop, other MCP
/// clients) can invoke the agent and maintain multi-turn conversations
/// using session IDs.
///
/// ## Usage
///
/// ```swift
/// import MCP
/// import Operator
///
/// let operative = try Operative(
///     name: "Assistant",
///     description: "A helpful assistant",
///     llm: myLLM,
///     systemPrompt: "You are a helpful assistant.",
///     tools: [],
///     budget: Budget(maxTurns: 10)
/// )
///
/// let server = OperativeMCPServer(operative: operative)
///
/// // For stdio (when running as a subprocess):
/// let transport = StdioTransport()
/// try await server.start(transport: transport)
///
/// // For testing:
/// let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
/// try await server.start(transport: serverTransport)
/// ```
///
/// ## The `run` Tool
///
/// The server exposes a single tool:
///
/// | Parameter | Type | Required | Description |
/// |-----------|------|----------|-------------|
/// | `message` | string | yes | The user message to send |
/// | `session_id` | string | no | Continue an existing conversation |
///
/// The response is a JSON object with `text`, `session_id`, and `usage` fields.
/// Pass the returned `session_id` in subsequent calls to continue the conversation.
public actor OperativeMCPServer {
    private let operative: Operative
    private let version: String
    private var server: MCP.Server?
    private var sessions: [String: LLM.Conversation] = [:]

    /// Creates an MCP server that wraps the given operative.
    ///
    /// - Parameters:
    ///   - operative: The operative to expose as an MCP tool.
    ///   - version: The server version string reported to clients.
    public init(operative: Operative, version: String = "1.0.0") {
        self.operative = operative
        self.version = version
    }

    /// Starts the MCP server on the given transport.
    ///
    /// The server will begin accepting tool calls immediately.
    ///
    /// - Parameter transport: The MCP transport to listen on.
    /// - Throws: ``OperativeMCPServerError/alreadyRunning`` if the server
    ///   is already started.
    public func start(transport: any MCP.Transport) async throws {
        guard server == nil else {
            throw OperativeMCPServerError.alreadyRunning
        }

        let mcpServer = MCP.Server(
            name: operative.name,
            version: version,
            capabilities: MCP.Server.Capabilities(tools: MCP.Server.Capabilities.Tools())
        )

        await mcpServer.withMethodHandler(ListTools.self) { [operative] _ in
            let tool = Tool(
                name: "run",
                description: "Send a message to \(operative.name): \(operative.description)",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "message": .object([
                            "type": .string("string"),
                            "description": .string("The user message to send"),
                        ]),
                        "session_id": .object([
                            "type": .string("string"),
                            "description": .string("Continue an existing conversation. Omit to start a new session."),
                        ]),
                    ]),
                    "required": .array([.string("message")]),
                ])
            )
            return ListTools.Result(tools: [tool])
        }

        await mcpServer.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self else {
                return CallTool.Result(
                    content: [.text("Server is shutting down")],
                    isError: true
                )
            }
            return await handleCallTool(params)
        }

        try await mcpServer.start(transport: transport)
        server = mcpServer
    }

    /// Stops the MCP server.
    ///
    /// This method is idempotent — calling it when already stopped has no effect.
    /// Active sessions are preserved in memory but will not be accessible until
    /// the server is restarted.
    public func stop() async {
        if let server {
            await server.stop()
        }
        server = nil
    }

    // MARK: - Private

    private func handleCallTool(_ params: CallTool.Parameters) async -> CallTool.Result {
        guard params.name == "run" else {
            return CallTool.Result(
                content: [.text("Unknown tool: \(params.name)")],
                isError: true
            )
        }

        // Extract message parameter
        guard let messageValue = params.arguments?["message"],
              case let .string(message) = messageValue
        else {
            return CallTool.Result(
                content: [.text(OperativeMCPServerError.missingRequiredParameter("message").localizedDescription)],
                isError: true
            )
        }

        // Resolve or create session
        let sessionID: String
        var existingConversation: LLM.Conversation?

        if let sessionValue = params.arguments?["session_id"],
           case let .string(requestedSessionID) = sessionValue
        {
            guard let conversation = sessions[requestedSessionID] else {
                return CallTool.Result(
                    content: [.text(OperativeMCPServerError.sessionNotFound(requestedSessionID).localizedDescription)],
                    isError: true
                )
            }
            sessionID = requestedSessionID
            existingConversation = conversation
        } else {
            sessionID = UUID().uuidString
        }

        // Run the operative
        do {
            let stream: OperationStream = if let conversation = existingConversation {
                operative.run(message, continuing: conversation)
            } else {
                operative.run(message)
            }

            let result: OperativeResult = try await stream.result()

            // Store conversation for future turns
            sessions[sessionID] = result.conversation

            // Build response JSON
            let response: [String: Any] = [
                "text": result.text ?? "",
                "session_id": sessionID,
                "usage": [
                    "prompt_tokens": result.usage.promptTokens,
                    "completion_tokens": result.usage.completionTokens,
                    "turns": result.turnsUsed,
                ],
            ]

            let jsonData: Data = try JSONSerialization.data(
                withJSONObject: response,
                options: [.sortedKeys]
            )
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            return CallTool.Result(content: [.text(jsonString)])
        } catch {
            return CallTool.Result(
                content: [.text("Agent error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
}
