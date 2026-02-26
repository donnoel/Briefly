import Foundation

protocol ContentDiskStoring {
    func loadSeedPacks() -> [TopicPackDTO]
    func loadUserPacks() -> [TopicPackDTO]
    func saveUserPacks(_ packs: [TopicPackDTO]) throws
}

/// Reads/writes topic packs to disk so AI-generated or edited content can persist.
final class ContentDiskStore: ContentDiskStoring {
    private let fileManager: FileManager
    private let userFilename = "user_content.json"
    private let seedResourceName = "seed_content"

    enum DiskError: LocalizedError {
        case userDirectoryUnavailable
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .userDirectoryUnavailable:
                return "Unable to access documents directory."
            case .writeFailed(let error):
                return "Failed to save your topics: \(error.localizedDescription)"
            }
        }
    }

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Loading

    func loadSeedPacks() -> [TopicPackDTO] {
        guard let url = Bundle.main.url(forResource: seedResourceName, withExtension: "json") else {
            return []
        }
        return load(from: url)
    }

    func loadUserPacks() -> [TopicPackDTO] {
        guard let url = userContentURL() else { return [] }
        return load(from: url)
    }

    // MARK: - Saving

    func saveUserPacks(_ packs: [TopicPackDTO]) throws {
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

    private func load(from url: URL) -> [TopicPackDTO] {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([TopicPackDTO].self, from: data)
        } catch {
            print("ContentDiskStore load failed for \(url.lastPathComponent): \(error)")
            return []
        }
    }

    private func userContentURL() -> URL? {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents.appendingPathComponent(userFilename)
    }
}
