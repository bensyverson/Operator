# Middleware

Intercepting, transforming, and filtering agent behavior.

## Overview

Middleware provides a composable pipeline for modifying or rejecting data as it flows through the agent loop. While the ``Operation`` event stream lets you *observe* what the agent does, middleware lets you *change* what it does.

Operator defines four middleware points, each corresponding to a stage in the agent loop:

1. **Pre-request**: Before messages are sent to the LLM.
2. **Post-response**: After the LLM responds, before the response is processed.
3. **Pre-tool-call**: After tool calls are parsed, before tools execute.
4. **Tool error**: When a tool throws an error during execution.

A middleware can implement any combination of these points. Default implementations are no-ops, so each middleware only handles the stages it cares about.

## The Middleware Protocol

```swift
protocol Middleware: Sendable {
    /// Transform or reject messages before they are sent to the LLM.
    func beforeRequest(_ context: inout RequestContext) async throws

    /// Transform or reject the LLM's response before it is processed.
    func afterResponse(_ context: inout ResponseContext) async throws

    /// Approve, modify, or reject tool calls before execution.
    /// Receives the full batch of tool calls from a single LLM response.
    func beforeToolCalls(_ calls: inout [ToolCallContext]) async throws

    /// Handle a tool execution error. Return a recovery strategy.
    func onToolError(_ error: Error, context: ToolCallContext) async throws -> ToolErrorRecovery
}
```

All four methods have default no-op implementations, so a middleware only needs to override the stages it participates in.

## Middleware Points in Detail

### Pre-Request

```swift
func beforeRequest(_ context: inout RequestContext) async throws
```

Runs before each LLM call. The ``RequestContext`` provides access to the outbound messages, tool schemas, and configuration. Use this to:

- **Filter content**: Remove or redact sensitive information from user messages before they reach the LLM.
- **Inject context**: Add system-level instructions or context that should accompany every request.
- **Reject requests**: Throw an error to abort the current turn entirely.

```swift
struct ProfanityFilter: Middleware {
    let patterns: [Regex<Substring>]

    func beforeRequest(_ context: inout RequestContext) async throws {
        for i in context.messages.indices {
            for pattern in patterns {
                if let content = context.messages[i].content {
                    context.messages[i].content = content.replacing(pattern, with: "[redacted]")
                }
            }
        }
    }
}
```

### Post-Response

```swift
func afterResponse(_ context: inout ResponseContext) async throws
```

Runs after the LLM responds, before the response is parsed for tool calls. The ``ResponseContext`` provides access to the raw response content. Use this to:

- **Detect secrets**: Check the LLM's output against a list of known secrets to prevent exfiltration.
- **Content filtering**: Redact or reject responses that contain prohibited content.
- **Logging**: Record raw LLM outputs for debugging or auditing.

```swift
struct SecretGuard: Middleware {
    let secrets: [String]

    func afterResponse(_ context: inout ResponseContext) async throws {
        for secret in secrets {
            if let text = context.responseText, text.contains(secret) {
                throw MiddlewareError.secretDetected
            }
        }
    }
}
```

The ``ProfanityFilter`` and ``SecretGuard`` could be combined into a single middleware that implements both ``beforeRequest`` and ``afterResponse`` — a bidirectional content filter:

```swift
struct ContentFilter: Middleware {
    let blockedPatterns: [Regex<Substring>]
    let secrets: [String]

    func beforeRequest(_ context: inout RequestContext) async throws {
        // Filter outbound content
        for i in context.messages.indices {
            for pattern in blockedPatterns {
                if let content = context.messages[i].content {
                    context.messages[i].content = content.replacing(pattern, with: "[redacted]")
                }
            }
        }
    }

    func afterResponse(_ context: inout ResponseContext) async throws {
        // Check inbound content for secret leakage
        for secret in secrets {
            if let text = context.responseText, text.contains(secret) {
                throw MiddlewareError.secretDetected
            }
        }
    }
}
```

### Pre-Tool-Call

```swift
func beforeToolCalls(_ calls: inout [ToolCallContext]) async throws
```

Runs after tool calls are parsed from the LLM's response, before any tool executes. Receives the **full batch** of tool calls from a single response. Each ``ToolCallContext`` has a mutable ``decision`` property:

