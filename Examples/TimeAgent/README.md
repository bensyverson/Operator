# TimeAgent

A minimal CLI agent built with [Operator](../../) that demonstrates tool use, multi-turn conversation, and LLM provider configuration.

## Tools

- **Time** — get the current time, query the timezone, and perform date arithmetic
- **Key-Value Store** — store and retrieve values in memory

## Usage

```bash
cd Examples/TimeAgent
swift run TimeAgent
```

This starts an interactive REPL. The agent remembers context across turns:

```
TimeAgent ready. Type your message, or "quit" to exit.

> What time is it?
It's currently Friday, February 21, 2026 at 4:30 PM PST.

> Store that as "last_check"
Done — stored "last_check" = "Friday, February 21, 2026 at 4:30 PM PST".

> What's 90 days from now?
90 days from today is Thursday, May 22, 2026.

> quit
```

### Provider options

```bash
# Local LM Studio (default)
swift run TimeAgent

# Anthropic (reads ANTHROPIC_API_KEY from environment)
swift run TimeAgent --provider anthropic

# OpenAI with explicit key
swift run TimeAgent --provider openai --api-key sk-...

# Use the flagship model with more turns per response
swift run TimeAgent --model-type flagship --max-turns 20
```

Text output streams to stdout; tool activity and diagnostics print to stderr.
