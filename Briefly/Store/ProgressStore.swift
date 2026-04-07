import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published private(set) var learnedCardIDs: Set<String> = []
    @Published private(set) var completedSectionIDs: Set<String> = []

    private let defaults: UserDefaults
    private let storageKey = "Briefly.learnedCardIDs"
    private let sectionKey = "Briefly.completedSectionIDs"
    private let saveDebounceInterval: TimeInterval = 0.5
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var backgroundObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        observeAppBackground()
    }

    // MARK: - Public

    func markLearned(_ card: Card) {
        learnedCardIDs.insert(card.id)
        scheduleSave()
    }

    func markSectionCompleted(_ section: TopicSection) {
        completedSectionIDs.insert(section.id)
        scheduleSave()
    }

    func isLearned(_ card: Card) -> Bool {
        learnedCardIDs.contains(card.id)
    }

    func progress(for topic: TopicPack) -> Double {
        var totalCardCount = 0
        var learnedCardCount = 0

        for section in topic.sections {
            for card in section.cards {
                totalCardCount += 1
                if learnedCardIDs.contains(card.id) {
                    learnedCardCount += 1
                }
            }
        }

        guard totalCardCount > 0 else { return 0 }
        return Double(learnedCardCount) / Double(totalCardCount)
    }

    func isSectionCompleted(_ section: TopicSection) -> Bool {
        completedSectionIDs.contains(section.id)
    }

    func resetProgress(for topic: TopicPack) {
        for section in topic.sections {
            completedSectionIDs.remove(section.id)
            for card in section.cards {
                learnedCardIDs.remove(card.id)
            }
        }
        flushPendingSaves()
    }

    func replace(learnedCardIDs: Set<String>, completedSectionIDs: Set<String>) {
        guard self.learnedCardIDs != learnedCardIDs || self.completedSectionIDs != completedSectionIDs else { return }
        self.learnedCardIDs = learnedCardIDs
        self.completedSectionIDs = completedSectionIDs
        flushPendingSaves()
    }

    // MARK: - Persistence

    private func load() {
        if let array = defaults.array(forKey: storageKey) as? [String] {
            learnedCardIDs = Set(array)
        }
        if let array = defaults.array(forKey: sectionKey) as? [String] {
            completedSectionIDs = Set(array)
        }
    }

    private func save() {
        defaults.set(Array(learnedCardIDs), forKey: storageKey)
        defaults.set(Array(completedSectionIDs), forKey: sectionKey)
    }

    private func scheduleSave() {
        pendingSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.save()
            }
        }
        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }

    isolated deinit {
        backgroundObserver.map(NotificationCenter.default.removeObserver)
        flushPendingSaves()
    }

    private func observeAppBackground() {
        #if canImport(UIKit)
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.flushPendingSaves()
            }
        }
        #endif
    }

    private func flushPendingSaves() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        save()
    }
}
