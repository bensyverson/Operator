# MCP Integration

Connect to MCP servers and use their tools with any Operative.

## Overview

The [Model Context Protocol](https://modelcontextprotocol.io) (MCP) is an open standard for connecting AI agents to external tools and data sources. Operator's MCP integration lets you connect to any MCP server and use its tools as standard ``Operable`` instances — no manual schema translation or glue code required.

This means your Operative can use local Swift tools and remote MCP tools side by side, with no distinction in how they're registered or called.

## Connecting to an MCP Server

Create an ``MCPConnection`` with a name and transport, then call ``MCPConnection/connect()``:

```swift
import Operator

let connection = MCPConnection(
    name: "filesystem",
    transport: .stdio(command: "/usr/bin/fs-server")
)
try await connection.connect()
```

Once connected, call ``MCPConnection/operables()`` to discover the server's tools and pass them to an Operative:

```swift
let operative = try Operative(
    name: "Agent",
    description: "An agent with MCP tools",
    llm: myLLM,
    systemPrompt: "You help users manage files.",
    tools: [localTools] + (try await connection.operables()),
    budget: Budget(maxTurns: 10)
)
```

Each call to ``MCPConnection/operables()`` queries the server's current tool list, so you always get the latest tools.

When you're done, disconnect:

```swift
await connection.disconnect()
```

## Transport Options

``MCPConnection`` supports three transport types:

### Stdio (macOS and Linux only)

Launches a subprocess and communicates via stdin/stdout. This is the most common transport for local MCP servers.

```swift
let connection = MCPConnection(
    name: "my-server",
    transport: .stdio(
        command: "/usr/local/bin/my-mcp-server",
        arguments: ["--verbose"],
        environment: ["API_KEY": "sk-..."]
    )
)
```

The subprocess is started on ``MCPConnection/connect()`` and terminated on ``MCPConnection/disconnect()``.

> Note: The `.stdio` transport is unavailable on iOS because `Foundation.Process` is not available on that platform. Use `.http` or `.custom` instead.

### HTTP

Connects via HTTP using the MCP Streamable HTTP transport, with optional SSE streaming for server-initiated messages.

```swift
let connection = MCPConnection(
    name: "remote-server",
    transport: .http(
        url: URL(string: "https://mcp.example.com/v1")!,
        requestModifier: { request in
            var req = request
            req.setValue("Bearer sk-...", forHTTPHeaderField: "Authorization")
            return req
        }
    )
)
```

### Custom

Use any type conforming to the MCP SDK's `Transport` protocol directly. This is primarily useful for testing:

```swift
import MCP

let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
let connection = MCPConnection(
    name: "test",
    transport: .custom(clientTransport)
)
```

## How It Works

Under the hood, ``MCPConnection`` manages an MCP `Client` that handles the protocol handshake, tool discovery, and tool calls. When you call ``MCPConnection/operables()``:

1. The connection queries the server for its tool list via `tools/list`.
2. Each MCP tool's `inputSchema` (a JSON Schema encoded as `MCP.Value`) is converted to Operator's `JSONSchema` type using a `Codable` round-trip.
3. The tools are wrapped as ``ToolProvider`` instances and bundled into a single ``ToolGroup``.

When the LLM calls an MCP tool during an agent run:

1. The ``ToolArguments`` (raw JSON from the LLM) are converted to MCP's `[String: Value]` format.
2. The call is dispatched to the MCP server via `tools/call`.
3. The server's response (text, images, audio, or resources) is converted to a ``ToolOutput`` string. Text content is included directly; non-text types are represented as descriptive placeholders like `[Image: image/png]`.

## Schema Conversion

MCP tools describe their parameters using JSON Schema. Operator's `JSONSchema` type supports the most commonly used JSON Schema features: `type`, `properties`, `items`, `required`, `description`, and `enum`. Unsupported features like `oneOf`, `anyOf`, `format`, `pattern`, and `additionalProperties` are silently ignored during conversion — the tool will still work, but the LLM won't see those constraints.

## Error Handling

``MCPConnectionError`` describes the errors specific to MCP connections:

- ``MCPConnectionError/notConnected`` — Thrown when calling ``MCPConnection/operables()`` or a tool before ``MCPConnection/connect()``.
- ``MCPConnectionError/alreadyConnected`` — Thrown when calling ``MCPConnection/connect()`` on an already-connected instance.
- ``MCPConnectionError/toolCallFailed(toolName:message:)`` — Thrown when an MCP tool reports an error in its response.
- ``MCPConnectionError/schemaConversionFailed(toolName:underlyingError:)`` — Thrown when a tool's JSON Schema cannot be decoded.

## Exposing an Operative as an MCP Server

``OperativeMCPServer`` wraps an Operative and exposes it as an MCP tool server. External clients — such as Claude Desktop, other MCP-aware applications, or your own tools — can invoke the agent and maintain multi-turn conversations using session IDs.

The server exposes a single tool called `run` with two parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `message` | string | yes | The user message to send |
| `session_id` | string | no | Continue an existing conversation |

### Example: Stdio Transport

When your application runs as a subprocess (e.g., invoked by Claude Desktop), use a `StdioTransport`:

```swift
import MCP
import Operator

let operative = try Operative(
    name: "Assistant",
    description: "A helpful assistant",
    llm: myLLM,
    systemPrompt: "You are a helpful assistant.",
    tools: [myTools],
    budget: Budget(maxTurns: 10)
)

let server = OperativeMCPServer(operative: operative)
let transport = StdioTransport()
try await server.start(transport: transport)
```

### Example: In-Memory Transport (Testing)

For unit tests or embedded scenarios, use `InMemoryTransport`:

```swift
import MCP

let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
try await server.start(transport: serverTransport)

let client = MCP.Client(name: "test", version: "1.0.0")
try await client.connect(transport: clientTransport)

let (content, _) = try await client.callTool(
    name: "run",
    arguments: ["message": .string("Hello!")]
)
```

### Session Management

Each call to `run` without a `session_id` creates a new session. The response includes a `session_id` that the client can pass in subsequent calls to continue the conversation with full history. Sessions are stored in memory for the lifetime of the server.

## Topics

### Connection (Client)

- ``MCPConnection``
- ``MCPConnectionError``

### Server

- ``OperativeMCPServer``
- ``OperativeMCPServerError``
