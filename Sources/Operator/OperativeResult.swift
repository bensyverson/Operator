import LLM

/// The final outcome of a successful Operative run.
///
/// Carried by ``Operation/completed(_:)``.
public struct OperativeResult: Friendly {
    /// The agent's final response text.
    public let text: String?

    /// The full conversation history, including all tool calls and results.
    public let conversation: LLM.Conversation

    /// Aggregate token usage for the entire run.
    public let usage: TokenUsage

    /// Total number of turns taken.
    public let turnsUsed: Int

    /// Creates an operative result with the given text, conversation, usage, and turn count.
    public init(
        text: String?,
        conversation: LLM.Conversation,
        usage: TokenUsage,
        turnsUsed: Int
    ) {
        self.text = text
        self.conversation = conversation
        self.usage = usage
        self.turnsUsed = turnsUsed
    }
}
