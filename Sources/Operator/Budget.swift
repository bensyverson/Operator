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

    public init(
        maxTurns: Int? = nil,
        maxTokens: Int? = nil,
        maxTokensPerTurn: Int? = nil,
        timeout: Duration? = nil
    ) {
        self.maxTurns = maxTurns
        self.maxTokens = maxTokens
        self.maxTokensPerTurn = maxTokensPerTurn
        self.timeout = timeout
    }

    // MARK: - Codable (Duration is not Codable, so we encode it as seconds)

    enum CodingKeys: String, CodingKey {
        case maxTurns
        case maxTokens
        case maxTokensPerTurn
        case timeoutSeconds
    }

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
    }

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
    }
}
