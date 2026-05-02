import Foundation
import Combine

@MainActor
final class DeckSessionViewModel: ObservableObject {
    struct QuizOption: Identifiable, Hashable {
        let id: String
        let text: String
        let isCorrect: Bool
    }

    let topic: TopicPack
    let section: TopicSection

    @Published private(set) var cards: [Card]
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isShowingBack: Bool = false
    @Published var isSectionComplete: Bool = false
    @Published private(set) var currentAnswerOptions: [QuizOption] = []
    @Published private(set) var selectedAnswerID: String?
    @Published private(set) var hasSubmittedCurrentQuestion: Bool = false
    @Published private(set) var wasSelectedAnswerCorrect: Bool = false
    @Published private(set) var correctAnswerCount: Int = 0

    private let progressStore: ProgressStore
    private let statusStore: TopicStatusStore
    private var quizOptionsByCardID: [String: [QuizOption]] = [:]

    var currentCard: Card? {
        guard cards.indices.contains(currentIndex), !isSectionComplete else { return nil }
        return cards[currentIndex]
    }

    var totalQuestionCount: Int {
        cards.count
    }

    var scorePercent: Int {
        guard totalQuestionCount > 0 else { return 0 }
        let percent = (Double(correctAnswerCount) / Double(totalQuestionCount)) * 100.0
        return Int(percent.rounded())
    }

    init(
        topic: TopicPack,
        section: TopicSection,
        progressStore: ProgressStore,
        statusStore: TopicStatusStore? = nil
    ) {
        self.topic = topic
        self.section = section
        self.cards = section.cards
        self.progressStore = progressStore
        self.statusStore = statusStore ?? .shared
        self.quizOptionsByCardID = Self.buildQuizOptionsByCardID(topic: topic, section: section)
        loadCurrentQuestionState()
        updateTopicCompletionIfNeeded()
    }

    // MARK: - Intent

    func submitAnswer(optionID: String) {
        guard !hasSubmittedCurrentQuestion else { return }
        guard let selectedOption = currentAnswerOptions.first(where: { $0.id == optionID }) else { return }

        selectedAnswerID = optionID
        hasSubmittedCurrentQuestion = true
        wasSelectedAnswerCorrect = selectedOption.isCorrect
        isShowingBack = true

        if selectedOption.isCorrect {
            correctAnswerCount += 1
            if let card = currentCard {
                progressStore.markLearned(card)
            }
        }
    }

    func advanceAfterSubmission() {
        guard hasSubmittedCurrentQuestion else { return }
        goToNextCard()
    }

    private func goToNextCard() {
        isShowingBack = false
        if currentIndex < cards.count - 1 {
            currentIndex += 1
            loadCurrentQuestionState()
        } else {
            isSectionComplete = true
            currentIndex = cards.count
            currentAnswerOptions = []
            selectedAnswerID = nil
            hasSubmittedCurrentQuestion = false
            wasSelectedAnswerCorrect = false
            progressStore.markSectionCompleted(section)
            updateTopicCompletionIfNeeded()
        }
    }

    func restart() {
        currentIndex = 0
        isShowingBack = false
        isSectionComplete = false
        correctAnswerCount = 0
        loadCurrentQuestionState()
    }

    private func updateTopicCompletionIfNeeded() {
        let allSectionsDone = topic.sections.allSatisfy { section in
            progressStore.isSectionCompleted(section)
        }
        if allSectionsDone {
            statusStore.markCompleted(topic.id)
        }
    }

    private func loadCurrentQuestionState() {
        guard let card = currentCard else {
            currentAnswerOptions = []
            selectedAnswerID = nil
            hasSubmittedCurrentQuestion = false
            wasSelectedAnswerCorrect = false
            return
        }

        currentAnswerOptions = quizOptionsByCardID[card.id] ?? []
        selectedAnswerID = nil
        hasSubmittedCurrentQuestion = false
        wasSelectedAnswerCorrect = false
    }

    private static func buildQuizOptionsByCardID(topic: TopicPack, section: TopicSection) -> [String: [QuizOption]] {
        var optionsByCardID: [String: [QuizOption]] = [:]
        let topicBackPool = topic.sections.flatMap(\.cards).map(\.back)
        let uniqueTopicBackPool = Array(NSOrderedSet(array: topicBackPool)) as? [String] ?? topicBackPool

        for card in section.cards {
            let sectionDistractors = section.cards
                .filter { $0.id != card.id }
                .map(\.back)
                .filter { $0 != card.back }
            let uniqueSectionDistractors = Array(NSOrderedSet(array: sectionDistractors)) as? [String] ?? sectionDistractors

            let topicFallbackDistractors = uniqueTopicBackPool.filter { $0 != card.back && !uniqueSectionDistractors.contains($0) }

            var distractors = Array(uniqueSectionDistractors.prefix(3))
            if distractors.count < 3 {
                let needed = 3 - distractors.count
                distractors.append(contentsOf: topicFallbackDistractors.prefix(needed))
            }

            if distractors.count < 3 {
                let remainingCandidates = uniqueTopicBackPool.filter { $0 != card.back }
                var candidateIndex = 0
                while distractors.count < 3, !remainingCandidates.isEmpty {
                    distractors.append(remainingCandidates[candidateIndex % remainingCandidates.count])
                    candidateIndex += 1
                }
            }

            let correctOption = QuizOption(id: "\(card.id)-correct", text: card.back, isCorrect: true)
            let distractorOptions = distractors.prefix(3).enumerated().map { index, text in
                QuizOption(id: "\(card.id)-distractor-\(index)", text: text, isCorrect: false)
            }

            let seededValue = stableStringSeed("\(topic.id)|\(section.id)|\(card.id)")
            let shuffled = ([correctOption] + distractorOptions).sorted {
                Self.stableOptionSortScore(seed: seededValue, optionID: $0.id)
                    < Self.stableOptionSortScore(seed: seededValue, optionID: $1.id)
            }
            optionsByCardID[card.id] = shuffled
        }

        return optionsByCardID
    }

    private static func stableOptionSortScore(seed: Int, optionID: String) -> Int {
        abs((seed &* 31) ^ stableStringSeed(optionID))
    }

    private static func stableStringSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            partialResult = (partialResult &* 33) &+ Int(scalar.value)
        }
    }
}
