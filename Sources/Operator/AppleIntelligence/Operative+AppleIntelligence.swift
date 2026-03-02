#if canImport(FoundationModels)

    /// Convenience initializer for creating an ``Operative`` powered by
    /// Apple's on-device Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    public extension Operative {
        /// Creates an Operative using the on-device Apple Intelligence model.
        ///
        /// This is a convenience that constructs an ``AppleIntelligenceService``
        /// internally, so you don't need to create one yourself.
        ///
        /// ```swift
        /// let agent = try Operative(
        ///     name: "Summarizer",
        ///     description: "Summarizes text on-device",
        ///     systemPrompt: "You summarize text concisely.",
        ///     tools: [MyTools()],
        ///     budget: Budget(maxTurns: 5)
        /// )
        /// ```
        ///
        /// > Tip: Tools whose ``ToolInput`` type also conforms to
        /// > `@Generable` (`ConvertibleFromGeneratedContent`) are automatically
        /// > bridged to Apple's on-device tool loop. The model calls them
        /// > internally during `respond(to:)` and Operator emits the usual
        /// > `.toolsRequested` / `.toolCompleted` / `.toolFailed` events.
        /// > Tools without `@Generable` inputs are silently excluded from
        /// > the on-device session.
        ///
        /// - Parameters:
        ///   - name: A human-readable name for this agent.
        ///   - description: A brief description of this agent's purpose.
        ///   - systemPrompt: The base system prompt sent with every request.
        ///   - tools: Operable conformers whose tools the agent can call.
        ///   - budget: Resource limits for the run.
        ///   - middleware: Ordered middleware pipeline.
        /// - Throws: ``OperativeError/duplicateToolName(_:)`` if tool names collide.
        init(
            name: String,
            description: String,
            systemPrompt: String,
            tools: [any Operable],
            budget: Budget,
            middleware: [any Middleware] = []
        ) throws {
            try self.init(
                name: name,
                description: description,
                llm: AppleIntelligenceService(),
                systemPrompt: systemPrompt,
                tools: tools,
                budget: budget,
                middleware: middleware
            )
        }
    }
#endif
