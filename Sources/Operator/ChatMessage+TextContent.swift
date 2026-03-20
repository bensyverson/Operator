import LLM

public extension ChatMessage {
    /// The concatenated text content of this message, or `nil` if there are no text parts.
    ///
    /// Re-exposed from the underlying LLM type so that consumers of Operator
    /// can access it without importing LLM directly.
    var extractedText: String? {
        let texts = content.compactMap(\.textContent)
        return texts.isEmpty ? nil : texts.joined()
    }
}
