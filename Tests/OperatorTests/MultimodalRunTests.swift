import Foundation
import LLM
@testable import Operator
import Testing

/// Avoid ambiguity with Foundation.Operation
private typealias Op = Operator.Operation

@Suite("Multimodal Run")
struct MultimodalRunTests {
    @Test("run([ContentPart]) builds conversation with multimodal content")
    func runWithContentParts() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("I see an image"),
        ])

        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "You are helpful",
            tools: [],
            budget: Budget(maxTurns: 5)
        )

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let parts: [ContentPart] = [
            .text("What is this?"),
            .image(data: imageData, mediaType: "image/jpeg"),
        ]

        var ops = [Op]()
        for await op in operative.run(parts) {
            ops.append(op)
        }

        // Verify the mock received a conversation with multimodal content
        #expect(mock.callCount == 1)
        let conversation = mock.receivedConversations[0]
        #expect(conversation.messages.count == 1)
        #expect(conversation.messages[0].role == .user)
        #expect(conversation.messages[0].content.count == 2)
        #expect(conversation.messages[0].hasMedia == true)

        // Verify completed
        let completed = ops.contains { if case .completed = $0 { true } else { false } }
        #expect(completed)
    }

    @Test("run([ContentPart], continuing:) appends multimodal to existing conversation")
    func runContinuingWithContentParts() async throws {
        let mock = MockLLMService(responses: [
            .textOnly("First response"),
            .textOnly("I see the image"),
        ])

        let operative = try Operative(
            name: "test",
            description: "test agent",
            llm: mock,
            systemPrompt: "You are helpful",
            tools: [],
            budget: Budget(maxTurns: 5)
        )

        // First run (text only)
        var firstResult: OperativeResult?
        for await op in operative.run("Hello") {
            if case let .completed(result) = op {
                firstResult = result
            }
        }

        let conversation = try #require(firstResult?.conversation)

        // Second run with multimodal content
        let imageData = Data([0xFF, 0xD8])
        let parts: [ContentPart] = [
            .text("What about this?"),
            .image(data: imageData, mediaType: "image/png"),
        ]

        for await _ in operative.run(parts, continuing: conversation) {}

        // Verify the second conversation has original messages + new multimodal
        #expect(mock.callCount == 2)
        let secondConversation = mock.receivedConversations[1]
        let lastMessage = secondConversation.messages.last
        #expect(lastMessage?.role == .user)
        #expect(lastMessage?.content.count == 2)
        #expect(lastMessage?.hasMedia == true)
    }
}
