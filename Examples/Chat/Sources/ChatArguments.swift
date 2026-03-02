import ArgumentParser

/// CLI arguments for the Chat app.
///
/// Uses `ParsableArguments` (not `ParsableCommand`) so the Chat app's
/// `@main` entry point remains the TextUI `App` conformance.
struct ChatArguments: ParsableArguments {
    @Option(name: .long, help: "LLM provider: anthropic, openai, lmstudio, or apple.")
    var provider: String?

    @Option(name: .long, help: "Base URL for an OpenAI-compatible API.")
    var host: String?

    @Option(name: .long, help: "Model identifier (e.g. anthropic/claude-3.5-sonnet).")
    var model: String?

    @Option(name: .long, help: "API key for the provider.")
    var apiKey: String?

    @Option(name: .long, help: "Model type: fast (default) or flagship.")
    var modelType: String = "fast"

    @Option(name: .long, help: "Maximum agent turns per response.")
    var maxTurns: Int = 10

    @Flag(name: .long, help: "Disable extended thinking / chain-of-thought reasoning.")
    var reasoningOff: Bool = false

    /// Resolves the provider option from the CLI flag.
    var resolvedProvider: ProviderOption? {
        guard let provider else { return nil }
        return ProviderOption(rawValue: provider.lowercased())
    }
}
