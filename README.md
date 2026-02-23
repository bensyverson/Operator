# Operator

A Swift library for building tool-using AI agents.

## Architecture

Operator sits in the middle of a three-layer stack:

| Layer | Role |
|-------|------|
| **[LLM](https://git.mattebox.com/ben/LLM)** | Raw model communication — stateless, provider-agnostic |
| **Operator** | Agent loop — tools, middleware, budgets, streaming events |
| **Orchestrator** *(future)* | Multi-agent composition — sub-agents, planning, memory |

Most applications need only Operator. Reach for Orchestrator when you need to coordinate multiple agents.

## Quick Example

```swift
import Operator

// Define a tool by conforming to Operable
struct URLParser: Operable {
    var toolGroup: ToolGroup {
        ToolGroup(
            name: "URL Parser",
            description: "Parse and inspect URLs",
            tools: [
                try Tool(
                    name: "parseURL",
                    description: "Parse a URL into its components",
                    input: ParseURLInput.self
                ) { input in
                    let results = input.components.map { $0.extract(from: input.url) }
                    return ToolOutput(results)
                },
            ]
        )
    }
}

// Create and run an Operative
let operative = try Operative(
    llm: myLLM,
    systemPrompt: "You help users work with URLs.",
    tools: [URLParser()],
    budget: Budget(maxTurns: 10)
)

for await operation in operative.run("What's the host and port of https://example.com:8080/api?active=true") {
    switch operation {
    case .text(let chunk):
        print(chunk, terminator: "")
    case .completed(let result):
        print("\nDone. Tokens used: \(result.usage.totalTokens)")
    default:
        break
    }
}
```

## Documentation

Full documentation is available as a DocC catalog at [`Sources/Operator/Documentation.docc/`](Sources/Operator/Documentation.docc/). Key articles:

- **[Architecture](Sources/Operator/Documentation.docc/Architecture.md)** — Data flow and the three-layer model
- **[Operative](Sources/Operator/Documentation.docc/Operative.md)** — The agent loop, configuration, and lifecycle
- **[Tools and Operables](Sources/Operator/Documentation.docc/ToolsAndOperables.md)** — Defining tools at three tiers of complexity
- **[Tool Input](Sources/Operator/Documentation.docc/ToolInput.md)** — Automatic JSON Schema extraction from Swift types
- **[Middleware](Sources/Operator/Documentation.docc/Middleware.md)** — Intercepting, transforming, and filtering agent behavior
- **[Budget](Sources/Operator/Documentation.docc/Budget.md)** — Controlling how long and how far an agent can run
- **[Operations](Sources/Operator/Documentation.docc/Operations.md)** — The real-time event stream
- **[Apple Intelligence](Sources/Operator/Documentation.docc/AppleIntelligence.md)** — On-device Foundation Models integration (macOS 26+, iOS 26+)

Generate HTML docs with:

```bash
swift package generate-documentation --target Operator

# Serve the docs:
swift package --disable-sandbox preview-documentation --target Operator

```

## Installation

Add Operator as a Swift Package Manager dependency:

```swift
dependencies: [
    .package(url: "git@git.mattebox.com:ben/Operator.git", branch: "main"),
]
```

Then add it to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Operator", package: "Operator"),
    ]
)
```

Requires Swift 6.2+ and macOS 15+ / iOS 18+.

## Example

See [`Examples/TimeAgent/`](Examples/TimeAgent/) for an interactive CLI agent that demonstrates tool use, multi-turn conversation, and provider configuration. Quick start:

```bash
cd Examples/TimeAgent
swift run TimeAgent
```
