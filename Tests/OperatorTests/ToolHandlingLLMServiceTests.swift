import Foundation
import LLM
@testable import Operator
import Testing

/// Avoid ambiguity with Foundation.Operation (NSOperation)
private typealias Op = Operator.Operation

// MARK: - Mock ToolHandlingLLMService

/// A mock LLM service that conforms to `ToolHandlingLLMService`, emitting
/// scripted operations directly to the continuation rather than going
/// through the standard agent loop.
private final class MockToolHandlingService: ToolHandlingLLMService, @unchecked Sendable {
    /// Operations to emit when `execute` is called.
    var scriptedOperations: [Op]

    /// Tracks whether `execute` was called.
    var executeCalled = false

    /// Tracks whether `chat` was called (should NOT be called when tools are present).
    var chatCalled = false

    /// Records the tool names passed to execute.
    var receivedToolNames: [String] = []

    /// Records the budget passed to execute.
    var receivedBudget: Budget?

    init(scriptedOperations: [Op]) {
        self.scriptedOperations = scriptedOperations
    }

    func chat(conversation: Conversation) -> AsyncThrowingStream<StreamEvent, Error> {
        chatCalled = true
        return AsyncThrowingStream { continuation in
            let response = ConversationResponse(
                text: "chat fallback",
                thinking: nil,
                toolCalls: [],
                conversation: conversation,
                rawResponse: LLM.OpenAICompatibleAPI.ChatCompletionResponse()
            )
            continuation.yield(.textDelta("chat fallback"))
            continuation.yield(.completed(response))
            continuation.finish()
        }
    }

    func execute(
        conversation _: Conversation,
        tools: [String: any ToolProvider],
        budget: Budget,
        middleware _: [any Middleware],
        continuation: OperationStream.Continuation
    ) async {
        executeCalled = true
        receivedToolNames = Array(tools.keys).sorted()
        receivedBudget = budget

        for operation in scriptedOperations {
            continuation.yield(operation)
        }
    }
}

// MARK: - Test Helpers

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

/// Collects all operations from a stream.
private func collectOperations(_ stream: OperationStream) async -> [Op] {
    var ops = [Op]()
    for await op in stream {
        ops.append(op)
    }
    return ops
}

// MARK: - Tests

