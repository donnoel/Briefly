import Foundation
import Testing
@testable import Briefly

@MainActor
struct ContentRepositoryTests {

    @Test
    func mergePrefersUserPackWhenIDsMatch() {
        let defaults = makeIsolatedDefaults()
        let disk = InMemoryDiskStore(
            seed: [makeDTO(id: "shared_id", title: "Seed Title", subtitle: "Seed subtitle")],
            user: [makeDTO(id: "shared_id", title: "User Title", subtitle: "User subtitle")]
        )

        let repo = makeRepository(disk: disk, defaults: defaults)

        #expect(repo.topics.count == 1)
        #expect(repo.topics.first?.id == "shared_id")
        #expect(repo.topics.first?.title == "User Title")
        #expect(repo.topics.first?.subtitle == "User subtitle")
    }

    @Test
    func mergePrefersUserPackWhenTitlesMatch() {
        let defaults = makeIsolatedDefaults()
        let disk = InMemoryDiskStore(
            seed: [makeDTO(id: "seed_alpha", title: "Duplicate Title")],
            user: [makeDTO(id: "user_alpha", title: "duplicate title")]
        )

        let repo = makeRepository(disk: disk, defaults: defaults)

        #expect(repo.topics.count == 1)
        #expect(repo.topics.first?.id == "user_alpha")
    }

    @Test
    func deleteThenReaddSameIDPersistsAfterRelaunch() throws {
        let defaults = makeIsolatedDefaults()
        let pack = makeDTO(id: "topic_readd", title: "Readd Topic")
        let disk = InMemoryDiskStore(seed: [], user: [pack])

        let firstLaunch = makeRepository(disk: disk, defaults: defaults)
        let topic = try #require(firstLaunch.topics.first)

        try firstLaunch.deleteTopic(topic)
        #expect(firstLaunch.topics.isEmpty)

        _ = try firstLaunch.appendOrReplaceUserPack(pack)
        #expect(firstLaunch.topics.contains(where: { $0.id == "topic_readd" }))

        let secondLaunch = makeRepository(disk: disk, defaults: defaults)
        #expect(secondLaunch.topics.map(\.id) == ["topic_readd"])
    }

    @Test
    func deleteKeepsSavedActiveOrderStable() throws {
        let defaults = makeIsolatedDefaults()
        let a = makeDTO(id: "alpha", title: "Alpha")
        let b = makeDTO(id: "beta", title: "Beta")
        let c = makeDTO(id: "gamma", title: "Gamma")
        let disk = InMemoryDiskStore(seed: [], user: [a, b, c])

        let orderStore = TopicOrderStore(defaults: defaults)
        orderStore.saveOrder(for: ["beta", "alpha", "gamma"])

        let statusStore = TopicStatusStore(defaults: defaults)
        let repo = ContentRepository(diskStore: disk, statusStore: statusStore, orderStore: orderStore)

        #expect(repo.topics.map(\.id) == ["beta", "alpha", "gamma"])

        let alphaTopic = try #require(repo.topics.first(where: { $0.id == "alpha" }))
        try repo.deleteTopic(alphaTopic)

        #expect(repo.topics.map(\.id) == ["beta", "gamma"])
        #expect(orderStore.loadOrder() == ["beta", "gamma"])

        let relaunch = makeRepository(disk: disk, defaults: defaults)
        #expect(relaunch.topics.map(\.id) == ["beta", "gamma"])
    }

    @Test
    func loadFailureBlocksMutationsInsteadOfOverwritingUserData() {
        let defaults = makeIsolatedDefaults()
        let disk = InMemoryDiskStore(seed: [], user: [], loadUserError: ContentDiskStore.DiskError.readFailed(URLError(.cannotDecodeRawData)))
        let repo = makeRepository(disk: disk, defaults: defaults)

        do {
            _ = try repo.appendOrReplaceUserPack(makeDTO(id: "new_topic", title: "New Topic"))
            #expect(false)
            return
        } catch let error as ContentRepository.RepositoryError {
            guard case .userContentUnavailable = error else {
                #expect(false)
                return
            }
        } catch {
            #expect(false)
            return
        }

        #expect(disk.saveCallCount == 0)
        #expect(repo.topics.isEmpty)
    }

    @Test
    func deleteThenReaddSameIDResetsCompletionAndProgress() throws {
        let defaults = makeIsolatedDefaults()
        let progressDefaults = makeIsolatedDefaults()
        let progressStore = ProgressStore(defaults: progressDefaults)
        let pack = makeDTO(id: "topic_reset", title: "Reset Topic")
        let disk = InMemoryDiskStore(seed: [], user: [pack])

        let firstLaunch = makeRepository(disk: disk, defaults: defaults, progressStore: progressStore)
        let topic = try #require(firstLaunch.topics.first)
        let section = try #require(topic.sections.first)
        let card = try #require(section.cards.first)

        progressStore.markLearned(card)
        progressStore.markSectionCompleted(section)
        firstLaunch.toggleCompleted(topic)

        try firstLaunch.deleteTopic(topic)

        #expect(progressStore.progress(for: topic) == 0)
        #expect(!firstLaunch.isCompleted(topic))

        let readded = try #require(firstLaunch.appendOrReplaceUserPack(pack))
        #expect(progressStore.progress(for: readded) == 0)
        #expect(!firstLaunch.isCompleted(readded))

        let secondLaunch = makeRepository(disk: disk, defaults: defaults, progressStore: ProgressStore(defaults: progressDefaults))
        let relaunchedTopic = try #require(secondLaunch.topics.first)
        #expect(!secondLaunch.isCompleted(relaunchedTopic))
    }

    private func makeRepository(
        disk: InMemoryDiskStore,
        defaults: UserDefaults,
        progressStore: ProgressStore? = nil
    ) -> ContentRepository {
        let statusStore = TopicStatusStore(defaults: defaults)
        let orderStore = TopicOrderStore(defaults: defaults)
        return ContentRepository(
            diskStore: disk,
            statusStore: statusStore,
            orderStore: orderStore,
            progressStore: progressStore ?? .shared
        )
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "BrieflyTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Failed to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeDTO(
        id: String,
        title: String,
        subtitle: String = "Subtitle",
        category: String = "General",
        difficulty: String = "Beginner"
    ) -> TopicPackDTO {
        TopicPackDTO(
            id: id,
            title: title,
            subtitle: subtitle,
            category: category,
            difficulty: difficulty,
            language: "en",
            description: nil,
            author: nil,
            version: nil,
            sections: [
                TopicSectionDTO(
                    id: "\(id)_section_0",
                    title: "Section",
                    cards: [
                        CardDTO(
                            id: "\(id)_section_0_card_0",
                            front: "Question",
                            back: "Answer",
                            source: nil,
                            tags: nil
                        )
                    ]
                )
            ]
        )
    }
}

private final class InMemoryDiskStore: ContentDiskStoring {
    private let seed: [TopicPackDTO]
    private(set) var user: [TopicPackDTO]
    private let loadUserError: Error?
    private(set) var saveCallCount = 0

    init(seed: [TopicPackDTO], user: [TopicPackDTO], loadUserError: Error? = nil) {
        self.seed = seed
        self.user = user
        self.loadUserError = loadUserError
    }

    func loadSeedPacks() -> [TopicPackDTO] {
        seed
    }

    func loadUserPacks() throws -> [TopicPackDTO] {
        if let loadUserError {
            throw loadUserError
        }
        user
    }

    func saveUserPacks(_ packs: [TopicPackDTO]) throws {
        saveCallCount += 1
        user = packs
    }
}
