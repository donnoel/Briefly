import Foundation
import Testing
@testable import Briefly

@MainActor
struct RecentTopicsStoreTests {

    @Test
    func recordOpenedMovesTopicToFrontWithoutDuplicates() {
        let defaults = makeIsolatedDefaults()
        let store = RecentTopicsStore(defaults: defaults)

        store.recordOpened(topicID: "alpha")
        store.recordOpened(topicID: "beta")
        store.recordOpened(topicID: "alpha")

        #expect(store.topicIDs == ["alpha", "beta"])
    }

    @Test
    func recordOpenedPersistsMostRecentTopics() {
        let defaults = makeIsolatedDefaults()
        let firstStore = RecentTopicsStore(defaults: defaults)

        firstStore.recordOpened(topicID: "alpha")
        firstStore.recordOpened(topicID: "beta")

        let secondStore = RecentTopicsStore(defaults: defaults)
        #expect(secondStore.topicIDs == ["beta", "alpha"])
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "RecentTopicsStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Failed to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
