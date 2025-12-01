import Foundation
import Combine

/// Allows lightweight editing of a generated pack before saving.
final class GeneratedPackReviewViewModel: ObservableObject {
    @Published var title: String
    @Published var subtitle: String
    @Published var category: String
    @Published var difficulty: Difficulty
    @Published var description: String
    @Published var sections: [EditableSection]

    struct EditableSection: Identifiable {
        let id: String
        var title: String
        var cards: [EditableCard]
    }

    struct EditableCard: Identifiable {
        let id: String
        var front: String
        var back: String
    }

    init(pack: TopicPackDTO) {
        self.title = pack.title
        self.subtitle = pack.subtitle
        self.category = pack.category
        self.difficulty = Difficulty(rawValue: pack.difficulty) ?? .beginner
        self.description = pack.description ?? ""
        self.sections = pack.sections.map { section in
            EditableSection(
                id: section.id,
                title: section.title,
                cards: section.cards.map { card in
                    EditableCard(id: card.id, front: card.front, back: card.back)
                }
            )
        }
    }

    func toDTO(original: TopicPackDTO) -> TopicPackDTO {
        TopicPackDTO(
            id: original.id,
            title: title,
            subtitle: subtitle,
            category: category,
            difficulty: difficulty.rawValue,
            language: original.language,
            description: description.isEmpty ? nil : description,
            author: original.author,
            version: original.version,
            sections: sections.map { section in
                TopicSectionDTO(
                    id: section.id,
                    title: section.title,
                    cards: section.cards.map { card in
                        CardDTO(
                            id: card.id,
                            front: card.front,
                            back: card.back,
                            source: nil,
                            tags: nil
                        )
                    }
                )
            }
        )
    }
}
