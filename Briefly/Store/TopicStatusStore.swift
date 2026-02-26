import Foundation
import Combine

@MainActor
final class TopicStatusStore: ObservableObject {
    static let shared = TopicStatusStore()

    private let completedKey = "Briefly.completedTopicIDs"
    private let deletedKey = "Briefly.deletedTopicIDs"
    private let defaults: UserDefaults

    @Published private(set) var completedIDs: Set<String> = []
    @Published private(set) var deletedIDs: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func markCompleted(_ id: String) {
        completedIDs.insert(id)
        save()
    }

    func toggleCompleted(_ id: String) {
        if completedIDs.contains(id) {
            completedIDs.remove(id)
        } else {
            completedIDs.insert(id)
        }
        save()
    }

    func isCompleted(_ id: String) -> Bool {
        completedIDs.contains(id)
    }

    func markDeleted(_ id: String) {
        deletedIDs.insert(id)
        save()
    }

    func unmarkDeleted(_ id: String) {
        guard deletedIDs.remove(id) != nil else { return }
        save()
    }

    func isDeleted(_ id: String) -> Bool {
        deletedIDs.contains(id)
    }

    private func load() {
        if let array = defaults.array(forKey: completedKey) as? [String] {
            completedIDs = Set(array)
        }
        if let array = defaults.array(forKey: deletedKey) as? [String] {
            deletedIDs = Set(array)
        }
    }

    private func save() {
        defaults.set(Array(completedIDs), forKey: completedKey)
        defaults.set(Array(deletedIDs), forKey: deletedKey)
    }
}
