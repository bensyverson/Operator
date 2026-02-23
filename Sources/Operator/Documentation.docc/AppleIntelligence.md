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

### Limitations

- **No tool calling**: The on-device model manages its own tool loop internally and does not emit tool calls through Operator's ``ToolProvider`` system. Tools are registered but may not be reliably invoked.
- **No token usage reporting**: ``LLMResponse/usage`` is always ``TokenUsage/zero``.
- **No extended thinking**: ``LLMResponse/thinking`` is always `nil`.
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
