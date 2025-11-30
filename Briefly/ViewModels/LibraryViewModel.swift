import Foundation
import Combine

final class LibraryViewModel: ObservableObject {
    @Published private(set) var topics: [TopicPack] = []

    private let contentRepository: ContentRepository
    private let progressStore: ProgressStore

    init(contentRepository: ContentRepository, progressStore: ProgressStore) {
        self.contentRepository = contentRepository
        self.progressStore = progressStore
        self.topics = contentRepository.topics
    }

    func progress(for topic: TopicPack) -> Double {
        progressStore.progress(for: topic)
    }
}
