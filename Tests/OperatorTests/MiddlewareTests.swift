import Foundation
@testable import Operator
import Testing

// MARK: - Test Helpers

/// A middleware that does nothing (uses all defaults).
private struct NoOpMiddleware: Middleware {}

/// A middleware that appends a suffix to every message's content.
private struct MessageAppender: Middleware {
    let suffix: String

    func beforeRequest(_ context: inout RequestContext) async throws {
        for i in context.messages.indices {
            if let content = context.messages[i].content {
                context.messages[i].content = content + suffix
            }
        }
    }
}

/// A middleware that rejects a named tool call.
private struct ToolBlocker: Middleware {
    let blockedName: String

    func beforeToolCalls(_ calls: inout [ToolCallContext]) async throws {
        for i in calls.indices where calls[i].name == blockedName {
            calls[i].decision = .reject(reason: "Blocked by ToolBlocker")
        }
    }
}

/// A middleware that throws immediately on beforeRequest.
private struct ThrowingMiddleware: Middleware {
    func beforeRequest(_: inout RequestContext) async throws {
        throw MiddlewareError.requestRejected(reason: "Blocked")
    }
}

/// A middleware that records whether it was called.
private final class CallTracker: Middleware, @unchecked Sendable {
    var beforeRequestCalled = false

    func beforeRequest(_: inout RequestContext) async throws {
        beforeRequestCalled = true
    }
}

// MARK: - Tests

@Suite("Middleware Protocol")
struct MiddlewareProtocolTests {
    @Test("Default no-op middleware — all four methods unchanged")
    func defaultNoOp() async throws {
        let middleware: any Middleware = NoOpMiddleware()
        var reqCtx = RequestContext(
            messages: [Message(role: .user, content: "Hello")],
            toolDefinitions: []
        )
        try await middleware.beforeRequest(&reqCtx)
        #expect(reqCtx.messages[0].content == "Hello")

        var respCtx = ResponseContext(responseText: "World")
        try await middleware.afterResponse(&respCtx)
        #expect(respCtx.responseText == "World")

        var calls = [ToolCallContext(name: "test", arguments: "{}", toolCallId: "c1")]
        try await middleware.beforeToolCalls(&calls)
        #expect(calls[0].decision == .proceed)

        struct TestErr: Error {}
        let recovery = try await middleware.onToolError(TestErr(), context: calls[0])
        if case .feedbackToLLM = recovery {
            // expected
        } else {
            Issue.record("Expected .feedbackToLLM")
        }
    }

    @Test("Default onToolError returns .feedbackToLLM with localized description")
    func defaultOnToolError() async throws {
        let middleware: any Middleware = NoOpMiddleware()
        struct DescribedError: Error, LocalizedError {
            var errorDescription: String? {
                "something broke"
            }
        }
        let ctx = ToolCallContext(name: "test", arguments: "{}", toolCallId: "c1")
        let recovery = try await middleware.onToolError(DescribedError(), context: ctx)
        if case let .feedbackToLLM(msg) = recovery {
            #expect(msg == "something broke")
        } else {
            Issue.record("Expected .feedbackToLLM")
        }
    }

    @Test("Selective override — only beforeRequest, others are no-ops")
    func selectiveOverride() async throws {
        let middleware: any Middleware = MessageAppender(suffix: " [filtered]")

        var reqCtx = RequestContext(
            messages: [Message(role: .user, content: "Hello")],
            toolDefinitions: []
        )
        try await middleware.beforeRequest(&reqCtx)
        #expect(reqCtx.messages[0].content == "Hello [filtered]")

        // afterResponse should be no-op
        var respCtx = ResponseContext(responseText: "World")
        try await middleware.afterResponse(&respCtx)
        #expect(respCtx.responseText == "World")
    }

    @Test("Pipeline ordering — two middlewares append to message content in order")
    func pipelineOrdering() async throws {
        let middlewares: [any Middleware] = [
            MessageAppender(suffix: " [A]"),
            MessageAppender(suffix: " [B]"),
        ]

        var ctx = RequestContext(
            messages: [Message(role: .user, content: "Hello")],
            toolDefinitions: []
        )

        for middleware in middlewares {
            try await middleware.beforeRequest(&ctx)
        }

        #expect(ctx.messages[0].content == "Hello [A] [B]")
    }

