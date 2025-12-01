import SwiftUI

struct AIGenerationSheet: View {
    @Binding var isPresented: Bool
    var onSave: (TopicPack) -> Void

    @State private var title: String = ""
    @State private var difficulty: Difficulty = .beginner
    @State private var estimatedMinutes: Int = 20
    @State private var language: String = "en"
    @State private var apiKey: String = APIKeyStore.shared.apiKey ?? ""
    @State private var targetSections: Int = 3
    @State private var targetCardsPerSection: Int = 5
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var pendingDTO: TopicPackDTO?
    @State private var showingReview = false

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

                Section("Size (for AI generation)") {
                    Stepper(value: $targetSections, in: 1...50) {
                        Text("Sections: \(targetSections)")
                    }
                    Stepper(value: $targetCardsPerSection, in: 1...50) {
                        Text("Cards per section: \(targetCardsPerSection)")
                    }
                    Text("For ~500 cards total, try 10 sections × 50 cards.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
        .sheet(isPresented: $showingReview) {
            if let dto = pendingDTO {
                NavigationStack {
                    GeneratedPackReviewView(
                        viewModel: GeneratedPackReviewViewModel(pack: dto),
                        onSave: { editedDTO in
                            if let model = ContentRepository.shared.appendOrReplaceUserPack(editedDTO) {
                                onSave(model)
                                isPresented = false
                            } else {
                                errorMessage = "Edited content could not be parsed."
                            }
                        },
                        originalDTO: dto
                    )
                }
            }
        }
    }

    private func generate() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !apiKey.isEmpty else { return }

        isGenerating = true
        errorMessage = nil
        APIKeyStore.shared.apiKey = apiKey

        let preferredModel = ModelPreferenceStore.shared.preferredModel ?? "gpt-4.1-mini"
        let configuration = OpenAIClient.Configuration(
            apiKeyProvider: { APIKeyStore.shared.apiKey },
            model: preferredModel
        )
        let client = OpenAIClient(configuration: configuration)
        let service = AIContentService(client: client)

        Task {
            do {
                let dto = try await service.generateTopicPack(
                    title: trimmedTitle,
                    difficulty: difficulty,
                    language: language,
                    estimatedMinutes: estimatedMinutes,
                    targetSections: targetSections,
                    targetCardsPerSection: targetCardsPerSection
                )
                guard dto.isValid() else {
                    await MainActor.run {
                        isGenerating = false
                        errorMessage = "Generated content was incomplete. Try again."
                    }
                    return
                }
                await MainActor.run {
                    pendingDTO = dto
                    isGenerating = false
                    showingReview = true
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = friendlyError(for: error)
                }
            }
        }
    }

    private func friendlyError(for error: Error) -> String {
        if let clientError = error as? OpenAIClient.ClientError {
            return clientError.localizedDescription
        }
        if let serviceError = error as? AIContentService.ServiceError {
            switch serviceError {
            case .emptyResponse, .invalidResponse, .decodingFailed:
                return "AI response was invalid. Try again with a clearer title."
            }
        }
        return "Error: \(error.localizedDescription)"
    }
}
