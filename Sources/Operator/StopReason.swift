import LLM

/// Why an Operative stopped running.
public enum StopReason: Friendly {
    /// The turn limit from ``Budget/maxTurns`` was reached.
    case turnLimitReached

    /// The cumulative token budget from ``Budget/maxTokens`` was exhausted.
    case tokenBudgetExhausted

    /// The wall-clock timeout from ``Budget/timeout`` expired.
    case timeout

    /// A tool explicitly requested the Operative to stop.
    case explicitStop(reason: String)
}
