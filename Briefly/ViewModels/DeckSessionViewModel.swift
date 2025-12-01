import Foundation
import Combine

final class DeckSessionViewModel: ObservableObject {
    let topic: TopicPack
    let section: TopicSection

    @Published private(set) var cards: [Card]
    @Published private(set) var currentIndex: Int = 0
    @Published var isShowingBack: Bool = false
    @Published var isSectionComplete: Bool = false

    private let progressStore: ProgressStore

    var currentCard: Card? {
        guard cards.indices.contains(currentIndex), !isSectionComplete else { return nil }
        return cards[currentIndex]
    }

    init(topic: TopicPack, section: TopicSection, progressStore: ProgressStore) {
        self.topic = topic
        self.section = section
        self.cards = section.cards
        self.progressStore = progressStore
    }

    // MARK: - Intent

    func reveal() {
        isShowingBack = true
    }

    func markKnownAndAdvance() {
        if let card = currentCard {
            progressStore.markLearned(card)
        }
        goToNextCard()
    }

    func markReviewAndAdvance() {
        // Reset to front and stay on the same card so the user can review it again.
        isShowingBack = false
    }

    private func goToNextCard() {
        isShowingBack = false
        if currentIndex < cards.count - 1 {
            currentIndex += 1
        } else {
            isSectionComplete = true
            currentIndex = cards.count
        }
    }

    func restart() {
        currentIndex = 0
        isShowingBack = false
        isSectionComplete = false
    }
}
