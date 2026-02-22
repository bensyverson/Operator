/// Context available at the start of each agent loop turn.
///
/// Carried by ``Operation/turnStarted(_:)``.
public struct TurnContext: Friendly {
    /// The current turn number (1-indexed).
    public let turnNumber: Int

    /// A snapshot of the remaining budget at the start of this turn.
    public let budgetRemaining: Budget

    /// Active pressure signals at the start of this turn.
    public let pressure: [PressureInfo]

    /// Creates a turn context for the given turn number, remaining budget, and pressure signals.
    public init(turnNumber: Int, budgetRemaining: Budget, pressure: [PressureInfo] = []) {
        self.turnNumber = turnNumber
        self.budgetRemaining = budgetRemaining
        self.pressure = pressure
    }
}
