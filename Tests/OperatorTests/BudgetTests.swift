import Foundation
@testable import Operator
import Testing

@Suite("Budget")
struct BudgetTests {
    @Test("Default init has all nil fields")
    func defaultInit() {
        let budget = Budget()
        #expect(budget.maxTurns == nil)
        #expect(budget.maxTokens == nil)
        #expect(budget.maxTokensPerTurn == nil)
        #expect(budget.timeout == nil)
    }

    @Test("Custom values are stored correctly")
    func customValues() {
        let budget = Budget(
            maxTurns: 10,
            maxTokens: 50000,
            maxTokensPerTurn: 4096,
            timeout: .seconds(120)
        )
        #expect(budget.maxTurns == 10)
        #expect(budget.maxTokens == 50000)
        #expect(budget.maxTokensPerTurn == 4096)
        #expect(budget.timeout == .seconds(120))
    }

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let budget = Budget(
            maxTurns: 5,
            maxTokens: 10000,
            maxTokensPerTurn: 2048,
            timeout: .seconds(60)
        )
        let data = try JSONEncoder().encode(budget)
        let decoded = try JSONDecoder().decode(Budget.self, from: data)
        #expect(decoded == budget)
    }

    @Test("Codable round-trip with nil fields")
    func codableRoundTripNil() throws {
        let budget = Budget()
        let data = try JSONEncoder().encode(budget)
        let decoded = try JSONDecoder().decode(Budget.self, from: data)
        #expect(decoded == budget)
    }

    @Test("Codable round-trip with partial fields")
    func codableRoundTripPartial() throws {
        let budget = Budget(maxTurns: 3, timeout: .milliseconds(500))
        let data = try JSONEncoder().encode(budget)
        let decoded = try JSONDecoder().decode(Budget.self, from: data)
        #expect(decoded == budget)
    }

    @Test("Equatable")
    func equatable() {
        let a = Budget(maxTurns: 5, maxTokens: 1000)
        let b = Budget(maxTurns: 5, maxTokens: 1000)
        let c = Budget(maxTurns: 10, maxTokens: 1000)
        #expect(a == b)
        #expect(a != c)
    }
}

@Suite("StopReason")
struct StopReasonTests {
    @Test("Codable round-trip for simple cases")
    func codableSimple() throws {
        let cases: [StopReason] = [
            .turnLimitReached,
            .tokenBudgetExhausted,
            .timeout,
        ]
        for reason in cases {
            let data = try JSONEncoder().encode(reason)
            let decoded = try JSONDecoder().decode(StopReason.self, from: data)
            #expect(decoded == reason)
        }
    }

    @Test("Codable round-trip for explicitStop with reason")
    func codableExplicitStop() throws {
        let reason = StopReason.explicitStop(reason: "User cancelled")
        let data = try JSONEncoder().encode(reason)
        let decoded = try JSONDecoder().decode(StopReason.self, from: data)
        #expect(decoded == reason)
    }

    @Test("Equality")
    func equality() {
        #expect(StopReason.timeout == StopReason.timeout)
        #expect(StopReason.timeout != StopReason.turnLimitReached)
        #expect(
            StopReason.explicitStop(reason: "A")
                != StopReason.explicitStop(reason: "B")
        )
        #expect(
            StopReason.explicitStop(reason: "A")
                == StopReason.explicitStop(reason: "A")
        )
    }
}
