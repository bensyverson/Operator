# Operations

The real-time event stream emitted by a running Operative.

## Overview

When an ``Operative`` runs, it produces an ``AsyncSequence`` of ``Operation`` values. Each Operation represents a discrete, observable moment in the agent's lifecycle. The stream serves two purposes:

1. **Display**: Applications use Operations to show users what the agent is doing — streaming text, listing tool calls, showing progress.
2. **Observation**: Orchestrator (or any upstream consumer) uses Operations to make decisions — tracking token consumption, detecting patterns, deciding when to intervene.

Operations are **not** a control mechanism. They describe what happened or is happening. To *change* agent behavior, use <doc:Middleware>.

## Operation Types

### Turn Lifecycle

```swift
case turnStarted(TurnContext)
case turnCompleted(TurnResult)
```

A **turn** is one iteration of the agent loop: a round-trip to the LLM, possibly followed by tool execution. ``turnStarted`` fires at the beginning of each iteration and carries context about the current turn number and remaining budget. ``turnCompleted`` fires after all tool calls for that turn have resolved, carrying token usage statistics for the turn.

### Thinking

```swift
case thinking(String)
```

Emitted when the LLM includes extended thinking or reasoning content in its response. This surfaces Anthropic thinking blocks and OpenAI reasoning content. Thinking is always emitted before the corresponding ``text`` event — the agent thinks, then speaks. Thinking content is also available to middleware via ``ResponseContext/thinking``.

### Streamed Text

```swift
case text(String)
```

Emitted as the LLM generates text content. Each event carries a chunk of text — typically a few tokens. These chunks arrive in order and can be concatenated to form the complete response. Text events may be interleaved with tool call events if the LLM produces text alongside tool calls.

### Tool Events

```swift
case toolsRequested([ToolRequest])
case toolsRejected([ToolRejection])
case toolCompleted(ToolRequest, ToolOutput)
case toolFailed(ToolRequest, ToolError)
```

These four events trace the full lifecycle of tool calls within a turn:

- **toolsRequested**: Emitted when the LLM's response includes tool calls. This represents the LLM's *intent* — what it wants to do. The list reflects the raw request before middleware has had a chance to approve or reject. This event is batched because a single LLM response can request multiple tool calls.

- **toolsRejected**: Emitted after pre-tool-call middleware runs, listing any tool calls that were blocked. Each ``ToolRejection`` includes the original request and the reason it was rejected. If no tools were rejected, this event is not emitted.

- **toolCompleted**: Emitted when a tool finishes executing successfully. Since tools execute concurrently, these events may arrive in any order. Each event pairs the original ``ToolRequest`` with the ``ToolOutput`` produced by the tool.

- **toolFailed**: Emitted when a tool throws an error during execution. The error may have been processed by error-recovery middleware. By default, the error message is fed back to the LLM as a tool result so it can adapt.

### Terminal Events

```swift
case completed(OperativeResult)
case stopped(StopReason)
```

Exactly one terminal event is emitted at the end of every run. After a terminal event, the stream ends.

- **completed**: The agent finished naturally — it produced a response with no further tool calls. The ``OperativeResult`` includes the final text, the full conversation, and aggregate usage statistics.

- **stopped**: The agent was halted by a budget constraint or external signal. ``StopReason`` indicates why:
  - ``.turnLimitReached``: The ``Budget/maxTurns`` limit was hit.
  - ``.tokenBudgetExhausted``: The cumulative token usage exceeded ``Budget/maxTokens``.
  - ``.timeout``: The ``Budget/timeout`` duration elapsed.
  - ``.explicitStop``: A tool or middleware explicitly requested termination.

## Temporal Sequence

Within a single turn, Operations arrive in a predictable order:

```
turnStarted
├── thinking (if extended thinking is present)
├── text (zero or more streamed chunks)
├── toolsRequested (if the LLM called tools)
├── toolsRejected (if middleware blocked any)
├── toolCompleted / toolFailed (one per executed tool, in completion order)
└── turnCompleted

... (next turn, or terminal event)

completed / stopped
```

A turn that produces only text (no tool calls) looks like:

```
turnStarted → thinking → text → text → text → turnCompleted → completed
```

A turn with tool calls looks like:

```
turnStarted → toolsRequested → toolCompleted → toolCompleted → turnCompleted
```

Multiple turns:

```
turnStarted → toolsRequested → toolCompleted → turnCompleted
turnStarted → toolsRequested → toolsRejected → toolCompleted → turnCompleted
turnStarted → text → turnCompleted → completed
```

## Consuming the Stream

### Full Event Handling

Process every event for maximum visibility:

```swift
for await operation in operative.run("Analyze this dataset") {
    switch operation {
    case .turnStarted(let ctx):
        updateUI(status: "Thinking... (turn \(ctx.turnNumber))")
    case .thinking(let content):
        showThinkingIndicator(content)
    case .text(let chunk):
        appendToOutput(chunk)
    case .toolsRequested(let tools):
        showToolActivity(tools.map(\.name))
    case .toolsRejected(let rejections):
        showWarnings(rejections.map { "\($0.request.name): \($0.reason)" })
    case .toolCompleted(let request, let output):
        showToolResult(request.name, output.summary)
    case .toolFailed(let request, let error):
        showToolError(request.name, error.localizedDescription)
    case .turnCompleted(let result):
        updateTokenCount(result.usage)
    case .completed(let result):
        showFinalResult(result.text)
    case .stopped(let reason):
        showStoppedBanner(reason)
    }
}
```

### Selective Handling

Ignore events you don't care about:

```swift
for await operation in operative.run("Summarize this") {
    if case .text(let chunk) = operation {
        print(chunk, terminator: "")
    }
}
```

### Just the Result

Skip the stream entirely:

```swift
let result = try await operative.run("Translate this to French").result()
print(result.text)
```

## Context Types

### TurnContext

Carried by ``turnStarted``. Provides situational awareness at the start of each turn:

- **turnNumber**: The current turn (1-indexed).
- **budgetRemaining**: A snapshot of the remaining budget (turns, tokens, time).

### TurnResult

Carried by ``turnCompleted``. Summarizes what happened during the turn:

- **usage**: Token counts for this turn (prompt tokens, completion tokens, total).
- **toolCallCount**: How many tools were called (including rejected).
- **cumulativeUsage**: Running total of token usage across all turns so far.

### OperativeResult

Carried by ``completed``. The final outcome of a successful run:

- **text**: The agent's final response text.
- **conversation**: The full conversation history, including all tool calls and results.
- **usage**: Aggregate token usage for the entire run.
- **turnsUsed**: Total number of turns taken.

### StopReason

Carried by ``stopped``. An enum indicating why the agent was halted. See the terminal events section above for the full case list.

## Design Rationale

### Why an event stream instead of callbacks?

An ``AsyncSequence`` composes naturally with Swift's concurrency model. Consumers can use `for await`, `map`, `filter`, `reduce`, or any async sequence operator. There's no need for a delegate protocol with ten optional methods, and no risk of callback ordering issues. The stream also gives Orchestrator a clean interface for observing child agents.

### Why are tool events split into requested/rejected/completed/failed?

This decomposition lets observers reconstruct the full picture: `requested = rejected + completed + failed`. A UI can show "the agent wanted to write a file but middleware blocked it" without needing access to middleware internals. Each event carries just the information relevant to that stage.

### Why is toolsRequested emitted before middleware runs?

Because it represents the LLM's intent, not what actually happened. This is valuable for logging, debugging, and UI — you want to know what the agent *tried* to do, not just what it was allowed to do.

## Topics

### Related

- <doc:Operative>
- <doc:Middleware>
