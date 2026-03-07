import Foundation
import Combine

@MainActor
final class RecentTopicsStore: ObservableObject {
    static let shared = RecentTopicsStore()

    @Published private(set) var topicIDs: [String] = []

    private let defaults: UserDefaults
    private let storageKey = "Briefly.recentTopicIDs"
    private let maxStoredTopics = 12

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func recordOpened(topicID: String) {
        let normalizedID = topicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty else { return }

        topicIDs.removeAll { $0.caseInsensitiveCompare(normalizedID) == .orderedSame }
        topicIDs.insert(normalizedID, at: 0)
        if topicIDs.count > maxStoredTopics {
            topicIDs = Array(topicIDs.prefix(maxStoredTopics))
        }
        save()
    }

    private func load() {
        topicIDs = defaults.array(forKey: storageKey) as? [String] ?? []
    }

    private func save() {
        defaults.set(topicIDs, forKey: storageKey)
    }
}
