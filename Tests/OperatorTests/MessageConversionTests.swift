import LLM
@testable import Operator
import Testing

@Suite("Message ↔ ChatMessage Conversion")
struct MessageConversionTests {
    @Test("init(from:) maps system role")
    func initFromSystemRole() {
        let chatMessage = LLM.OpenAICompatibleAPI.ChatMessage(
            content: "You are a helper",
            role: .system
        )
        let message = Message(from: chatMessage)
        #expect(message.role == .system)
        #expect(message.content == "You are a helper")
        #expect(message.toolCallId == nil)
    }

    @Test("init(from:) maps user role")
    func initFromUserRole() {
        let chatMessage = LLM.OpenAICompatibleAPI.ChatMessage(
            content: "Hello",
            role: .user
        )
        let message = Message(from: chatMessage)
        #expect(message.role == .user)
        #expect(message.content == "Hello")
    }

    @Test("init(from:) maps assistant role")
    func initFromAssistantRole() {
        let chatMessage = LLM.OpenAICompatibleAPI.ChatMessage(
            content: "Hi there",
            role: .assistant
        )
        let message = Message(from: chatMessage)
        #expect(message.role == .assistant)
        #expect(message.content == "Hi there")
    }

    @Test("init(from:) maps tool role and preserves tool_call_id")
    func initFromToolRole() {
        let chatMessage = LLM.OpenAICompatibleAPI.ChatMessage(
            content: "result data",
            role: .tool,
            tool_call_id: "call_123"
        )
        let message = Message(from: chatMessage)
        #expect(message.role == .tool)
        #expect(message.content == "result data")
        #expect(message.toolCallId == "call_123")
    }

    @Test("init(from:) handles nil content")
    func initFromNilContent() {
        let chatMessage = LLM.OpenAICompatibleAPI.ChatMessage(
            content: nil,
            role: .assistant
        )
        let message = Message(from: chatMessage)
        #expect(message.role == .assistant)
        #expect(message.content == nil)
    }

    @Test("toChatMessage() round-trips correctly")
    func toChatMessageRoundTrip() {
        let original = Message(role: .user, content: "Hello world")
        let chatMessage = original.toChatMessage()
        #expect(chatMessage.role == .user)
        #expect(chatMessage.content == "Hello world")
        #expect(chatMessage.tool_call_id == nil)

        let roundTripped = Message(from: chatMessage)
        #expect(roundTripped == original)
    }

    @Test("toChatMessage() preserves toolCallId")
    func toChatMessagePreservesToolCallId() {
        let original = Message(role: .tool, content: "done", toolCallId: "call_456")
        let chatMessage = original.toChatMessage()
        #expect(chatMessage.role == .tool)
        #expect(chatMessage.content == "done")
        #expect(chatMessage.tool_call_id == "call_456")
    }
}

@Suite("ToolRequest ← ToolCall Conversion")
struct ToolRequestConversionTests {
    @Test("init(from:) converts ToolCall fields")
    func initFromToolCall() {
        let toolCall = LLM.OpenAICompatibleAPI.ToolCall(
            id: "call_abc",
            function: LLM.OpenAICompatibleAPI.FunctionCall(
                name: "readFile",
                arguments: "{\"path\":\"/tmp/test.txt\"}"
            )
        )
        let request = ToolRequest(from: toolCall)
        #expect(request.name == "readFile")
        #expect(request.arguments == "{\"path\":\"/tmp/test.txt\"}")
        #expect(request.toolCallId == "call_abc")
    }

    @Test("init(from:) handles empty arguments")
    func initFromEmptyArguments() {
        let toolCall = LLM.OpenAICompatibleAPI.ToolCall(
            id: "call_def",
            function: LLM.OpenAICompatibleAPI.FunctionCall(
                name: "getCurrentTime",
                arguments: "{}"
            )
        )
        let request = ToolRequest(from: toolCall)
        #expect(request.name == "getCurrentTime")
        #expect(request.arguments == "{}")
        #expect(request.toolCallId == "call_def")
    }
}
