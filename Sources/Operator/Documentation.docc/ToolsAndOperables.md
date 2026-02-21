# Tools and Operables

Defining tools that an Operative can use.

## Overview

Tools are the actions an Operative can take. When an LLM decides to call a tool, Operator dispatches the call, executes the tool's implementation, and feeds the result back to the model. The tool system is built on two core concepts:

- **Tool**: A single callable action with a name, description, parameter schema, and implementation.
- **Operable**: A type that provides a group of related tools.

Tools are **capability providers**, not data. A ``FileSystem`` is a good Operable — it provides read, write, and list capabilities. A `URL` or a `String` is data — it flows through tool arguments and user messages, not through tool registration.

## The Operable Protocol

Any type can provide tools by conforming to ``Operable``:

```swift
protocol Operable: Sendable {
    var toolGroup: ToolGroup { get }
}
```

The single ``toolGroup`` property returns a ``ToolGroup`` containing the type's tools. Using a single nested property avoids name collisions with properties the conforming type might already have (e.g., `name`, `description`, `tools`).

```swift
struct FileSystem: Operable {
    let rootPath: String

    var toolGroup: ToolGroup {
        ToolGroup(
            name: "File System",
            description: "Read, write, and list files on disk",
            tools: [
                // ... tool definitions
            ]
        )
    }
}
```

### ToolGroup

A ``ToolGroup`` bundles related tools with metadata:

```swift
struct ToolGroup: Sendable {
    let name: String
    let description: String?
    let tools: [any ToolProvider]
}
```

The **name** and **description** provide context to the LLM about what this group of tools can do. When the Operative builds tool schemas for the LLM, it prefixes each tool's description with the group name:

```
[File System] Read the contents of a file at the given path
```

This helps the LLM understand which tools are related and what domain they operate in, without injecting hidden text into the system prompt. The description is optional — if omitted, no prefix is added.

## Defining Tools

Operator offers three tiers of tool definition, each suited to different complexity levels.

### Tier 1: Closure-Based Tools

The most common approach. Define the tool inline with its name, description, input type, and an execution closure:

```swift
Tool(
    name: "readFile",
    description: "Read the contents of a file at the given path",
    input: ReadFileInput.self
) { input in
    let content = try String(contentsOfFile: input.path, encoding: .utf8)
    return ToolOutput(content)
}
```

The ``input`` parameter is a ``ToolInput`` type — a plain `Codable` struct whose properties define the tool's parameters. See <doc:ToolInput> for how this works.

For tools with no parameters:

```swift
Tool(name: "getCurrentTime", description: "Get the current date and time") {
    ToolOutput(Date.now.formatted())
}
```

### Tier 2: Reusable ToolInput Types

When multiple tools share an input shape, define the input once and reuse it:

```swift
struct FileReference: ToolInput {
    let path: String

    static var paramDescriptions: [String: String] {
        ["path": "Absolute path to the file"]
    }
}

// Both tools take the same input
Tool(name: "readFile", description: "Read a file", input: FileReference.self) { input in
    ToolOutput(try String(contentsOfFile: input.path, encoding: .utf8))
}

Tool(name: "deleteFile", description: "Delete a file", input: FileReference.self) { input in
    try FileManager.default.removeItem(atPath: input.path)
    return ToolOutput("Deleted \(input.path)")
}
```

This tier is also useful for testing — ``ToolInput`` types are plain value types that can be constructed directly in tests without parsing JSON.

### Tier 3: Full Tool Conformance

For tools with complex internal state, dependencies, or lifecycle requirements, conform directly to the ``ToolProvider`` protocol:

```swift
protocol ToolProvider: Sendable {
    var definition: ToolDefinition { get }
    func call(arguments: ToolArguments) async throws -> ToolOutput
}
```

```swift
struct DatabaseQueryTool: ToolProvider {
    let connection: DatabaseConnection
    let maxRows: Int

    var definition: ToolDefinition {
        ToolDefinition(
            function: FunctionDefinition(
                name: "queryDatabase",
                description: "Execute a read-only SQL query",
                parameters: .object(
                    properties: [
                        "sql": .string(description: "The SQL query to execute"),
                        "limit": .integer(description: "Maximum rows to return"),
                    ],
                    required: ["sql"]
                )
            )
        )
    }

    func call(arguments: ToolArguments) async throws -> ToolOutput {
        let sql: String = try arguments.require("sql")
        let limit = arguments.optionalInt("limit") ?? maxRows
        let rows = try await connection.query(sql, limit: limit)
        return ToolOutput(rows.description)
    }
}
```

This tier gives full control over the ``ToolDefinition`` (including the ``JSONSchema``) and the execution logic. Use it when the automatic schema extraction of ``ToolInput`` doesn't fit your needs.

### Choosing a Tier

| Tier | When to use | Schema | Type safety |
|------|-------------|--------|-------------|
| Closure + ToolInput | Most tools | Auto-generated from Codable | Full — typed input struct |
| Reusable ToolInput | Shared input shapes, testability | Auto-generated from Codable | Full — typed input struct |
| Full Tool conformance | Complex tools, custom schemas | Hand-written | Manual — raw ToolArguments |

All three tiers produce values conforming to ``ToolProvider``. They can be mixed freely within a single ``ToolGroup``.

## Registering Tools with an Operative

Pass an array of ``Operable`` instances when creating an Operative:

```swift
let operative = Operative(
    llm: myLLM,
    systemPrompt: "You are a helpful assistant.",
    tools: [
        FileSystem(rootPath: "/Users/ben/project"),
        WebSearch(apiKey: searchKey),
        Calculator(),
    ],
    budget: Budget(maxTurns: 10)
)
```

The Operative flattens all ``ToolGroup/tools`` into a single list, prefixes descriptions with group names, and converts them to ``ToolDefinition`` schemas for the LLM. Tool names must be unique across all Operables — if two tools share a name, the Operative will raise an error at initialization.

## ToolOutput

Every tool returns a ``ToolOutput``, which wraps the result that gets fed back to the LLM:

```swift
struct ToolOutput: Friendly {
    let content: String
}
```

``ToolOutput`` can be initialized from a ``String``, an array of strings (joined with newlines), or any ``Encodable`` value (serialized to JSON). The content is always a string because that is what the LLM consumes as a tool result.

```swift
// From a string
ToolOutput("File contents here")

// From an array
ToolOutput(["line 1", "line 2", "line 3"])

// From an Encodable value
ToolOutput(encoding: myStruct)
```

## Topics

### Related

- <doc:ToolInput>
- <doc:Operative>
