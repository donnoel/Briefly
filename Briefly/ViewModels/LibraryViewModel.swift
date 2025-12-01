import Foundation
import Combine

final class LibraryViewModel: ObservableObject {
    @Published private(set) var topics: [TopicPack] = []

    private let contentRepository: ContentRepository
    private let progressStore: ProgressStore
    private var cancellables = Set<AnyCancellable>()

    init(contentRepository: ContentRepository, progressStore: ProgressStore) {
        self.contentRepository = contentRepository
        self.progressStore = progressStore
        self.topics = contentRepository.topics

        contentRepository.$topics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updated in
                self?.topics = updated
            }
            .store(in: &cancellables)
    }

    func progress(for topic: TopicPack) -> Double {
        progressStore.progress(for: topic)
    }
}
