import SwiftUI

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = APIKeyStore.shared.apiKey ?? ""
    @State private var statusMessage: String?
    @State private var selectedModel: String = ModelPreferenceStore.shared.preferredModel ?? "gpt-4.1-mini"

    private let modelOptions: [(id: String, note: String)] = [
        ("gpt-4.1-mini", "Fastest/cheapest, good for most decks"),
        ("gpt-4o-mini", "Fast, multimodal-lite"),
        ("gpt-4.1", "Better quality, slower"),
        ("gpt-4o", "Higher quality, slower"),
        ("gpt-5.1", "Best quality, most expensive")
    ]

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

                Section("Model") {
                    Picker("Preferred Model", selection: $selectedModel) {
                        ForEach(modelOptions, id: \.id) { model in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.id)
                                Text(model.note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(model.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: selectedModel) { newValue in
                        ModelPreferenceStore.shared.preferredModel = newValue
                        statusMessage = "Model set to \(newValue)."
                    }
                    if let note = selectedModelNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
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

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var selectedModelNote: String? {
        modelOptions.first(where: { $0.id == selectedModel })?.note
    }
}
