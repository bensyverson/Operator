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

// MARK: - Compaction Middleware Tests

@Suite("CompactionMiddleware")
struct CompactionMiddlewareTests {
    @Test("Truncates tool outputs exceeding maxToolOutputLength")
    func truncatesLongToolOutputs() async throws {
        let longOutput = String(repeating: "x", count: 5000)
        var ctx = RequestContext(
            messages: [
                Message(role: .system, content: "You are helpful"),
                Message(role: .user, content: "Do something"),
                Message(role: .tool, content: longOutput, toolCallId: "call_1"),
                Message(role: .user, content: "Recent message"),
            ],
            toolDefinitions: []
        )

        let compactor = CompactionMiddleware(maxToolOutputLength: 100, preserveRecentTurns: 0)
        try await compactor.beforeRequest(&ctx)

        let toolMessage = ctx.messages.first(where: { $0.role == .tool })
        #expect(toolMessage != nil)
        #expect((toolMessage?.content?.count ?? 0) < 5000) // Significantly smaller than original
        #expect(toolMessage?.content?.contains("[truncated") == true)
    }

    @Test("Preserves tool outputs under threshold")
    func preservesShortToolOutputs() async throws {
        let shortOutput = "Result: 42"
        var ctx = RequestContext(
            messages: [
                Message(role: .system, content: "You are helpful"),
                Message(role: .user, content: "Do something"),
                Message(role: .tool, content: shortOutput, toolCallId: "call_1"),
            ],
            toolDefinitions: []
        )

        let compactor = CompactionMiddleware(maxToolOutputLength: 100, preserveRecentTurns: 0)
        try await compactor.beforeRequest(&ctx)

        let toolMessage = ctx.messages.first(where: { $0.role == .tool })
        #expect(toolMessage?.content == shortOutput)
    }

    @Test("Preserves recent N turns from collapsing")
    func preservesRecentTurns() async throws {
        let longOutput = String(repeating: "x", count: 5000)
        var ctx = RequestContext(
            messages: [
                Message(role: .system, content: "You are helpful"),
                // Old turn
                Message(role: .user, content: "Old question"),
                Message(role: .assistant, content: nil, toolCalls: [
                    Message.ToolCallInfo(id: "call_old", name: "tool", arguments: "{}"),
                ]),
                Message(role: .tool, content: longOutput, toolCallId: "call_old"),
                // Recent turn (should be preserved)
                Message(role: .user, content: "Recent question"),
                Message(role: .assistant, content: nil, toolCalls: [
                    Message.ToolCallInfo(id: "call_new", name: "tool", arguments: "{}"),
                ]),
                Message(role: .tool, content: longOutput, toolCallId: "call_new"),
            ],
            toolDefinitions: []
        )

        // preserveRecentTurns: 1 means the last user+assistant+tool group is preserved
        let compactor = CompactionMiddleware(
            maxToolOutputLength: 100,
            preserveRecentTurns: 1
        )
        try await compactor.beforeRequest(&ctx)

        // The recent tool output should be preserved (in the last N turns)
        let toolMessages = ctx.messages.filter { $0.role == .tool }
        #expect(toolMessages.count == 2)

        // Old tool output truncated
        let oldTool = toolMessages.first(where: { $0.toolCallId == "call_old" })
        #expect(oldTool?.content?.contains("[truncated") == true)

        // Recent tool output preserved
        let newTool = toolMessages.first(where: { $0.toolCallId == "call_new" })
        #expect(newTool?.content == longOutput)
    }

    @Test("Trims oldest messages when over target")
    func trimsOldestMessages() async throws {
        // Create many messages totaling ~8000 chars
        var messages = [Message(role: .system, content: "System prompt")]
        for i in 0 ..< 20 {
            messages.append(Message(role: .user, content: "User message \(i) " + String(repeating: "a", count: 200)))
            messages.append(Message(role: .assistant, content: "Assistant response \(i) " + String(repeating: "b", count: 200)))
        }
        messages.append(Message(role: .user, content: "Final question"))

        var ctx = RequestContext(messages: messages, toolDefinitions: [])

        // Target ~1000 tokens (~4000 chars)
        let compactor = CompactionMiddleware(
            preserveRecentTurns: 2,
            targetTokenEstimate: 1000
        )
        try await compactor.beforeRequest(&ctx)

        // Should have fewer messages than original
        #expect(ctx.messages.count < messages.count)
        // System message preserved
        #expect(ctx.messages[0].role == .system)
        #expect(ctx.messages[0].content == "System prompt")
        // Final question preserved
        #expect(ctx.messages.last?.content == "Final question")
    }

