import LLM

/// Middleware that mechanically reduces conversation history length.
///
/// CompactionMiddleware operates in four progressive phases during
/// ``Middleware/beforeRequest(_:)``:
///
/// 1. **Truncate** — Long tool outputs in older messages are truncated
///    to ``maxToolOutputLength`` characters.
/// 2. **Strip media** — Images and PDFs in older messages are replaced
///    with text placeholders preserving metadata, reducing token usage.
/// 3. **Collapse** — Old tool call/result pairs are collapsed into brief
///    summaries when the estimated token count exceeds ``targetTokenEstimate``.
/// 4. **Trim** — The oldest messages are removed (preserving system messages
///    and the most recent ``preserveRecentTurns`` turns) when still over target.
///
/// This middleware performs no LLM calls — it uses mechanical heuristics only.
/// For LLM-based summarization, build a custom middleware.
///
/// When ``pressureOnly`` is `true` (recommended for most use cases), compaction
/// only runs if ``RequestContext/pressure`` is non-empty, integrating with the
/// agent loop's pressure detection system.
///
/// ## Example
///
/// ```swift
/// let operative = try Operative(
///     name: "LongRunner",
///     description: "An agent with long-running sessions",
///     llm: myLLM,
///     systemPrompt: "...",
///     tools: [myTools],
///     budget: Budget(maxTurns: 100, contextWindowTokens: 200_000),
///     middleware: [CompactionMiddleware(pressureOnly: true)]
/// )
/// ```
public struct CompactionMiddleware: Middleware, Sendable {
    /// Maximum character length for tool outputs in older messages.
    ///
    /// Tool outputs exceeding this length are truncated with a marker.
    /// Defaults to `4000`.
    public let maxToolOutputLength: Int

    /// Number of recent turns to preserve from truncation and collapsing.
    ///
    /// A "turn" is approximated as a user message followed by assistant
    /// and tool messages. Defaults to `4`.
    public let preserveRecentTurns: Int

    /// Target estimated token count for the conversation.
    ///
    /// When set, collapsing and trimming activate to try to bring the
    /// estimated token count under this target. When `nil`, only truncation
    /// is applied (no message removal). Defaults to `nil`.
    public let targetTokenEstimate: Int?

    /// When `true`, compaction only runs if pressure signals are present.
    ///
    /// When `false`, compaction runs every turn. Defaults to `false`.
    public let pressureOnly: Bool

    /// Creates a compaction middleware with the given configuration.
    ///
    /// - Parameters:
    ///   - maxToolOutputLength: Maximum character length for tool outputs. Defaults to `4000`.
    ///   - preserveRecentTurns: Number of recent turns to preserve. Defaults to `4`.
    ///   - targetTokenEstimate: Target token estimate for trimming. Defaults to `nil`.
    ///   - pressureOnly: Only compact when pressure signals are present. Defaults to `false`.
    public init(
        maxToolOutputLength: Int = 4000,
        preserveRecentTurns: Int = 4,
        targetTokenEstimate: Int? = nil,
        pressureOnly: Bool = false
    ) {
        self.maxToolOutputLength = maxToolOutputLength
        self.preserveRecentTurns = preserveRecentTurns
        self.targetTokenEstimate = targetTokenEstimate
        self.pressureOnly = pressureOnly
    }

    public func beforeRequest(_ context: inout RequestContext) async throws {
        // If pressureOnly, skip compaction when no pressure signals
        if pressureOnly, context.pressure.isEmpty {
            return
        }

        // Phase 1: Truncate long tool outputs (outside preserved region)
        let preserveBoundary = computePreserveBoundary(messages: context.messages)
        truncateToolOutputs(messages: &context.messages, preserveAfter: preserveBoundary)

        // Phase 2: Strip media from old messages
        stripMedia(messages: &context.messages, preserveAfter: preserveBoundary)

        // Phase 3: Collapse old tool call/result pairs (if over target)
        if let target = targetTokenEstimate {
            let estimated = estimateTokens(messages: context.messages)
            if estimated > target {
                collapseToolPairs(messages: &context.messages, preserveAfter: preserveBoundary)
            }
        }

        // Phase 4: Trim oldest messages (if still over target)
        if let target = targetTokenEstimate {
            let estimated = estimateTokens(messages: context.messages)
            if estimated > target {
                trimOldMessages(messages: &context.messages, target: target, preserveAfter: preserveBoundary)
            }
        }
    }

