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

    /// Sets the image resizer on the underlying ``LLM`` actor.
    ///
    /// The resizer is called automatically when images exceed the model's
    /// maximum input dimensions. On Apple platforms, a CoreGraphics-based
    /// resizer is set by default.
    ///
    /// - Parameter resizer: A closure that resizes image data, or `nil` to disable.
    public func setImageResizer(
        _ resizer: (@Sendable (Data, String, CGSize) async throws -> Data)?
    ) async {
        await llm.setImageResizer(resizer)
    }

    /// Sets the image describer on the underlying ``LLM`` actor.
    ///
    /// When set, this closure is called during media stripping to generate
    /// text descriptions for images that lack one, preserving semantic
    /// information when images are removed from older messages.
    ///
    /// - Parameter describer: A closure that generates a text description, or `nil` to disable.
    public func setImageDescriber(
        _ describer: (@Sendable (Data, String) async throws -> String)?
    ) async {
        await llm.setImageDescriber(describer)
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
