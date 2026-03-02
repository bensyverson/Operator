import TextUI

/// A single chat message bubble with alignment and color based on role.
///
/// - User messages: right-aligned with cyan border
/// - Agent messages: left-aligned with default border
struct MessageBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer() }
            Text(message.text)
                .padding(horizontal: 1)
                .border(.rounded)
                .foregroundColor(isUser ? .cyan : .white)
            if !isUser { Spacer() }
        }
    }
}
