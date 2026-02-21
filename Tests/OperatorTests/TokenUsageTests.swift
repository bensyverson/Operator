import Foundation
import LLM
@testable import Operator
import Testing

@Suite("TokenUsage")
struct TokenUsageTests {
    @Test("Basic construction")
    func basicConstruction() {
        let usage = TokenUsage(promptTokens: 100, completionTokens: 50, totalTokens: 150)
        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 50)
        #expect(usage.totalTokens == 150)
    }

    @Test("Zero static property")
    func zeroProperty() {
        let zero = TokenUsage.zero
        #expect(zero.promptTokens == 0)
        #expect(zero.completionTokens == 0)
        #expect(zero.totalTokens == 0)
    }

    @Test("Addition operator")
    func addition() {
        let a = TokenUsage(promptTokens: 100, completionTokens: 50, totalTokens: 150)
        let b = TokenUsage(promptTokens: 200, completionTokens: 75, totalTokens: 275)
        let sum = a + b
        #expect(sum.promptTokens == 300)
        #expect(sum.completionTokens == 125)
        #expect(sum.totalTokens == 425)
    }

    @Test("From OpenAI-style usage (prompt_tokens/completion_tokens)")
    func fromOpenAIUsage() throws {
        // Encode an OpenAI-style usage JSON and decode as LLM's Usage type
        let json = """
        {"prompt_tokens": 500, "completion_tokens": 200, "total_tokens": 700}
        """
        let usage = try JSONDecoder().decode(
            LLM.OpenAICompatibleAPI.ChatCompletionResponse.Usage.self,
            from: Data(json.utf8)
        )
        let tokenUsage = TokenUsage.from(usage)
        #expect(tokenUsage.promptTokens == 500)
        #expect(tokenUsage.completionTokens == 200)
        #expect(tokenUsage.totalTokens == 700)
    }

    @Test("From Anthropic-style usage (input_tokens/output_tokens)")
    func fromAnthropicUsage() throws {
        let json = """
        {"input_tokens": 300, "output_tokens": 100, "model": "claude-3"}
        """
        let usage = try JSONDecoder().decode(
            LLM.OpenAICompatibleAPI.ChatCompletionResponse.Usage.self,
            from: Data(json.utf8)
        )
        let tokenUsage = TokenUsage.from(usage)
        #expect(tokenUsage.promptTokens == 300)
        #expect(tokenUsage.completionTokens == 100)
        #expect(tokenUsage.totalTokens == 400)
    }

    @Test("From usage with nil fields falls back to zero")
    func fromNilFields() throws {
        let json = """
        {"model": "test"}
        """
        let usage = try JSONDecoder().decode(
            LLM.OpenAICompatibleAPI.ChatCompletionResponse.Usage.self,
            from: Data(json.utf8)
        )
        let tokenUsage = TokenUsage.from(usage)
        #expect(tokenUsage.promptTokens == 0)
        #expect(tokenUsage.completionTokens == 0)
        #expect(tokenUsage.totalTokens == 0)
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let usage = TokenUsage(promptTokens: 42, completionTokens: 18, totalTokens: 60)
        let data = try JSONEncoder().encode(usage)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        #expect(decoded == usage)
    }
}
