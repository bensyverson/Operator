# Architecture

How Operator fits into the broader agentic stack.

## Overview

The agentic stack is composed of three libraries, each with a distinct responsibility and audience. They are designed to be used independently — you only depend on the layers you need.

### LLM

The foundation layer. LLM handles raw communication with language model providers (OpenAI, Anthropic, local models). It is also the layer used by ``AppleIntelligenceService`` to normalize on-device Foundation Model responses into the same format as cloud providers. LLM is:

- **Stateless**: Each call is independent. LLM does not track conversations or tool state.
- **Provider-agnostic**: A single API surface with provider-specific serialization handled internally.
- **Minimal**: It sends prompts, receives responses, manages rate limits, and nothing more.

LLM defines the wire types that flow between your application and the model: ``LLM/OpenAICompatibleAPI/ChatMessage``, ``LLM/ToolDefinition``, ``LLM/JSONSchema``, and others. Operator builds on these types but does not expose them directly to tool authors.

### Operator

The agent layer. Operator runs an LLM in a loop with access to tools. Its core responsibilities are:

- **Tool management**: Defining, registering, and dispatching tools via the ``Operable`` protocol and ``ToolProvider`` type.
- **The agent loop**: Sending messages to the LLM, parsing tool calls from responses, executing tools, and feeding results back until the task is complete or a budget is exhausted.
- **Middleware**: A pipeline for transforming, filtering, or intercepting messages, tool calls, and responses.
- **Budget enforcement**: Limiting the agent's resource usage by turns, tokens, or wall-clock time.
- **Event streaming**: Emitting a real-time ``AsyncSequence`` of ``Operation`` events that describe everything the agent does.

Operator is deliberately unopinionated. It provides the mechanism for running an agent, but leaves policy decisions — prompt engineering, tool approval UX, context management strategies — to the consumer or to OperativeKit.

### [OperativeKit](https://github.com/bensyverson/OperativeKit)

The composition layer. OperativeKit allows developers to build complex agentic systems by composing multiple Operatives. Capabilities include:

- **Sub-agents**: Spawning child Operatives with their own tools and budgets for focused sub-tasks.
- **Parallel execution**: Running multiple agents concurrently and merging their results.
- **Skills**: Reusable, pre-configured tool + prompt bundles that can be attached to agents.
- **Memory**: Persistent state across agent runs — conversation history, learned facts, user preferences.
- **Context management**: Strategies for compressing, summarizing, or clearing context when budgets run low.
- **Planning**: Structured reasoning modes where the agent proposes a plan before executing.

Each sub-agent in OperativeKit is an ``Operative`` instance. OperativeKit composes Operatives; it does not replace them.

## Why Three Layers?

This separation exists because real applications have different needs:

- **Non-agentic apps** depend on LLM alone. They make direct calls to language models for classification, extraction, summarization, or conversation — no tool loop needed.
- **Simple agentic apps** depend on Operator. They need a tool-using agent but don't require multi-agent coordination. A coding assistant, a data analysis bot, or a customer support agent might fall here.
- **Complex agentic apps** depend on OperativeKit. They coordinate multiple agents with different roles, manage shared memory, and implement sophisticated control flow.

Each layer adds capability without forcing complexity on simpler use cases.

## Data Flow

A single turn of the agent loop flows through these layers:

```
Consumer
   │
   ▼
┌──────────────────────────────────────┐
│  Operative                           │
│                                      │
│  1. Apply pre-request middleware     │
│  2. Send messages + tool schemas     │──── LLM ────▶ Provider API
│  3. Receive response                 │◀────────────
│  4. Apply post-response middleware   │
│  5. Parse tool calls                 │
│  6. Apply pre-tool-call middleware   │
│  7. Execute approved tools           │
│  8. Handle errors (error middleware) │
│  9. Emit Operations to consumer      │
│  10. Check budget → continue or stop │
│                                      │
└──────────────────────────────────────┘
   │
   ▼
Operation stream (AsyncSequence)
```

OperativeKit, when present, sits above this loop. It creates and manages Operatives, observes their Operation streams, and makes decisions about spawning new agents, adjusting budgets, or compressing context.

## Design Principles

Several principles guided the architecture:

- **Capability providers, not data.** Types that conform to ``Operable`` represent things that *do* something (file systems, web clients, parsers), not things that *are* something (URLs, strings, records). Data flows through tool arguments and user messages.
- **Events for observation, middleware for control.** The ``Operation`` stream is a factual log of what happened — consumers use it for display, logging, and downstream decisions. ``Middleware`` is for intercepting and transforming behavior *before* it happens.
- **Budgets, not unbounded loops.** Every Operative runs within a ``Budget``. There is no "run forever" mode. This is a safety property that also enables OperativeKit to reason about resource allocation.
- **The LLM decides.** Operator does not impose tool selection heuristics. The language model decides which tools to call, in what order, and when to stop. Middleware can override specific decisions, but the default is to trust the model.
- **Engine-agnostic.** The ``LLMService`` protocol abstracts over model providers. Cloud LLMs (Claude, GPT) are the primary target, but the same ``Operative`` can be powered by Apple's on-device Foundation Models via ``AppleIntelligenceService`` — see <doc:AppleIntelligence>.
