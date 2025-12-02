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
    func appendOrReplaceUserPack(_ pack: TopicPackDTO) throws -> TopicPack? {
        guard pack.isValid() else { return nil }
        let originalUserPacks = userPackDTOs

        if let existingIndex = userPackDTOs.firstIndex(where: { $0.id == pack.id }) {
            userPackDTOs[existingIndex] = pack
        } else if let titleIndex = userPackDTOs.firstIndex(where: {
            $0.title.caseInsensitiveCompare(pack.title) == .orderedSame
        }) {
            userPackDTOs[titleIndex] = pack
        } else {
            userPackDTOs.insert(pack, at: 0)
        }

        do {
            try diskStore.saveUserPacks(userPackDTOs)
        } catch {
            userPackDTOs = originalUserPacks
            throw error
        }

        let combined = deduplicatedDTOs(seed: seedPackDTOs, user: userPackDTOs)
        var loadedTopics = combined.compactMap { $0.toModel() }

        let isNewTopic = !topics.contains(where: { $0.id == pack.id })
        let newTopicModel = pack.toModel()

        if isNewTopic, let newTopicModel {
            // Build list without duplicating the new topic, and place it first in active list.
            let withoutNew = loadedTopics.filter { $0.id != newTopicModel.id }
            let active = withoutNew.filter { !statusStore.isCompleted($0.id) }
            let completed = withoutNew.filter { statusStore.isCompleted($0.id) }
            topics = [newTopicModel] + active + completed
            orderStore.saveOrder(for: ([newTopicModel] + active).map { $0.id })
        } else {
            applyOrdering(to: &loadedTopics)
            if !loadedTopics.isEmpty {
                topics = loadedTopics
            }
        }

        return pack.toModel()
    }

    func deleteTopic(_ topic: TopicPack) throws {
        let originalUserPacks = userPackDTOs
        // Remove from user packs if present
        if let index = userPackDTOs.firstIndex(where: { $0.id == topic.id }) {
            userPackDTOs.remove(at: index)
            do {
                try diskStore.saveUserPacks(userPackDTOs)
            } catch {
                userPackDTOs = originalUserPacks
                throw error
            }
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

        // Preserve stable ordering: user items first (in their current order), then seeds (in their current order).
        var merged: [TopicPackDTO] = []
        var seenTitles = Set<String>()

        for dto in userFiltered {
            let lower = dto.title.lowercased()
            if seenTitles.contains(lower) { continue }
            seenTitles.insert(lower)
            merged.append(dto)
        }

        for dto in seedFiltered {
            let lower = dto.title.lowercased()
            if seenTitles.contains(lower) { continue }
            seenTitles.insert(lower)
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

    private static let sampleTopics: [TopicPack] = []
}
