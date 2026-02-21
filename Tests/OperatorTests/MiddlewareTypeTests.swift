import Foundation
@testable import Operator
import Testing

@Suite("Message")
struct MessageTests {
    @Test("Codable round-trip for each role")
    func codableRoundTrip() throws {
        let roles: [Message.Role] = [.system, .user, .assistant, .tool]
        for role in roles {
            let message = Message(role: role, content: "Hello from \(role)")
            let data = try JSONEncoder().encode(message)
            let decoded = try JSONDecoder().decode(Message.self, from: data)
            #expect(decoded == message)
        }
    }

    @Test("Codable round-trip with nil content")
    func codableNilContent() throws {
        let message = Message(role: .assistant, content: nil)
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        #expect(decoded == message)
        #expect(decoded.content == nil)
    }

    @Test("Message with toolCallId round-trip")
    func codableWithToolCallId() throws {
        let message = Message(role: .tool, content: "result", toolCallId: "call_123")
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)
        #expect(decoded == message)
        #expect(decoded.toolCallId == "call_123")
    }
}

@Suite("ToolCallDecision")
struct ToolCallDecisionTests {
    @Test("Codable round-trip for all cases")
    func codableRoundTrip() throws {
        let args = try ToolArguments(fromJSON: #"{"key": "value"}"#)
        let cases: [ToolCallDecision] = [
            .proceed,
            .modify(args),
            .reject(reason: "Not allowed"),
        ]
        for decision in cases {
            let data = try JSONEncoder().encode(decision)
            let decoded = try JSONDecoder().decode(ToolCallDecision.self, from: data)
            #expect(decoded == decision)
        }
    }

    @Test("Equality")
    func equality() {
        #expect(ToolCallDecision.proceed == ToolCallDecision.proceed)
        #expect(ToolCallDecision.proceed != ToolCallDecision.reject(reason: "no"))
        #expect(
            ToolCallDecision.reject(reason: "a")
                != ToolCallDecision.reject(reason: "b")
        )
    }
}

@Suite("ToolErrorRecovery")
struct ToolErrorRecoveryTests {
    @Test("Codable round-trip for both cases")
    func codableRoundTrip() throws {
        let cases: [ToolErrorRecovery] = [
            .feedbackToLLM("Something went wrong"),
            .throw,
        ]
        for recovery in cases {
            let data = try JSONEncoder().encode(recovery)
            let decoded = try JSONDecoder().decode(ToolErrorRecovery.self, from: data)
            #expect(decoded == recovery)
        }
    }
}

@Suite("ToolRequest")
struct ToolRequestTests {
    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let request = ToolRequest(name: "readFile", arguments: "path=/tmp/test", toolCallId: "call_abc")
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ToolRequest.self, from: data)
        #expect(decoded == request)
    }
}

@Suite("ToolRejection")
struct ToolRejectionTests {
    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let request = ToolRequest(name: "deleteFile", arguments: "path=/etc/passwd", toolCallId: "call_xyz")
        let rejection = ToolRejection(request: request, reason: "Dangerous operation")
        let data = try JSONEncoder().encode(rejection)
        let decoded = try JSONDecoder().decode(ToolRejection.self, from: data)
        #expect(decoded == rejection)
    }
}

@Suite("ToolError")
struct ToolErrorTests {
    @Test("Stores message and underlying error")
    func storesMessageAndError() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? {
                "test failure"
            }
        }
        let underlying = TestError()
        let toolError = ToolError(message: "Tool crashed", underlyingError: underlying)
        #expect(toolError.message == "Tool crashed")
        #expect(toolError.underlyingError is TestError)
    }
}

@Suite("ToolCallContext")
struct ToolCallContextTests {
    @Test("Default decision is .proceed")
    func defaultDecision() {
        let ctx = ToolCallContext(name: "search", arguments: "q=hello", toolCallId: "call_1")
        #expect(ctx.decision == .proceed)
    }

    @Test("Default attemptCount is 1")
    func defaultAttemptCount() {
        let ctx = ToolCallContext(name: "search", arguments: "q=hello", toolCallId: "call_1")
        #expect(ctx.attemptCount == 1)
    }

    @Test("Mutability — change decision to .reject")
    func mutability() {
        var ctx = ToolCallContext(name: "search", arguments: "q=hello", toolCallId: "call_1")
        ctx.decision = .reject(reason: "Blocked by policy")
        #expect(ctx.decision == .reject(reason: "Blocked by policy"))
    }
}

@Suite("RequestContext")
struct RequestContextTests {
    @Test("Mutability — append a message")
    func appendMessage() {
        var ctx = RequestContext(messages: [
            Message(role: .user, content: "Hello"),
        ], toolDefinitions: [])
        ctx.messages.append(Message(role: .system, content: "Be helpful"))
        #expect(ctx.messages.count == 2)
        #expect(ctx.messages[1].role == .system)
    }
}

@Suite("ResponseContext")
struct ResponseContextTests {
    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let request = ToolRequest(name: "search", arguments: "q=test", toolCallId: "call_1")
        let ctx = ResponseContext(responseText: "Here are the results", toolCalls: [request])
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(ResponseContext.self, from: data)
        #expect(decoded == ctx)
    }
}
