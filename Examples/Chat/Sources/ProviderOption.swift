import Foundation

/// Available LLM providers for the chat app.
enum ProviderOption: String, CaseIterable, Sendable {
    case apple
    case anthropic
    case openai
    case lmstudio

    /// Display name for the picker UI.
    var displayName: String {
        switch self {
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .lmstudio: "LM Studio"
        case .apple: "Apple Intelligence"
        }
    }

    /// The environment variable name for the API key, if required.
    var envKeyName: String? {
        switch self {
        case .anthropic: "ANTHROPIC_API_KEY"
        case .openai: "OPENAI_API_KEY"
        case .lmstudio: nil
        case .apple: nil
        }
    }

    /// Whether this provider requires an API key.
    var requiresAPIKey: Bool {
        envKeyName != nil
    }

    /// Checks whether the required API key is available in the environment.
    func hasAPIKey() -> Bool {
        guard let envKeyName else { return true }
        let value = ProcessInfo.processInfo.environment[envKeyName]
        return value != nil && !value!.isEmpty
    }

    /// Returns the API key from the environment, if available.
    func apiKey() -> String? {
        guard let envKeyName else { return nil }
        return ProcessInfo.processInfo.environment[envKeyName]
    }
}
