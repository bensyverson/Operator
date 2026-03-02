# Apple Intelligence Integration

Use Apple's on-device Foundation Models with Operator.

## Overview

Operator supports Apple's on-device Foundation Models (macOS 26+, iOS 26+) in two ways:

1. **As an LLM engine** — Use ``AppleIntelligenceService`` to run an ``Operative`` entirely on-device for tasks like summarization, classification, or simple Q&A.
2. **As a tool bridge** — Use ``AppleToolAdapter`` to wrap Apple `FoundationModels.Tool` instances so they can be called by any cloud LLM (Claude, GPT, etc.) through Operator's agent loop.

Both integration points are confined behind `#if canImport(FoundationModels)` with `@available` annotations. They have no impact on Linux or older Apple platform builds.

## Using the On-Device Model

The simplest path is the ``Operative`` convenience initializer that creates an ``AppleIntelligenceService`` for you:

```swift
import Operator

let summarizer = try Operative(
    name: "Summarizer",
    description: "Summarizes text on-device",
    systemPrompt: "You produce concise summaries of the provided text.",
    tools: [],
    budget: Budget(maxTurns: 3)
)

let stream = summarizer.run("Summarize the following: \(longText)")
for await operation in stream {
    switch operation {
    case .text(let chunk):
        print(chunk, terminator: "")
    case .completed(let result):
        print("\nDone.")
    default:
        break
    }
}
```

You can also create the service directly and pass it to the standard ``Operative`` initializer:

```swift
let service = AppleIntelligenceService()
let operative = try Operative(
    name: "Classifier",
    description: "Classifies input",
    llm: service,
    systemPrompt: "Classify the user's input.",
    tools: [],
    budget: Budget(maxTurns: 1)
)
```

### Tool Calling with `@Generable`

The on-device model manages its own tool loop internally — it calls tools
during `respond(to:)` and never exposes structured tool calls to the caller.
Operator bridges this automatically: any tool whose ``ToolInput`` type also
conforms to `@Generable` (`ConvertibleFromGeneratedContent`) is wrapped as
an Apple `FoundationModels.Tool` and handed to the session.

```swift
@Generable
struct WeatherInput: ToolInput {
    @Guide(description: "City name")
    var city: String

    static var paramDescriptions: [String: String] {
        ["city": "City name"]
    }
}

// This SAME tool works with both cloud LLMs and Apple Intelligence:
let tool = try Tool(
    name: "getWeather",
    description: "Get current weather for a city",
    input: WeatherInput.self
) { input in
    ToolOutput("Sunny in \(input.city)")
}
```

Both `@Guide` descriptions and ``ToolInput/paramDescriptions`` are needed:
`@Guide` drives Apple's guided generation; `paramDescriptions` drives JSON
Schema extraction for cloud LLMs. The descriptions should match but are not
validated against each other.

When the on-device model calls a tool, Operator emits the usual
`.toolsRequested`, `.toolCompleted`, and `.toolFailed` events, so your
event-handling code works identically regardless of the backend.

Tools whose input type does **not** conform to `@Generable` are silently
excluded from the on-device session. If all tools are excluded, the session
still runs — it just won't have any tools available.

### Middleware Differences

When running on Apple Intelligence, middleware hooks behave differently
because Apple drives the tool loop:

| Hook | Supported | Notes |
|------|-----------|-------|
| `afterResponse` | Yes | Called after `respond(to:)` returns |
| `onToolError` | No | Errors are caught by the proxy and returned to the model |
| `beforeRequest` | No | No standard request object exists |
| `beforeToolCalls` | No | Apple calls tools autonomously |

### Limitations

- **No token usage reporting**: ``TokenUsage`` is always ``TokenUsage/zero``.
- **No extended thinking**: Thinking content is always `nil`.
- **Single turn**: From Operator's perspective, each `run()` is one turn. Apple may internally loop over multiple tool calls, but the ``Budget/maxTurns`` limit counts the entire `respond(to:)` as a single turn.
- **Hardware requirement**: Requires Apple Intelligence–enabled hardware at runtime. Use `@available` checks and runtime guards as appropriate.

## Bridging Apple Tools

If you have an Apple `FoundationModels.Tool` and want to use it with a cloud LLM (for example, an Anthropic model), wrap it with ``AppleToolAdapter``:

```swift
import FoundationModels
import Operator

// Your Apple-native tool — note the Codable conformance on the args type.
// @Generable does not synthesize Decodable, so you must add it explicitly.
@Generable
struct WeatherArgs: Codable {
    var city: String
}

struct WeatherTool: FoundationModels.Tool {
    let name = "getWeather"
    let description = "Get current weather for a city"

    func call(arguments: WeatherArgs) async throws -> String {
        // ... fetch weather ...
        return "Sunny, 72°F"
    }
}

// Wrap it for Operator — provide the schema explicitly
let adapted = AppleToolAdapter(
    tool: WeatherTool(),
    parameterSchema: .object(
        properties: ["city": .string(description: "City name")],
        required: ["city"]
    )
)
```

If the tool's `Arguments` type also conforms to ``ToolInput``, the schema is auto-extracted:

```swift
let adapted = try AppleToolAdapter(tool: WeatherTool())
```

The adapted tool is a standard ``ToolProvider`` and can be included in any ``ToolGroup``.

## Availability Checking

All Apple Intelligence types require macOS 26.0+ or iOS 26.0+. Operator confines them behind `#if canImport(FoundationModels)` and `@available` annotations, so your project compiles cleanly on older platforms and Linux.

At runtime, check availability before constructing these types:

```swift
if #available(macOS 26.0, iOS 26.0, *) {
    let service = AppleIntelligenceService()
    // ...
}
```

## Topics

### On-Device Model

- ``AppleIntelligenceService``

### Tool Bridge

- ``AppleToolAdapter``

### Convenience

- ``Operative``
