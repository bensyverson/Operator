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

    @Flag(name: .shortAndLong, help: "Show detailed debug output on stderr.")
    var verbose: Bool = false

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

            var spinnerTask: Task<Void, Never>?
            var completedTools = false

            // Ensure the cursor is restored if we exit unexpectedly.
            defer {
                spinnerTask?.cancel()
                Terminal.showCursor()
            }

            for await operation in stream {
                switch operation {
                case let .text(chunk):
                    if spinnerTask != nil {
                        spinnerTask?.cancel()
                        spinnerTask = nil
                        Terminal.clearLine()
                    }
                    if completedTools {
                        print() // blank line between tool traces and response
                        completedTools = false
                    }
                    Terminal.write(chunk)

                case let .turnStarted(context):
                    if verbose {
                        StderrStream.print("  [turn \(context.turnNumber)]")
                    } else {
                        spinnerTask?.cancel()
                        spinnerTask = Task { await Self.animate("Thinking…") }
                    }

                case let .toolsRequested(requests):
                    if verbose {
                        for request in requests {
                            StderrStream.print("  [call] \(request.name)")
                        }
                    } else {
                        let names = requests.map(\.name).joined(separator: ", ")
                        spinnerTask?.cancel()
                        spinnerTask = Task { await Self.animate("Calling \(names)…") }
                    }

                case let .toolCompleted(request, output):
                    if verbose {
                        StderrStream.print("  [done] \(request.name) -> \(output.content.prefix(120))")
                    } else {
                        if spinnerTask != nil {
                            spinnerTask?.cancel()
                            spinnerTask = nil
                            Terminal.clearLine()
                        }
                        print("  [Tool: \(request.name)]")
                        completedTools = true
                    }

                case let .toolFailed(request, error):
                    if spinnerTask != nil {
                        spinnerTask?.cancel()
                        spinnerTask = nil
                        Terminal.clearLine()
                    }
                    print("Error: \(request.name) — \(error)")

                case let .completed(result):
                    if spinnerTask != nil {
                        spinnerTask?.cancel()
                        spinnerTask = nil
                        Terminal.clearLine()
                    }
                    print() // final newline after streamed text
                    if verbose {
                        StderrStream.print("  [ok] \(result.turnsUsed) turn(s), \(result.usage.totalTokens) tokens")
                    }
                    lastConversation = result.conversation

                case let .stopped(reason):
                    if spinnerTask != nil {
                        spinnerTask?.cancel()
                        spinnerTask = nil
                        Terminal.clearLine()
                    }
                    print()
                    print("Stopped: \(reason)")

                default:
                    break
                }
            }

            print() // blank line between exchanges
        }
    }

    // MARK: - Spinner

    private static func animate(_ label: String) async {
        let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        Terminal.hideCursor()
        var i = 0
        while !Task.isCancelled {
            Terminal.write("\r\u{1B}[2K\u{1B}[2m\(frames[i % frames.count]) \(label)\u{1B}[0m")
            i += 1
            try? await Task.sleep(for: .milliseconds(80))
        }
    }

    // MARK: - Operative Setup

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

// MARK: - Terminal

private enum Terminal {
    static func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    static func clearLine() {
        write("\r\u{1B}[2K\u{1B}[?25h")
    }

    static func hideCursor() {
        write("\u{1B}[?25l")
    }

    static func showCursor() {
        write("\u{1B}[?25h")
    }
}

// MARK: - StderrStream

private enum StderrStream {
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
