import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published private(set) var learnedCardIDs: Set<String> = []

    private let storageKey = "Briefly.learnedCardIDs"
    private let saveDebounceInterval: TimeInterval = 0.5
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var backgroundObserver: NSObjectProtocol?

    private init() {
        load()
        observeAppBackground()
    }

    // MARK: - Public

    func markLearned(_ card: Card) {
        learnedCardIDs.insert(card.id)
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

    // MARK: - Persistence

    private func load() {
        let defaults = UserDefaults.standard
        if let array = defaults.array(forKey: storageKey) as? [String] {
            learnedCardIDs = Set(array)
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(Array(learnedCardIDs), forKey: storageKey)
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

    deinit {
        pendingSaveWorkItem?.cancel()
        backgroundObserver.map(NotificationCenter.default.removeObserver)
        Task { @MainActor in
            self.flushPendingSaves()
        }
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
