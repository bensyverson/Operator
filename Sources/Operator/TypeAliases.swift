import LLM

// MARK: - Public Type Aliases

// These aliases decouple consumers from the underlying LLM library.
// Code that imports Operator should reference these types (e.g., `Operator.Conversation`)
// rather than importing LLM directly. If the underlying library changes, only these
// aliases (or their replacement bridge types) need to be updated.

/// An ongoing conversation with an LLM, including message history and configuration.
///
/// Used to continue multi-turn interactions via ``Operative/run(_:continuing:)``.
public typealias Conversation = LLM.Conversation

/// A streaming event from an LLM response.
public typealias StreamEvent = LLM.StreamEvent

/// A completed LLM response including the updated conversation.
public typealias ConversationResponse = LLM.ConversationResponse

/// Configuration for LLM conversations (model selection, token limits, etc.).
public typealias ConversationConfiguration = LLM.ConversationConfiguration

/// The definition of a tool that can be called by an LLM.
public typealias ToolDefinition = LLM.OpenAICompatibleAPI.ToolDefinition

/// The definition of a function within a tool definition.
public typealias FunctionDefinition = LLM.OpenAICompatibleAPI.FunctionDefinition

/// A JSON Schema describing a tool's parameters or a type's structure.
public typealias JSONSchema = LLM.OpenAICompatibleAPI.JSONSchema

/// A tool call requested by the LLM.
public typealias LLMToolCall = LLM.OpenAICompatibleAPI.ToolCall

/// A function call within a tool call.
public typealias FunctionCall = LLM.OpenAICompatibleAPI.FunctionCall

/// A chat message in a conversation.
public typealias ChatMessage = LLM.OpenAICompatibleAPI.ChatMessage

/// An LLM provider configuration (API endpoint and credentials).
///
/// ```swift
/// let provider: Provider = .anthropic(apiKey: "sk-ant-...")
/// let service = LLMServiceAdapter(.init(provider: provider))
/// ```
public typealias Provider = LLM.Provider

/// Model quality selection (fast vs. flagship).
public typealias ModelType = LLM.ModelType

/// A model name identifier used in API requests (e.g. `"anthropic/claude-sonnet-4"`).
public typealias ModelName = LLM.OpenAICompatibleAPI.ModelName
