import SwiftUI
import Foundation
import Combine

@MainActor
final class ContentRepository: ObservableObject {
    static let shared = ContentRepository()

    @Published private(set) var topics: [TopicPack] = []
    private let diskStore: ContentDiskStore
    private var seedPackDTOs: [TopicPackDTO] = []
    private var userPackDTOs: [TopicPackDTO] = []
    private let statusStore: TopicStatusStore
    private let orderStore: TopicOrderStore

    private init(
        diskStore: ContentDiskStore = ContentDiskStore(),
        statusStore: TopicStatusStore = TopicStatusStore.shared,
        orderStore: TopicOrderStore = TopicOrderStore.shared
    ) {
        self.diskStore = diskStore
        self.statusStore = statusStore
        self.orderStore = orderStore
        loadContent()
    }

    // MARK: - Loading

    private func loadContent() {
        seedPackDTOs = diskStore.loadSeedPacks()
        userPackDTOs = diskStore.loadUserPacks()
        let mergedDTOs = deduplicatedDTOs(seed: seedPackDTOs, user: userPackDTOs)

        var loadedTopics = mergedDTOs.compactMap { $0.toModel() }
        applyOrdering(to: &loadedTopics)
        topics = loadedTopics.isEmpty ? Self.sampleTopics : loadedTopics
    }

    // MARK: - Mutation

    @discardableResult
    func appendOrReplaceUserPack(_ pack: TopicPackDTO) -> TopicPack? {
        guard pack.isValid() else { return nil }

        if let existingIndex = userPackDTOs.firstIndex(where: { $0.id == pack.id }) {
            userPackDTOs[existingIndex] = pack
        } else if let titleIndex = userPackDTOs.firstIndex(where: {
            $0.title.caseInsensitiveCompare(pack.title) == .orderedSame
        }) {
            userPackDTOs[titleIndex] = pack
        } else {
            userPackDTOs.insert(pack, at: 0)
        }

        diskStore.saveUserPacks(userPackDTOs)

        let combined = deduplicatedDTOs(seed: seedPackDTOs, user: userPackDTOs)
        var loadedTopics = combined.compactMap { $0.toModel() }
        applyOrdering(to: &loadedTopics)
        if !loadedTopics.isEmpty {
            topics = loadedTopics
        }

        return pack.toModel()
    }

    func deleteTopic(_ topic: TopicPack) {
        // Remove from user packs if present
        if let index = userPackDTOs.firstIndex(where: { $0.id == topic.id }) {
            userPackDTOs.remove(at: index)
            diskStore.saveUserPacks(userPackDTOs)
        }
        // Always mark deleted to hide seed topics as well.
        statusStore.markDeleted(topic.id)

        let combined = deduplicatedDTOs(seed: seedPackDTOs, user: userPackDTOs)
        let loadedTopics = combined.compactMap { $0.toModel() }
        topics = loadedTopics
    }

    func toggleCompleted(_ topic: TopicPack) {
        statusStore.toggleCompleted(topic.id)
        objectWillChange.send()
    }

    func isCompleted(_ topic: TopicPack) -> Bool {
        statusStore.isCompleted(topic.id)
    }

    func reorderActiveTopics(from source: IndexSet, to destination: Int) {
        var active = topics.filter { !statusStore.isCompleted($0.id) }
        let completed = topics.filter { statusStore.isCompleted($0.id) }
        active.move(fromOffsets: source, toOffset: destination)
        topics = active + completed
        orderStore.saveOrder(for: active.map { $0.id })
    }

    private func filteredForDeletion(_ dtos: [TopicPackDTO]) -> [TopicPackDTO] {
        dtos.filter { !statusStore.isDeleted($0.id) }
    }

