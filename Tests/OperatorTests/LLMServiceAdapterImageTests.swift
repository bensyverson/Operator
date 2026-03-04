import Foundation
import LLM
@testable import Operator
import Testing

/// Thread-safe flag for verifying closure invocation.
private final class CallFlag: @unchecked Sendable {
    var called = false
}

@Suite("LLMServiceAdapter Image Configuration")
struct LLMServiceAdapterImageTests {
    @Test("setImageResizer propagates to LLM actor")
    func setImageResizer() async throws {
        let llm = LLM(provider: .lmStudio)
        let adapter = LLMServiceAdapter(llm)

        let flag = CallFlag()
        let resizer: @Sendable (Data, String, CGSize) async throws -> Data = { data, _, _ in
            flag.called = true
            return data
        }

        await adapter.setImageResizer(resizer)

        // Verify by calling the resizer through the actor
        let testData = Data([0xFF, 0xD8])
        _ = try await llm.imageResizer?(testData, "image/jpeg", CGSize(width: 100, height: 100))
        #expect(flag.called)
    }

    @Test("setImageDescriber propagates to LLM actor")
    func setImageDescriber() async throws {
        let llm = LLM(provider: .lmStudio)
        let adapter = LLMServiceAdapter(llm)

        let flag = CallFlag()
        let describer: @Sendable (Data, String) async throws -> String = { _, _ in
            flag.called = true
            return "A test image"
        }

        await adapter.setImageDescriber(describer)

        // Verify by calling the describer through the actor
        let testData = Data([0xFF, 0xD8])
        let description: String? = try await llm.imageDescriber?(testData, "image/jpeg")
        #expect(flag.called)
        #expect(description == "A test image")
    }

    @Test("setImageResizer with nil clears the resizer")
    func clearImageResizer() async {
        let llm = LLM(provider: .lmStudio)
        let adapter = LLMServiceAdapter(llm)

        await adapter.setImageResizer(nil)

        let hasResizer: Bool = await llm.imageResizer != nil
        #expect(!hasResizer)
    }
}
