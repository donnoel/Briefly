import Foundation
import Testing
@testable import Briefly

@MainActor
struct ContentRepositoryTests {

    @Test
    func mergePrefersUserPackWhenIDsMatch() async {
        let defaults = makeIsolatedDefaults()
        let disk = InMemoryDiskStore(
            seed: [makeDTO(id: "shared_id", title: "Seed Title", subtitle: "Seed subtitle")],
            user: [makeDTO(id: "shared_id", title: "User Title", subtitle: "User subtitle")]
        )

        let repo = await makeRepository(disk: disk, defaults: defaults)

        #expect(repo.topics.count == 1)
        #expect(repo.topics.first?.id == "shared_id")
        #expect(repo.topics.first?.title == "User Title")
        #expect(repo.topics.first?.subtitle == "User subtitle")
    }

    @Test
    func mergePrefersUserPackWhenTitlesMatch() async {
        let defaults = makeIsolatedDefaults()
        let disk = InMemoryDiskStore(
            seed: [makeDTO(id: "seed_alpha", title: "Duplicate Title")],
            user: [makeDTO(id: "user_alpha", title: "duplicate title")]
        )

        let repo = await makeRepository(disk: disk, defaults: defaults)

        #expect(repo.topics.count == 1)
        #expect(repo.topics.first?.id == "user_alpha")
    }

    @Test
    func deleteThenReaddSameIDPersistsAfterRelaunch() async throws {
        let defaults = makeIsolatedDefaults()
        let pack = makeDTO(id: "topic_readd", title: "Readd Topic")
        let disk = InMemoryDiskStore(seed: [], user: [pack])

        let firstLaunch = await makeRepository(disk: disk, defaults: defaults)
        let topic = try #require(firstLaunch.topics.first)

        try await firstLaunch.deleteTopic(topic)
        #expect(firstLaunch.topics.isEmpty)

        _ = try await firstLaunch.appendOrReplaceUserPack(pack)
        #expect(firstLaunch.topics.contains(where: { $0.id == "topic_readd" }))

        let secondLaunch = await makeRepository(disk: disk, defaults: defaults)
        #expect(secondLaunch.topics.map(\.id) == ["topic_readd"])
    }

    @Test
    func deleteKeepsSavedActiveOrderStable() async throws {
        let defaults = makeIsolatedDefaults()
        let a = makeDTO(id: "alpha", title: "Alpha")
        let b = makeDTO(id: "beta", title: "Beta")
        let c = makeDTO(id: "gamma", title: "Gamma")
        let disk = InMemoryDiskStore(seed: [], user: [a, b, c])

        let orderStore = TopicOrderStore(defaults: defaults)
        orderStore.saveOrder(for: ["beta", "alpha", "gamma"])

        let statusStore = TopicStatusStore(defaults: defaults)
        let repo = ContentRepository(diskStore: disk, statusStore: statusStore, orderStore: orderStore)
        await repo.awaitInitialLoad()

        #expect(repo.topics.map(\.id) == ["beta", "alpha", "gamma"])

        let alphaTopic = try #require(repo.topics.first(where: { $0.id == "alpha" }))
        try await repo.deleteTopic(alphaTopic)

        #expect(repo.topics.map(\.id) == ["beta", "gamma"])
        #expect(orderStore.loadOrder() == ["beta", "gamma"])

        let relaunch = await makeRepository(disk: disk, defaults: defaults)
        #expect(relaunch.topics.map(\.id) == ["beta", "gamma"])
    }

    @Test
    func loadFailureBlocksMutationsInsteadOfOverwritingUserData() async {
        let defaults = makeIsolatedDefaults()
        let disk = InMemoryDiskStore(seed: [], user: [], loadUserError: ContentDiskStore.DiskError.readFailed(URLError(.cannotDecodeRawData)))
        let repo = await makeRepository(disk: disk, defaults: defaults)

        do {
            _ = try await repo.appendOrReplaceUserPack(makeDTO(id: "new_topic", title: "New Topic"))
            #expect(Bool(false))
            return
        } catch let error as ContentRepository.RepositoryError {
            guard case .userContentUnavailable = error else {
                #expect(Bool(false))
                return
            }
        } catch {
            #expect(Bool(false))
            return
        }

        #expect(await disk.saveCallCount == 0)
        #expect(repo.topics.isEmpty)
    }

    @Test
    func deleteThenReaddSameIDResetsCompletionAndProgress() async throws {
        let defaults = makeIsolatedDefaults()
        let progressDefaults = makeIsolatedDefaults()
        let progressStore = ProgressStore(defaults: progressDefaults)
        let pack = makeDTO(id: "topic_reset", title: "Reset Topic")
        let disk = InMemoryDiskStore(seed: [], user: [pack])

        let firstLaunch = await makeRepository(disk: disk, defaults: defaults, progressStore: progressStore)
        let topic = try #require(firstLaunch.topics.first)
        let section = try #require(topic.sections.first)
        let card = try #require(section.cards.first)

        progressStore.markLearned(card)
        progressStore.markSectionCompleted(section)
        firstLaunch.toggleCompleted(topic)

        try await firstLaunch.deleteTopic(topic)

        #expect(progressStore.progress(for: topic) == 0)
        #expect(!firstLaunch.isCompleted(topic))

        let readdedCandidate = try await firstLaunch.appendOrReplaceUserPack(pack)
        let readded = try #require(readdedCandidate)
        #expect(progressStore.progress(for: readded) == 0)
        #expect(!firstLaunch.isCompleted(readded))

        let secondLaunch = await makeRepository(disk: disk, defaults: defaults, progressStore: ProgressStore(defaults: progressDefaults))
        let relaunchedTopic = try #require(secondLaunch.topics.first)
        #expect(!secondLaunch.isCompleted(relaunchedTopic))
    }

