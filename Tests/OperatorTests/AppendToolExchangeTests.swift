import Foundation
import LLM
@testable import Operator
import Testing

@Suite("RequestContext.appendToolExchange")
struct AppendToolExchangeTests {
    private struct Args: Codable, Equatable {
        let query: String
        let count: Int
    }

    /// An Encodable that deliberately throws during encoding, used to
    /// exercise the error path of ``RequestContext/appendToolExchange``.
    private struct ThrowingEncodable: Encodable {
        struct BoomError: Error {}
        func encode(to _: Encoder) throws {
            throw BoomError()
        }
    }

    @Test("Empty context — appends assistant then tool message")
    func emptyContext_appendsAssistantThenTool() throws {
        var context = RequestContext(messages: [], toolDefinitions: [])
        let args = Args(query: "hello", count: 3)
        let output = ToolOutput("recalled content")

        try context.appendToolExchange(
            toolName: "memory",
            arguments: args,
            result: output
        )

        #expect(context.messages.count == 2)

        let assistant = context.messages[0]
        #expect(assistant.role == .assistant)
        #expect(assistant.content.isEmpty)
        #expect(assistant.toolCalls?.count == 1)
        let call = try #require(assistant.toolCalls?.first)
        #expect(call.name == "memory")

        let decoded = try JSONDecoder().decode(Args.self, from: Data(call.arguments.utf8))
        #expect(decoded == args)

        let tool = context.messages[1]
        #expect(tool.role == .tool)
        #expect(tool.toolCallId == call.id)
        #expect(tool.textContent == "recalled content")
    }

    @Test("Preserves existing messages")
    func preservesExistingMessages() throws {
        var context = RequestContext(
            messages: [Message(role: .user, content: "Original user message")],
            toolDefinitions: []
        )

        try context.appendToolExchange(
            toolName: "memory",
            arguments: Args(query: "q", count: 1),
            result: ToolOutput("result")
        )

        #expect(context.messages.count == 3)
        #expect(context.messages[0].role == .user)
        #expect(context.messages[0].textContent == "Original user message")
        #expect(context.messages[1].role == .assistant)
        #expect(context.messages[2].role == .tool)
    }

    @Test("Encodable arguments round-trip through the synthesized call")
    func encodableArguments_roundTrip() throws {
        var context = RequestContext(messages: [], toolDefinitions: [])
        let args = Args(query: "the quick brown fox", count: 42)

        try context.appendToolExchange(
            toolName: "memory",
            arguments: args,
            result: ToolOutput("ok")
        )

        let call = try #require(context.messages.first?.toolCalls?.first)
        let decoded = try JSONDecoder().decode(Args.self, from: Data(call.arguments.utf8))
        #expect(decoded == args)
    }

    @Test("Explicit toolCallId is honored on both messages")
    func explicitToolCallId_isHonored() throws {
        var context = RequestContext(messages: [], toolDefinitions: [])

        try context.appendToolExchange(
            toolName: "memory",
            arguments: Args(query: "x", count: 0),
            result: ToolOutput("r"),
            toolCallId: "abc-123"
        )

        let call = try #require(context.messages[0].toolCalls?.first)
        #expect(call.id == "abc-123")
        #expect(context.messages[1].toolCallId == "abc-123")
    }

    @Test("Throws on non-encodable arguments — messages unchanged")
    func throwsOnNonEncodable() throws {
        var context = RequestContext(
            messages: [Message(role: .user, content: "preserved")],
            toolDefinitions: []
        )

        #expect(throws: (any Error).self) {
            try context.appendToolExchange(
                toolName: "memory",
                arguments: ThrowingEncodable(),
                result: ToolOutput("never appended")
            )
        }

        #expect(context.messages.count == 1)
        #expect(context.messages[0].textContent == "preserved")
    }

    @Test("ToolOutput multimodal content flows through to tool message")
    func multimodalToolOutput() throws {
        var context = RequestContext(messages: [], toolDefinitions: [])
        let parts: [ContentPart] = [.text("part one"), .text("part two")]
        let output = ToolOutput(parts)

        try context.appendToolExchange(
            toolName: "memory",
            arguments: Args(query: "q", count: 1),
            result: output
        )

        let tool = context.messages[1]
        #expect(tool.content.count == 2)
        #expect(tool.content == parts)
    }
}