    // MARK: - Private

    /// Computes the index boundary: messages at or after this index are preserved.
    private func computePreserveBoundary(messages: [Message]) -> Int {
        guard preserveRecentTurns > 0 else { return messages.count }

        // Walk backward, counting user messages as turn boundaries
        var turnsFound = 0
        for i in stride(from: messages.count - 1, through: 0, by: -1) {
            if messages[i].role == .user {
                turnsFound += 1
                if turnsFound >= preserveRecentTurns {
                    return i
                }
            }
        }
        // Not enough turns to fill the preserve window — preserve everything
        return 0
    }

    /// Phase 1: Truncate long tool outputs in messages before the preserve boundary.
    private func truncateToolOutputs(messages: inout [Message], preserveAfter: Int) {
        for i in messages.indices where i < preserveAfter {
            if messages[i].role == .tool,
               let text = messages[i].textContent,
               text.count > maxToolOutputLength
            {
                let truncated = String(text.prefix(maxToolOutputLength))
                messages[i].content = [.text(truncated + "\n[truncated — \(text.count - maxToolOutputLength) chars removed]")]
            }
        }
    }

    /// Phase 2: Replace media parts in old messages with text placeholders.
    ///
    /// For each message before the preserve boundary, replaces image and PDF
    /// content parts with descriptive text placeholders preserving metadata.
    private func stripMedia(messages: inout [Message], preserveAfter: Int) {
        for i in messages.indices where i < preserveAfter {
            guard messages[i].hasMedia else { continue }
            messages[i].content = messages[i].content.map { part in
                switch part {
                case .text:
                    return part
                case let .image(_, _, filename, description):
                    return .text(imagePlaceholder(filename: filename, description: description))
                case let .pdf(_, title):
                    if let title {
                        return .text("[PDF: \"\(title)\"]")
                    }
                    return .text("[PDF]")
                default:
                    return .text("[Media]")
                }
            }
        }
    }

    /// Builds a human-readable placeholder string for an image.
    private func imagePlaceholder(filename: String?, description: String?) -> String {
        switch (filename, description) {
        case let (name?, desc?):
            "[Image: \"\(name)\" — \(desc)]"
        case let (name?, nil):
            "[Image: \"\(name)\"]"
        case (nil, _):
            "[Image]"
        }
    }

    /// Phase 3: Collapse old tool call/result pairs into summaries.
    private func collapseToolPairs(messages: inout [Message], preserveAfter: Int) {
        var i = 0
        while i < min(preserveAfter, messages.count) {
            // Look for assistant messages with tool calls
            if messages[i].role == .assistant,
               let toolCalls = messages[i].toolCalls,
               !toolCalls.isEmpty
            {
                // Collect the tool call names
                let toolNames = toolCalls.map(\.name).joined(separator: ", ")
                let summary = "[Collapsed: called \(toolNames)]"

                // Replace the assistant message with a summary
                messages[i] = Message(role: .assistant, content: summary)

                // Remove corresponding tool result messages
                let j = i + 1
                while j < min(preserveAfter, messages.count), messages[j].role == .tool {
                    messages.remove(at: j)
                    // Don't increment j — the next message slides into this index
                }
            }
            i += 1
        }
    }

    /// Phase 4: Trim the oldest non-system messages to get under the target.
    private func trimOldMessages(messages: inout [Message], target: Int, preserveAfter _: Int) {
        while estimateTokens(messages: messages) > target {
            // Find the first non-system message that's before the preserve boundary
            let currentPreserveBoundary = computePreserveBoundary(messages: messages)
            guard let removeIndex = messages.indices.first(where: {
                $0 < currentPreserveBoundary && messages[$0].role != .system
            }) else {
                break // Nothing left to remove
            }
            messages.remove(at: removeIndex)
        }
    }

    /// Rough token estimate accounting for text and media.
    ///
    /// Text: characters / 4. Each image: ~1000 tokens. Each PDF: ~500 tokens.
    private func estimateTokens(messages: [Message]) -> Int {
        messages.reduce(0) { total, msg in
            total + msg.content.reduce(0) { partTotal, part in
                switch part {
                case let .text(s):
                    partTotal + s.count / 4
                case .image:
                    partTotal + 1000
                case .pdf:
                    partTotal + 500
                default:
                    partTotal + 100
                }
            }
        }
    }
}
