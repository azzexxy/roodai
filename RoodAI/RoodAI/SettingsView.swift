import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = KeychainStore.apiKey

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-...", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text("Stored in your device's Keychain and sent only to api.anthropic.com. Create a key at console.anthropic.com.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        KeychainStore.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
            }
        }
    }
}
