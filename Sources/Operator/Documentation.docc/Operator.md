# ``Operator``

A Swift library for building tool-using AI agents.

## Overview

Operator provides the core building blocks for creating agentic AI features in your applications. An **agent** is an LLM running in a loop with access to tools — it receives a task, decides which tools to call, observes the results, and repeats until the task is complete.

Operator sits in the middle of a three-layer architecture:

- **LLM** — Handles raw model communication: sending prompts, receiving responses, managing rate limits. Stateless and provider-agnostic.
- **Operator** — Runs the agent loop. Manages tools, middleware, budgets, and streams real-time events. This is the library you're reading about.
- **Orchestrator** *(future)* — Composes agents into higher-level workflows: parallel execution, sub-agents, planning, memory, and skills.

Most applications need only Operator. Reach for Orchestrator when you need to coordinate multiple agents or implement complex agentic patterns.

### Quick Example

```swift
// Define a tool by conforming to Operable
struct URLParser: Operable {
    var toolGroup: ToolGroup {
        ToolGroup(
            name: "URL Parser",
            description: "Parse and inspect URLs",
            tools: [
                Tool(
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
let operative = Operative(
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

## Topics

### Essentials

- <doc:Architecture>
- <doc:Operative>
- <doc:Operations>

### Tools

- <doc:ToolsAndOperables>
- <doc:ToolInput>

### Configuration

- <doc:Middleware>
- <doc:Budget>
