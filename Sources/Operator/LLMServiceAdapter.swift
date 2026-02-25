import Foundation
import LLM

/// Adapter that wraps an ``LLM`` actor to conform to ``LLMService``.
///
/// The ``Operative`` convenience initializer that accepts an ``LLM`` instance
/// creates one automatically. You can also create one directly when you need
/// an ``LLMService`` value — for example, to populate the model tier map
/// passed to `Organization`:
///
/// ```swift
/// let llm = LLM(provider: .anthropic(apiKey: key))
/// let service = LLMServiceAdapter(llm)
/// let models: [ModelTier: any LLMService] = [.standard: service]
/// ```
public struct LLMServiceAdapter: LLMService {
    private let llm: LLM

    /// Creates an adapter wrapping the given ``LLM`` actor.
    ///
    /// - Parameter llm: The LLM actor to wrap.
    public init(_ llm: LLM) {
        self.llm = llm
    }

    /// Creates an adapter from a ``Provider``, constructing the ``LLM`` actor internally.
    ///
    /// This is the preferred initializer for consumers that don't need direct
    /// access to the ``LLM`` actor — it avoids requiring `import LLM`.
    ///
    /// ```swift
    /// let service = LLMServiceAdapter(provider: .anthropic(apiKey: key))
    /// ```
    ///
    /// - Parameter provider: The LLM provider to use.
    public init(provider: Provider) {
        llm = LLM(provider: provider)
    }

    public func chat(conversation: Conversation) -> AsyncThrowingStream<StreamEvent, Error> {
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
