# Budget and Termination

Controlling how long and how far an Operative can run.

## Overview

Every ``Operative`` runs within a ``Budget``. There is no "run forever" mode — budgets are a fundamental safety property that also enables Orchestrator to reason about resource allocation across multiple agents.

A Budget defines four independent limits. The Operative checks all four at the start of each turn and stops as soon as any limit is reached.

## The Budget Type

```swift
struct Budget: Friendly {
    /// Maximum number of turns (LLM round-trips) the agent may take.
    var maxTurns: Int?

    /// Maximum total tokens (prompt + completion) across all turns.
    var maxTokens: Int?

    /// Maximum tokens for a single LLM call.
    var maxTokensPerTurn: Int?

    /// Maximum wall-clock time for the entire run.
    var timeout: Duration?
}
```

All fields are optional. An unset limit means no constraint on that dimension. However, at least one limit should be set in practice — an Operative with no budget constraints could loop indefinitely.

### Examples

```swift
// A focused agent: 5 turns, 2 minutes max
Budget(maxTurns: 5, timeout: .seconds(120))

// A long-running agent with token awareness
Budget(maxTurns: 50, maxTokens: 200_000, maxTokensPerTurn: 8_000)

// A quick, single-shot agent
Budget(maxTurns: 1)
```

## Termination Conditions

When a budget limit is reached, the Operative emits a ``.stopped`` Operation with a ``StopReason`` indicating which limit caused termination:

```swift
enum StopReason: Friendly {
    /// The maxTurns limit was reached.
    case turnLimitReached

    /// Cumulative token usage exceeded maxTokens.
    case tokenBudgetExhausted

    /// The timeout duration elapsed.
    case timeout

    /// A tool or middleware explicitly requested termination.
    case explicitStop(reason: String)
}
```

### Turn Limit

The Operative increments a turn counter at the start of each iteration. If the counter exceeds ``Budget/maxTurns``, the loop stops before making another LLM call.

This is the simplest and most predictable limit. Use it when you want to bound the number of LLM round-trips regardless of cost.

### Token Budget

The Operative tracks cumulative token usage (prompt + completion) across all turns. After each LLM response, it adds the reported token counts to a running total. If the total exceeds ``Budget/maxTokens``, the loop stops before the next turn.

The per-turn limit (``Budget/maxTokensPerTurn``) is passed to the LLM as a maximum completion token budget for each individual call. This prevents a single turn from consuming a disproportionate share of the global budget.

Token counts come from the LLM provider's usage reports — Operator does not estimate tokens independently. If the provider does not report usage (some local models), token-based budgeting will not function.

### Timeout

The Operative records the start time of each ``run(_:)`` call. At the start of each turn, it checks elapsed time against ``Budget/timeout``. If the timeout has passed, the loop stops.

The timeout is wall-clock time, not CPU time. It includes time spent waiting for LLM responses, executing tools, and awaiting middleware (including user approval prompts). If a tool approval middleware blocks for user input, that time counts against the timeout.

### Explicit Stop

Any tool can signal that the agent should stop by returning a special ``ToolOutput`` value:

```swift
func call(arguments: ToolArguments) async throws -> ToolOutput {
    return ToolOutput.stop(reason: "Task complete — all files processed")
}
```

Middleware can also trigger an explicit stop by throwing a ``StopRequested`` error from any middleware point.

This is useful for tools that know the task is done (e.g., a "submit answer" tool), or for middleware that detects a termination condition the budget doesn't cover.

## Budget Tracking and Reporting

The Operative tracks budget consumption throughout a run and reports it via Operations:

- ``TurnContext`` (in ``.turnStarted``): Includes ``budgetRemaining`` — a snapshot of how much budget is left on each dimension.
- ``TurnResult`` (in ``.turnCompleted``): Includes ``usage`` for the turn and ``cumulativeUsage`` for the run so far.
- ``OperativeResult`` (in ``.completed``): Includes the final aggregate ``usage`` across all turns.

This information is designed for Orchestrator consumption. When Orchestrator observes that a child agent's budget is running low, it can decide to:

- Compress context and spawn a continuation agent
- Abort the sub-task and try a different approach
- Allocate additional budget

## Budget and Orchestrator

Orchestrator creates Operatives with specific budgets to control resource allocation:

```swift
// A root agent with a generous budget
let rootAgent = Operative(
    llm: flagshipLLM,
    systemPrompt: "You are a project manager coordinating sub-tasks.",
    tools: [...],
    budget: Budget(maxTurns: 50, maxTokens: 500_000, timeout: .minutes(10))
)

// A focused sub-agent with a tight budget
let subAgent = Operative(
    llm: fastLLM,
    systemPrompt: "You search the web for specific information.",
    tools: [webSearch],
    budget: Budget(maxTurns: 5, maxTokens: 20_000, timeout: .seconds(30))
)
```

By varying budgets and LLM instances, Orchestrator can balance cost, speed, and capability across a multi-agent system.

## Topics

### Related

- <doc:Operative>
- <doc:Operations>
