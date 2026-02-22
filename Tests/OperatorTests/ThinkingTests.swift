import Foundation
import LLM
@testable import Operator
import Testing

/// Avoid ambiguity with Foundation.Operation (NSOperation)
private typealias Op = Operator.Operation

// MARK: - Test Helpers

/// Collects all operations from a stream.
private func collectOperations(_ stream: OperationStream) async -> [Op] {
    var ops = [Op]()
    for await op in stream {
        ops.append(op)
    }
    return ops
}

// MARK: - Thinking Tests

@Suite("Thinking Operations")
struct ThinkingOperationTests {
    @Test("Thinking content emitted as .thinking operation")
    func thinkingEmitted() async throws {
        let mock = MockLLMService(responses: [
            .withThinking("Let me reason about this...", text: "The answer is 42"),
        ])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Think about this"))

        var foundThinking = false
        for op in ops {
            if case let .thinking(content) = op {
                foundThinking = true
                #expect(content == "Let me reason about this...")
            }
        }
        #expect(foundThinking)
    }

    @Test("Thinking appears before text in operation stream")
    func thinkingBeforeText() async throws {
        let mock = MockLLMService(responses: [
            .withThinking("Reasoning...", text: "Answer"),
        ])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Think"))

        var thinkingIndex: Int?
        var textIndex: Int?
        for (i, op) in ops.enumerated() {
            if case .thinking = op { thinkingIndex = i }
            if case .text = op { textIndex = i }
        }

        guard let ti = thinkingIndex, let xi = textIndex else {
            Issue.record("Expected both thinking and text operations")
            return
        }
        #expect(ti < xi, "Thinking should appear before text")
    }

    @Test("No thinking operation when thinking is nil")
    func noThinkingWhenNil() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("Just text"),
        ])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("No thinking"))

        let thinkingOps = ops.filter {
            if case .thinking = $0 { return true }
            return false
        }
        #expect(thinkingOps.isEmpty)
    }

    @Test("Thinking available in ResponseContext for middleware inspection")
    func thinkingInResponseContext() async throws {
        let recorder = ThinkingRecorder()
        let mock = MockLLMService(responses: [
            .withThinking("Deep thoughts", text: "Result"),
        ])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 10),
            middleware: [recorder]
        )

        _ = await collectOperations(operative.run("Think"))

        #expect(recorder.capturedThinking == "Deep thoughts")
    }
}

// MARK: - Test Middleware

/// Records the thinking content from ResponseContext.
private final class ThinkingRecorder: Middleware, @unchecked Sendable {
    var capturedThinking: String?

    func afterResponse(_ context: inout ResponseContext) async throws {
        capturedThinking = context.thinking
    }
}
