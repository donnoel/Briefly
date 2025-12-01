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

    func delete(_ topic: TopicPack) {
        contentRepository.deleteTopic(topic)
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
}