    private func deduplicatedDTOs(seed: [TopicPackDTO], user: [TopicPackDTO]) -> [TopicPackDTO] {
        // Merge by id, user wins; then remove title duplicates (user title wins).
        let seedFiltered = filteredForDeletion(seed)
        let userFiltered = filteredForDeletion(user)

        var byID: [String: TopicPackDTO] = [:]
        seedFiltered.forEach { byID[$0.id] = $0 }
        userFiltered.forEach { byID[$0.id] = $0 }

        var titleSet = Set<String>()
        var merged: [TopicPackDTO] = []
        for dto in byID.values {
            let lower = dto.title.lowercased()
            if titleSet.contains(lower) { continue }
            titleSet.insert(lower)
            merged.append(dto)
        }

        // Order: user first, then remaining seeds.
        let userIDs = Set(userFiltered.map { $0.id })
        let users = merged.filter { userIDs.contains($0.id) }
        let seeds = merged.filter { !userIDs.contains($0.id) }
        return users + seeds
    }

    private func applyOrdering(to topicModels: inout [TopicPack]) {
        let order = orderStore.loadOrder()
        guard !order.isEmpty else { return }

        var orderMap: [String: Int] = [:]
        for (idx, id) in order.enumerated() {
            orderMap[id] = idx
        }

        topicModels.sort { lhs, rhs in
            let lhsCompleted = statusStore.isCompleted(lhs.id)
            let rhsCompleted = statusStore.isCompleted(rhs.id)

            // Keep completed items after active items
            if lhsCompleted != rhsCompleted {
                return !lhsCompleted && rhsCompleted
            }

            // Within active items, respect stored order; fall back to current order.
            let lhsOrder = orderMap[lhs.id]
            let rhsOrder = orderMap[rhs.id]

            switch (lhsOrder, rhsOrder) {
            case let (.some(l), .some(r)):
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return false
            }
        }
    }

    // MARK: - Sample Content

    private static let sampleTopics: [TopicPack] = [
        TopicPack(
            id: "astronomy_foundations",
            title: "Astronomy – Foundations",
            subtitle: "Understand the cosmos in small steps.",
            category: "Science",
            difficulty: .beginner,
            estimatedMinutes: 45,
            sections: [
                TopicSection(
                    id: "astro_scale",
                    title: "Scale of the Universe",
                    cards: [
                        Card(
                            id: "astro_scale_au",
                            front: "What is an astronomical unit (AU)?",
                            back: "The average distance between Earth and the Sun (~150 million km)."
                        ),
                        Card(
                            id: "astro_scale_ly",
                            front: "What is a light-year?",
                            back: "The distance light travels in one year, about 9.46 trillion km."
                        ),
                        Card(
                            id: "astro_scale_galaxy",
                            front: "What is a galaxy?",
                            back: "A massive system of stars, gas, dust, and dark matter bound together by gravity."
                        )
                    ]
                ),
                TopicSection(
                    id: "astro_stars",
                    title: "Stars & Galaxies",
                    cards: [
                        Card(
                            id: "astro_star_def",
                            front: "What is a star?",
                            back: "A huge ball of hot, glowing gas held together by gravity and powered by nuclear fusion."
                        ),
                        Card(
                            id: "astro_milky_way",
                            front: "What is the Milky Way?",
                            back: "The galaxy that contains our Solar System, with hundreds of billions of stars."
                        )
                    ]
                )
            ]
        ),
        TopicPack(
            id: "logic_basics",
            title: "Logic – Basics",
            subtitle: "Learn how arguments really work.",
            category: "Thinking",
            difficulty: .beginner,
            estimatedMinutes: 30,
            sections: [
                TopicSection(
                    id: "logic_argument",
                    title: "Arguments & Claims",
                    cards: [
                        Card(
                            id: "logic_argument_def",
                            front: "What is an argument in logic?",
                            back: "A set of statements where some (premises) are offered as support for another (the conclusion)."
                        ),
                        Card(
                            id: "logic_premise",
                            front: "What is a premise?",
                            back: "A statement that provides a reason or evidence for accepting a conclusion."
                        )
                    ]
                ),
                TopicSection(
                    id: "logic_fallacies",
                    title: "Common Fallacies",
                    cards: [
                        Card(
                            id: "logic_strawman",
                            front: "What is a straw man fallacy?",
                            back: "Misrepresenting an opponent’s position to make it easier to attack instead of addressing their actual argument."
                        ),
                        Card(
                            id: "logic_ad_hominem",
                            front: "What is an ad hominem?",
                            back: "Attacking the person making the argument rather than the argument itself."
                        )
                    ]
                )
            ]
        )
    ]
}
