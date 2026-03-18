import SwiftUI
import Foundation
import Combine
import CloudKit

@MainActor
final class ContentRepository: ObservableObject {
    static let shared = ContentRepository()

    enum RepositoryError: LocalizedError {
        case userContentUnavailable(Error)

        var errorDescription: String? {
            switch self {
            case .userContentUnavailable(let error):
                return "Your saved topics could not be loaded. Fix or remove the existing saved topics file before making changes. (\(error.localizedDescription))"
            }
        }
    }

    @Published private(set) var topics: [TopicPack] = []
    private let diskStore: any ContentDiskStoring
    private var seedPackDTOs: [TopicPackDTO] = []
    private var userPackDTOs: [TopicPackDTO] = []
    private let statusStore: TopicStatusStore
    private let orderStore: TopicOrderStore
    private let progressStore: ProgressStore
    private let cloudSyncService: (any CloudTopicSyncing)?
    private var userPackLoadFailure: Error?
    private var initialLoadTask: Task<Void, Never>?
    private var cloudSyncTask: Task<Void, Never>?
    private var cloudDebouncedSyncTask: Task<Void, Never>?

    private enum SyncTrigger {
        case localMutation
        case remoteNotification
    }

    init(
        diskStore: (any ContentDiskStoring)? = nil,
        statusStore: TopicStatusStore? = nil,
        orderStore: TopicOrderStore? = nil,
        progressStore: ProgressStore? = nil,
        cloudSyncService: (any CloudTopicSyncing)? = nil
    ) {
        self.diskStore = diskStore ?? ContentDiskStore()
        self.statusStore = statusStore ?? .shared
        self.orderStore = orderStore ?? .shared
        self.progressStore = progressStore ?? .shared
        self.cloudSyncService = cloudSyncService ?? CloudTopicSyncService.shared
        initialLoadTask = Task { @MainActor in
            await performInitialLoad()
            refreshFromCloud()
        }
    }

    // MARK: - Loading

    func awaitInitialLoad() async {
        await initialLoadTask?.value
    }

    private func performInitialLoad() async {
        seedPackDTOs = await diskStore.loadSeedPacks()
        do {
            userPackDTOs = try await diskStore.loadUserPacks()
            userPackLoadFailure = nil
        } catch {
            userPackDTOs = []
            userPackLoadFailure = error
        }
        rebuildTopicsFromCurrentDTOs()
    }

    // MARK: - Mutation

    @discardableResult
    func appendOrReplaceUserPack(_ pack: TopicPackDTO) async throws -> TopicPack? {
        await awaitInitialLoad()
        guard pack.isValid() else { return nil }
        try ensureUserContentIsWritable()
        let wasDeleted = statusStore.isDeleted(pack.id)
        if wasDeleted {
            statusStore.unmarkDeleted(pack.id)
        }
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
            try await diskStore.saveUserPacks(userPackDTOs)
        } catch {
            userPackDTOs = originalUserPacks
            if wasDeleted {
                statusStore.markDeleted(pack.id)
            }
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

        scheduleCloudSync()

        return pack.toModel()
    }

    func deleteTopic(_ topic: TopicPack) async throws {
        await awaitInitialLoad()
        let originalUserPacks = userPackDTOs
        // Remove from user packs if present
        if let index = userPackDTOs.firstIndex(where: { $0.id == topic.id }) {
            try ensureUserContentIsWritable()
            userPackDTOs.remove(at: index)
            do {
                try await diskStore.saveUserPacks(userPackDTOs)
            } catch {
                userPackDTOs = originalUserPacks
                throw error
            }
        }
        // Always mark deleted to hide seed topics as well.
        statusStore.markDeleted(topic.id)
        statusStore.unmarkCompleted(topic.id)
        progressStore.resetProgress(for: topic)

        let combined = deduplicatedDTOs(seed: seedPackDTOs, user: userPackDTOs)
        var loadedTopics = combined.compactMap { $0.toModel() }
        applyOrdering(to: &loadedTopics)
        topics = loadedTopics.isEmpty ? Self.sampleTopics : loadedTopics
        let activeIDs = loadedTopics
            .filter { !statusStore.isCompleted($0.id) }
            .map(\.id)
        orderStore.saveOrder(for: activeIDs)
        scheduleCloudSync()
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
        scheduleCloudSync()
    }