    @Test("Pipeline ordering — beforeToolCalls rejection visible to later middleware")
    func pipelineToolCallRejection() async throws {
        let blocker = ToolBlocker(blockedName: "deleteFile")

        // A middleware that reads the decision set by the previous middleware.
        struct DecisionReader: Middleware {
            func beforeToolCalls(_ calls: inout [ToolCallContext]) async throws {
                // The blocker should have already rejected "deleteFile"
                for call in calls where call.name == "deleteFile" {
                    if case .reject = call.decision {
                        // expected — leave it alone
                    } else {
                        throw MiddlewareError.requestRejected(reason: "Expected rejection not found")
                    }
                }
            }
        }

        let middlewares: [any Middleware] = [blocker, DecisionReader()]

        var calls = [
            ToolCallContext(name: "readFile", arguments: "{}", toolCallId: "c1"),
            ToolCallContext(name: "deleteFile", arguments: "{}", toolCallId: "c2"),
        ]

        for middleware in middlewares {
            try await middleware.beforeToolCalls(&calls)
        }

        #expect(calls[0].decision == .proceed)
        #expect(calls[1].decision == .reject(reason: "Blocked by ToolBlocker"))
    }

    @Test("Middleware short-circuit on throw — first throws, second never runs")
    func shortCircuitOnThrow() async throws {
        let tracker = CallTracker()
        let middlewares: [any Middleware] = [ThrowingMiddleware(), tracker]

        var ctx = RequestContext(
            messages: [Message(role: .user, content: "Hello")],
            toolDefinitions: []
        )

        var didThrow = false
        for middleware in middlewares {
            do {
                try await middleware.beforeRequest(&ctx)
            } catch {
                didThrow = true
                break
            }
        }

        #expect(didThrow)
        #expect(!tracker.beforeRequestCalled)
    }
}

@Suite("ContentFilter")
struct ContentFilterTests {
    @Test("Redacts blocked patterns in beforeRequest")
    func redactsBlockedPatterns() async throws {
        let filter = try ContentFilter(
            blockedPatterns: [Regex("password")],
            secrets: []
        )

        var ctx = RequestContext(
            messages: [Message(role: .user, content: "My password is secret123")],
            toolDefinitions: []
        )
        try await filter.beforeRequest(&ctx)
        #expect(ctx.messages[0].content == "My [redacted] is secret123")
    }

    @Test("Multiple patterns")
    func multiplePatterns() async throws {
        let filter = try ContentFilter(
            blockedPatterns: [Regex("password"), Regex("secret")],
            secrets: []
        )

        var ctx = RequestContext(
            messages: [Message(role: .user, content: "My password is secret")],
            toolDefinitions: []
        )
        try await filter.beforeRequest(&ctx)
        #expect(ctx.messages[0].content == "My [redacted] is [redacted]")
    }

    @Test("Passes clean messages unchanged")
    func passesCleanMessages() async throws {
        let filter = try ContentFilter(
            blockedPatterns: [Regex("password")],
            secrets: []
        )

        var ctx = RequestContext(
            messages: [Message(role: .user, content: "Hello, world!")],
            toolDefinitions: []
        )
        try await filter.beforeRequest(&ctx)
        #expect(ctx.messages[0].content == "Hello, world!")
    }

    @Test("Detects secrets in afterResponse")
    func detectsSecrets() async throws {
        let filter = ContentFilter(
            blockedPatterns: [],
            secrets: ["sk-abc123"]
        )

        var ctx = ResponseContext(responseText: "Here is the key: sk-abc123")
        await #expect(throws: MiddlewareError.self) {
            try await filter.afterResponse(&ctx)
        }
    }

    @Test("Passes clean responses")
    func passesCleanResponses() async throws {
        let filter = ContentFilter(
            blockedPatterns: [],
            secrets: ["sk-abc123"]
        )

        var ctx = ResponseContext(responseText: "Everything is fine")
        try await filter.afterResponse(&ctx)
        #expect(ctx.responseText == "Everything is fine")
    }

    @Test("Empty patterns and secrets is no-op")
    func emptyIsNoOp() async throws {
        let filter = ContentFilter(blockedPatterns: [], secrets: [])

        var reqCtx = RequestContext(
            messages: [Message(role: .user, content: "Hello password secret")],
            toolDefinitions: []
        )
        try await filter.beforeRequest(&reqCtx)
        #expect(reqCtx.messages[0].content == "Hello password secret")

        var respCtx = ResponseContext(responseText: "sk-abc123")
        try await filter.afterResponse(&respCtx)
        #expect(respCtx.responseText == "sk-abc123")
    }

    @Test("Handles messages with nil content")
    func handlesNilContent() async throws {
        let filter = try ContentFilter(
            blockedPatterns: [Regex("password")],
            secrets: []
        )

        var ctx = RequestContext(
            messages: [Message(role: .assistant, content: nil)],
            toolDefinitions: []
        )
        try await filter.beforeRequest(&ctx)
        #expect(ctx.messages[0].content == nil)
    }
}

@Suite("MiddlewareError")
struct MiddlewareErrorTests {
    @Test("Localized descriptions")
    func localizedDescriptions() {
        let secretError = MiddlewareError.secretDetected
        #expect(secretError.localizedDescription == "A known secret was detected in the response")

        let rejectedError = MiddlewareError.requestRejected(reason: "Too long")
        #expect(rejectedError.localizedDescription == "Request rejected: Too long")
    }
}
