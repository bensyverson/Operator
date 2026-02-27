import LLM
@testable import Operator
import Testing

private typealias Op = Operator.Operation

private func collectOperations(_ stream: OperationStream) async -> [Op] {
    var ops = [Op]()
    for await op in stream {
        ops.append(op)
    }
    return ops
}

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

// MARK: - Budget maxTokensPerTurn Wiring Tests

@Suite("Budget.maxTokensPerTurn wiring")
struct BudgetMaxTokensPerTurnTests {
    @Test("maxTokensPerTurn is applied to conversation configuration")
    func maxTokensPerTurnApplied() async throws {
        let mock = MockLLMService(responses: [
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
            budget: Budget(maxTurns: 1, maxTokensPerTurn: 8192)
        )

        _ = await collectOperations(operative.run("Hello"))

        #expect(mock.receivedConversations.count == 1)
        #expect(mock.receivedConversations[0].configuration.maxTokens == 8192)
    }

    @Test("When maxTokensPerTurn is nil, original maxTokens is preserved")
    func maxTokensPerTurnNil_preservesOriginal() async throws {
        let mock = MockLLMService(responses: [
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
            budget: Budget(maxTurns: 1)
        )

        _ = await collectOperations(operative.run("Hello"))

        #expect(mock.receivedConversations.count == 1)
        // When no maxTokensPerTurn is set, the conversation's original maxTokens should be nil
        #expect(mock.receivedConversations[0].configuration.maxTokens == nil)
    }
}
