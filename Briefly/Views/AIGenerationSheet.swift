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

        let backendClient = BrieflyBackendClient()
        let service = AIContentService(transport: backendClient, jobTransport: backendClient)

        generationTask = Task {
            do {
                let handle = try await service.startTopicPackGenerationJob(
                    title: trimmedTitle,
                    difficulty: difficulty,
                    language: language,
                    targetSections: targetSections,
                    targetCardsPerSection: targetCardsPerSection
                )

                Self.logger.debug(
                    "Fresh Topics job created: jobID=\(handle.id.rawValue, privacy: .public) title=\(trimmedTitle, privacy: .public)"
                )

                await MainActor.run {
                    progressFraction = 0.1
                    progressText = "Job started…"
                }

                while true {
                    try Task.checkCancellation()

                    let status = try await service.fetchTopicPackGenerationJobStatus(jobID: handle.id)

                    switch status.state {
                    case .queued:
                        Self.logger.debug("Fresh Topics job queued: jobID=\(handle.id.rawValue, privacy: .public)")
                        await MainActor.run {
                            progressFraction = max(progressFraction, 0.15)
                            progressText = "Queued…"
                        }

                    case .running:
                        Self.logger.debug("Fresh Topics job running: jobID=\(handle.id.rawValue, privacy: .public)")
                        await MainActor.run {
                            progressFraction = min(max(progressFraction, 0.2) + 0.1, 0.9)
                            progressText = "Generating…"
                        }

                    case .completed:
                        Self.logger.debug("Fresh Topics job completed: jobID=\(handle.id.rawValue, privacy: .public)")
                        await MainActor.run {
                            progressFraction = 0.95
                            progressText = "Finalizing…"
                        }

                        let dto = try await service.fetchTopicPackGenerationJobResult(handle: handle)

                        await MainActor.run {
                            pendingDTO = dto
                            isGenerating = false
                            progressFraction = 1.0
                            progressText = nil
                            showingReview = true
                            generationTask = nil
                        }
                        return

                    case .failed(let reason):
                        Self.logger.error(
                            "Fresh Topics job failed: jobID=\(handle.id.rawValue, privacy: .public) reason=\(reason, privacy: .public)"
                        )
                        throw BrieflyBackendClient.ClientError.jobFailed(reason: reason)
                    }

                    try await Task.sleep(nanoseconds: 1_000_000_000)
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
