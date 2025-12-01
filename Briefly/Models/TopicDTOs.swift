import Foundation

// Codable representations for loading/saving topic packs.
struct CardDTO: Codable, Hashable {
    let id: String
    let front: String
    let back: String
    let source: String?
    let tags: [String]?

    func toModel() -> Card {
        Card(
            id: id,
            front: front,
            back: back
        )
    }
}

struct TopicSectionDTO: Codable, Hashable {
    let id: String
    let title: String
    let cards: [CardDTO]

    func toModel() -> TopicSection {
        TopicSection(
            id: id,
            title: title,
            cards: cards.map { $0.toModel() }
        )
    }
}

struct TopicPackDTO: Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let difficulty: String
    let estimatedMinutes: Int
    let language: String?
    let description: String?
    let author: String?
    let version: String?
    let sections: [TopicSectionDTO]

    func toModel() -> TopicPack? {
        guard let difficultyEnum = Difficulty(rawValue: difficulty) else {
            return nil
        }

        return TopicPack(
            id: id,
            title: title,
            subtitle: subtitle,
            category: category,
            difficulty: difficultyEnum,
            estimatedMinutes: estimatedMinutes,
            sections: sections.map { $0.toModel() }
        )
    }

    // Basic validation to guard against empty generations.
    func isValid() -> Bool {
        guard !id.isEmpty,
              !title.isEmpty,
              !subtitle.isEmpty,
              !category.isEmpty,
              !sections.isEmpty else { return false }

        let hasCards = sections.contains { !$0.cards.isEmpty }
        return hasCards
    }

    func trimmed(
        maxSections: Int,
        maxCardsPerSection: Int,
        maxFrontLength: Int,
        maxBackLength: Int
    ) -> TopicPackDTO {
        let limitedSections = sections.prefix(maxSections).map { section in
            let limitedCards = section.cards.prefix(maxCardsPerSection).map { card -> CardDTO in
                let front = String(card.front.prefix(maxFrontLength))
                let back = String(card.back.prefix(maxBackLength))
                return CardDTO(id: card.id, front: front, back: back, source: card.source, tags: card.tags)
            }
            return TopicSectionDTO(id: section.id, title: section.title, cards: Array(limitedCards))
        }

        return TopicPackDTO(
            id: id,
            title: title,
            subtitle: subtitle,
            category: category,
            difficulty: difficulty,
            estimatedMinutes: estimatedMinutes,
            language: language,
            description: description,
            author: author,
            version: version,
            sections: Array(limitedSections)
        )
    }
}
