import SwiftUI

struct AIGenerationSheet: View {
    @Binding var isPresented: Bool
    var onSave: (TopicPack) -> Void

    @State private var title: String = ""
    @State private var difficulty: Difficulty = .beginner
    @State private var estimatedMinutes: Int = 20
    @State private var language: String = "en"
    @State private var apiKey: String = APIKeyStore.shared.apiKey ?? ""
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    TextField("Title or concept", text: $title)
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    Stepper(value: $estimatedMinutes, in: 5...90, step: 5) {
                        Text("Estimated minutes: \(estimatedMinutes)")
                    }
                    TextField("Language (e.g., en, es)", text: $language)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("OpenAI") {
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Label("Generate with AI", systemImage: "sparkles")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.isEmpty || isGenerating)
                } footer: {
                    Text("Content will be drafted with OpenAI and saved locally after generation.")
                }
            }
            .navigationTitle("New AI Topic")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                        .disabled(isGenerating)
                }
            }
            .alert(
                "Generation failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { _ in errorMessage = nil }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func generate() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !apiKey.isEmpty else { return }

        isGenerating = true
        errorMessage = nil
        APIKeyStore.shared.apiKey = apiKey

        let configuration = OpenAIClient.Configuration(apiKeyProvider: { APIKeyStore.shared.apiKey })
        let client = OpenAIClient(configuration: configuration)
        let service = AIContentService(client: client)

        Task {
            do {
                let dto = try await service.generateTopicPack(
                    title: trimmedTitle,
                    difficulty: difficulty,
                    language: language,
                    estimatedMinutes: estimatedMinutes
                )
                if let model = ContentRepository.shared.appendUserPack(dto) {
                    await MainActor.run {
                        onSave(model)
                        isGenerating = false
                        isPresented = false
                    }
                } else {
                    await MainActor.run {
                        isGenerating = false
                        errorMessage = "Generated content could not be parsed."
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
