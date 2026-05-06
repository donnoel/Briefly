import SwiftUI
import Combine

final class AppCoordinator: ObservableObject {
    @Published var path: [Route] = []

    enum Route: Hashable {
        case topic(topicID: String)
        case deck(topicID: String, sectionID: String)
    }

    // MARK: - Navigation

    func showTopic(topicID: String) {
        path.append(.topic(topicID: topicID))
    }

    func showDeck(topicID: String, sectionID: String) {
        path.append(.deck(topicID: topicID, sectionID: sectionID))
    }

    func popToRoot() {
        path.removeAll()
    }

    func popLast() {
        _ = path.popLast()
    }
}
