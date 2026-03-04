import LLM

/// A bidirectional content filter middleware.
///
/// Redacts outbound messages matching ``blockedPatterns`` and
/// detects ``secrets`` leaking in LLM responses.
///
/// Scans both text content and image descriptions for blocked patterns.
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

    /// Creates a content filter with the given blocked patterns and secrets.
    public init(blockedPatterns: [Regex<Substring>], secrets: [String]) {
        self.blockedPatterns = blockedPatterns
        self.secrets = secrets
    }

    /// Redacts blocked patterns from outbound message content parts.
    public func beforeRequest(_ context: inout RequestContext) async throws {
        guard !blockedPatterns.isEmpty else { return }

        for i in context.messages.indices {
            for j in context.messages[i].content.indices {
                context.messages[i].content[j] = redact(context.messages[i].content[j])
            }
        }
    }

    /// Throws if the LLM response contains any known secret.
    public func afterResponse(_ context: inout ResponseContext) async throws {
        guard let text = context.responseText else { return }
        for secret in secrets {
            if text.contains(secret) {
                throw MiddlewareError.secretDetected
            }
        }
    }

    // MARK: - Private

    /// Redacts blocked patterns from a single content part.
    private func redact(_ part: ContentPart) -> ContentPart {
        switch part {
        case let .text(s):
            var filtered = s
            for pattern in blockedPatterns {
                filtered = filtered.replacing(pattern, with: "[redacted]")
            }
            return .text(filtered)
        case let .image(data, mediaType, filename, description):
            guard let desc = description else { return part }
            var filtered = desc
            for pattern in blockedPatterns {
                filtered = filtered.replacing(pattern, with: "[redacted]")
            }
            return .image(data: data, mediaType: mediaType, filename: filename, description: filtered)
        default:
            return part
        }
    }
}
