import Foundation
import Combine

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
        statusStore: TopicStatusStore = TopicStatusStore.shared
    ) {
        self.contentRepository = contentRepository
        self.progressStore = progressStore
        self.statusStore = statusStore
        self.topics = contentRepository.topics

        contentRepository.$topics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updated in
                self?.topics = updated
            }
            .store(in: &cancellables)

        statusStore.$completedIDs
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
        targetSections: Int = 3,
        cardsPerSection: Int = 5
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
        let categories = ["Science", "Thinking", "Life", "Tech", "Creativity"]

        var subject = subjects.randomElement() ?? "surprising ideas"
        var attempts = 0
        while existingTitles.contains(subject.lowercased()) && attempts < 5 {
            subject = subjects.randomElement() ?? "surprising ideas"
            attempts += 1
        }

        let category = categories.randomElement() ?? "General"
        let difficulty = Difficulty.allCases.randomElement() ?? .beginner

        let config = OpenAIClient.Configuration(
            apiKeyProvider: { apiKey },
            model: ModelPreferenceStore.shared.preferredModel ?? "gpt-4.1-mini"
        )
        let service = AIContentService(client: OpenAIClient(configuration: config))

        let dto = try await service.generateTopicPack(
            title: subject.capitalized,
            difficulty: difficulty,
            language: "en",
            targetSections: targetSections,
            targetCardsPerSection: cardsPerSection
        )

        return try await MainActor.run {
            let unique = makeUnique(dto: dto, existingIDs: existingIDs, existingTitles: existingTitles)
            return try self.contentRepository.appendOrReplaceUserPack(unique)
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
}
