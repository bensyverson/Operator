/// Information about resource utilization pressure on the agent.
///
/// Emitted via ``Operation/pressure(_:)`` when utilization exceeds
/// the configured ``Budget/pressureThreshold``. Middleware can inspect
/// pressure via ``RequestContext/pressure`` to react (e.g., trigger compaction).
public struct PressureInfo: Friendly {
    /// The dimension being measured.
    public enum Dimension: String, Friendly {
        /// Context window approaching capacity (prompt tokens vs window size).
        case contextWindow
        /// Cumulative token budget approaching limit.
        case tokenBudget
    }

    /// Which resource dimension is under pressure.
    public let dimension: Dimension

    /// Current utilization as a fraction of capacity (0.0–1.0+).
    public let utilization: Double

    /// The current value (e.g., tokens used).
    public let current: Int

    /// The capacity limit (e.g., context window size or token budget).
    public let limit: Int

    /// Creates a pressure info with the given dimension, utilization, current value, and limit.
    public init(dimension: Dimension, utilization: Double, current: Int, limit: Int) {
        self.dimension = dimension
        self.utilization = utilization
        self.current = current
        self.limit = limit
    }
}
