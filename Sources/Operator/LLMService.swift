import LLM

/// Abstraction over the LLM library for testability.
///
/// The ``Operative`` calls through this protocol to make LLM requests.
/// In production, ``LLMServiceAdapter`` wraps an ``LLM`` actor. In tests,
/// ``MockLLMService`` returns scripted responses.
public protocol LLMService: Sendable {
    /// Streams a conversation to the LLM, yielding incremental events.
    ///
    /// The returned stream emits ``LLM/StreamEvent`` values:
    /// - `.textDelta` — an incremental chunk of response text
    /// - `.thinkingDelta` — an incremental chunk of extended thinking
    /// - `.toolCallDelta` — partial tool call data (consumed internally)
    /// - `.completed` — the final ``LLM/ConversationResponse`` with
    ///   full text, tool calls, usage, and the updated conversation
    ///
    /// Errors are delivered through the stream rather than thrown directly.
    ///
    /// - Parameter conversation: The full conversation state including
    ///   system prompt, messages, tools, and configuration.
    /// - Returns: An asynchronous stream of ``LLM/StreamEvent`` values.
    func chat(conversation: LLM.Conversation) -> AsyncThrowingStream<LLM.StreamEvent, Error>
}
