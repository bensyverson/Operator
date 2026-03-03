import TextUI

/// The initial screen where the user selects an LLM provider.
///
/// Shows a picker with available providers, an API key warning if needed,
/// and a Start button that validates the configuration before proceeding.
///
/// The Picker self-registers with `.activate` interaction in the focus ring,
/// so we don't use `.focused()` here — it would double-register and break
/// default focus ordering. The first control rendered (Picker) gets focus
/// automatically on the first frame.
struct ProviderPickerView: View {
    @EnvironmentObject var state: ChatState

    var body: some View {
        VStack {
            Text("Chat").bold()
            Text("Select a provider to begin.").dim()
            Text(" ")
            Picker(
                "Provider",
                selection: state.selectedProviderIndex,
                options: ProviderOption.allCases.map(\.displayName)
            ) { [state] newIndex in
                state.selectedProviderIndex = newIndex
                let provider = ProviderOption.allCases[newIndex]
                if provider.requiresAPIKey, !provider.hasAPIKey() {
                    state.providerWarning = "Set \(provider.envKeyName!) to use \(provider.displayName)."
                } else {
                    state.providerWarning = nil
                }
            }
            if let warning = state.providerWarning {
                Text(warning).foregroundColor(.yellow)
            }
            Text(" ")
            Button("Start") { [state] in
                do {
                    try state.buildOperative()
                    state.providerConfirmed = true
                    state.showProviderPicker = false
                } catch {
                    state.providerWarning = "Error: \(error)"
                }
            }
            .disabled(!canStart)
        }
        .padding(horizontal: 2, vertical: 1)
        .border(.rounded)
        .frame(maxWidth: 50)
    }

    private var canStart: Bool {
        let provider = ProviderOption.allCases[state.selectedProviderIndex]
        return provider.hasAPIKey()
    }
}
