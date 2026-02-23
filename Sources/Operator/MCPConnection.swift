import Foundation
import MCP

#if os(macOS) || os(Linux)
    #if canImport(System)
        import System
    #else
        @preconcurrency import SystemPackage
    #endif
#endif

/// A connection to an MCP (Model Context Protocol) server.
///
/// `MCPConnection` manages the lifecycle of an MCP client, discovers
/// tools exposed by the server, and wraps them as standard ``Operable``
/// instances that can be passed to an ``Operative``.
///
/// ## Usage
///
/// ```swift
/// let connection = MCPConnection(
///     name: "filesystem",
///     transport: .stdio(command: "/usr/bin/fs-server")
/// )
/// try await connection.connect()
///
/// let operative = try Operative(
///     name: "Agent",
///     description: "MCP-equipped agent",
///     llm: myLLM,
///     systemPrompt: "You help with file operations.",
///     tools: [localTools] + (try await connection.operables()),
///     budget: Budget(maxTurns: 10)
/// )
/// ```
///
/// ## Transport Options
///
/// - ``Transport/stdio(command:arguments:environment:)`` — Launches a
///   subprocess and communicates via stdin/stdout. Available on macOS
///   and Linux only.
/// - ``Transport/http(url:configuration:requestModifier:)`` — Connects
///   via HTTP with optional SSE streaming.
/// - ``Transport/custom(_:)`` — Uses any `MCP.Transport` directly.
///   Useful for testing with `InMemoryTransport`.
///
/// ## Lifecycle
///
/// The connection follows a simple state machine:
/// `created → connected → disconnected`. Call ``connect()`` to
/// establish the connection, and ``disconnect()`` to tear it down.
/// Disconnect is idempotent and safe to call multiple times.
public actor MCPConnection {
    /// Transport configuration for connecting to an MCP server.
    public enum Transport: Sendable {
        #if os(macOS) || os(Linux)
            /// Launch a subprocess and communicate via stdin/stdout.
            ///
            /// The subprocess is started when ``MCPConnection/connect()`` is called
            /// and terminated on ``MCPConnection/disconnect()``.
            ///
            /// - Parameters:
            ///   - command: Path to the MCP server executable.
            ///   - arguments: Command-line arguments to pass.
            ///   - environment: Environment variables for the subprocess. If `nil`,
            ///     inherits the current process environment.
            case stdio(command: String, arguments: [String] = [], environment: [String: String]? = nil)
        #endif

        /// Connect via HTTP (Streamable HTTP transport).
        ///
        /// - Parameters:
        ///   - url: The MCP server endpoint URL.
        ///   - configuration: URL session configuration. Defaults to `.default`.
        ///   - requestModifier: A closure to modify outgoing requests, e.g. to
        ///     add authorization headers. Defaults to identity.
        case http(
            url: URL,
            configuration: URLSessionConfiguration = .default,
            requestModifier: @Sendable (URLRequest) -> URLRequest = { $0 }
        )

        /// Use a custom `MCP.Transport` directly.
        ///
        /// Primarily useful for testing with `InMemoryTransport`.
        case custom(any MCP.Transport)
    }

    /// The display name for this connection, used as the ``ToolGroup`` name.
    public let name: String

    private let transportConfig: Transport
    private var client: MCP.Client?
    private var activeTransport: (any MCP.Transport)?

    #if os(macOS) || os(Linux)
        private var process: Foundation.Process?
    #endif

    /// Creates an MCP connection with the given name and transport.
    ///
    /// The connection is not established until ``connect()`` is called.
    ///
    /// - Parameters:
    ///   - name: A display name for this connection, used as the tool group name.
    ///   - transport: The transport configuration to use.
    public init(name: String, transport: Transport) {
        self.name = name
        transportConfig = transport
    }

    /// Establishes the connection to the MCP server.
    ///
    /// This performs the MCP initialization handshake. After connecting,
    /// use ``operables()`` to discover the server's tools.
    ///
    /// - Throws: ``MCPConnectionError/alreadyConnected`` if already connected,
    ///   or any transport-level error.
    public func connect() async throws {
        guard client == nil else {
            throw MCPConnectionError.alreadyConnected
        }

        let transport: any MCP.Transport

        switch transportConfig {
        #if os(macOS) || os(Linux)
            case let .stdio(command, arguments, environment):
                transport = try launchStdioProcess(
                    command: command,
                    arguments: arguments,
                    environment: environment
                )
        #endif
        case let .http(url, configuration, requestModifier):
            transport = HTTPClientTransport(
                endpoint: url,
                configuration: configuration,
                requestModifier: requestModifier
            )
        case let .custom(customTransport):
            transport = customTransport
        }

        let mcpClient = MCP.Client(
            name: name,
            version: "1.0.0"
        )

        try await mcpClient.connect(transport: transport)

        client = mcpClient
        activeTransport = transport
    }

    /// Disconnects from the MCP server.
    ///
    /// This method is idempotent — calling it when already disconnected
    /// or never connected has no effect.
    public func disconnect() async {
        if let client {
            await client.disconnect()
        }
        client = nil
        activeTransport = nil

        #if os(macOS) || os(Linux)
            if let process, process.isRunning {
                process.terminate()
            }
            process = nil
        #endif
    }

    /// Discovers the server's tools and returns them as ``Operable`` instances.
    ///
    /// Each call queries the server's current tool list. The returned array
    /// contains a single ``Operable`` whose ``ToolGroup`` includes all tools.
    ///
    /// - Returns: An array containing one ``Operable`` with all MCP tools.
    /// - Throws: ``MCPConnectionError/notConnected`` if not connected,
    ///   or ``MCPConnectionError/schemaConversionFailed(toolName:underlyingError:)``
    ///   if a tool's schema cannot be converted.
    public func operables() async throws -> [any Operable] {
        guard let client else {
            throw MCPConnectionError.notConnected
        }

        var allTools: [Tool] = []
        var cursor: String?

        repeat {
            let result = try await client.listTools(cursor: cursor)
            allTools.append(contentsOf: result.tools)
            cursor = result.nextCursor
        } while cursor != nil

        var providers: [any ToolProvider] = []
        for tool in allTools {
            do {
                let provider = try MCPToolProvider(mcpTool: tool, connection: self)
                providers.append(provider)
            } catch {
                throw MCPConnectionError.schemaConversionFailed(
                    toolName: tool.name,
                    underlyingError: error
                )
            }
        }

        let group = ToolGroup(
            name: name,
            description: "Tools from MCP server '\(name)'",
            tools: providers
        )

        return [MCPOperable(toolGroup: group)]
    }

    /// Calls an MCP tool by name with the given arguments.
    ///
    /// This is used internally by ``MCPToolProvider`` to dispatch calls.
    ///
    /// - Parameters:
    ///   - name: The MCP tool name.
    ///   - arguments: The tool arguments from the LLM.
    /// - Returns: A ``ToolOutput`` with the tool's response.
    /// - Throws: ``MCPConnectionError/notConnected`` if not connected,
    ///   or ``MCPConnectionError/toolCallFailed(toolName:message:)`` if the
    ///   tool reports an error.
    func callTool(name: String, arguments: ToolArguments) async throws -> ToolOutput {
        guard let client else {
            throw MCPConnectionError.notConnected
        }

        let mcpArgs: [String: MCP.Value] = try arguments.toMCPValues()
        let result = try await client.callTool(name: name, arguments: mcpArgs)

        if result.isError == true {
            let message: String = result.content.compactMap { item -> String? in
                if case let .text(text) = item { return text }
                return nil
            }.joined(separator: "\n")
            throw MCPConnectionError.toolCallFailed(
                toolName: name,
                message: message.isEmpty ? "Unknown error" : message
            )
        }

        return ToolOutput(mcpContent: result.content)
    }

    #if os(macOS) || os(Linux)
        /// Launches a subprocess for stdio transport.
        private func launchStdioProcess(
            command: String,
            arguments: [String],
            environment: [String: String]?
        ) throws -> StdioTransport {
            let proc = Foundation.Process()
            proc.executableURL = URL(fileURLWithPath: command)
            proc.arguments = arguments
            if let environment {
                proc.environment = environment
            }

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            proc.standardInput = stdinPipe
            proc.standardOutput = stdoutPipe

            try proc.run()
            process = proc

            return StdioTransport(
                input: FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor),
                output: FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)
            )
        }
    #endif
}
