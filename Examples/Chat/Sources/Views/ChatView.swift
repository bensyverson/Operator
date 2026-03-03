import TextUI

/// The top-level chat view with the conversation interface as the base
/// and the provider picker shown as a modal overlay.
struct ChatView: View {
    @EnvironmentObject var state: ChatState

    var body: some View {
        VStack {
            if state.debugMode {
                DebugBannerView()
            }
            MessageListView()
            Divider.horizontal
            InputBarView()
        }
        .modal(
            isPresented: state.showProviderPicker,
            onDismiss: dismissAction
        ) {
            ProviderPickerView()
        }
    }

    private var dismissAction: (@Sendable () -> Void)? {
        guard state.providerConfirmed else { return nil }
        return { [state] in state.showProviderPicker = false }
    }
}
