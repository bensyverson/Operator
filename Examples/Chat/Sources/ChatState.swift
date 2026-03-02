import Foundation
import Operator
import TextUI

/// The shared state for the chat application.
///
/// Follows the same pattern as `ThemeState` in the TextUI Demo: a plain
/// `final class: @unchecked Sendable` (no `@MainActor`), with `didSet`
/// calling `MainActor.assumeIsolated { StateSignal.send() }`.
///
/// We can't use `@MainActor` because TextUI's `View.body` is nonisolated —
/// reading any property from body would be a cross-isolation access error.
/// The render loop always runs on the main actor, so access is safe at
/// runtime; `@unchecked Sendable` tells the compiler to trust us.
final class ChatState: @unchecked Sendable {
    // MARK: - Reactive properties (trigger re-render)

    var messages: [ChatMessage] = [] {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

    /// Non-reactive: TextField manages its own display via EditState in the
    /// FocusStore, and RunLoop already renders after every key event. Making
    /// this reactive would cause a redundant second render on every keystroke.
    /// When cleared on submit, the re-render is triggered by `messages` or
    /// `isStreaming` changes in the same call.
    var inputText: String = ""

    var isStreaming: Bool = false {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

    var debugMode: Bool = false {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

    var providerConfirmed: Bool = false {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

    var currentTurn: Int = 0 {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

    var totalTokens: Int = 0 {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

    var providerWarning: String? {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

    var selectedProviderIndex: Int = 0 {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

    var pressureWarning: String? {
        didSet { MainActor.assumeIsolated { StateSignal.send() } }
    }

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
