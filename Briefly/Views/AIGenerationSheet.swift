import SwiftUI
import os

struct AIGenerationSheet: View {
    private static let logger = Logger(subsystem: "dn.Briefly", category: "AIGenerationSheet")

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
                    Section("Progress") {
                        VStack(alignment: .leading, spacing: 10) {
                            ProgressView(value: progressFraction)
                                .tint(BrieflyTheme.Colors.accent)
                            HStack {
                                Text(progressText ?? "Generating…")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(BrieflyTheme.Colors.textPrimary)
                                Spacer()
                                Text("\(Int((progressFraction * 100).rounded()))%")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            Text("Keep this sheet open while we build your topic.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button(role: .destructive) {
                                cancelGeneration()
                            } label: {
                                Text("Cancel Generation")
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                Text("Generating…")
                                    .font(.headline)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Topic")
                                    .font(.headline)
                            }
                        }
                    }
                    .buttonStyle(BrieflyPrimaryButtonStyle())
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }

                Section("Topic") {
                    TextField("Title or concept", text: $title)
                        .disabled(isGenerating)
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .disabled(isGenerating)
                }

                Section("Size") {
                    Stepper(value: $targetSections, in: 1...50) {
                        Text("Sections: \(targetSections)")
                    }
                    .disabled(isGenerating)
                    Stepper(value: $targetCardsPerSection, in: 1...50) {
                        Text("Cards per section: \(targetCardsPerSection)")
                    }
                    .disabled(isGenerating)
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
                                Self.logger.debug(
                                    "Fresh Topics persistence start: sections=\(editedDTO.sections.count, privacy: .public) cards=\(editedDTO.sections.reduce(0) { $0 + $1.cards.count }, privacy: .public)"
                                )
                                if let model = try await ContentRepository.shared.appendOrReplaceUserPack(editedDTO) {
                                    Self.logger.debug("Fresh Topics persistence success")
                                    onSave(model)
                                    isPresented = false
                                    return true
                                } else {
                                    Self.logger.error("Fresh Topics persistence failed: classification=persistence_failure reason=append returned nil model")
                                    errorMessage = "Edited content could not be parsed."
                                    return false
                                }
                            } catch {
                                Self.logger.error(
                                    "Fresh Topics persistence failed: classification=\(errorClassification(for: error), privacy: .public) reason=\(error.localizedDescription, privacy: .public)"
                                )
                                errorMessage = error.localizedDescription
                                return false
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
        Self.logger.debug(
            "Fresh Topics generation start: title=\(trimmedTitle, privacy: .public) targetSections=\(targetSections, privacy: .public) cardsPerSection=\(targetCardsPerSection, privacy: .public)"
        )

        isGenerating = true
        errorMessage = nil
        progressFraction = 0
        progressText = "Starting…"
        cancelGeneration(resetUI: false)
        let service = AIContentService(transport: BrieflyBackendClient())

        generationTask = Task {
            do {
                let batchSize = max(1, min(targetSections, 5))
                let perRequestSections = AIContentService.RequestSizing.sectionsPerRequest(for: batchSize)
                let perRequestCards = AIContentService.RequestSizing.cardsPerSection(for: targetCardsPerSection)
                if perRequestCards != targetCardsPerSection || perRequestSections != batchSize {
                    Self.logger.debug(
                        "Fresh Topics workload tuned for latency: requestedSectionsPerBatch=\(batchSize, privacy: .public) effectiveSectionsPerBatch=\(perRequestSections, privacy: .public) requestedCardsPerSection=\(targetCardsPerSection, privacy: .public) effectiveCardsPerSection=\(perRequestCards, privacy: .public)"
                    )
                }
                let totalBatches = max(1, Int(ceil(Double(targetSections) / Double(perRequestSections))))

                var aggregatedSections: [TopicSectionDTO] = []
                var baseDTO: TopicPackDTO?
                var sectionCounter = 0

                for batch in 0..<totalBatches {
                    try Task.checkCancellation()
                    let remaining = targetSections - aggregatedSections.count
                    let requestSections = max(1, min(perRequestSections, remaining))
                    Self.logger.debug(
                        "Fresh Topics batch \(batch + 1, privacy: .public)/\(totalBatches, privacy: .public) start: requestSections=\(requestSections, privacy: .public) requestCardsPerSection=\(perRequestCards, privacy: .public) currentAggregatedSections=\(aggregatedSections.count, privacy: .public)"
                    )

                    let dto: TopicPackDTO
                    do {
                        dto = try await service.generateTopicPack(
                            title: trimmedTitle,
                            difficulty: difficulty,
                            language: language,
                            targetSections: requestSections,
                            targetCardsPerSection: perRequestCards
                        )
                    } catch {
                        Self.logger.error(
                            "Fresh Topics batch \(batch + 1, privacy: .public) failed: classification=\(errorClassification(for: error), privacy: .public) reason=\(error.localizedDescription, privacy: .public)"
                        )
                        throw error
                    }

                    if baseDTO == nil {
                        baseDTO = dto
                        Self.logger.debug(
                            "Fresh Topics base DTO selected: id=\(dto.id, privacy: .public) title=\(dto.title, privacy: .public) category=\(dto.category, privacy: .public) difficulty=\(dto.difficulty, privacy: .public)"
                        )
                    }
                    let baseID = baseDTO?.id ?? dto.id
                    let assembly = FreshTopicsAssembly.appendSections(
                        from: dto,
                        baseID: baseID,
                        into: &aggregatedSections,
                        targetSections: targetSections,
                        sectionCounter: &sectionCounter
                    )
                    let returnedCardCount = dto.sections.reduce(0) { $0 + $1.cards.count }
                    Self.logger.debug(
                        "Fresh Topics batch \(batch + 1, privacy: .public) complete: returnedSections=\(dto.sections.count, privacy: .public) returnedCards=\(returnedCardCount, privacy: .public) addedSections=\(assembly.addedSections, privacy: .public) addedCards=\(assembly.addedCards, privacy: .public) droppedEmptySections=\(assembly.droppedEmptySections, privacy: .public) aggregatedSections=\(aggregatedSections.count, privacy: .public)"
                    )

                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        progressFraction = Double(batch + 1) / Double(totalBatches)
                        progressText = "Generating batch \(batch + 1) of \(totalBatches)…"
                    }
                }

                guard let base = baseDTO else {
                    throw AIContentService.ServiceError.validationFailed(details: "missing base DTO from generation")
                }

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
                let finalCardCount = finalDTO.sections.reduce(0) { $0 + $1.cards.count }
                Self.logger.debug(
                    "Fresh Topics final assembly: sections=\(finalDTO.sections.count, privacy: .public) cards=\(finalCardCount, privacy: .public)"
                )

                Self.logger.debug("Fresh Topics final validation start")
                guard finalDTO.isValid() else {
                    let reason = FreshTopicsAssembly.validationFailureReason(for: finalDTO)
                    Self.logger.error("Fresh Topics final DTO invalid: \(reason, privacy: .public)")
                    await MainActor.run {
                        isGenerating = false
                        progressText = nil
                        errorMessage = "Generated content was incomplete. Try again."
                    }
                    return
                }
                Self.logger.debug("Fresh Topics final validation success")

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
                Self.logger.debug("Fresh Topics generation cancelled")
                await MainActor.run {
                    isGenerating = false
                    progressText = nil
                    generationTask = nil
                }
            } catch {
                let userMessage = friendlyError(for: error)
                Self.logger.error(
                    "Fresh Topics surfaced error: classification=\(errorClassification(for: error), privacy: .public) message=\(userMessage, privacy: .public) reason=\(error.localizedDescription, privacy: .public)"
                )
                await MainActor.run {
                    isGenerating = false
                    progressText = nil
                    errorMessage = userMessage
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
        if let clientError = error as? BrieflyBackendClient.ClientError {
            return clientError.localizedDescription
        }
        if let serviceError = error as? AIContentService.ServiceError {
            return serviceError.localizedDescription
        }
        return "Error: \(error.localizedDescription)"
    }

    private func errorClassification(for error: Error) -> String {
        if let serviceError = error as? AIContentService.ServiceError {
            switch serviceError {
            case .emptyResponse:
                return "empty_response"
            case .invalidJSON:
                return "decode_invalid_json"
            case .dtoDecodingFailed:
                return "decode_dto_failed"
            case .validationFailed:
                return "validation_failed"
            case .jobTransportUnavailable:
                return "job_transport_unavailable"
            }
        }
        if let clientError = error as? BrieflyBackendClient.ClientError {
            switch clientError {
            case .badResponse:
                return "backend_http_failure"
            case .invalidResponse:
                return "backend_invalid_envelope"
            case .requestTimedOut:
                return "backend_timeout"
            case .transport:
                return "backend_transport_failure"
            case .jobNotFound:
                return "job_not_found"
            case .jobNotReady:
                return "job_not_ready"
            case .jobFailed:
                return "job_failed"
            }
        }
        if error is ContentRepository.RepositoryError {
            return "persistence_failure"
        }
        return "unknown"
    }
}

enum FreshTopicsAssembly {
    struct AppendResult {
        let addedSections: Int
        let addedCards: Int
        let droppedEmptySections: Int
    }

    static func appendSections(
        from dto: TopicPackDTO,
        baseID: String,
        into aggregatedSections: inout [TopicSectionDTO],
        targetSections: Int,
        sectionCounter: inout Int
    ) -> AppendResult {
        var addedSections = 0
        var addedCards = 0
        var droppedEmptySections = 0

        for section in dto.sections {
            if aggregatedSections.count >= targetSections { break }
            guard !section.cards.isEmpty else {
                droppedEmptySections += 1
                continue
            }

            let normalizedID = "\(baseID)_section_\(sectionCounter)"
            sectionCounter += 1

            let normalizedCards = section.cards.enumerated().map { index, card in
                let cardID = "\(normalizedID)_card_\(index)"
                return CardDTO(
                    id: cardID,
                    front: card.front,
                    back: card.back,
                    source: card.source,
                    tags: card.tags
                )
            }

            let normalizedSection = TopicSectionDTO(
                id: normalizedID,
                title: section.title,
                cards: normalizedCards
            )
            aggregatedSections.append(normalizedSection)
            addedSections += 1
            addedCards += normalizedCards.count
        }

        return AppendResult(
            addedSections: addedSections,
            addedCards: addedCards,
            droppedEmptySections: droppedEmptySections
        )
    }

    static func validationFailureReason(for dto: TopicPackDTO) -> String {
        var reasons: [String] = []
        if dto.id.isEmpty { reasons.append("missing id") }
        if dto.title.isEmpty { reasons.append("missing title") }
        if dto.subtitle.isEmpty { reasons.append("missing subtitle") }
        if dto.category.isEmpty { reasons.append("missing category") }
        if dto.sections.isEmpty { reasons.append("no sections") }
        if !dto.sections.contains(where: { !$0.cards.isEmpty }) { reasons.append("no cards in any section") }
        return reasons.isEmpty ? "unknown validation failure" : reasons.joined(separator: ", ")
    }
}
