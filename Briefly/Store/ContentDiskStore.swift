import Foundation

/// Reads/writes topic packs to disk so AI-generated or edited content can persist.
final class ContentDiskStore {
    private let fileManager: FileManager
    private let userFilename = "user_content.json"
    private let seedResourceName = "seed_content"

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

    func saveUserPacks(_ packs: [TopicPackDTO]) {
        guard let url = userContentURL() else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(packs)

            let directory = url.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            // In this first pass we silently fail; later we can surface errors to the UI.
            print("ContentDiskStore saveUserPacks failed: \(error)")
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
