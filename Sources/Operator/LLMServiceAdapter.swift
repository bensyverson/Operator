import LLM

/// Internal adapter that wraps an ``LLM`` actor to conform to ``LLMService``.
///
/// Users never interact with this type directly. The ``Operative``
/// convenience initializer that accepts an ``LLM`` instance creates
/// one automatically.
struct LLMServiceAdapter: LLMService {
    private let llm: LLM

    init(_ llm: LLM) {
        self.llm = llm
    }

    func chat(conversation: LLM.Conversation) -> AsyncThrowingStream<LLM.StreamEvent, Error> {
        let service = llm
        let conversationSnapshot = conversation
        return AsyncThrowingStream { continuation in
            Task {
                let stream = await service.streamChat(conversation: conversationSnapshot)
                do {
                    for try await event in stream {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
