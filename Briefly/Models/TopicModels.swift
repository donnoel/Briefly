import Foundation

struct Card: Identifiable, Hashable {
    let id: String
    let front: String
    let back: String
}

struct TopicSection: Identifiable, Hashable {
    let id: String
    let title: String
    let cards: [Card]
}

enum Difficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

struct TopicPack: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let difficulty: Difficulty
    let estimatedMinutes: Int
    let sections: [TopicSection]
}
