#if canImport(FoundationModels)
    import Foundation
    import FoundationModels

    /// Internal protocol for tools that can be automatically bridged to
    /// Apple FoundationModels.
    ///
    /// ``ClosureTool`` conditionally conforms when its `Input` is also
    /// `@Generable` (i.e. conforms to `Generable`).
    /// At runtime, ``AppleIntelligenceService`` checks `tool as? AFMBridgeable`
    /// to discover which tools from the registry can participate in the
    /// on-device model's internal tool loop.
    @available(macOS 26.0, iOS 26.0, *)
    protocol AFMBridgeable {
        /// Builds a ``FoundationModels.Tool`` proxy that wraps this Operator tool.
        ///
        /// - Parameters:
        ///   - name: Tool name from the ``ToolDefinition``.
        ///   - description: Tool description from the ``ToolDefinition``.
        ///   - eventHandler: Callback for emitting ``Operation`` events. Called
        ///     from Apple's tool execution context, potentially concurrently.
        /// - Returns: A type-erased `FoundationModels.Tool` to register with
        ///   the ``LanguageModelSession``.
        func makeAFMProxy(
            name: String,
            description: String,
            eventHandler: @escaping @Sendable (Operation) -> Void
        ) -> any FoundationModels.Tool
    }

    @available(macOS 26.0, iOS 26.0, *)
    extension ClosureTool: AFMBridgeable where Input: Generable {
        func makeAFMProxy(
            name: String,
            description: String,
            eventHandler: @escaping @Sendable (Operation) -> Void
        ) -> any FoundationModels.Tool {
            OperatorToolProxy<Input>(
                name: name,
                description: description,
                execute: execute,
                eventHandler: eventHandler
            )
        }
    }
#endif
