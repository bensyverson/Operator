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

// MARK: - Pressure Tests

@Suite("Pressure Detection")
struct PressureDetectionTests {
    @Test("Token budget pressure emitted when utilization exceeds threshold")
    func tokenBudgetPressure() async throws {
        // First response uses 90 of 100 tokens → 90% utilization
        let echoRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"hi\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls(
                [echoRequest],
                usage: TokenUsage(promptTokens: 30, completionTokens: 60, totalTokens: 90)
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
            budget: Budget(maxTurns: 10, maxTokens: 100)
        )

        let ops = await collectOperations(operative.run("Test"))

        // Turn 2 should have token budget pressure (90/100 = 0.9 > 0.8)
        let pressureOps = ops.compactMap { op -> PressureInfo? in
            if case let .pressure(info) = op { return info }
            return nil
        }
        let budgetPressure = pressureOps.filter { $0.dimension == .tokenBudget }
        #expect(!budgetPressure.isEmpty)
        #expect(budgetPressure[0].utilization >= 0.8)
        #expect(budgetPressure[0].current == 90)
        #expect(budgetPressure[0].limit == 100)
    }

    @Test("Context window pressure emitted when prompt tokens approach limit")
    func contextWindowPressure() async throws {
        let echoRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"hi\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            // First response: 85k prompt tokens out of 100k context window
            .withToolCalls(
                [echoRequest],
                usage: TokenUsage(promptTokens: 85000, completionTokens: 500, totalTokens: 85500)
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
            budget: Budget(maxTurns: 10, contextWindowTokens: 100_000)
        )

        let ops = await collectOperations(operative.run("Test"))

        let pressureOps = ops.compactMap { op -> PressureInfo? in
            if case let .pressure(info) = op { return info }
            return nil
        }
        let contextPressure = pressureOps.filter { $0.dimension == .contextWindow }
        #expect(!contextPressure.isEmpty)
        #expect(contextPressure[0].utilization >= 0.8)
        #expect(contextPressure[0].current == 85000)
        #expect(contextPressure[0].limit == 100_000)
    }

    @Test("No pressure when below threshold")
    func noPressureBelowThreshold() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("done", usage: TokenUsage(promptTokens: 10, completionTokens: 5, totalTokens: 15)),
        ])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 10, maxTokens: 1000, contextWindowTokens: 100_000)
        )

        let ops = await collectOperations(operative.run("Test"))

        let pressureOps = ops.filter {
            if case .pressure = $0 { return true }
            return false
        }
        #expect(pressureOps.isEmpty)
    }

    @Test("Custom threshold works")
    func customThreshold() async throws {
        let echoRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"hi\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls(
                [echoRequest],
                usage: TokenUsage(promptTokens: 10, completionTokens: 50, totalTokens: 60)
            ),
            .textOnly("done"),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))
        // threshold at 0.5, usage will be 60/100 = 0.6
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10, maxTokens: 100, pressureThreshold: 0.5)
        )

        let ops = await collectOperations(operative.run("Test"))

        let pressureOps = ops.compactMap { op -> PressureInfo? in
            if case let .pressure(info) = op { return info }
            return nil
        }
        let budgetPressure = pressureOps.filter { $0.dimension == .tokenBudget }
        #expect(!budgetPressure.isEmpty)
    }

    @Test("No context window pressure when contextWindowTokens is nil")
    func noContextPressureWhenNil() async throws {
        let echoRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"hi\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls(
                [echoRequest],
                usage: TokenUsage(promptTokens: 90000, completionTokens: 500, totalTokens: 90500)
            ),
            .textOnly("done"),
        ])
        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))
        // No contextWindowTokens set, even though prompt tokens are huge
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10)
        )

        let ops = await collectOperations(operative.run("Test"))

        let contextPressure = ops.compactMap { op -> PressureInfo? in
            if case let .pressure(info) = op, info.dimension == .contextWindow { return info }
            return nil
        }
        #expect(contextPressure.isEmpty)
    }

    @Test("Pressure info available in RequestContext for middleware")
    func pressureInRequestContext() async throws {
        let recorder = PressureRecorder()
        let echoRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"hi\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls(
                [echoRequest],
                usage: TokenUsage(promptTokens: 30, completionTokens: 60, totalTokens: 90)
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
            budget: Budget(maxTurns: 10, maxTokens: 100),
            middleware: [recorder]
        )

        _ = await collectOperations(operative.run("Test"))

        // Second call to beforeRequest should have pressure info
        #expect(recorder.pressurePerCall.count == 2)
        #expect(recorder.pressurePerCall[0].isEmpty) // First turn: no pressure
        #expect(!recorder.pressurePerCall[1].isEmpty) // Second turn: budget pressure
    }
}

// MARK: - Test Helpers (shared with OperativeTests)

private struct TestOperable: Operable {
    let toolGroup: ToolGroup
}

private struct EchoInput: ToolInput {
    let message: String
    static var paramDescriptions: [String: String] {
        ["message": "The message to echo"]
    }
}

private func makeEchoTool() -> any ToolProvider {
    try! Tool(name: "echo", description: "Echoes input", input: EchoInput.self) { input in
        ToolOutput(input.message)
    }
}

// MARK: - Test Middleware

/// Records pressure signals from each beforeRequest call.
private final class PressureRecorder: Middleware, @unchecked Sendable {
    var pressurePerCall: [[PressureInfo]] = []

    func beforeRequest(_ context: inout RequestContext) async throws {
        pressurePerCall.append(context.pressure)
    }
}
