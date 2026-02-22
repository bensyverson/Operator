import Foundation
import LLM

/// The core agent type that runs an LLM in a loop with tools.
///
/// An Operative encapsulates a configured agent: an LLM connection,
/// a set of tools, a system prompt, a budget, and optional middleware.
/// Call ``run(_:)`` to start the agent loop and receive a stream of
/// ``Operation`` events.
///
/// See <doc:Operative> for detailed documentation.
public struct Operative: Sendable {
    /// A human-readable name for this agent, used for logging, debugging, and orchestration.
    public let name: String

    /// A brief description of this agent's purpose.
    public let description: String

    /// The system prompt sent with every LLM request.
    public let systemPrompt: String

    /// Resource limits for the run.
    public let budget: Budget

    /// Ordered middleware pipeline.
    public let middleware: [any Middleware]

    /// The LLM service used for model calls.
    let llm: any LLMService

    /// Flattened tool registry mapping tool names to their providers.
    let toolRegistry: [String: any ToolProvider]

    /// Tool definitions sent to the LLM.
    let toolDefinitions: [LLM.OpenAICompatibleAPI.ToolDefinition]

    /// Configuration passed through to LLM conversations.
    let configuration: LLM.ConversationConfiguration

    /// Creates an Operative with an ``LLMService`` (protocol-based, for testability).
    ///
    /// - Parameters:
    ///   - name: A human-readable name for this agent.
    ///   - description: A brief description of this agent's purpose.
    ///   - llm: The LLM service to use for model calls.
    ///   - systemPrompt: The base system prompt sent with every request.
    ///   - tools: Operable conformers whose tools the agent can call.
    ///   - budget: Resource limits for the run.
    ///   - middleware: Ordered middleware pipeline.
    ///   - configuration: LLM conversation configuration.
    /// - Throws: ``OperativeError/duplicateToolName(_:)`` if tool names collide.
    public init(
        name: String,
        description: String,
        llm: any LLMService,
        systemPrompt: String,
        tools: [any Operable],
        budget: Budget,
        middleware: [any Middleware] = [],
        configuration: LLM.ConversationConfiguration = LLM.ConversationConfiguration()
    ) throws {
        self.name = name
        self.description = description
        self.llm = llm
        self.systemPrompt = systemPrompt
        self.budget = budget
        self.middleware = middleware
        self.configuration = configuration

        // Flatten all tool groups into a single registry
        var registry = [String: any ToolProvider]()
        var definitions = [LLM.OpenAICompatibleAPI.ToolDefinition]()

        for operable in tools {
            let group = operable.toolGroup
            for tool in group.tools {
                let name = tool.definition.function.name
                if registry[name] != nil {
                    throw OperativeError.duplicateToolName(name)
                }
                registry[name] = tool

                // Prefix the tool description with the group name
                var definition = tool.definition
                let originalDescription = definition.function.description
                definition.function.description = "[\(group.name)] \(originalDescription)"
                definitions.append(definition)
            }
        }

        toolRegistry = registry
        toolDefinitions = definitions
    }

    /// Creates an Operative with an ``LLM`` actor directly.
    ///
    /// This convenience initializer wraps the actor in an internal adapter.
    ///
    /// - Parameters:
    ///   - name: A human-readable name for this agent.
    ///   - description: A brief description of this agent's purpose.
    ///   - llm: The LLM actor to use for model calls.
    ///   - systemPrompt: The base system prompt sent with every request.
    ///   - tools: Operable conformers whose tools the agent can call.
    ///   - budget: Resource limits for the run.
    ///   - middleware: Ordered middleware pipeline.
    ///   - configuration: LLM conversation configuration.
    /// - Throws: ``OperativeError/duplicateToolName(_:)`` if tool names collide.
    public init(
        name: String,
        description: String,
        llm: LLM,
        systemPrompt: String,
        tools: [any Operable],
        budget: Budget,
        middleware: [any Middleware] = [],
        configuration: LLM.ConversationConfiguration = LLM.ConversationConfiguration()
    ) throws {
        try self.init(
            name: name,
            description: description,
            llm: LLMServiceAdapter(llm),
            systemPrompt: systemPrompt,
            tools: tools,
            budget: budget,
            middleware: middleware,
            configuration: configuration
        )
    }
}
