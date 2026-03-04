import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var topics: [TopicPack] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: String?
    @Published var selectedDifficulty: Difficulty?

    private let contentRepository: ContentRepository
    private let progressStore: ProgressStore
    private let statusStore: TopicStatusStore
    private var cancellables = Set<AnyCancellable>()

    init(
        contentRepository: ContentRepository,
        progressStore: ProgressStore,
        statusStore: TopicStatusStore? = nil
    ) {
        self.contentRepository = contentRepository
        self.progressStore = progressStore
        self.statusStore = statusStore ?? .shared
        self.topics = contentRepository.topics

        contentRepository.$topics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updated in
                self?.topics = updated
            }
            .store(in: &cancellables)

        self.statusStore.$completedIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func progress(for topic: TopicPack) -> Double {
        progressStore.progress(for: topic)
    }

    func refresh() {
        topics = contentRepository.topics
    }

    var availableCategories: [String] {
        Array(Set(topics.map { $0.category })).sorted()
    }

    var filteredTopics: [TopicPack] {
        topics.filter { topic in
            if let category = selectedCategory, category != topic.category { return false }
            if let difficulty = selectedDifficulty, difficulty != topic.difficulty { return false }

            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            return topic.title.lowercased().contains(query)
                || topic.subtitle.lowercased().contains(query)
                || topic.category.lowercased().contains(query)
        }
    }

    var activeTopics: [TopicPack] {
        filteredTopics.filter { !isCompleted($0) }
    }

    var completedTopics: [TopicPack] {
        filteredTopics.filter { isCompleted($0) }
    }

    func delete(_ topic: TopicPack) throws {
        try contentRepository.deleteTopic(topic)
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
        guard let apiKey = APIKeyStore.shared.apiKey, !apiKey.isEmpty else {
            throw RandomTopicError.missingAPIKey
        }

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
        // Pick a subject the user doesn't already have. If all are taken, synthesize a new one.
        let subject: String = {
            let unseenSubjects = subjects.filter { !existingTitles.contains($0.lowercased()) }
            let candidate = unseenSubjects.randomElement() ?? "surprise topic"
            if existingTitles.contains(candidate.lowercased()) {
                return "surprise topic \(UUID().uuidString.prefix(6))"
            }
            return candidate
        }()

        let difficulty = Difficulty.allCases.randomElement() ?? .beginner

        let config = OpenAIClient.Configuration(
            apiKeyProvider: { apiKey },
            model: ModelPreferenceStore.shared.preferredModel ?? "gpt-4.1-mini"
        )
        let service = AIContentService(client: OpenAIClient(configuration: config))

        // Progressive strategy: request sections in two smaller batches concurrently, then merge.
        let firstTarget = min(targetSections, 3)
        let secondTarget = max(targetSections - firstTarget, 0)

        async let firstCall = service.generateTopicPack(
            title: subject.capitalized,
            difficulty: difficulty,
            language: "en",
            targetSections: firstTarget,
            targetCardsPerSection: cardsPerSection
        )

        async let secondCall: TopicPackDTO? = secondTarget > 0 ? service.generateTopicPack(
            title: subject.capitalized,
            difficulty: difficulty,
            language: "en",
            targetSections: secondTarget,
            targetCardsPerSection: cardsPerSection
        ) : nil

        // Await both calls before persisting to ensure all-or-nothing saves.
        let firstDTO = try await firstCall
        let secondDTO = try await secondCall

        // Choose the final pack ID/title before normalizing IDs to avoid collisions.
        let uniqueBase = makeUnique(dto: firstDTO, existingIDs: existingIDs, existingTitles: existingTitles)
        let baseID = uniqueBase.id
        let baseTitle = uniqueBase.title

        var normalizedBase = normalize(
            dto: uniqueBase,
            baseID: baseID,
            baseTitle: baseTitle,
            sectionStartIndex: 0
        )

        if let secondDTO {
            let normalizedSecond = normalize(
                dto: secondDTO,
                baseID: baseID,
                baseTitle: baseTitle,
                sectionStartIndex: normalizedBase.sections.count
            )
            normalizedBase = mergeSections(into: normalizedBase, additionalSections: normalizedSecond.sections)
        }

        return try await MainActor.run {
            try self.contentRepository.appendOrReplaceUserPack(normalizedBase)
        }
    }

    enum RandomTopicError: LocalizedError {
        case missingAPIKey

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Please set your OpenAI API key in Settings."
            }
        }
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
        var sectionCounter = sectionStartIndex
        let normalizedSections: [TopicSectionDTO] = dto.sections.map { section in
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
            sections: normalizedSections
        )
    }

    private func mergeSections(into dto: TopicPackDTO, additionalSections: [TopicSectionDTO]) -> TopicPackDTO {
        TopicPackDTO(
            id: dto.id,
            title: dto.title,
            subtitle: dto.subtitle,
            category: dto.category,
            difficulty: dto.difficulty,
            language: dto.language,
            description: dto.description,
            author: dto.author,
            version: dto.version,
            sections: dto.sections + additionalSections
        )
    }
}
