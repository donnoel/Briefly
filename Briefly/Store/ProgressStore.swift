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
        let allCards = topic.sections.flatMap(\.cards)
        guard !allCards.isEmpty else { return 0 }

        let learnedCount = allCards.filter { learnedCardIDs.contains($0.id) }.count
        return Double(learnedCount) / Double(allCards.count)
    }

    func isSectionCompleted(_ section: TopicSection) -> Bool {
        completedSectionIDs.contains(section.id)
    }

    func resetProgress(for topic: TopicPack) {
        let cardIDs = Set(topic.sections.flatMap(\.cards).map(\.id))
        let sectionIDs = Set(topic.sections.map(\.id))

        learnedCardIDs.subtract(cardIDs)
        completedSectionIDs.subtract(sectionIDs)
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
