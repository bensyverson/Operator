import TextUI

/// The top-level chat view that switches between the provider picker
/// and the conversation interface.
struct ChatView: View {
    @EnvironmentObject var state: ChatState

    var body: some View {
        ZStack {
            if state.providerConfirmed {
                VStack {
                    if state.debugMode {
                        DebugBannerView()
                    }
                    MessageListView()
                    Divider.horizontal
                    InputBarView()
                }
            } else {
                ProviderPickerView()
            }
        }
    }
}
