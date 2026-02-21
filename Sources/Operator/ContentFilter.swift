/// A bidirectional content filter middleware.
///
/// Redacts outbound messages matching ``blockedPatterns`` and
/// detects ``secrets`` leaking in LLM responses.
///
/// ```swift
/// let filter = ContentFilter(
///     blockedPatterns: [/password/, /secret/],
///     secrets: ["sk-abc123"]
/// )
/// ```
public struct ContentFilter: Middleware, @unchecked Sendable {
    /// Regex patterns to redact from outbound messages.
    public nonisolated(unsafe) let blockedPatterns: [Regex<Substring>]

    /// Known secret strings that must not appear in LLM output.
    public let secrets: [String]

    public init(blockedPatterns: [Regex<Substring>], secrets: [String]) {
        self.blockedPatterns = blockedPatterns
        self.secrets = secrets
    }

    public func beforeRequest(_ context: inout RequestContext) async throws {
        for i in context.messages.indices {
            guard let content = context.messages[i].content else { continue }
            var filtered = content
            for pattern in blockedPatterns {
                filtered = filtered.replacing(pattern, with: "[redacted]")
            }
            context.messages[i].content = filtered
        }
    }

    public func afterResponse(_ context: inout ResponseContext) async throws {
        guard let text = context.responseText else { return }
        for secret in secrets {
            if text.contains(secret) {
                throw MiddlewareError.secretDetected
            }
        }
    }
}
