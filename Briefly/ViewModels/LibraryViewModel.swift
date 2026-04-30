import Foundation
import Combine
import os

@MainActor
final class LibraryViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "dn.Briefly", category: "LibraryViewModel")

    struct TopicGroup: Identifiable {
        let title: String
        let topics: [TopicPack]

        var id: String { title }
    }

    private struct DerivedState {
        var availableCategories: [String] = []
        var filteredTopics: [TopicPack] = []
        var activeTopics: [TopicPack] = []
        var completedTopics: [TopicPack] = []
        var continueLearningTopics: [TopicPack] = []
        var featuredTopic: TopicPack?
        var exploreTopicGroups: [TopicGroup] = []
        var inProgressTopicCount: Int = 0
        var progressByTopicID: [String: Double] = [:]
    }

    @Published private(set) var topics: [TopicPack] = [] {
        didSet {
            recomputeProgressCache()
            recomputeDerivedState()
        }
    }
    @Published var searchText: String = "" {
        didSet { recomputeDerivedState() }
    }
    @Published var selectedCategory: String? {
        didSet { recomputeDerivedState() }
    }
    @Published var selectedDifficulty: Difficulty? {
        didSet { recomputeDerivedState() }
    }
    @Published private var derivedState = DerivedState()
    @Published private(set) var hasCompletedInitialLoad: Bool = false

    private let contentRepository: ContentRepository
    private let progressStore: ProgressStore
    private let statusStore: TopicStatusStore
    private let recentTopicsStore: RecentTopicsStore
    private var cancellables = Set<AnyCancellable>()
    private var cachedProgressByTopicID: [String: Double] = [:]

    init(
        contentRepository: ContentRepository,
        progressStore: ProgressStore,
        statusStore: TopicStatusStore? = nil,
        recentTopicsStore: RecentTopicsStore? = nil
    ) {
        self.contentRepository = contentRepository
        self.progressStore = progressStore
        self.statusStore = statusStore ?? .shared
        self.recentTopicsStore = recentTopicsStore ?? .shared
        self.topics = contentRepository.topics
        self.hasCompletedInitialLoad = contentRepository.hasCompletedInitialLoad

        contentRepository.$topics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updated in
                self?.topics = updated
            }
            .store(in: &cancellables)

        contentRepository.$hasCompletedInitialLoad
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasCompleted in
                self?.hasCompletedInitialLoad = hasCompleted
            }
            .store(in: &cancellables)

        self.statusStore.$completedIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recomputeDerivedState()
            }
            .store(in: &cancellables)

        self.progressStore.$learnedCardIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recomputeProgressCache()
                self?.recomputeDerivedState()
            }
            .store(in: &cancellables)

        self.progressStore.$completedSectionIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recomputeProgressCache()
                self?.recomputeDerivedState()
            }
            .store(in: &cancellables)

        self.recentTopicsStore.$topicIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recomputeDerivedState()
            }
            .store(in: &cancellables)

        recomputeProgressCache()
        recomputeDerivedState()
    }

    func progress(for topic: TopicPack) -> Double {
        cachedProgressByTopicID[topic.id] ?? progressStore.progress(for: topic)
    }

    func refresh() {
        topics = contentRepository.topics
    }

    var availableCategories: [String] { derivedState.availableCategories }
    var filteredTopics: [TopicPack] { derivedState.filteredTopics }
    var activeTopics: [TopicPack] { derivedState.activeTopics }
    var completedTopics: [TopicPack] { derivedState.completedTopics }
    var continueLearningTopics: [TopicPack] { derivedState.continueLearningTopics }
    var featuredTopic: TopicPack? { derivedState.featuredTopic }
    var exploreTopicGroups: [TopicGroup] { derivedState.exploreTopicGroups }
    var inProgressTopicCount: Int { derivedState.inProgressTopicCount }

    func featuredProgress() -> Double {
        guard let featuredTopic else { return 0 }
        return progress(for: featuredTopic)
    }

    func recordTopicOpened(_ topic: TopicPack) {
        recentTopicsStore.recordOpened(topicID: topic.id)
    }

    func delete(_ topic: TopicPack) async throws {
        try await contentRepository.deleteTopic(topic)
    }

    func toggleCompleted(_ topic: TopicPack) {
        contentRepository.toggleCompleted(topic)
    }

    func isCompleted(_ topic: TopicPack) -> Bool {
        contentRepository.isCompleted(topic)
    }

    func moveActiveTopics(from source: IndexSet, to destination: Int) {
        contentRepository.reorderActiveTopics(from: source, to: destination)
    }

    func generateRandomTopic(
        targetSections: Int = 5,
        cardsPerSection: Int = 10
    ) async throws -> TopicPack? {
        let existingTitles = Set(topics.map { $0.title.lowercased() })
        let existingIDs = Set(topics.map { $0.id.lowercased() })

        let subjects = [
            "ethical AI dilemmas",
            "urban farming hacks",
            "ancient architecture highlights",
            "creative writing prompts",
            "climate resilience basics",
            "neuroscience curiosities",
            "space exploration milestones",
            "everyday mental models",
            "productivity with focus",
            "entrepreneurship pitfalls",
            "marine biology curiosities",
            "mythology snapshots",
            "data privacy essentials",
            "behavioral economics",
            "cognitive biases",
            "public speaking essentials",
            "career pivots",
            "philosophy sparks",
            "design thinking"
        ]

        let subject: String = {
            let unseenSubjects = subjects.filter { !existingTitles.contains($0.lowercased()) }
            if let candidate = unseenSubjects.randomElement() {
                return candidate
            }
            return Self.synthesizedSubject(existingTitles: existingTitles)
        }()

        let requestedTitle = subject.capitalized
        let difficulty = Difficulty.allCases.randomElement() ?? .beginner

        let backendClient = BrieflyBackendClient()
        let service = AIContentService(transport: backendClient, jobTransport: backendClient)

        Self.logger.debug(
            "Surprise Me start: requestedTitle=\(requestedTitle, privacy: .public) targetSections=\(targetSections, privacy: .public) cardsPerSection=\(cardsPerSection, privacy: .public)"
        )

        let handle: AIContentService.GenerationJobHandle
        do {
            handle = try await service.startTopicPackGenerationJob(
                title: requestedTitle,
                difficulty: difficulty,
                language: "en",
                targetSections: targetSections,
                targetCardsPerSection: cardsPerSection
            )
            Self.logger.debug(
                "Surprise Me job created: jobID=\(handle.id.rawValue, privacy: .public) title=\(requestedTitle, privacy: .public)"
            )
        } catch {
            logSurpriseMeError(error, stage: "job create")
            throw error
        }

        while true {
            let status: AIGenerationJobStatus
            do {
                status = try await service.fetchTopicPackGenerationJobStatus(jobID: handle.id)
            } catch {
                logSurpriseMeError(error, stage: "job status")
                throw error
            }

            switch status.state {
            case .queued:
                Self.logger.debug("Surprise Me job queued: jobID=\(handle.id.rawValue, privacy: .public)")

            case .running:
                Self.logger.debug("Surprise Me job running: jobID=\(handle.id.rawValue, privacy: .public)")

            case .completed:
                Self.logger.debug("Surprise Me job completed: jobID=\(handle.id.rawValue, privacy: .public)")

                let dto: TopicPackDTO
                do {
                    dto = try await service.fetchTopicPackGenerationJobResult(handle: handle)
                    let dtoCounts = SurpriseMeAssembly.dtoCounts(dto)
                    Self.logger.debug(
                        "Surprise Me job result fetched: sections=\(dtoCounts.sections, privacy: .public) cards=\(dtoCounts.cards, privacy: .public)"
                    )
                } catch {
                    logSurpriseMeError(error, stage: "job result")
                    throw error
                }

                let uniqueBase = makeUnique(dto: dto, existingIDs: existingIDs, existingTitles: existingTitles)
                let baseID = uniqueBase.id
                let sanitizedTitle = Self.sanitizedRandomTopicTitle(
                    generatedTitle: uniqueBase.title,
                    requestedTitle: requestedTitle
                )
                let baseTitle = Self.makeUniqueTitle(base: sanitizedTitle, existingTitles: existingTitles)

                let normalizedDTO = normalize(
                    dto: uniqueBase,
                    baseID: baseID,
                    baseTitle: baseTitle,
                    sectionStartIndex: 0
                )
                let normalizedCounts = SurpriseMeAssembly.dtoCounts(normalizedDTO)
                Self.logger.debug(
                    "Surprise Me normalized: id=\(normalizedDTO.id, privacy: .public) title=\(normalizedDTO.title, privacy: .public) sections=\(normalizedCounts.sections, privacy: .public) cards=\(normalizedCounts.cards, privacy: .public)"
                )

                Self.logger.debug("Surprise Me final validation start")
                guard normalizedDTO.isValid() else {
                    let reason = SurpriseMeAssembly.validationFailureReason(for: normalizedDTO)
                    Self.logger.error("Surprise Me final DTO invalid: \(reason, privacy: .public)")
                    throw AIContentService.ServiceError.validationFailed(details: reason)
                }
                Self.logger.debug("Surprise Me final validation success")

                Self.logger.debug("Surprise Me persistence start")
                do {
                    let persisted = try await contentRepository.appendOrReplaceUserPack(normalizedDTO)
                    Self.logger.debug("Surprise Me persistence success")
                    return persisted
                } catch {
                    Self.logger.error(
                        "Surprise Me persistence failed: classification=\(self.surpriseMeErrorClassification(for: error), privacy: .public) reason=\(error.localizedDescription, privacy: .public)"
                    )
                    throw error
                }

            case .failed(let reason):
                let error = BrieflyBackendClient.ClientError.jobFailed(reason: reason)
                logSurpriseMeError(error, stage: "job failed")
                throw error
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func recomputeDerivedState() {
        let categories = Array(Set(topics.map(\.category))).sorted()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = topics.filter { topic in
            if let category = selectedCategory, category != topic.category { return false }
            if let difficulty = selectedDifficulty, difficulty != topic.difficulty { return false }
            guard !query.isEmpty else { return true }
            return topic.title.lowercased().contains(query)
                || topic.subtitle.lowercased().contains(query)
                || topic.category.lowercased().contains(query)
        }

        var active: [TopicPack] = []
        var completed: [TopicPack] = []
        active.reserveCapacity(filtered.count)
        completed.reserveCapacity(filtered.count)
        for topic in filtered {
            if statusStore.isCompleted(topic.id) {
                completed.append(topic)
            } else {
                active.append(topic)
            }
        }

        let progressByTopicID = cachedProgressByTopicID

        let recentIDs = recentTopicsStore.topicIDs
        let recentLowercasedIDs = Set(recentIDs.map { $0.lowercased() })

        var continueLearning: [TopicPack] = []
        if !active.isEmpty {
            let visibleByID = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
            var seenIDs = Set<String>()

            for id in recentIDs {
                guard let topic = visibleByID[id],
                      shouldHighlightForResume(topic, progressByTopicID: progressByTopicID, recentLowercasedIDs: recentLowercasedIDs),
                      seenIDs.insert(topic.id).inserted
                else {
                    continue
                }
                continueLearning.append(topic)
            }

            for topic in active where shouldHighlightForResume(topic, progressByTopicID: progressByTopicID, recentLowercasedIDs: recentLowercasedIDs) {
                guard seenIDs.insert(topic.id).inserted else { continue }
                continueLearning.append(topic)
            }

            continueLearning = continueLearning.isEmpty
                ? Array(active.prefix(5))
                : Array(continueLearning.prefix(8))
        }

        let exploreGroups = Dictionary(grouping: active, by: \.category)
            .map { TopicGroup(title: $0.key, topics: $0.value) }
            .sorted { lhs, rhs in
                if lhs.topics.count == rhs.topics.count {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.topics.count > rhs.topics.count
            }

        let inProgressCount = active.reduce(into: 0) { count, topic in
            if (progressByTopicID[topic.id] ?? 0) > 0 {
                count += 1
            }
        }

        derivedState = DerivedState(
            availableCategories: categories,
            filteredTopics: filtered,
            activeTopics: active,
            completedTopics: completed,
            continueLearningTopics: continueLearning,
            featuredTopic: continueLearning.first ?? active.first ?? completed.first,
            exploreTopicGroups: exploreGroups,
            inProgressTopicCount: inProgressCount,
            progressByTopicID: progressByTopicID
        )
    }

    private func recomputeProgressCache() {
        var progressByTopicID: [String: Double] = [:]
        progressByTopicID.reserveCapacity(topics.count)
        for topic in topics {
            progressByTopicID[topic.id] = progressStore.progress(for: topic)
        }
        cachedProgressByTopicID = progressByTopicID
    }

    private func shouldHighlightForResume(
        _ topic: TopicPack,
        progressByTopicID: [String: Double],
        recentLowercasedIDs: Set<String>
    ) -> Bool {
        (progressByTopicID[topic.id] ?? 0) > 0
            || recentLowercasedIDs.contains(topic.id.lowercased())
    }

    private func makeUnique(dto: TopicPackDTO, existingIDs: Set<String>, existingTitles: Set<String>) -> TopicPackDTO {
        let baseID = dto.id.isEmpty ? UUID().uuidString : dto.id
        var newID = baseID
        var counter = 1
        while existingIDs.contains(newID.lowercased()) {
            newID = "\(baseID)_\(counter)"
            counter += 1
        }

        var newTitle = dto.title
        counter = 1
        while existingTitles.contains(newTitle.lowercased()) {
            newTitle = "\(dto.title) (\(counter))"
            counter += 1
        }

        return TopicPackDTO(
            id: newID,
            title: newTitle,
            subtitle: dto.subtitle,
            category: dto.category,
            difficulty: dto.difficulty,
            language: dto.language,
            description: dto.description,
            author: dto.author,
            version: dto.version,
            sections: dto.sections
        )
    }

    private func normalize(
        dto: TopicPackDTO,
        baseID: String,
        baseTitle: String,
        sectionStartIndex: Int
    ) -> TopicPackDTO {
        let normalized = SurpriseMeAssembly.normalizedSections(
            from: dto.sections,
            baseID: baseID,
            sectionStartIndex: sectionStartIndex
        )
        if normalized.droppedEmptySections > 0 {
            Self.logger.debug("Surprise Me normalize dropped empty sections: \(normalized.droppedEmptySections, privacy: .public)")
        }

        return TopicPackDTO(
            id: baseID,
            title: baseTitle,
            subtitle: dto.subtitle,
            category: dto.category,
            difficulty: dto.difficulty,
            language: dto.language,
            description: dto.description,
            author: dto.author,
            version: dto.version,
            sections: normalized.sections
        )
    }

    private func logSurpriseMeError(_ error: Error, stage: String) {
        Self.logger.error(
            "Surprise Me stage failed: stage=\(stage, privacy: .public) classification=\(self.surpriseMeErrorClassification(for: error), privacy: .public)"
        )
        switch error {
        case let serviceError as AIContentService.ServiceError:
            switch serviceError {
            case .emptyResponse:
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: empty response")
            case .invalidJSON(let details):
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: invalid JSON - \(details, privacy: .public)")
            case .dtoDecodingFailed(let details):
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: decode error - \(details, privacy: .public)")
            case .validationFailed(let details):
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: validation error - \(details, privacy: .public)")
            case .jobTransportUnavailable:
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: job transport unavailable")
            }
        case let clientError as BrieflyBackendClient.ClientError:
            switch clientError {
            case .badResponse(let status, _):
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: backend status \(status, privacy: .public)")
            case .invalidResponse:
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: invalid backend envelope")
            case .requestTimedOut:
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: request timed out")
            case .transport(let transportError):
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: transport error \(transportError.localizedDescription, privacy: .public)")
            case .jobNotFound(let id):
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: job not found id=\(id, privacy: .public)")
            case .jobNotReady:
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: job not ready")
            case .jobFailed(let reason):
                Self.logger.error("Surprise Me \(stage, privacy: .public) failed: job failed - \(reason, privacy: .public)")
            }
        default:
            Self.logger.error("Surprise Me \(stage, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func surpriseMeErrorClassification(for error: Error) -> String {
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

    static func sanitizedRandomTopicTitle(generatedTitle: String, requestedTitle: String) -> String {
        let trimmedGenerated = generatedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGenerated.isEmpty else { return requestedTitle }
        return isGenericSurpriseTitle(trimmedGenerated) ? requestedTitle : trimmedGenerated
    }

    private static func makeUniqueTitle(base: String, existingTitles: Set<String>) -> String {
        var uniqueTitle = base
        var counter = 1
        while existingTitles.contains(uniqueTitle.lowercased()) {
            uniqueTitle = "\(base) (\(counter))"
            counter += 1
        }
        return uniqueTitle
    }

    private static func isGenericSurpriseTitle(_ title: String) -> Bool {
        let normalized = title
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "surprise",
            "suprise",
            "surprise me",
            "surprise topic",
            "suprise topic",
            "random topic"
        ].contains(normalized)
    }

    private static func synthesizedSubject(existingTitles: Set<String>) -> String {
        let adjectives = ["practical", "modern", "curious", "strategic", "creative", "human centered"]
        let domains = ["decision making", "systems thinking", "digital wellness", "communication patterns", "learning science", "problem framing"]

        for _ in 0..<24 {
            guard let adjective = adjectives.randomElement(), let domain = domains.randomElement() else { break }
            let candidate = "\(adjective) \(domain)"
            if !existingTitles.contains(candidate.lowercased()) {
                return candidate
            }
        }

        let suffix = UUID().uuidString.prefix(6).lowercased()
        return "practical systems thinking \(suffix)"
    }
}

enum SurpriseMeAssembly {
    struct NormalizedSectionsResult {
        let sections: [TopicSectionDTO]
        let droppedEmptySections: Int
    }

    static func normalizedSections(
        from sections: [TopicSectionDTO],
        baseID: String,
        sectionStartIndex: Int
    ) -> NormalizedSectionsResult {
        var sectionCounter = sectionStartIndex
        var droppedEmptySections = 0

        let normalizedSections: [TopicSectionDTO] = sections.compactMap { section in
            guard !section.cards.isEmpty else {
                droppedEmptySections += 1
                return nil
            }
            let sectionID = "\(baseID)_section_\(sectionCounter)"
            defer { sectionCounter += 1 }
            var cardCounter = 0
            let cards = section.cards.map { card in
                let cardID = "\(sectionID)_card_\(cardCounter)"
                cardCounter += 1
                return CardDTO(
                    id: cardID,
                    front: card.front,
                    back: card.back,
                    source: card.source,
                    tags: card.tags
                )
            }
            return TopicSectionDTO(id: sectionID, title: section.title, cards: cards)
        }

        return NormalizedSectionsResult(
            sections: normalizedSections,
            droppedEmptySections: droppedEmptySections
        )
    }

    static func dtoCounts(_ dto: TopicPackDTO) -> (sections: Int, cards: Int) {
        (dto.sections.count, dto.sections.reduce(0) { $0 + $1.cards.count })
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

enum FreshTopicsAssembly {
    struct AppendSectionsResult {
        let addedSections: Int
        let addedCards: Int
        let droppedEmptySections: Int
    }

    static func appendSections(
        from dto: TopicPackDTO,
        baseID: String,
        into aggregated: inout [TopicSectionDTO],
        targetSections: Int,
        sectionCounter: inout Int
    ) -> AppendSectionsResult {
        var addedSections = 0
        var addedCards = 0
        var droppedEmptySections = 0

        for section in dto.sections {
            guard aggregated.count < targetSections else { break }
            guard !section.cards.isEmpty else {
                droppedEmptySections += 1
                continue
            }

            let sectionID = "\(baseID)_section_\(sectionCounter)"
            sectionCounter += 1
            var cardCounter = 0
            let cards = section.cards.map { card in
                let cardID = "\(sectionID)_card_\(cardCounter)"
                cardCounter += 1
                return CardDTO(
                    id: cardID,
                    front: card.front,
                    back: card.back,
                    source: card.source,
                    tags: card.tags
                )
            }
            aggregated.append(TopicSectionDTO(id: sectionID, title: section.title, cards: cards))
            addedSections += 1
            addedCards += cards.count
        }

        return AppendSectionsResult(
            addedSections: addedSections,
            addedCards: addedCards,
            droppedEmptySections: droppedEmptySections
        )
    }

    static func validationFailureReason(for dto: TopicPackDTO) -> String {
        SurpriseMeAssembly.validationFailureReason(for: dto)
    }
}
