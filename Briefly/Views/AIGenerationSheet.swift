import SwiftUI

struct AIGenerationSheet: View {
    @Binding var isPresented: Bool
    var onSave: (TopicPack) -> Void

    @State private var title: String = ""
    @State private var difficulty: Difficulty = .beginner
    @State private var language: String = "en"
    @State private var targetSections: Int = 5
    @State private var targetCardsPerSection: Int = 10
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var pendingDTO: TopicPackDTO?
    @State private var showingReview = false
    @State private var progressFraction: Double = 0
    @State private var progressText: String?
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                if isGenerating {
                    Section {
                        ProgressView(value: progressFraction)
                        if let progressText {
                            Text(progressText)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Topic") {
                    TextField("Title or concept", text: $title)
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    Button {
                        generate()
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Label("Generate", systemImage: "sparkles")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }

                Section("Size") {
                    Stepper(value: $targetSections, in: 1...50) {
                        Text("Sections: \(targetSections)")
                    }
                    Stepper(value: $targetCardsPerSection, in: 1...50) {
                        Text("Cards per section: \(targetCardsPerSection)")
                    }
                }
            }
            .navigationTitle("Fresh Topics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        cancelGeneration()
                        isPresented = false
                    }
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
            .onDisappear {
                cancelGeneration()
            }
        }
        .sheet(isPresented: $showingReview) {
            if let dto = pendingDTO {
                NavigationStack {
                    GeneratedPackReviewView(
                        viewModel: GeneratedPackReviewViewModel(pack: dto),
                        onSave: { editedDTO in
                            do {
                                if let model = try ContentRepository.shared.appendOrReplaceUserPack(editedDTO) {
                                    onSave(model)
                                    isPresented = false
                                } else {
                                    errorMessage = "Edited content could not be parsed."
                                }
                            } catch {
                                errorMessage = error.localizedDescription
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
        guard !trimmedTitle.isEmpty else { return }
        guard let apiKey = APIKeyStore.shared.apiKey, !apiKey.isEmpty else {
            errorMessage = "Please set your OpenAI API key in Settings."
            return
        }

        isGenerating = true
        errorMessage = nil
        progressFraction = 0
        progressText = "Starting…"
        APIKeyStore.shared.apiKey = apiKey
        cancelGeneration(resetUI: false)
        let preferredModel = ModelPreferenceStore.shared.preferredModel ?? "gpt-4.1-mini"
        let configuration = OpenAIClient.Configuration(
            apiKeyProvider: { apiKey },
            model: preferredModel
        )
        let client = OpenAIClient(configuration: configuration)
        let service = AIContentService(client: client)

        generationTask = Task {
            do {
                let batchSize = max(1, min(targetSections, 5))
                let totalBatches = max(1, Int(ceil(Double(targetSections) / Double(batchSize))))

                var aggregatedSections: [TopicSectionDTO] = []
                var baseDTO: TopicPackDTO?
                var sectionCounter = 0

                for batch in 0..<totalBatches {
                    try Task.checkCancellation()
                    let remaining = targetSections - aggregatedSections.count
                    let requestSections = max(1, min(batchSize, remaining))

                    let dto = try await service.generateTopicPack(
                        title: trimmedTitle,
                        difficulty: difficulty,
                        language: language,
                        targetSections: requestSections,
                        targetCardsPerSection: targetCardsPerSection
                    )

                    if baseDTO == nil {
                        baseDTO = dto
                    }
                    for section in dto.sections {
                        if aggregatedSections.count >= targetSections { break }
                        let normalizedID = "\(dto.id)_section_\(sectionCounter)"
                        sectionCounter += 1
                        let normalizedSection = TopicSectionDTO(
                            id: normalizedID,
                            title: section.title,
                            cards: section.cards.enumerated().map { index, card in
                                let cardID = "\(normalizedID)_card_\(index)"
                                return CardDTO(
                                    id: cardID,
                                    front: card.front,
                                    back: card.back,
                                    source: card.source,
                                    tags: card.tags
                                )
                            }
                        )
                        aggregatedSections.append(normalizedSection)
                    }

                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        progressFraction = Double(batch + 1) / Double(totalBatches)
                        progressText = "Generating batch \(batch + 1) of \(totalBatches)…"
                    }
                }

                guard let base = baseDTO else { throw AIContentService.ServiceError.invalidResponse }

                let finalDTO = TopicPackDTO(
                    id: base.id,
                    title: base.title,
                    subtitle: base.subtitle,
                    category: base.category,
                    difficulty: base.difficulty,
                    language: base.language,
                    description: base.description,
                    author: base.author,
                    version: base.version,
                    sections: aggregatedSections
                )

                guard finalDTO.isValid() else {
                    await MainActor.run {
                        isGenerating = false
                        progressText = nil
                        errorMessage = "Generated content was incomplete. Try again."
                    }
                    return
                }

                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    pendingDTO = finalDTO
                    isGenerating = false
                    progressText = nil
                    showingReview = true
                }
                await MainActor.run {
                    generationTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    isGenerating = false
                    progressText = nil
                    generationTask = nil
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    progressText = nil
                    errorMessage = friendlyError(for: error)
                    generationTask = nil
                }
            }
        }
    }

    private func cancelGeneration(resetUI: Bool = true) {
        generationTask?.cancel()
        generationTask = nil
        if resetUI {
            isGenerating = false
            progressText = nil
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