    @Test
    func libraryViewModelUpdatesInProgressCountAfterLearningCard() async throws {
        let defaults = makeIsolatedDefaults()
        let progressDefaults = makeIsolatedDefaults()
        let recentDefaults = makeIsolatedDefaults()
        let progressStore = ProgressStore(defaults: progressDefaults)
        let statusStore = TopicStatusStore(defaults: defaults)
        let orderStore = TopicOrderStore(defaults: defaults)
        let disk = InMemoryDiskStore(
            seed: [],
            user: [
                makeDTO(id: "alpha", title: "Alpha"),
                makeDTO(id: "beta", title: "Beta")
            ]
        )
        let repository = ContentRepository(
            diskStore: disk,
            statusStore: statusStore,
            orderStore: orderStore,
            progressStore: progressStore,
            cloudSyncService: NoopCloudSyncService()
        )
        await repository.awaitInitialLoad()
        let recentStore = RecentTopicsStore(defaults: recentDefaults)
        let viewModel = LibraryViewModel(
            contentRepository: repository,
            progressStore: progressStore,
            statusStore: statusStore,
            recentTopicsStore: recentStore
        )

        #expect(viewModel.inProgressTopicCount == 0)

        let alpha = try #require(viewModel.activeTopics.first(where: { $0.id == "alpha" }))
        let alphaCard = try #require(alpha.sections.first?.cards.first)
        progressStore.markLearned(alphaCard)
        await Task.yield()
        await Task.yield()

        #expect(viewModel.inProgressTopicCount == 1)
        #expect(viewModel.progress(for: alpha) > 0)
    }

    @Test
    func libraryViewModelPrioritizesRecentTopicsForContinueLearning() async throws {
        let defaults = makeIsolatedDefaults()
        let progressDefaults = makeIsolatedDefaults()
        let recentDefaults = makeIsolatedDefaults()
        let progressStore = ProgressStore(defaults: progressDefaults)
        let statusStore = TopicStatusStore(defaults: defaults)
        let orderStore = TopicOrderStore(defaults: defaults)
        let disk = InMemoryDiskStore(
            seed: [],
            user: [
                makeDTO(id: "alpha", title: "Alpha"),
                makeDTO(id: "beta", title: "Beta")
            ]
        )
        let repository = ContentRepository(
            diskStore: disk,
            statusStore: statusStore,
            orderStore: orderStore,
            progressStore: progressStore,
            cloudSyncService: NoopCloudSyncService()
        )
        await repository.awaitInitialLoad()
        let recentStore = RecentTopicsStore(defaults: recentDefaults)
        let viewModel = LibraryViewModel(
            contentRepository: repository,
            progressStore: progressStore,
            statusStore: statusStore,
            recentTopicsStore: recentStore
        )

        for topic in viewModel.activeTopics {
            if let card = topic.sections.first?.cards.first {
                progressStore.markLearned(card)
            }
        }
        await Task.yield()
        await Task.yield()

        recentStore.recordOpened(topicID: "beta")
        recentStore.recordOpened(topicID: "alpha")
        await Task.yield()
        await Task.yield()

        #expect(Array(viewModel.continueLearningTopics.prefix(2)).map(\.id) == ["alpha", "beta"])
    }

    private func makeRepository(
        disk: InMemoryDiskStore,
        defaults: UserDefaults,
        progressStore: ProgressStore? = nil
    ) async -> ContentRepository {
        let statusStore = TopicStatusStore(defaults: defaults)
        let orderStore = TopicOrderStore(defaults: defaults)
        let repository = ContentRepository(
            diskStore: disk,
            statusStore: statusStore,
            orderStore: orderStore,
            progressStore: progressStore ?? .shared
        )
        await repository.awaitInitialLoad()
        return repository
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

private actor InMemoryDiskStore: ContentDiskStoring {
    private let seed: [TopicPackDTO]
    private(set) var user: [TopicPackDTO]
    private let loadUserError: Error?
    private(set) var saveCallCount = 0

    init(seed: [TopicPackDTO], user: [TopicPackDTO], loadUserError: Error? = nil) {
        self.seed = seed
        self.user = user
        self.loadUserError = loadUserError
    }

    func loadSeedPacks() async -> [TopicPackDTO] {
        seed
    }

    func loadUserPacks() async throws -> [TopicPackDTO] {
        if let loadUserError {
            throw loadUserError
        }
        return user
    }

    func saveUserPacks(_ packs: [TopicPackDTO]) async throws {
        saveCallCount += 1
        user = packs
    }
}

private actor NoopCloudSyncService: CloudTopicSyncing {
    func fetchState() async throws -> CloudTopicState? {
        nil
    }

    func saveState(_ state: CloudTopicState) async throws {}

    func ensureChangeSubscription() async {}
}