```swift
enum ToolCallDecision {
    /// Allow the tool call to proceed as-is.
    case proceed

    /// Allow the tool call with modified arguments.
    case modify(ToolArguments)

    /// Block the tool call. The reason is fed back to the LLM.
    case reject(reason: String)
}
```

The decision defaults to ``.proceed``. Middleware can flip it to ``.reject`` or ``.modify`` for any tool call in the batch.

This is the mechanism for **tool approval**. An Orchestrator-supplied middleware could prompt the user for confirmation:

```swift
struct UserApprovalMiddleware: Middleware {
    let approvalHandler: ([ToolCallContext]) async -> [ToolCallDecision]

    func beforeToolCalls(_ calls: inout [ToolCallContext]) async throws {
        let decisions = await approvalHandler(calls)
        for (index, decision) in decisions.enumerated() {
            calls[index].decision = decision
        }
    }
}
```

The approval handler receives the full batch, so it can present a single prompt to the user: *"The agent wants to read config.json and write output.txt — approve?"* This is more natural than prompting per-tool.

Because the middleware is `async`, it can `await` user input indefinitely. The agent loop pauses naturally — no special pause/resume machinery required.

### Tool Error

```swift
func onToolError(_ error: Error, context: ToolCallContext) async throws -> ToolErrorRecovery
```

Runs when a tool throws an error during execution. Returns a recovery strategy:

```swift
enum ToolErrorRecovery {
    /// Feed the error message back to the LLM as a tool result,
    /// allowing it to adapt or retry with different arguments.
    case feedbackToLLM(String)

    /// Propagate the error, halting the agent loop.
    case `throw`
}
```

The default behavior (when no middleware handles the error) is ``.feedbackToLLM(error.localizedDescription)`` — the LLM receives the error message and can decide how to proceed. This is usually the right behavior, since LLMs are often capable of recovering from tool errors by adjusting their approach.

```swift
struct RetryLogger: Middleware {
    func onToolError(_ error: Error, context: ToolCallContext) async throws -> ToolErrorRecovery {
        log.warning("Tool \(context.name) failed: \(error)")

        if context.attemptCount > 3 {
            return .throw  // Give up after 3 failures
        }

        return .feedbackToLLM("Error: \(error.localizedDescription). Please try a different approach.")
    }
}
```

## Composition Order

Middlewares execute in the order they are provided to the Operative:

```swift
let operative = try Operative(
    llm: myLLM,
    systemPrompt: "...",
    tools: [...],
    budget: Budget(maxTurns: 10),
    middleware: [loggingMiddleware, contentFilter, approvalMiddleware]
)
```

For each middleware point:

1. `loggingMiddleware` runs first
2. `contentFilter` runs second, seeing the output of step 1
3. `approvalMiddleware` runs third, seeing the output of step 2

If any middleware throws, the pipeline short-circuits — later middlewares do not run, and the error propagates. For ``beforeToolCalls``, a rejection by an earlier middleware is visible to later middlewares (the ``decision`` is already set to ``.reject``), but later middlewares can override it if they choose.

This ordering is intuitive: middlewares closer to the beginning of the array are "closer to the outside" (they see raw input first and processed output last), while middlewares closer to the end are "closer to the LLM."

## Middleware vs. Operations

A common question: should I use middleware or observe the Operation stream?

| Need | Use |
|------|-----|
| Block a tool call before it runs | Middleware (``beforeToolCalls``) |
| Display a tool call in the UI | Operations (``.toolsRequested``) |
| Redact content before it reaches the LLM | Middleware (``beforeRequest``) |
| Log what the agent did for debugging | Operations (any event) |
| Modify the LLM's response | Middleware (``afterResponse``) |
| Track token usage over time | Operations (``.turnCompleted``) |
| Recover from a tool error | Middleware (``onToolError``) |
| Show the user that a tool failed | Operations (``.toolFailed``) |

The principle: **middleware is for control, Operations are for observation.** Middleware runs *before* things happen and can change the outcome. Operations describe what *did* happen and are read-only.

## Topics

### Related

- <doc:Operations>
- <doc:Operative>
