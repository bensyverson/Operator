import Foundation
import LLM
@testable import Operator
import Testing

@Suite("ConversationFormatter")
struct ConversationFormatterTests {
    @Test("Empty message list produces empty string")
    func emptyMessages() {
        let result = ConversationFormatter.format([])
        #expect(result == "")
    }

    @Test("Single user message")
    func singleUserMessage() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(content: "Hello!", role: .user),
        ]
        let result = ConversationFormatter.format(messages)
        #expect(result == "[User]: Hello!")
    }

    @Test("Single assistant message")
    func singleAssistantMessage() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(content: "Hi there!", role: .assistant),
        ]
        let result = ConversationFormatter.format(messages)
        #expect(result == "[Assistant]: Hi there!")
    }

    @Test("Multi-turn conversation")
    func multiTurnConversation() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(content: "What is 2+2?", role: .user),
            LLM.OpenAICompatibleAPI.ChatMessage(content: "The answer is 4.", role: .assistant),
            LLM.OpenAICompatibleAPI.ChatMessage(content: "Thanks!", role: .user),
        ]
        let result = ConversationFormatter.format(messages)
        let expected = """
        [User]: What is 2+2?
        [Assistant]: The answer is 4.
        [User]: Thanks!
        """
        #expect(result == expected)
    }

    @Test("Tool result message")
    func toolResultMessage() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(
                content: "{\"temperature\": 72}",
                role: .tool,
                tool_call_id: "call_123"
            ),
        ]
        let result = ConversationFormatter.format(messages)
        #expect(result == "[Tool Result]: {\"temperature\": 72}")
    }

    @Test("System message")
    func systemMessage() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(content: "You are a helpful assistant.", role: .system),
        ]
        let result = ConversationFormatter.format(messages)
        #expect(result == "[System]: You are a helpful assistant.")
    }

    @Test("Assistant message with tool calls shows call names")
    func assistantWithToolCalls() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(
                content: nil,
                role: .assistant,
                tool_calls: [
                    LLM.OpenAICompatibleAPI.ToolCall(
                        id: "call_1",
                        type: "function",
                        function: LLM.OpenAICompatibleAPI.FunctionCall(
                            name: "getWeather",
                            arguments: "{\"city\": \"Paris\"}"
                        )
                    ),
                ]
            ),
        ]
        let result = ConversationFormatter.format(messages)
        #expect(result == "[Assistant]: [Called tool: getWeather]")
    }

    @Test("Message with nil content is skipped")
    func nilContentSkipped() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(content: "Hello", role: .user),
            LLM.OpenAICompatibleAPI.ChatMessage(content: nil, role: .assistant),
            LLM.OpenAICompatibleAPI.ChatMessage(content: "Goodbye", role: .user),
        ]
        let result = ConversationFormatter.format(messages)
        let expected = """
        [User]: Hello
        [User]: Goodbye
        """
        #expect(result == expected)
    }

    @Test("Mixed conversation with tools")
    func mixedConversation() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(content: "What's the weather?", role: .user),
            LLM.OpenAICompatibleAPI.ChatMessage(
                content: nil,
                role: .assistant,
                tool_calls: [
                    LLM.OpenAICompatibleAPI.ToolCall(
                        id: "call_1",
                        type: "function",
                        function: LLM.OpenAICompatibleAPI.FunctionCall(
                            name: "getWeather",
                            arguments: "{}"
                        )
                    ),
                ]
            ),
            LLM.OpenAICompatibleAPI.ChatMessage(
                content: "Sunny, 72°F",
                role: .tool,
                tool_call_id: "call_1"
            ),
            LLM.OpenAICompatibleAPI.ChatMessage(content: "It's sunny and 72°F!", role: .assistant),
        ]
        let result = ConversationFormatter.format(messages)
        let expected = """
        [User]: What's the weather?
        [Assistant]: [Called tool: getWeather]
        [Tool Result]: Sunny, 72°F
        [Assistant]: It's sunny and 72°F!
        """
        #expect(result == expected)
    }

    @Test("Multiple tool calls in one message")
    func multipleToolCalls() {
        let messages: [LLM.OpenAICompatibleAPI.ChatMessage] = [
            LLM.OpenAICompatibleAPI.ChatMessage(
                content: nil,
                role: .assistant,
                tool_calls: [
                    LLM.OpenAICompatibleAPI.ToolCall(
                        id: "call_1",
                        type: "function",
                        function: LLM.OpenAICompatibleAPI.FunctionCall(name: "search", arguments: "{}")
                    ),
                    LLM.OpenAICompatibleAPI.ToolCall(
                        id: "call_2",
                        type: "function",
                        function: LLM.OpenAICompatibleAPI.FunctionCall(name: "fetch", arguments: "{}")
                    ),
                ]
            ),
        ]
        let result = ConversationFormatter.format(messages)
        #expect(result == "[Assistant]: [Called tools: search, fetch]")
    }
}
