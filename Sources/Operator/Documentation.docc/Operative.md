# The Operative

The core agent type that runs an LLM in a loop with tools.

## Overview

An ``Operative`` is the central type in the Operator library. It encapsulates a configured agent: an LLM connection, a set of tools, a system prompt, a budget, and optional middleware. When you call ``run(_:)``, the Operative enters a loop — sending messages to the LLM, executing tool calls, and streaming events — until the task is complete or a budget limit is reached.

### Creating an Operative

An Operative is initialized with everything it needs to run:

```swift
let operative = try Operative(
    name: "FileAssistant",
    description: "A helpful assistant with file system access",
    llm: myLLM,
    systemPrompt: "You are a helpful assistant with access to the user's file system.",
    tools: [fileSystem, webSearch, calculator],
    budget: Budget(maxTurns: 20, maxTokens: 100_000, timeout: .seconds(300)),
    middleware: [secretsFilter, loggingMiddleware]
)
```

The initializer throws ``OperativeError/duplicateToolName(_:)`` if any two tools across all Operables share the same name.

**Parameters:**

- **name**: A human-readable name for this agent. Used for logging, debugging, and orchestration — for example, when multiple agents collaborate, the name identifies each agent in event streams.
- **description**: A brief description of this agent's purpose. Useful for tooling and orchestration layers that need to understand what an agent does.
- **llm**: An ``LLM`` instance or any ``LLMService`` conformer. The Operative uses this to make model calls. Different Operatives can use different LLM instances (and therefore different models or providers), which is useful when OperativeKit needs to mix fast and powerful models. The ``LLMService`` protocol is exposed for testability — pass a mock in tests.
- **systemPrompt**: The base system prompt sent with every request. Operator includes this verbatim — it does not inject additional instructions. The ``Operable/toolGroup`` descriptions are appended to tool schemas, not to the system prompt.
- **tools**: An array of ``Operable`` conformers. The Operative flattens their ``ToolGroup/tools`` into a single tool list and sends the corresponding schemas to the LLM.
- **budget**: A ``Budget`` that defines the Operative's resource limits. See <doc:Budget> for details.
- **middleware**: An ordered array of ``Middleware`` conformers. See <doc:Middleware> for how they compose.

### Running an Operative

The ``run(_:)`` method accepts a user message and returns an ``OperationStream`` (an `AsyncStream<Operation>`) of events:

```swift
for await operation in operative.run("Find all Swift files in the project and count the lines of code") {
    switch operation {
    case .turnStarted(let context):
        print("Turn \(context.turnNumber) of \(context.budgetRemaining.maxTurns ?? -1)")
    case .text(let chunk):
        print(chunk, terminator: "")
    case .toolsRequested(let requests):
        print("Agent wants to call: \(requests.map(\.name).joined(separator: ", "))")
    case .toolCompleted(let request, let output):
        print("  \(request.name) → \(output.content)")
    case .completed(let result):
        print("\nFinal answer: \(result.text ?? "")")
    case .stopped(let reason):
        print("Agent stopped: \(reason)")
    default:
        break
    }
}
```

The stream emits events in real time as the agent works. When the agent finishes — either by producing a final response without tool calls, or by hitting a budget limit — the stream emits a terminal event (``.completed`` or ``.stopped``) and ends.

### Getting Just the Result

If you don't need real-time events, the ``result()`` convenience method consumes the stream and returns the final outcome:

```swift
let result = try await operative.run("What's 2 + 2?").result()
print(result.text ?? "")  // "4"
print(result.usage)       // Token usage summary
print(result.turnsUsed)   // Number of turns taken
```

This is equivalent to iterating the stream and extracting the terminal event.

## The Agent Loop

Each invocation of ``run(_:)`` executes the following loop:

```
1. Add the user's message to the conversation
2. Check budget → stop if exhausted
3. Run pre-request middleware on the outbound messages
4. Send messages + tool schemas to the LLM (via the LLM library)
5. Stream the response, emitting .text operations for content chunks
6. Run post-response middleware on the LLM's response
7. If the response contains no tool calls → emit .completed, end
8. Emit .toolsRequested with the full batch of requested tool calls
9. Run pre-tool-call middleware on the batch → approve, modify, or reject each
10. Emit .toolsRejected for any rejected calls
11. Execute approved tools (concurrently)
12. Emit .toolCompleted or .toolFailed for each tool
13. Add tool results to the conversation
14. Emit .turnCompleted with usage stats
15. Go to step 2
```

Steps 2 through 15 constitute a single **turn**. The Operative tracks turns and token usage against the ``Budget`` and stops when any limit is reached.

## Concurrency

The Operative executes approved tool calls concurrently by default. If the LLM requests three tool calls in a single response, all three run in parallel (subject to Swift's cooperative threading). Tool implementations should be safe for concurrent execution.

If a tool has ordering requirements relative to other tools, that should be expressed at the OperativeKit level (by separating the tools into different Operatives) or by designing the tool to be idempotent.

## Multi-Turn Conversations

An Operative is stateful for the duration of a single ``run(_:)`` call. It maintains the conversation history (messages, tool results) within that run. Once the run completes, the Operative does not retain conversation state — a subsequent call to ``run(_:)`` starts fresh.

To continue a conversation across runs, pass the previous result's conversation back via ``run(_:continuing:)``:

```swift
// First turn
let result1 = try await operative.run("Store my name as Alice").result()

// Second turn — agent remembers the first turn
let result2 = try await operative.run("What's my name?", continuing: result1.conversation).result()
```

Each call to ``run(_:continuing:)`` gets a fresh budget. The conversation history (including all tool calls and results) is preserved, so the agent has full context from prior turns.

For more complex orchestration — multiple agents, planning, or persistent memory — use the [OperativeKit](https://github.com/bensyverson/OperativeKit) layer.

## Topics

### Related

- <doc:Operations>
- <doc:Budget>
- <doc:Middleware>
