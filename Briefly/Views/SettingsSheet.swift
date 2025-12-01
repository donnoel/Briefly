import SwiftUI

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var statusMessage: String?
    @State private var selectedModel: String = ModelPreferenceStore.shared.preferredModel ?? "gpt-4.1-mini"
    @State private var showingKeyEntry = false
    @State private var pendingKey: String = ""

    private let modelOptions: [(id: String, note: String)] = [
        ("gpt-4.1-mini", "Fast & cheap"),
        ("gpt-4o-mini", "Fast, multimodal-lite"),
        ("gpt-4.1", "Better quality"),
        ("gpt-4o", "Higher quality"),
        ("gpt-5.1", "Best quality")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI API Key") {
                    HStack {
                        if let currentKey = APIKeyStore.shared.apiKey, !currentKey.isEmpty {
                            Label("Saved", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Not set", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Button("Add/Update") {
                            pendingKey = ""
                            showingKeyEntry = true
                        }
                        Button("Clear", role: .destructive) {
                            APIKeyStore.shared.apiKey = nil
                            statusMessage = "Key removed."
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Stored securely in Keychain.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Model") {
                    Picker("Preferred Model", selection: $selectedModel) {
                        ForEach(modelOptions, id: \.id) { model in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.id)
                                Text(model.note)
                                    .font(.caption2)
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
        .sheet(isPresented: $showingKeyEntry) {
            NavigationStack {
                Form {
                    Section("OpenAI API Key") {
                        SecureField("Enter or paste key", text: $pendingKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .navigationTitle("Set API Key")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingKeyEntry = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            APIKeyStore.shared.apiKey = pendingKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            statusMessage = "Saved to Keychain."
                            pendingKey = ""
                            showingKeyEntry = false
                        }
                        .disabled(pendingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
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