    @Test("Preserves system messages during trimming")
    func preservesSystemMessages() async throws {
        var messages = [Message(role: .system, content: "Important system instructions")]
        for i in 0 ..< 20 {
            messages.append(Message(role: .user, content: "Message \(i) " + String(repeating: "x", count: 500)))
            messages.append(Message(role: .assistant, content: "Response \(i) " + String(repeating: "y", count: 500)))
        }

        var ctx = RequestContext(messages: messages, toolDefinitions: [])

        let compactor = CompactionMiddleware(
            preserveRecentTurns: 1,
            targetTokenEstimate: 500
        )
        try await compactor.beforeRequest(&ctx)

        #expect(ctx.messages[0].role == .system)
        #expect(ctx.messages[0].content == "Important system instructions")
    }

    @Test("pressureOnly mode skips compaction without pressure")
    func pressureOnlySkipsWithoutPressure() async throws {
        let longOutput = String(repeating: "x", count: 5000)
        var ctx = RequestContext(
            messages: [
                Message(role: .system, content: "System"),
                Message(role: .tool, content: longOutput, toolCallId: "call_1"),
            ],
            toolDefinitions: [],
            pressure: [] // No pressure
        )

        let compactor = CompactionMiddleware(
            maxToolOutputLength: 100,
            preserveRecentTurns: 0,
            pressureOnly: true
        )
        try await compactor.beforeRequest(&ctx)

        // Tool output should NOT be truncated (no pressure)
        let toolMessage = ctx.messages.first(where: { $0.role == .tool })
        #expect(toolMessage?.content == longOutput)
    }

    @Test("pressureOnly mode runs when pressure present")
    func pressureOnlyRunsWithPressure() async throws {
        let longOutput = String(repeating: "x", count: 5000)
        let pressure = PressureInfo(
            dimension: .contextWindow,
            utilization: 0.9,
            current: 180_000,
            limit: 200_000
        )
        var ctx = RequestContext(
            messages: [
                Message(role: .system, content: "System"),
                Message(role: .tool, content: longOutput, toolCallId: "call_1"),
            ],
            toolDefinitions: [],
            pressure: [pressure]
        )

        let compactor = CompactionMiddleware(
            maxToolOutputLength: 100,
            preserveRecentTurns: 0,
            pressureOnly: true
        )
        try await compactor.beforeRequest(&ctx)

        // Tool output SHOULD be truncated (pressure present)
        let toolMessage = ctx.messages.first(where: { $0.role == .tool })
        #expect(toolMessage?.content?.contains("[truncated") == true)
    }

    @Test("No-op on short conversations")
    func noOpOnShortConversation() async throws {
        var ctx = RequestContext(
            messages: [
                Message(role: .system, content: "System"),
                Message(role: .user, content: "Hello"),
            ],
            toolDefinitions: []
        )

        let compactor = CompactionMiddleware(targetTokenEstimate: 1000)
        try await compactor.beforeRequest(&ctx)

        #expect(ctx.messages.count == 2)
        #expect(ctx.messages[0].content == "System")
        #expect(ctx.messages[1].content == "Hello")
    }

    @Test("Integration: full agent loop with compaction middleware")
    func integrationWithAgentLoop() async throws {
        let toolRequest = ToolRequest(
            name: "echo",
            arguments: "{\"message\":\"" + String(repeating: "x", count: 5000) + "\"}",
            toolCallId: "call_1"
        )
        let mock = MockLLMService(responses: [
            .withToolCalls([toolRequest]),
            .textOnly("done"),
        ])

        let echoTool = try Tool(name: "echo", description: "Echoes input", input: EchoInputC.self) { input in
            ToolOutput(input.message)
        }
        let operable = TestOperableC(toolGroup: ToolGroup(
            name: "Test",
            tools: [echoTool]
        ))

        let compactor = CompactionMiddleware(maxToolOutputLength: 200)
        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "test",
            tools: [operable],
            budget: Budget(maxTurns: 10),
            middleware: [compactor]
        )

        let ops = await collectOperations(operative.run("Echo"))

        var foundCompleted = false
        for op in ops {
            if case .completed = op {
                foundCompleted = true
            }
        }
        #expect(foundCompleted)
    }
}

// MARK: - Test Types (local to avoid collision)

private struct TestOperableC: Operable {
    let toolGroup: ToolGroup
}

private struct EchoInputC: ToolInput {
    let message: String
    static var paramDescriptions: [String: String] {
        ["message": "The message to echo"]
    }
}
