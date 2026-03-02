import TextUI

/// An animated typing indicator ("...", "....", ".....") shown while
/// the agent is streaming but before any text has arrived.
struct TypingIndicatorView: View {
    @AnimationTick var tick

    private var dots: String {
        String(repeating: ".", count: (tick / 10 % 3) + 1)
    }

    var body: some View {
        HStack {
            Text(dots).dim()
            Spacer()
        }
    }
}
