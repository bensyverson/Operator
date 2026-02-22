import Foundation
import LLM
@testable import Operator
import Testing

/// Avoid ambiguity with Foundation.Operation (NSOperation)
private typealias Op = Operator.Operation

// MARK: - Test Helpers

/// A simple Operable for testing.
private struct TestOperable: Operable {
    let toolGroup: ToolGroup
}

/// Creates a simple echo tool for testing.
private func makeEchoTool() -> any ToolProvider {
    try! Tool(name: "echo", description: "Echoes input", input: EchoInput.self) { input in
        ToolOutput(input.message)
    }
}

private struct EchoInput: ToolInput {
    let message: String
    static var paramDescriptions: [String: String] {
        ["message": "The message to echo"]
    }
}

/// Creates a tool that returns a stop signal.
private func makeStopTool() -> any ToolProvider {
    try! Tool(name: "stop", description: "Stops the agent", input: StopInput.self) { input in
        ToolOutput.stop(reason: input.reason)
    }
}

private struct StopInput: ToolInput {
    let reason: String
    static var paramDescriptions: [String: String] {
        ["reason": "Why to stop"]
    }
}

/// Creates a tool that throws an error.
private func makeFailingTool() -> any ToolProvider {
    try! Tool(name: "fail", description: "Always fails", input: FailInput.self) { _ in
        throw TestToolError.intentional
    }
}

private struct FailInput: ToolInput {
    let value: String
    static var paramDescriptions: [String: String] {
        ["value": "Ignored"]
    }
}

private enum TestToolError: Error, LocalizedError {
    case intentional

    var errorDescription: String? {
        "Intentional test error"
    }
}

/// Collects all operations from a stream.
private func collectOperations(_ stream: OperationStream) async -> [Op] {
    var ops = [Op]()
    for await op in stream {
        ops.append(op)
    }
    return ops
}

// MARK: - Init Tests

@Suite("Operative Init")
struct OperativeInitTests {
    @Test("Init stores name and description")
    func initNameAndDescription() throws {
        let mock = MockLLMService(responses: [])
        let operative = try Operative(
            name: "TestAgent",
            description: "A test agent for unit testing",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget()
        )
        #expect(operative.name == "TestAgent")
        #expect(operative.description == "A test agent for unit testing")
    }

    @Test("Init with single Operable flattens tools")
    func initSingleOperable() throws {
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))
        let mock = MockLLMService(responses: [])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget()
        )
        #expect(operative.toolRegistry.count == 1)
        #expect(operative.toolRegistry["echo"] != nil)
        #expect(operative.toolDefinitions.count == 1)
        #expect(operative.toolDefinitions[0].function.description.hasPrefix("[Test]"))
    }

    @Test("Init with multiple Operables flattens and prefixes descriptions")
    func initMultipleOperables() throws {
        let op1 = TestOperable(toolGroup: ToolGroup(
            name: "Group A",
            tools: [makeEchoTool()]
        ))
        let stopTool = makeStopTool()
        let op2 = TestOperable(toolGroup: ToolGroup(
            name: "Group B",
            tools: [stopTool]
        ))
        let mock = MockLLMService(responses: [])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [op1, op2],
            budget: Budget()
        )
        #expect(operative.toolRegistry.count == 2)
        #expect(operative.toolDefinitions[0].function.description.contains("[Group A]"))
        #expect(operative.toolDefinitions[1].function.description.contains("[Group B]"))
    }

    @Test("Init throws on duplicate tool names")
    func initDuplicateToolNames() throws {
        let op1 = TestOperable(toolGroup: ToolGroup(
            name: "Group A",
            tools: [makeEchoTool()]
        ))
        let op2 = TestOperable(toolGroup: ToolGroup(
            name: "Group B",
            tools: [makeEchoTool()]
        ))
        let mock = MockLLMService(responses: [])
        #expect(throws: OperativeError.self) {
            try Operative(
                name: "test",
                description: "test agent",
                llm: mock,
                systemPrompt: "test",
                tools: [op1, op2],
                budget: Budget()
            )
        }
    }

    @Test("Init with empty tools succeeds")
    func initEmptyTools() throws {
        let mock = MockLLMService(responses: [])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget()
        )
        #expect(operative.toolRegistry.isEmpty)
        #expect(operative.toolDefinitions.isEmpty)
    }

    @Test("Init stores middleware in order")
    func initMiddlewareOrder() throws {
        let mw1 = RecordingMiddleware(id: "first")
        let mw2 = RecordingMiddleware(id: "second")
        let mock = MockLLMService(responses: [])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(),
            middleware: [mw1, mw2]
        )
        #expect(operative.middleware.count == 2)
    }
}

