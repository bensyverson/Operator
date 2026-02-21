import LLM

/// Abstraction over the LLM library for testability.
///
/// The ``Operative`` calls through this protocol to make LLM requests.
/// In production, ``LLMServiceAdapter`` wraps an ``LLM`` actor. In tests,
/// ``MockLLMService`` returns scripted responses.
public protocol LLMService: Sendable {
    /// Sends a conversation to the LLM and returns a normalized response.
    ///
    /// - Parameter conversation: The full conversation state including
    ///   system prompt, messages, tools, and configuration.
    /// - Returns: A normalized ``LLMResponse`` with text, tool calls,
    ///   usage, and the updated conversation.
    func chat(conversation: LLM.Conversation) async throws -> LLMResponse
}
