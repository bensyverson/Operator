import TextUI

@main
struct ChatApp: App {
    let state: ChatState

    init() {
        let chatState = ChatState()
        let args = chatState.args

        // If --provider was passed and valid, skip the picker screen
        if let resolved = args.resolvedProvider {
            chatState.selectedProviderIndex = ProviderOption.allCases.firstIndex(of: resolved) ?? 0
            if resolved.hasAPIKey() {
                do {
                    try chatState.buildOperative()
                    chatState.providerConfirmed = true
                    chatState.showProviderPicker = false
                } catch {
                    chatState.providerWarning = "Error: \(error)"
                }
            }
        }

        state = chatState
    }

    var body: some View {
        VStack {
            CommandBar().foregroundColor(.blue)
            ChatView()
        }
        .environmentObject(state)
    }

    var commands: [CommandGroup] {
        let chatState = state
        return [
            CommandGroup("App") {
                Button("Quit") { Application.quit() }
                    .keyboardShortcut("q", modifiers: .control)
                Button("Debug") {
                    chatState.debugMode.toggle()
                }
                .keyboardShortcut("d", modifiers: .control)
                Button("Switch Provider") {
                    chatState.showProviderPicker = true
                }
            },
        ]
    }
}