// MARK: - Agent Loop Tests

@Suite("Operative Agent Loop")
struct OperativeAgentLoopTests {
    @Test("Single turn, no tools — text response")
    func singleTurnTextOnly() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("Hello, world!"),
        ])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "You are helpful",
            tools: [],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Hi"))

        // Expected: turnStarted, text, turnCompleted, completed
        #expect(ops.count == 4)
        guard case let .turnStarted(ctx) = ops[0] else {
            Issue.record("Expected turnStarted")
            return
        }
        #expect(ctx.turnNumber == 1)

        guard case let .text(text) = ops[1] else {
            Issue.record("Expected text")
            return
        }
        #expect(text == "Hello, world!")

        guard case .turnCompleted = ops[2] else {
            Issue.record("Expected turnCompleted")
            return
        }

        guard case let .completed(result) = ops[3] else {
            Issue.record("Expected completed")
            return
        }
        #expect(result.text == "Hello, world!")
        #expect(result.turnsUsed == 1)
    }

    @Test("Multi-turn with tools — tool call then text response")
    func multiTurnWithTools() async throws {
        let echoToolRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"ping\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([echoToolRequest]),
            .textOnly("pong"),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Echo ping"))

        var foundToolsRequested = false
        var foundToolCompleted = false
        var foundCompleted = false
        var turnCount = 0

        for op in ops {
            switch op {
            case .turnStarted:
                turnCount += 1
            case let .toolsRequested(requests):
                foundToolsRequested = true
                #expect(requests.count == 1)
                #expect(requests[0].name == "echo")
            case let .toolCompleted(request, output):
                foundToolCompleted = true
                #expect(request.name == "echo")
                #expect(output.content == "ping")
            case let .completed(result):
                foundCompleted = true
                #expect(result.text == "pong")
                #expect(result.turnsUsed == 2)
            default:
                break
            }
        }

        #expect(foundToolsRequested)
        #expect(foundToolCompleted)
        #expect(foundCompleted)
        #expect(turnCount == 2)
    }

    @Test("Turn limit — stops after maxTurns")
    func turnLimitReached() async throws {
        let echoRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"loop\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([echoRequest]),
            .withToolCalls([ToolRequest(name: "echo", arguments: "{\"message\":\"loop2\"}", toolCallId: "call_2")]),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 1)
        )

        let ops = await collectOperations(operative.run("Loop"))

        let stoppedOps = ops.filter {
            if case .stopped(.turnLimitReached) = $0 { return true }
            return false
        }
        #expect(stoppedOps.count == 1)
    }

    @Test("Token budget — stops when exhausted")
    func tokenBudgetExhausted() async throws {
        let echoRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"hi\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls(
                [echoRequest],
                usage: TokenUsage(promptTokens: 50, completionTokens: 60, totalTokens: 110)
            ),
            .textOnly("done"),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTokens: 100)
        )

        let ops = await collectOperations(operative.run("Exhaust"))

        let stoppedOps = ops.filter {
            if case .stopped(.tokenBudgetExhausted) = $0 { return true }
            return false
        }
        #expect(stoppedOps.count == 1)
    }

    @Test("Middleware rejection — tool rejected, not executed")
    func middlewareRejection() async throws {
        let toolRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"blocked\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([toolRequest]),
            .textOnly("ok"),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))
        let rejectMiddleware = RejectingMiddleware(toolNames: ["echo"])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10),
            middleware: [rejectMiddleware]
        )

        let ops = await collectOperations(operative.run("Try echo"))

        var foundRejected = false
        var foundToolCompleted = false

        for op in ops {
            switch op {
            case let .toolsRejected(rejections):
                foundRejected = true
                #expect(rejections.count == 1)
                #expect(rejections[0].request.name == "echo")
                #expect(rejections[0].reason == "Blocked by test")
            case .toolCompleted:
                foundToolCompleted = true
            default:
                break
            }
        }

        #expect(foundRejected)
        #expect(!foundToolCompleted)
    }

    @Test("Tool error with feedbackToLLM recovery")
    func toolErrorFeedback() async throws {
        let failRequest = ToolRequest(
            name: "fail",
            arguments: "{\"value\":\"x\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([failRequest]),
            .textOnly("recovered"),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeFailingTool()]
        ))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Fail"))

        var foundToolFailed = false
        var foundCompleted = false

        for op in ops {
            switch op {
            case let .toolFailed(request, error):
                foundToolFailed = true
                #expect(request.name == "fail")
                #expect(error.message.contains("Intentional"))
            case .completed:
                foundCompleted = true
            default:
                break
            }
        }

        #expect(foundToolFailed)
        #expect(foundCompleted)
    }

    @Test("Tool error with .throw recovery — stops")
    func toolErrorThrow() async throws {
        let failRequest = ToolRequest(
            name: "fail",
            arguments: "{\"value\":\"x\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([failRequest]),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeFailingTool()]
        ))
        let throwMiddleware = ThrowOnErrorMiddleware()
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10),
            middleware: [throwMiddleware]
        )

        let ops = await collectOperations(operative.run("Fail hard"))

        let stoppedOps = ops.filter {
            if case .stopped = $0 { return true }
            return false
        }
        #expect(stoppedOps.count == 1)
    }

    @Test("Explicit stop — tool returns stop signal")
    func explicitStop() async throws {
        let stopRequest = ToolRequest(
            name: "stop",
            arguments: "{\"reason\":\"Done here\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([stopRequest]),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeStopTool()]
        ))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Stop"))

        var foundStopped = false
        for op in ops {
            if case let .stopped(.explicitStop(reason)) = op {
                foundStopped = true
                #expect(reason == "Done here")
            }
        }
        #expect(foundStopped)
    }

    @Test("Multiple tool calls execute concurrently")
    func concurrentToolCalls() async throws {
        let request1 = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"first\"}",
            toolCallId: "call_1"
        )
        let request2 = ToolRequest(
            name: "echo2",
            arguments: "{\"message\":\"second\"}",
            toolCallId: "call_2"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([request1, request2]),
            .textOnly("done"),
        ])

        let echo1 = try Tool(name: "echo", description: "Echo 1", input: EchoInput.self) { input in
            ToolOutput(input.message)
        }
        let echo2 = try Tool(name: "echo2", description: "Echo 2", input: EchoInput.self) { input in
            ToolOutput(input.message)
        }
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [echo1, echo2]
        ))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Two tools"))

        let completedOps = ops.filter {
            if case .toolCompleted = $0 { return true }
            return false
        }
        #expect(completedOps.count == 2)
    }

    @Test("result() convenience returns OperativeResult")
    func resultConvenience() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("42"),
        ])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget()
        )

        let result = try await operative.run("What is 6 * 7?").result()
        #expect(result.text == "42")
        #expect(result.turnsUsed == 1)
    }

    @Test("result() throws on stopped")
    func resultThrowsOnStopped() async throws {
        let echoRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"loop\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([echoRequest]),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 1)
        )

        await #expect(throws: OperativeError.self) {
            try await operative.run("Loop").result()
        }
    }
}

// MARK: - Test Middleware

/// Records which middleware hooks were called, in order.
final class RecordingMiddleware: Middleware, @unchecked Sendable {
    let id: String
    var calls: [String] = []

    init(id: String) {
        self.id = id
    }

    func beforeRequest(_: inout RequestContext) async throws {
        calls.append("beforeRequest")
    }

    func afterResponse(_: inout ResponseContext) async throws {
        calls.append("afterResponse")
    }
}

/// Rejects specified tool names.
final class RejectingMiddleware: Middleware, @unchecked Sendable {
    let toolNames: Set<String>

    init(toolNames: [String]) {
        self.toolNames = Set(toolNames)
    }

    func beforeToolCalls(_ calls: inout [ToolCallContext]) async throws {
        for i in calls.indices {
            if toolNames.contains(calls[i].name) {
                calls[i].decision = .reject(reason: "Blocked by test")
            }
        }
    }
}

/// Returns .throw for any tool error.
final class ThrowOnErrorMiddleware: Middleware, @unchecked Sendable {
    func onToolError(_: Error, context _: ToolCallContext) async throws -> ToolErrorRecovery {
        .throw
    }
}
