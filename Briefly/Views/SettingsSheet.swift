import SwiftUI

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = APIKeyStore.shared.apiKey ?? ""
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Enter your key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Save Key") {
                        APIKeyStore.shared.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        statusMessage = "Saved to Keychain."
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear Key", role: .destructive) {
                        apiKey = ""
                        APIKeyStore.shared.apiKey = nil
                        statusMessage = "Key removed."
                    }
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    if let statusMessage {
                        Text(statusMessage)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Stored securely in the iOS Keychain.")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}
