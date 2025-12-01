import Foundation

@MainActor
final class TopicOrderStore {
    static let shared = TopicOrderStore()

    private let orderKey = "Briefly.topicOrder"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveOrder(for ids: [String]) {
        defaults.set(ids, forKey: orderKey)
    }

    func loadOrder() -> [String] {
        defaults.array(forKey: orderKey) as? [String] ?? []
    }
}