@Suite("ToolHandlingLLMService Delegation")
struct ToolHandlingLLMServiceDelegationTests {
    @Test("Operative delegates to ToolHandlingLLMService.execute instead of running its own loop")
    func delegatesToExecute() async throws {
        let expectedConversation = Conversation(systemPrompt: "test")

        let mockService = MockToolHandlingService(scriptedOperations: [
            .turnStarted(TurnContext(turnNumber: 1, budgetRemaining: Budget(maxTurns: 5))),
            .text("Hello from tool-handling service"),
            .turnCompleted(TurnResult(
                usage: TokenUsage.zero,
                toolCallCount: 0,
                cumulativeUsage: TokenUsage.zero,
                conversation: expectedConversation
            )),
            .completed(OperativeResult(
                text: "Hello from tool-handling service",
                conversation: expectedConversation,
                usage: TokenUsage.zero,
                turnsUsed: 1
            )),
        ])

        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mockService,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 5)
        )

        let result = try await operative.run("Hi").result()

        #expect(mockService.executeCalled)
        #expect(!mockService.chatCalled)
        #expect(result.text == "Hello from tool-handling service")
        #expect(result.turnsUsed == 1)
    }

    @Test("Operative passes tool registry to ToolHandlingLLMService")
    func passesToolRegistry() async throws {
        let expectedConversation = Conversation(systemPrompt: "test")

        let mockService = MockToolHandlingService(scriptedOperations: [
            .completed(OperativeResult(
                text: "done",
                conversation: expectedConversation,
                usage: TokenUsage.zero,
                turnsUsed: 1
            )),
        ])

        let operable = TestOperable(toolGroup: ToolGroup(
            name: "Test",
            tools: [makeEchoTool()]
        ))

        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mockService,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 5)
        )

        _ = try await operative.run("Hi").result()

        #expect(mockService.receivedToolNames == ["echo"])
    }

    @Test("Operative passes budget to ToolHandlingLLMService")
    func passesBudget() async throws {
        let expectedConversation = Conversation(systemPrompt: "test")

        let mockService = MockToolHandlingService(scriptedOperations: [
            .completed(OperativeResult(
                text: "done",
                conversation: expectedConversation,
                usage: TokenUsage.zero,
                turnsUsed: 1
            )),
        ])

        let budget = Budget(maxTurns: 3, maxTokens: 1000, timeout: .seconds(30))
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mockService,
            systemPrompt: "test",
            tools: [],
            budget: budget
        )

        _ = try await operative.run("Hi").result()

        #expect(mockService.receivedBudget?.maxTurns == 3)
        #expect(mockService.receivedBudget?.maxTokens == 1000)
        #expect(mockService.receivedBudget?.timeout == .seconds(30))
    }

    @Test("Tool events from ToolHandlingLLMService appear in the operation stream")
    func toolEventsAppearInStream() async throws {
        let expectedConversation = Conversation(systemPrompt: "test")
        let toolRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"hello\"}",
            toolCallId: "proxy_1"
        )
        let toolOutput = ToolOutput("hello")

        let mockService = MockToolHandlingService(scriptedOperations: [
            .turnStarted(TurnContext(turnNumber: 1, budgetRemaining: Budget())),
            .toolsRequested([toolRequest]),
            .toolCompleted(toolRequest, toolOutput),
            .text("Result: hello"),
            .turnCompleted(TurnResult(
                usage: TokenUsage.zero,
                toolCallCount: 1,
                cumulativeUsage: TokenUsage.zero,
                conversation: expectedConversation
            )),
            .completed(OperativeResult(
                text: "Result: hello",
                conversation: expectedConversation,
                usage: TokenUsage.zero,
                turnsUsed: 1
            )),
        ])

        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mockService,
            systemPrompt: "test",
            tools: [],
            budget: Budget()
        )

        let ops = await collectOperations(operative.run("Echo hello"))

        var foundToolsRequested = false
        var foundToolCompleted = false
        var foundText = false
        var foundCompleted = false

        for op in ops {
            switch op {
            case let .toolsRequested(requests):
                foundToolsRequested = true
                #expect(requests.count == 1)
                #expect(requests[0].name == "echo")
            case let .toolCompleted(request, output):
                foundToolCompleted = true
                #expect(request.name == "echo")
                #expect(output.content == "hello")
            case let .text(text):
                foundText = true
                #expect(text == "Result: hello")
            case .completed:
                foundCompleted = true
            default:
                break
            }
        }

        #expect(foundToolsRequested)
        #expect(foundToolCompleted)
        #expect(foundText)
        #expect(foundCompleted)
    }

    @Test("ToolHandlingLLMService can emit stopped events")
    func stoppedEventFromService() async throws {
        let mockService = MockToolHandlingService(scriptedOperations: [
            .stopped(.timeout),
        ])

        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mockService,
            systemPrompt: "test",
            tools: [],
            budget: Budget()
        )

        let ops = await collectOperations(operative.run("Hi"))

        let stoppedOps = ops.filter {
            if case .stopped(.timeout) = $0 { return true }
            return false
        }
        #expect(stoppedOps.count == 1)
    }

    @Test("Non-ToolHandlingLLMService uses standard agent loop")
    func standardServiceUsesLoop() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("standard response"),
        ])
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [],
            budget: Budget(maxTurns: 5)
        )

        let result = try await operative.run("Hi").result()

        #expect(result.text == "standard response")
        #expect(mock.callCount == 1)
    }

    @Test("Continuing a conversation passes through to ToolHandlingLLMService")
    func continuingConversation() async throws {
        let conversation = Conversation(systemPrompt: "test")

        let mockService = MockToolHandlingService(scriptedOperations: [
            .completed(OperativeResult(
                text: "continued",
                conversation: conversation,
                usage: TokenUsage.zero,
                turnsUsed: 1
            )),
        ])

        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mockService,
            systemPrompt: "test",
            tools: [],
            budget: Budget()
        )

        let result = try await operative.run("Follow up", continuing: conversation).result()

        #expect(mockService.executeCalled)
        #expect(result.text == "continued")
    }
}
