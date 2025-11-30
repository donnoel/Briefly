import Foundation
import Combine

final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published private(set) var learnedCardIDs: Set<String> = []

    private let storageKey = "Briefly.learnedCardIDs"

    private init() {
        load()
    }

    // MARK: - Public

    func markLearned(_ card: Card) {
        learnedCardIDs.insert(card.id)
        save()
    }

    func isLearned(_ card: Card) -> Bool {
        learnedCardIDs.contains(card.id)
    }

    func progress(for topic: TopicPack) -> Double {
        let allCards = topic.sections.flatMap(\.cards)
        guard !allCards.isEmpty else { return 0 }

        let learnedCount = allCards.filter { learnedCardIDs.contains($0.id) }.count
        return Double(learnedCount) / Double(allCards.count)
    }

    // MARK: - Persistence

    private func load() {
        let defaults = UserDefaults.standard
        if let array = defaults.array(forKey: storageKey) as? [String] {
            learnedCardIDs = Set(array)
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(Array(learnedCardIDs), forKey: storageKey)
    }
}
