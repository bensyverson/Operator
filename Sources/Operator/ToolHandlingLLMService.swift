import LLM

/// An LLM service that handles tool execution internally.
///
/// When ``Operative``'s run loop detects that its LLM service conforms to
/// this protocol, it delegates the entire execution to the service rather
/// than running its own tool call → execute → loop cycle. The service
/// emits ``Operation`` events directly to the continuation.
///
/// ## Why this exists
///
/// Some LLM runtimes (e.g., Apple's FoundationModels) manage tool calling
/// internally — the runtime calls tools during generation and never exposes
/// structured tool call objects to the caller. This protocol lets such
/// services integrate with Operator's event stream without fighting the
/// standard loop.
///
/// ## Contract
///
/// - The service MUST emit `.completed` or `.stopped` before returning.
/// - The service SHOULD emit `.turnStarted` / `.turnCompleted` for structure.
/// - The service SHOULD emit `.toolsRequested` / `.toolCompleted` / `.toolFailed`
///   for each tool invocation it observes.
/// - ``Budget/timeout`` should be respected (wrap the generation call).
/// - Best-effort middleware: call `onToolError` for tool failures,
///   `afterResponse` with the final text. Skip `beforeRequest` and
///   `beforeToolCalls` (not applicable when the runtime drives the loop).
protocol ToolHandlingLLMService: LLMService {
    /// Runs the full conversation including tool execution, emitting
    /// ``Operation`` events to the continuation as work proceeds.
    ///
    /// - Parameters:
    ///   - conversation: The conversation state to execute.
    ///   - tools: The flattened tool registry mapping names to providers.
    ///   - budget: Resource limits for the run.
    ///   - middleware: Ordered middleware pipeline for best-effort hooks.
    ///   - continuation: The stream continuation to yield events into.
    func execute(
        conversation: Conversation,
        tools: [String: any ToolProvider],
        budget: Budget,
        middleware: [any Middleware],
        continuation: OperationStream.Continuation
    ) async
}
