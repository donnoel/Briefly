import SwiftUI
import Combine

final class AppCoordinator: ObservableObject {
    @Published var path: [Route] = []

    enum Route: Hashable {
        case topic(TopicPack)
        case deck(TopicPack, TopicSection)
    }

    // MARK: - Navigation

    func showTopic(_ topic: TopicPack) {
        path.append(.topic(topic))
    }

    func showDeck(for topic: TopicPack, section: TopicSection) {
        guard !section.cards.isEmpty else { return }
        path.append(.deck(topic, section))
    }

    func popToRoot() {
        path.removeAll()
    }

    func popLast() {
        _ = path.popLast()
    }
}
