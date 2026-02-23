import ArgumentParser
import Foundation
import LLM
import Operator

@main
struct TimeAgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "TimeAgent",
        abstract: "A demo CLI agent with time utilities and a key-value store."
    )

    @Option(name: .long, help: "LLM provider: openai, anthropic, lmstudio, or apple. Auto-detects from API key env vars if omitted.")
    var provider: String?

    @Option(name: .long, help: "API key for the provider. Falls back to OPENAI_API_KEY or ANTHROPIC_API_KEY.")
    var apiKey: String?

    @Option(name: .long, help: "Model type: fast (default) or flagship.")
    var modelType: String = "fast"

    @Option(name: .long, help: "Maximum number of agent turns per response.")
    var maxTurns: Int = 10

    func run() async throws {
        let operative = try buildOperative()

        print("TimeAgent ready. Type your message, or \"quit\" to exit.\n")

        var lastConversation: LLM.Conversation?

        while true {
            print("> ", terminator: "")
            guard let line = readLine(strippingNewline: true) else { break }
            let input = line.trimmingCharacters(in: .whitespaces)
            if input.isEmpty { continue }
            if input.lowercased() == "quit" || input.lowercased() == "exit" { break }

            let stream: OperationStream = if let conversation = lastConversation {
                operative.run(input, continuing: conversation)
            } else {
                operative.run(input)
            }

            for await operation in stream {
                switch operation {
                case let .text(chunk):
                    print(chunk, terminator: "")
                case let .turnStarted(context):
                    StderrStream.print("  [turn \(context.turnNumber)]")
                case let .toolsRequested(requests):
                    for request in requests {
                        StderrStream.print("  [call] \(request.name)")
                    }
                case let .toolCompleted(request, output):
                    StderrStream.print("  [done] \(request.name) -> \(output.content.prefix(120))")
                case let .toolFailed(request, error):
                    StderrStream.print("  [fail] \(request.name): \(error)")
                case let .completed(result):
                    print() // final newline after streamed text
                    StderrStream.print("  [ok] \(result.turnsUsed) turn(s), \(result.usage.totalTokens) tokens")
                    lastConversation = result.conversation
                case let .stopped(reason):
                    print()
                    StderrStream.print("  [stopped] \(reason)")
                    // Keep the conversation even if the budget was hit
                    if case let .completed(result) = operation {
                        lastConversation = result.conversation
                    }
                default:
                    break
                }
            }

            print() // blank line between exchanges
        }
    }

    private func buildOperative() throws -> Operative {
        let systemPrompt = "You are a helpful assistant with access to time utilities and a key-value store. Use your tools to answer the user's questions accurately."
        let tools: [any Operable] = [TimeTool(), KeyValueStore()]
        let budget = Budget(maxTurns: maxTurns)

        #if canImport(FoundationModels)
            if provider?.lowercased() == "apple" {
                guard #available(macOS 26.0, iOS 26.0, *) else {
                    throw ValidationError("Apple Intelligence requires macOS 26.0 or later.")
                }
                return try Operative(
                    name: "TimeAgent",
                    description: "A demo agent with time utilities and a key-value store",
                    systemPrompt: systemPrompt,
                    tools: tools,
                    budget: budget
                )
            }
        #endif

        let resolvedProvider = try resolveProvider()
        let llm = LLM(provider: resolvedProvider)

        let resolvedModelType: LLM.ModelType = switch modelType {
        case "flagship": .flagship
        default: .fast
        }

        let config = LLM.ConversationConfiguration(modelType: resolvedModelType, maxTokens: 4096)

        return try Operative(
            name: "TimeAgent",
            description: "A demo agent with time utilities and a key-value store",
            llm: llm,
            systemPrompt: systemPrompt,
            tools: tools,
            budget: budget,
            configuration: config
        )
    }

    private func resolveProvider() throws -> LLM.Provider {
        let env = ProcessInfo.processInfo.environment

        // If the user specified a provider explicitly, use it.
        if let provider {
            switch provider.lowercased() {
            case "openai":
                guard let key = apiKey ?? env["OPENAI_API_KEY"] else {
                    throw ValidationError("OpenAI requires an API key via --api-key or OPENAI_API_KEY.")
                }
                return .openAI(apiKey: key)
            case "anthropic":
                guard let key = apiKey ?? env["ANTHROPIC_API_KEY"] else {
                    throw ValidationError("Anthropic requires an API key via --api-key or ANTHROPIC_API_KEY.")
                }
                return .anthropic(apiKey: key)
            case "lmstudio":
                return .lmStudio
            case "apple":
                throw ValidationError("Apple Intelligence is not available on this platform.")
            default:
                throw ValidationError("Unknown provider '\(provider)'. Use openai, anthropic, lmstudio, or apple.")
            }
        }

        // Auto-detect from --api-key or environment variables.
        if let key = apiKey ?? env["ANTHROPIC_API_KEY"] {
            return .anthropic(apiKey: key)
        }
        if let key = apiKey ?? env["OPENAI_API_KEY"] {
            return .openAI(apiKey: key)
        }

        // Fall back to local LM Studio.
        return .lmStudio
    }
}

// MARK: - StderrStream

enum StderrStream {
    static func print(_ message: String) {
        var stream = Stream()
        Swift.print(message, to: &stream)
    }

    private struct Stream: TextOutputStream {
        mutating func write(_ string: String) {
            FileHandle.standardError.write(Data(string.utf8))
        }
    }
}
