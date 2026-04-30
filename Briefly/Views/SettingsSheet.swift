import SwiftUI

struct SettingsSheet: View {
    @Binding var isPresented: Bool
    @State private var selectedModel = OpenAIModelCatalog.defaultModel

    private let modelStore = ModelPreferenceStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI Model") {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(OpenAIModelCatalog.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.inline)

                    Text("This selection is used for generation requests that support model overrides.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .onAppear {
                selectedModel = modelStore.preferredModel ?? OpenAIModelCatalog.defaultModel
            }
            .onChange(of: selectedModel) { _, newValue in
                modelStore.preferredModel = newValue
            }
        }
    }
}
