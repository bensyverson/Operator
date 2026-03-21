import Foundation
import Operator
import TextUI

/// The shared state for the chat application.
///
/// Uses TextUI's `@Observed` property wrapper on a `@MainActor` class.
/// Each `@Observed` property automatically calls `StateSignal.send()`
/// on mutation, triggering a re-render.
@MainActor
final class ChatState {
    // MARK: - Reactive properties (trigger re-render via @Observed)

    @Observed var messages: [ChatMessage] = []

    /// Non-reactive: TextField manages its own display via EditState in the
    /// FocusStore, and RunLoop already renders after every key event. Making
    /// this reactive would cause a redundant second render on every keystroke.
    /// When cleared on submit, the re-render is triggered by `messages` or
    /// `isStreaming` changes in the same call.
    var inputText: String = ""

    @Observed var isStreaming: Bool = false
    @Observed var debugMode: Bool = false
    @Observed var providerConfirmed: Bool = false
    @Observed var showProviderPicker: Bool = true
    @Observed var currentTurn: Int = 0
    @Observed var totalTokens: Int = 0
    @Observed var providerWarning: String?
    @Observed var selectedProviderIndex: Int = 0
    @Observed var pressureWarning: String?

    // MARK: - Non-reactive (no UI binding)

    var lastConversation: Conversation?
    var operative: Operative?
    var args: ChatArguments = .parseOrExit()
}

/// Errors thrown during operative configuration.
enum OperativeError: Error, CustomStringConvertible {
    case configurationError(String)

    var description: String {
        switch self {
        case let .configurationError(msg): msg
        }
    }
}
