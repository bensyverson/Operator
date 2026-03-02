import LLM

// MARK: - Convenience Initializers

// These initializers live in the Operator module so consumers can construct
// a `ConversationConfiguration` without importing LLM directly. The
// canonical init is defined in LLM and uses LLM-specific types in its
// default arguments, which Swift won't resolve across module boundaries.

public extension ConversationConfiguration {
    /// Creates a default conversation configuration.
    init() {
        self.init(modelType: .fast)
    }

    /// Creates a conversation configuration with an explicit model name.
    ///
    /// Use this when targeting an OpenAI-compatible endpoint (e.g. OpenRouter)
    /// that requires a model identifier in every request.
    ///
    /// - Parameter model: The model name to include in API requests.
    init(model: ModelName) {
        self.init(modelType: .fast, model: model)
    }

    /// Creates a conversation configuration with common parameters.
    ///
    /// - Parameters:
    ///   - modelType: Quality tier selection (`.fast` or `.flagship`).
    ///   - inference: Inference mode (`.direct` or `.reasoning`).
    ///   - model: An explicit model name override, or `nil` to use the provider default.
    ///   - maxTokens: Maximum completion tokens per turn, or `nil` for the provider default.
    init(
        modelType: ModelType = .fast,
        inference: InferenceType = .direct,
        model: ModelName? = nil,
        maxTokens: Int? = nil
    ) {
        // Pass `temperature` explicitly to disambiguate from this initializer
        // and resolve to the canonical LLM.ConversationConfiguration.init.
        self.init(
            modelType: modelType,
            inference: inference,
            model: model,
            temperature: nil,
            maxTokens: maxTokens
        )
    }
}
