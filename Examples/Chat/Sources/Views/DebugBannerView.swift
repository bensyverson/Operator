import TextUI

/// A dim banner at the top of the chat showing turn count, token usage,
/// and any pressure warnings. Only visible when debug mode is active.
struct DebugBannerView: View {
    @EnvironmentObject var state: ChatState

    private var bannerText: String {
        var parts = [String]()
        parts.append("Turn: \(state.currentTurn)")
        parts.append("Tokens: \(state.totalTokens)")
        if let warning = state.pressureWarning {
            parts.append("! \(warning)")
        }
        return parts.joined(separator: "  |  ")
    }

    var body: some View {
        HStack {
            Text(bannerText).dim().italic()
            Spacer()
        }
    }
}
