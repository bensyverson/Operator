#if canImport(FoundationModels)
    import Foundation
    import FoundationModels

    /// Wraps an Operator tool as a `FoundationModels.Tool` so Apple's on-device
    /// model can call it during its internal tool loop.
    ///
    /// When the session invokes this proxy:
    /// 1. JSON-encode the typed `Input` for the `.toolsRequested` event (observability)
    /// 2. Call the user's `execute` closure directly with the typed `Input`
    /// 3. Emit `.toolCompleted` or `.toolFailed`
    /// 4. Return the string result to Apple's session
    @available(macOS 26.0, iOS 26.0, *)
    struct OperatorToolProxy<Input: ToolInput & Generable>: FoundationModels.Tool {
        let name: String
        let description: String

        typealias Arguments = Input

        private let execute: @Sendable (Input) async throws -> ToolOutput
        private let eventHandler: @Sendable (Operation) -> Void

        init(
            name: String,
            description: String,
            execute: @escaping @Sendable (Input) async throws -> ToolOutput,
            eventHandler: @escaping @Sendable (Operation) -> Void
        ) {
            self.name = name
            self.description = description
            self.execute = execute
            self.eventHandler = eventHandler
        }

        func call(arguments input: Input) async throws -> String {
            let toolCallId = UUID().uuidString

            let argumentsJSON: String
            do {
                let data = try JSONEncoder().encode(input)
                argumentsJSON = String(data: data, encoding: .utf8) ?? "{}"
            } catch {
                argumentsJSON = "{}"
            }
            let request = ToolRequest(
                name: name,
                arguments: argumentsJSON,
                toolCallId: toolCallId
            )

            eventHandler(.toolsRequested([request]))

            do {
                let output = try await execute(input)
                eventHandler(.toolCompleted(request, output))
                return output.textContent ?? ""
            } catch {
                let toolError = ToolError(
                    message: error.localizedDescription,
                    underlyingError: error
                )
                eventHandler(.toolFailed(request, toolError))
                return "Error: \(error.localizedDescription)"
            }
        }
    }
#endif
