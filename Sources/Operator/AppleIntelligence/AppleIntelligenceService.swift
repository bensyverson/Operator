#if canImport(FoundationModels)
    import Foundation
    import FoundationModels
    import LLM

    /// An ``LLMService`` that uses Apple's on-device Foundation Models.
    ///
    /// Creates a fresh `LanguageModelSession` per ``chat(conversation:)``
    /// call. Prior conversation messages are formatted as a plain-text
    /// transcript and appended to the session instructions so the model
    /// has context without replaying inference.
    ///
    /// > Important: Requires Apple Intelligence–enabled hardware running
    /// > macOS 26+ or iOS 26+. The on-device model does not report token
    /// > usage, does not support tool calling through Operator's loop, and
    /// > does not expose extended thinking.
    ///
    /// See <doc:AppleIntelligence> for usage guidance.
    @available(macOS 26.0, iOS 26.0, *)
    public struct AppleIntelligenceService: LLMService {
        /// Creates an Apple Intelligence service.
        public init() {}

        public func chat(conversation: Conversation) -> AsyncThrowingStream<StreamEvent, Error> {
            let conversationSnapshot = conversation
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        // Build session instructions from system prompt + prior messages
                        let priorMessages = conversationSnapshot.messages.dropLast()
                        var instructions = conversationSnapshot.systemPrompt

                        if !priorMessages.isEmpty {
                            let transcript = ConversationFormatter.format(priorMessages)
                            instructions += "\n\nConversation so far:\n" + transcript
                        }

                        let session = LanguageModelSession(instructions: instructions)

                        // The final message should be the user's latest input
                        let userMessage: String = conversationSnapshot.messages.last?.content ?? ""
                        let response = try await session.respond(to: userMessage)
                        let responseText = response.content

                        // Emit the full text as a single delta
                        continuation.yield(.textDelta(responseText))

                        // Build updated conversation with assistant response appended
                        let updatedConversation = conversationSnapshot.addingAssistantMessage(responseText)

                        let conversationResponse = ConversationResponse(
                            text: responseText,
                            thinking: nil,
                            toolCalls: [],
                            conversation: updatedConversation,
                            rawResponse: LLM.OpenAICompatibleAPI.ChatCompletionResponse()
                        )
                        continuation.yield(.completed(conversationResponse))
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }
#endif
