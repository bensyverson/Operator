# Chat

A full-screen terminal chat UI built with [TextUI](https://github.com/bensyverson/TextUI) and [Operator](../../).

Chat demonstrates streaming responses, tool calling, multi-turn conversation, and debug mode — all inside a rich TUI with a provider picker, message bubbles, and a command bar.

## Quick Start

Chat will show an interactive Provider picker on launch.

```bash
swift run
```

If you supply `--provider`, the picker will be skipped:

```
# Apple Intelligence (no API key needed)
swift run --provider apple

# Cloud providers
export ANTHROPIC_API_KEY="sk-ant-..."
swift run Chat --provider anthropic
```


## Options

| Flag | Description |
|---|---|
| `--provider` | `anthropic`, `openai`, `lmstudio`, or `apple` |
| `--host` | Base URL for any OpenAI-compatible API |
| `--model` | Model identifier (e.g. `anthropic/claude-sonnet-4`) |
| `--api-key` | API key (overrides environment variable) |
| `--model-type` | `fast` (default) or `flagship` |
| `--max-turns` | Maximum agent turns per response (default: 10) |
| `--reasoning-off` | Disable extended thinking / chain-of-thought |

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `Enter` | Send message |
| `Ctrl-D` | Toggle debug mode (shows tool calls and thinking) |
| `Ctrl-Q` | Quit |

## Built-in Tools

The agent has access to four tools out of the box:

- **TimeTool** — Current date/time and timezone conversions
- **Calculator** — Arithmetic expression evaluation
- **KeyValueStore** — Persistent key-value storage (in-memory)
- **SystemInfo** — Host name, OS version, CPU architecture

## Using a Custom Host

Point Chat at any OpenAI-compatible endpoint with `--host`:

```bash
# OpenRouter
export OPENROUTER_API_KEY="sk-or-..."
swift run Chat --host https://openrouter.ai/api/v1 --model anthropic/claude-sonnet-4

# Any local server
swift run Chat --host http://localhost:8080/v1
```

## Architecture

Chat is structured as a TextUI `App` with shared `ChatState`:

```
Sources/
├── ChatApp.swift              # @main entry point
├── ChatArguments.swift        # CLI argument parsing
├── ChatMessage.swift          # Message model
├── ChatState.swift            # Shared reactive state
├── ChatState+Operative.swift  # Agent construction
├── ChatState+Provider.swift   # Provider resolution
├── ChatState+SendMessage.swift# Streaming message loop
├── ProviderOption.swift       # Provider enum
├── Tools/                     # Built-in tool implementations
└── Views/                     # TextUI view components
```
