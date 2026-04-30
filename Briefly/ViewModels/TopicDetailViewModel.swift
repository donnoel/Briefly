import Foundation
import Combine

final class TopicDetailViewModel: ObservableObject {
    let topic: TopicPack
    @Published private(set) var sections: [TopicSection] = []

    private let progressStore: ProgressStore

    init(topic: TopicPack, progressStore: ProgressStore) {
        self.topic = topic
        self.progressStore = progressStore
        self.sections = topic.sections
    }

    func progressFraction() -> Double {
        progressStore.progress(for: topic)
    }

    func progressText() -> String {
        let fraction = progressFraction()
        let percent = Int((fraction * 100).rounded())
        return "\(percent)% learned"
    }

    func isSectionCompleted(_ section: TopicSection) -> Bool {
        progressStore.isSectionCompleted(section)
    }

    func canStudy(_ section: TopicSection) -> Bool {
        !section.cards.isEmpty
    }
}
