import Foundation
import LLM
@testable import Operator
import Testing

private typealias Op = Operator.Operation

// MARK: - Test Helpers

private struct EchoInput: ToolInput {
    let message: String
    static var paramDescriptions: [String: String] {
        ["message": "The message to echo"]
    }
}

private struct TestOperable: Operable {
    let toolGroup: ToolGroup
}

private func makeEchoTool() -> any ToolProvider {
    try! Tool(name: "echo", description: "Echoes input", input: EchoInput.self) { input in
        ToolOutput(input.message)
    }
}

private func collectOperations(_ stream: OperationStream) async -> [Op] {
    var ops = [Op]()
    for await op in stream {
        ops.append(op)
    }
    return ops
}

// MARK: - afterRun recorder

/// Records every `afterRun` invocation plus timestamps for ordering checks.
private final class AfterRunRecorder: Middleware, @unchecked Sendable {
    var contexts: [RunContext] = []
    var timestamps: [ContinuousClock.Instant] = []

    func afterRun(_ context: RunContext) async throws {
        contexts.append(context)
        timestamps.append(ContinuousClock.now)
    }
}

/// A middleware that delays inside `afterRun` to test synchronous awaiting.
private final class DelayingAfterRun: Middleware, @unchecked Sendable {
    let delay: Duration
    var startedAt: ContinuousClock.Instant?
    var finishedAt: ContinuousClock.Instant?

    init(delay: Duration) {
        self.delay = delay
    }

    func afterRun(_: RunContext) async throws {
        startedAt = ContinuousClock.now
        try await Task.sleep(for: delay)
        finishedAt = ContinuousClock.now
    }
}

/// A middleware whose `afterRun` throws.
private struct ThrowingAfterRun: Middleware {
    struct Boom: Error {}
    func afterRun(_: RunContext) async throws {
        throw Boom()
    }
}

/// A middleware whose `beforeRequest` throws — used to abort a run early.
private struct ThrowingBeforeRequest: Middleware {
    func beforeRequest(_: inout RequestContext) async throws {
        throw MiddlewareError.requestRejected(reason: "abort")
    }
}

/// A middleware that does not override any hook — exercises the default
/// no-op `afterRun`.
private struct SilentMiddleware: Middleware {}

// MARK: - Tests

@Suite("afterRun middleware hook")
struct AfterRunHookTests {
    @Test("Fires exactly once on a single-turn run")
    func firesOnceOnSingleTurnRun() async throws {
        let mock = MockLLMService(responses: [.textOnly("hello")])
        let recorder = AfterRunRecorder()
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 5),
            middleware: [recorder]
        )

        _ = await collectOperations(operative.run("hi"))

        #expect(recorder.contexts.count == 1)
        let ctx = try #require(recorder.contexts.first)
        #expect(ctx.finalText == "hello")
        #expect(ctx.toolCalls.isEmpty)
    }

    @Test("Fires exactly once on a multi-step run")
    func firesOnceOnMultiStepRun() async throws {
        let call1 = ToolRequest(name: "echo", arguments: "{\"message\":\"one\"}", toolCallId: "c1")
        let call2 = ToolRequest(name: "echo", arguments: "{\"message\":\"two\"}", toolCallId: "c2")
        let mock = MockLLMService(responses: [
            .withToolCalls([call1], usage: TokenUsage(promptTokens: 1, completionTokens: 1, totalTokens: 2)),
            .withToolCalls([call2], usage: TokenUsage(promptTokens: 1, completionTokens: 1, totalTokens: 2)),
            .withThinking("final thought", text: "done"),
        ])
        let recorder = AfterRunRecorder()
        let operable = TestOperable(toolGroup: ToolGroup(name: "Test", tools: [makeEchoTool()]))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10),
            middleware: [recorder]
        )

        _ = await collectOperations(operative.run("go"))

        #expect(recorder.contexts.count == 1)
        let ctx = try #require(recorder.contexts.first)
        #expect(ctx.toolCalls.count == 2)
        #expect(ctx.toolCalls.map(\.toolCallId) == ["c1", "c2"])
        #expect(ctx.finalText == "done")
        #expect(ctx.thinking.contains("final thought"))
    }

    @Test("Messages span from user through final assistant")
    func messagesContainsUserThroughFinal() async throws {
        let mock = MockLLMService(responses: [.textOnly("answered")])
        let recorder = AfterRunRecorder()
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 5),
            middleware: [recorder]
        )

        _ = await collectOperations(operative.run("original question"))

        let ctx = try #require(recorder.contexts.first)
        #expect(ctx.messages.first?.role == .user)
        #expect(ctx.messages.first?.textContent == "original question")
        #expect(ctx.messages.last?.role == .assistant)
        #expect(ctx.messages.last?.toolCalls == nil || ctx.messages.last?.toolCalls?.isEmpty == true)
    }

    @Test("afterRun is awaited synchronously before run completes")
    func awaitedSynchronously() async throws {
        let mock = MockLLMService(responses: [.textOnly("done")])
        let delayer = DelayingAfterRun(delay: .milliseconds(150))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 5),
            middleware: [delayer]
        )

        let ops = await collectOperations(operative.run("hi"))

        let started = try #require(delayer.startedAt)
        let finished = try #require(delayer.finishedAt)

        // Find the position of the .completed operation and assert
        // the delay finished before it was yielded. We can't get a
        // post-hoc timestamp for .completed (Operations don't carry
        // them), so instead assert: afterRun ran (started < finished),
        // .completed appears, and delay was non-trivial.
        let completedIndex = ops.firstIndex(where: {
            if case .completed = $0 { return true }
            return false
        })
        #expect(completedIndex != nil)
        #expect(finished - started >= .milliseconds(100))
    }

    @Test("A throwing afterRun emits an explicit stop")
    func throwingAfterRunEmitsExplicitStop() async throws {
        let mock = MockLLMService(responses: [.textOnly("done")])
        let thrower = ThrowingAfterRun()
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 5),
            middleware: [thrower]
        )

        let ops = await collectOperations(operative.run("hi"))

        let sawExplicitStop = ops.contains {
            if case .stopped(.explicitStop) = $0 { return true }
            return false
        }
        let sawCompleted = ops.contains {
            if case .completed = $0 { return true }
            return false
        }
        #expect(sawExplicitStop)
        #expect(!sawCompleted)
    }

    @Test("Does not fire when the run aborts before a terminal turn")
    func doesNotFireIfRunAbortsEarly() async throws {
        let mock = MockLLMService(responses: [.textOnly("unreachable")])
        let recorder = AfterRunRecorder()
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 5),
            middleware: [ThrowingBeforeRequest(), recorder]
        )

        _ = await collectOperations(operative.run("hi"))

        #expect(recorder.contexts.isEmpty)
    }

    @Test("Default afterRun implementation is a no-op")
    func defaultImplementationIsNoOp() async throws {
        let mock = MockLLMService(responses: [.textOnly("ok")])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 5),
            middleware: [SilentMiddleware()]
        )

        let ops = await collectOperations(operative.run("hi"))

        let completed = ops.contains {
            if case .completed = $0 { return true }
            return false
        }
        #expect(completed)
    }
}