    @discardableResult
    func refreshFromCloud() -> Task<Void, Never>? {
        guard let cloudSyncService else { return nil }
        cloudSyncTask?.cancel()
        let syncTask = Task { @MainActor in
            await awaitInitialLoad()
            await performCloudSync(using: cloudSyncService, trigger: .remoteNotification)
        }
        cloudSyncTask = syncTask
        return syncTask
    }

    private func ensureUserContentIsWritable() throws {
        if let userPackLoadFailure {
            throw RepositoryError.userContentUnavailable(userPackLoadFailure)
        }
    }

    private func rebuildTopicsFromCurrentDTOs() {
        let mergedDTOs = deduplicatedDTOs(seed: seedPackDTOs, user: userPackDTOs)
        var loadedTopics = mergedDTOs.compactMap { $0.toModel() }
        applyOrdering(to: &loadedTopics)
        topics = loadedTopics.isEmpty ? Self.sampleTopics : loadedTopics
    }

    private func scheduleCloudSync() {
        guard let cloudSyncService else { return }
        cloudDebouncedSyncTask?.cancel()
        cloudDebouncedSyncTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            await performCloudSync(using: cloudSyncService, trigger: .localMutation)
        }
    }

    private func performCloudSync(using cloudSyncService: any CloudTopicSyncing, trigger: SyncTrigger) async {
        for _ in 0..<3 {
            do {
                let localState = currentLocalSyncState()
                let remoteState = try await cloudSyncService.fetchState()

                let mergedState = mergeCloudAndLocalState(
                    remoteState: remoteState,
                    localState: localState,
                    trigger: trigger
                )
                if mergedState.userPacks != localState.userPacks || mergedState.orderedTopicIDs != localState.orderedTopicIDs {
                    do {
                        try await diskStore.saveUserPacks(mergedState.userPacks)
                        userPackDTOs = mergedState.userPacks
                        userPackLoadFailure = nil
                        orderStore.saveOrder(for: mergedState.orderedTopicIDs)
                        rebuildTopicsFromCurrentDTOs()
                    } catch {
                        return
                    }
                }

                if remoteState == nil || remoteState != mergedState {
                    try await cloudSyncService.saveState(mergedState)
                }
                return
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            } catch {
                // Best-effort sync. Local content remains the source of truth when cloud is unavailable.
                return
            }
        }
    }

    private func currentLocalSyncState() -> CloudTopicState {
        let canonicalIDByLowercasedID = Dictionary(
            uniqueKeysWithValues: userPackDTOs.map { ($0.id.lowercased(), $0.id) }
        )
        return CloudTopicState(
            userPacks: userPackDTOs,
            orderedTopicIDs: normalizeOrder(
                orderStore.loadOrder(),
                canonicalIDByLowercasedID: canonicalIDByLowercasedID
            )
        )
    }

    private func mergeCloudAndLocalState(
        remoteState: CloudTopicState?,
        localState: CloudTopicState,
        trigger: SyncTrigger
    ) -> CloudTopicState {
        guard let remoteState else {
            let mergedPacks = deduplicatedDTOs(seed: [], user: localState.userPacks)
            return CloudTopicState(
                userPacks: mergedPacks,
                orderedTopicIDs: mergedOrder(
                    preferredOrder: localState.orderedTopicIDs,
                    secondaryOrder: [],
                    packs: mergedPacks
                )
            )
        }

        let mergedPacks = deduplicatedDTOs(seed: remoteState.userPacks, user: localState.userPacks)
        let preferredOrder: [String]
        let secondaryOrder: [String]
        switch trigger {
        case .localMutation:
            preferredOrder = localState.orderedTopicIDs
            secondaryOrder = remoteState.orderedTopicIDs
        case .remoteNotification:
            preferredOrder = remoteState.orderedTopicIDs
            secondaryOrder = localState.orderedTopicIDs
        }

        return CloudTopicState(
            userPacks: mergedPacks,
            orderedTopicIDs: mergedOrder(preferredOrder: preferredOrder, secondaryOrder: secondaryOrder, packs: mergedPacks)
        )
    }

    private func mergedOrder(preferredOrder: [String], secondaryOrder: [String], packs: [TopicPackDTO]) -> [String] {
        let canonicalIDByLowercasedID = Dictionary(uniqueKeysWithValues: packs.map { ($0.id.lowercased(), $0.id) })
        let normalizedPreferred = normalizeOrder(preferredOrder, canonicalIDByLowercasedID: canonicalIDByLowercasedID)
        let normalizedSecondary = normalizeOrder(secondaryOrder, canonicalIDByLowercasedID: canonicalIDByLowercasedID)
        let fallback = normalizeOrder(packs.map(\.id), canonicalIDByLowercasedID: canonicalIDByLowercasedID)

        var merged: [String] = []
        var seen = Set<String>()
        for id in normalizedPreferred + normalizedSecondary + fallback {
            let key = id.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(id)
        }
        return merged
    }

    private func normalizeOrder(
        _ order: [String],
        canonicalIDByLowercasedID: [String: String]
    ) -> [String] {
        var normalized: [String] = []
        normalized.reserveCapacity(order.count)
        var seen = Set<String>()
        seen.reserveCapacity(order.count)
        for id in order {
            let key = id.lowercased()
            guard !seen.contains(key), let canonicalID = canonicalIDByLowercasedID[key] else {
                continue
            }
            seen.insert(key)
            normalized.append(canonicalID)
        }
        return normalized
    }

    private func filteredForDeletion(_ dtos: [TopicPackDTO]) -> [TopicPackDTO] {
        dtos.filter { !statusStore.isDeleted($0.id) }
    }

    private func deduplicatedDTOs(seed: [TopicPackDTO], user: [TopicPackDTO]) -> [TopicPackDTO] {
        // Merge by id first (user wins), then remove title duplicates (user title wins).
        var seedFiltered: [TopicPackDTO] = []
        seedFiltered.reserveCapacity(seed.count)
        for dto in seed where !statusStore.isDeleted(dto.id) {
            seedFiltered.append(dto)
        }

        var userFiltered: [TopicPackDTO] = []
        userFiltered.reserveCapacity(user.count)
        for dto in user where !statusStore.isDeleted(dto.id) {
            userFiltered.append(dto)
        }

        var resolvedByID: [String: TopicPackDTO] = [:]
        resolvedByID.reserveCapacity(seedFiltered.count + userFiltered.count)
        for dto in seedFiltered {
            resolvedByID[dto.id.lowercased()] = dto
        }
        for dto in userFiltered {
            resolvedByID[dto.id.lowercased()] = dto
        }

        var orderedByID: [TopicPackDTO] = []
        orderedByID.reserveCapacity(seedFiltered.count + userFiltered.count)
        var seenIDs = Set<String>()
        seenIDs.reserveCapacity(seedFiltered.count + userFiltered.count)
        for dto in userFiltered + seedFiltered {
            let idKey = dto.id.lowercased()
            guard !seenIDs.contains(idKey), let resolved = resolvedByID[idKey] else { continue }
            seenIDs.insert(idKey)
            orderedByID.append(resolved)
        }

        var merged: [TopicPackDTO] = []
        merged.reserveCapacity(orderedByID.count)
        var seenTitles = Set<String>()
        seenTitles.reserveCapacity(orderedByID.count)
        for dto in orderedByID {
            let titleKey = dto.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !seenTitles.contains(titleKey) else { continue }
            seenTitles.insert(titleKey)
            merged.append(dto)
        }
        return merged
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
