import Foundation
import TextUI

/// The input bar at the bottom of the chat: a text field and send button.
///
/// The TextField stays focusable during streaming (only the Send button
/// is disabled) so the user doesn't lose focus. Enter submits via
/// `.onSubmit`, which requires the TextField to self-register with
/// `.edit` interaction — so we don't use `.focused()` here.
struct InputBarView: View {
    @EnvironmentObject var state: ChatState

    var body: some View {
        HStack {
            TextField("Message", text: state.inputText) { [state] newValue in
                state.inputText = newValue
            }
            .onSubmit { [state] in
                sendMessage(state)
            }
            .border()

            Text(" ")
            Button("Send") { [state] in
                sendMessage(state)
            }
            .disabled(state.isStreaming)
            .buttonStyle(.bordered)
        }
    }
}

@MainActor
private func sendMessage(_ state: ChatState) {
    guard !state.isStreaming else { return }
    let text = state.inputText
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    Task { @MainActor in
        await state.send(text)
    }
}
