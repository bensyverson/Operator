/// Context available at the start of each agent loop turn.
///
/// Carried by ``Operation/turnStarted(_:)``.
public struct TurnContext: Friendly {
    /// The current turn number (1-indexed).
    public let turnNumber: Int

    /// A snapshot of the remaining budget at the start of this turn.
    public let budgetRemaining: Budget

    /// Creates a turn context for the given turn number and remaining budget.
    public init(turnNumber: Int, budgetRemaining: Budget) {
        self.turnNumber = turnNumber
        self.budgetRemaining = budgetRemaining
    }
}
