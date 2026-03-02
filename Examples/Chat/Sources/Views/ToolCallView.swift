import TextUI

/// Displays a tool call name with arguments, and optionally the tool's output.
/// Rendered centered to visually distinguish from user/agent messages.
struct ToolCallView: View {
    @EnvironmentObject var state: ChatState
    let message: ChatMessage

    var body: some View {
        HStack {
            Spacer()
            if message.role == .toolCall {
                VStack(alignment: .center) {
                    Text(toolCallLabel).dim()
                    if state.debugMode,
                       let args = message.toolArguments
                    {
                        Text(args).dim().italic()
                    }
                }
            } else {
                // .toolOutput
                VStack(alignment: .center) {
                    if let name = message.toolName {
                        Text("\(name) ->").dim()
                    }
                    Text(message.text).dim().italic()
                }
            }
            Spacer()
        }
    }

    private var toolCallLabel: String {
        if let name = message.toolName {
            return "[\(name)]"
        }
        return "[tool]"
    }
}
