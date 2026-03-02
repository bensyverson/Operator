import TextUI

/// The scrollable list of chat messages.
///
/// Filters messages based on debug mode: thinking and system messages
/// are only shown when debug mode is active.
struct MessageListView: View {
    @EnvironmentObject var state: ChatState

    var body: some View {
        ScrollView {
            ForEach(visibleMessages) { message in
                MessageView(message: message)
            }
            if state.isStreaming, shouldShowTypingIndicator {
                TypingIndicatorView()
                    .animating()
            }
        }
        .defaultScrollAnchor(.bottom)
    }

    /// Messages filtered by debug mode visibility.
    private var visibleMessages: [ChatMessage] {
        state.messages.filter { message in
            switch message.role {
            case .thinking, .system, .toolOutput:
                state.debugMode
            case .user, .agent, .toolCall:
                true
            }
        }
    }

    /// Show typing indicator when streaming and the last message is not
    /// yet an agent message (i.e., no text has arrived yet).
    private var shouldShowTypingIndicator: Bool {
        guard let last = state.messages.last else { return true }
        return last.role != .agent
    }
}
