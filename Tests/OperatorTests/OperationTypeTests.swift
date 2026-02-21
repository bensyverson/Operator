import Foundation
import LLM
@testable import Operator
import Testing

@Suite("TurnContext")
struct TurnContextTests {
    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let ctx = TurnContext(
            turnNumber: 3,
            budgetRemaining: Budget(maxTurns: 7, maxTokens: 5000)
        )
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(TurnContext.self, from: data)
        #expect(decoded == ctx)
    }
}

@Suite("TurnResult")
struct TurnResultTests {
    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let result = TurnResult(
            usage: TokenUsage(promptTokens: 100, completionTokens: 50, totalTokens: 150),
            toolCallCount: 2,
            cumulativeUsage: TokenUsage(promptTokens: 300, completionTokens: 120, totalTokens: 420)
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(TurnResult.self, from: data)
        #expect(decoded == result)
    }
}

@Suite("OperativeResult")
struct OperativeResultTests {
    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let conversation = LLM.Conversation(
            systemPrompt: "You are helpful"
        )
        let result = OperativeResult(
            text: "Here is your answer",
            conversation: conversation,
            usage: TokenUsage(promptTokens: 500, completionTokens: 200, totalTokens: 700),
            turnsUsed: 3
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(OperativeResult.self, from: data)
        #expect(decoded == result)
    }
}

@Suite("Operation")
struct OperationTests {
    @Test("Pattern matching — turnStarted")
    func turnStarted() {
        let op = Operation.turnStarted(TurnContext(turnNumber: 1, budgetRemaining: Budget()))
        if case let .turnStarted(ctx) = op {
            #expect(ctx.turnNumber == 1)
        } else {
            Issue.record("Expected .turnStarted")
        }
    }

    @Test("Pattern matching — text")
    func text() {
        let op = Operation.text("Hello")
        if case let .text(chunk) = op {
            #expect(chunk == "Hello")
        } else {
            Issue.record("Expected .text")
        }
    }

    @Test("Pattern matching — toolsRequested")
    func toolsRequested() {
        let request = ToolRequest(name: "search", arguments: "{}", toolCallId: "c1")
        let op = Operation.toolsRequested([request])
        if case let .toolsRequested(reqs) = op {
            #expect(reqs.count == 1)
            #expect(reqs[0].name == "search")
        } else {
            Issue.record("Expected .toolsRequested")
        }
    }

    @Test("Pattern matching — toolsRejected")
    func toolsRejected() {
        let request = ToolRequest(name: "delete", arguments: "{}", toolCallId: "c2")
        let rejection = ToolRejection(request: request, reason: "Not allowed")
        let op = Operation.toolsRejected([rejection])
        if case let .toolsRejected(rejections) = op {
            #expect(rejections.count == 1)
            #expect(rejections[0].reason == "Not allowed")
        } else {
            Issue.record("Expected .toolsRejected")
        }
    }

    @Test("Pattern matching — toolCompleted")
    func toolCompleted() {
        let request = ToolRequest(name: "read", arguments: "{}", toolCallId: "c3")
        let output = ToolOutput("file contents")
        let op = Operation.toolCompleted(request, output)
        if case let .toolCompleted(req, out) = op {
            #expect(req.name == "read")
            #expect(out.content == "file contents")
        } else {
            Issue.record("Expected .toolCompleted")
        }
    }

    @Test("Pattern matching — toolFailed")
    func toolFailed() {
        let request = ToolRequest(name: "write", arguments: "{}", toolCallId: "c4")
        struct TestErr: Error {}
        let error = ToolError(message: "Permission denied", underlyingError: TestErr())
        let op = Operation.toolFailed(request, error)
        if case let .toolFailed(req, err) = op {
            #expect(req.name == "write")
            #expect(err.message == "Permission denied")
        } else {
            Issue.record("Expected .toolFailed")
        }
    }

    @Test("Pattern matching — turnCompleted")
    func turnCompleted() {
        let result = TurnResult(
            usage: TokenUsage.zero,
            toolCallCount: 0,
            cumulativeUsage: TokenUsage.zero
        )
        let op = Operation.turnCompleted(result)
        if case let .turnCompleted(r) = op {
            #expect(r.toolCallCount == 0)
        } else {
            Issue.record("Expected .turnCompleted")
        }
    }

    @Test("Pattern matching — completed")
    func completed() {
        let conversation = LLM.Conversation(
            systemPrompt: "test"
        )
        let result = OperativeResult(
            text: "Done",
            conversation: conversation,
            usage: TokenUsage.zero,
            turnsUsed: 1
        )
        let op = Operation.completed(result)
        if case let .completed(r) = op {
            #expect(r.text == "Done")
        } else {
            Issue.record("Expected .completed")
        }
    }

    @Test("Pattern matching — stopped")
    func stopped() {
        let op = Operation.stopped(.timeout)
        if case let .stopped(reason) = op {
            #expect(reason == .timeout)
        } else {
            Issue.record("Expected .stopped")
        }
    }
}
