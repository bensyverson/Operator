import Foundation

/// The role of a message in the conversation.
enum MessageRole {
    case user
    case agent
    case thinking
    case toolCall
    case toolOutput
    case system
}

/// A single message in the chat conversation.
struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    var text: String
    var toolName: String?
    var toolArguments: String?
    var toolOutput: String?
}
