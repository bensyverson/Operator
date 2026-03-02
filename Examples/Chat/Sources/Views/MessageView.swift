import TextUI

/// Renders a single ``ChatMessage`` with the appropriate visual treatment
/// based on its role.
struct MessageView: View {
    let message: ChatMessage

    // swiftformat:disable:next redundantViewBuilder
    @ViewBuilder var body: some View {
        switch message.role {
        case .user, .agent:
            MessageBubbleView(message: message)
        case .thinking:
            HStack {
                Text(message.text).dim().italic()
                Spacer()
            }
        case .toolCall, .toolOutput:
            ToolCallView(message: message)
        case .system:
            HStack {
                Text(message.text).dim()
                Spacer()
            }
        }
    }
}
