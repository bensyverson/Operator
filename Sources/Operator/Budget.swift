import Foundation
import LLM

/// Constraints that govern how long an Operative may run.
///
/// All fields are optional. An unset field means "no limit" for that dimension.
public struct Budget: Friendly {
    /// Maximum number of LLM round-trips.
    public var maxTurns: Int?

    /// Maximum cumulative tokens across all turns.
    public var maxTokens: Int?

    /// Maximum tokens per individual LLM call.
    public var maxTokensPerTurn: Int?

    /// Wall-clock time limit for the entire run.
    public var timeout: Duration?

    /// Override for the context window size in tokens.
    ///
    /// When set, the agent loop computes context window pressure using
    /// the API-reported prompt token count against this limit. When `nil`,
    /// no context window pressure is calculated.
    public var contextWindowTokens: Int?

    /// Utilization threshold (0.0–1.0) at which pressure signals are emitted.
    ///
    /// Defaults to `0.8` (80%). Pressure is emitted when utilization of any
    /// dimension exceeds this threshold.
    public var pressureThreshold: Double

    /// Creates a budget with the given limits.
    public init(
        maxTurns: Int? = nil,
        maxTokens: Int? = nil,
        maxTokensPerTurn: Int? = nil,
        timeout: Duration? = nil,
        contextWindowTokens: Int? = nil,
        pressureThreshold: Double = 0.8
    ) {
        self.maxTurns = maxTurns
        self.maxTokens = maxTokens
        self.maxTokensPerTurn = maxTokensPerTurn
        self.timeout = timeout
        self.contextWindowTokens = contextWindowTokens
        self.pressureThreshold = pressureThreshold
    }

    // MARK: - Codable (Duration is not Codable, so we encode it as seconds)

    enum CodingKeys: String, CodingKey {
        case maxTurns
        case maxTokens
        case maxTokensPerTurn
        case timeoutSeconds
        case contextWindowTokens
        case pressureThreshold
    }

    /// Creates a budget by decoding from the given decoder.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxTurns = try container.decodeIfPresent(Int.self, forKey: .maxTurns)
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        maxTokensPerTurn = try container.decodeIfPresent(Int.self, forKey: .maxTokensPerTurn)
        if let seconds = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) {
            timeout = Duration.seconds(seconds)
        } else {
            timeout = nil
        }
        contextWindowTokens = try container.decodeIfPresent(Int.self, forKey: .contextWindowTokens)
        pressureThreshold = try container.decodeIfPresent(Double.self, forKey: .pressureThreshold) ?? 0.8
    }

    /// Encodes the budget into the given encoder.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(maxTurns, forKey: .maxTurns)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(maxTokensPerTurn, forKey: .maxTokensPerTurn)
        if let timeout {
            let seconds = Double(timeout.components.seconds) +
                Double(timeout.components.attoseconds) / 1e18
            try container.encode(seconds, forKey: .timeoutSeconds)
        }
        try container.encodeIfPresent(contextWindowTokens, forKey: .contextWindowTokens)
        try container.encode(pressureThreshold, forKey: .pressureThreshold)
    }
}
