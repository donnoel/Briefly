import Foundation

protocol ContentDiskStoring: Sendable {
    func loadSeedPacks() async -> [TopicPackDTO]
    func loadUserPacks() async throws -> [TopicPackDTO]
    func saveUserPacks(_ packs: [TopicPackDTO]) async throws
}

/// Reads/writes topic packs to disk so AI-generated or edited content can persist.
actor ContentDiskStore: ContentDiskStoring {
    private let fileManager: FileManager = .default
    private let userFilename = "user_content.json"
    private let seedResourceName = "seed_content"

    enum DiskError: LocalizedError {
        case readFailed(Error)
        case userDirectoryUnavailable
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .readFailed(let error):
                return "Failed to load your saved topics: \(error.localizedDescription)"
            case .userDirectoryUnavailable:
                return "Unable to access documents directory."
            case .writeFailed(let error):
                return "Failed to save your topics: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Loading

    func loadSeedPacks() async -> [TopicPackDTO] {
        if ProcessInfo.processInfo.arguments.contains("-uiTestSeedTopic") {
            return Self.uiTestSeedPacks
        }

        guard let url = Bundle.main.url(forResource: seedResourceName, withExtension: "json") else {
            return []
        }
        do {
            return try decodePacks(from: url)
        } catch {
            assertionFailure("Failed to load seed packs: \(error)")
            return []
        }
    }

    func loadUserPacks() async throws -> [TopicPackDTO] {
        guard let url = userContentURL() else { return [] }
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        do {
            return try decodePacks(from: url)
        } catch {
            throw DiskError.readFailed(error)
        }
    }

    // MARK: - Saving

    func saveUserPacks(_ packs: [TopicPackDTO]) async throws {
        guard let url = userContentURL() else { throw DiskError.userDirectoryUnavailable }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(packs)

            let directory = url.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw DiskError.writeFailed(error)
        }
    }

    // MARK: - Helpers

    private func decodePacks(from url: URL) throws -> [TopicPackDTO] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([TopicPackDTO].self, from: data)
    }

    private func userContentURL() -> URL? {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents.appendingPathComponent(userFilename)
    }

    private static var uiTestSeedPacks: [TopicPackDTO] {
        [
            TopicPackDTO(
                id: "ui_test_topic_1",
                title: "UI Test Topic",
                subtitle: "Seeded topic for deterministic UI performance tests.",
                category: "General",
                difficulty: "Beginner",
                language: "en",
                description: nil,
                author: nil,
                version: "1",
                sections: [
                    TopicSectionDTO(
                        id: "ui_test_section_1",
                        title: "Section 1",
                        cards: [
                            CardDTO(
                                id: "ui_test_card_1",
                                front: "Question?",
                                back: "Answer.",
                                source: nil,
                                tags: nil
                            )
                        ]
                    )
                ]
            )
        ]
    }
}
