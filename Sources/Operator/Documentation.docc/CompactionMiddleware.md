# Compaction Middleware

Mechanically reducing conversation history to manage context window usage.

## Overview

``CompactionMiddleware`` is a built-in middleware that reduces the size of the conversation history without making any LLM calls. It operates in ``Middleware/beforeRequest(_:)`` using four progressive phases:

1. **Truncate** — Tool outputs in older messages that exceed ``CompactionMiddleware/maxToolOutputLength`` characters are truncated, with a marker indicating how much was removed.
2. **Strip media** — Images and PDFs in older messages are replaced with text placeholders (e.g., `[Image: "photo.jpg"]`, `[PDF: "report.pdf"]`), preserving metadata while dramatically reducing token usage.
3. **Collapse** — Old tool call/result pairs are replaced with brief summaries (e.g., `[Collapsed: called search, read_file]`).
4. **Trim** — The oldest non-system messages are removed entirely when the estimated token count still exceeds ``CompactionMiddleware/targetTokenEstimate``.

Each phase is more aggressive than the last. The middleware always preserves:
- **System messages** — Never removed or modified.
- **Recent turns** — The most recent ``CompactionMiddleware/preserveRecentTurns`` turns are exempt from truncation and collapsing.

### Compaction vs. Summarization

CompactionMiddleware performs *mechanical* reduction — it truncates, collapses, and trims without understanding the content. This is fast, predictable, and free (no LLM calls). For *semantic* reduction that preserves meaning, build a custom middleware that calls the LLM to summarize older messages.

## Configuration

```swift
let compactor = CompactionMiddleware(
    maxToolOutputLength: 4000,     // Truncate tool outputs beyond this
    preserveRecentTurns: 4,        // Keep the last 4 turns intact
    targetTokenEstimate: 50_000,   // Aim for ~50k tokens
    pressureOnly: true             // Only compact when under pressure
)
```

### Pressure-Driven Compaction

When ``CompactionMiddleware/pressureOnly`` is `true` (recommended), the middleware only activates when ``RequestContext/pressure`` is non-empty. This integrates with the agent loop's pressure detection:

```swift
let operative = try Operative(
    name: "LongRunner",
    description: "An agent with long sessions",
    provider: .anthropic(apiKey: key),
    systemPrompt: "...",
    tools: [myTools],
    budget: Budget(
        maxTurns: 100,
        contextWindowTokens: 200_000,  // Enables pressure detection
        pressureThreshold: 0.8         // Signal at 80% utilization
    ),
    middleware: [
        CompactionMiddleware(pressureOnly: true)
    ]
)
```

With this setup, the agent runs normally until context window utilization reaches 80%. At that point, pressure signals appear in ``RequestContext/pressure``, and the compaction middleware begins reducing the conversation history.

### Always-On Compaction

When ``CompactionMiddleware/pressureOnly`` is `false`, compaction runs every turn. This is useful for agents that are known to have long-running sessions:

```swift
CompactionMiddleware(
    maxToolOutputLength: 2000,
    preserveRecentTurns: 6,
    targetTokenEstimate: 30_000,
    pressureOnly: false
)
```

## Token Estimation

CompactionMiddleware uses rough heuristics for internal size decisions: text characters / 4, each image ~1000 tokens, each PDF ~500 tokens. This means conversations with images trigger compaction sooner, which is appropriate given the token cost of vision input. These estimates are only used to decide *how aggressively* to compact (phases 3 and 4), not *whether* to compact — that decision is driven by the actual API-reported pressure signals when ``pressureOnly`` is `true`.

## Topics

### Related

- <doc:Middleware>
- <doc:Budget>
- <doc:Operations>
