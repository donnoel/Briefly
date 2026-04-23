import Foundation
import Testing
@testable import Briefly

struct FreshTopicsAssemblyTests {

    @Test
    func appendSectionsSkipsEmptySectionsAndAddsNonEmpty() {
        let dto = TopicPackDTO(
            id: "pack_a",
            title: "Feet",
            subtitle: "Basics",
            category: "Anatomy",
            difficulty: "Beginner",
            language: "en",
            description: nil,
            author: nil,
            version: nil,
            sections: [
                TopicSectionDTO(id: "s_empty", title: "Empty", cards: []),
                TopicSectionDTO(
                    id: "s_full",
                    title: "Filled",
                    cards: [
                        CardDTO(id: "c1", front: "Q", back: "A", source: nil, tags: nil)
                    ]
                )
            ]
        )

        var aggregated: [TopicSectionDTO] = []
        var sectionCounter = 0

        let result = FreshTopicsAssembly.appendSections(
            from: dto,
            baseID: "base_pack",
            into: &aggregated,
            targetSections: 3,
            sectionCounter: &sectionCounter
        )

        #expect(result.droppedEmptySections == 1)
        #expect(result.addedSections == 1)
        #expect(result.addedCards == 1)
        #expect(aggregated.count == 1)
        #expect(aggregated[0].id == "base_pack_section_0")
        #expect(aggregated[0].cards[0].id == "base_pack_section_0_card_0")
    }

    @Test
    func appendSectionsHonorsTargetSectionLimit() {
        let dto = TopicPackDTO(
            id: "pack_a",
            title: "Feet",
            subtitle: "Basics",
            category: "Anatomy",
            difficulty: "Beginner",
            language: "en",
            description: nil,
            author: nil,
            version: nil,
            sections: [
                TopicSectionDTO(id: "s1", title: "One", cards: [CardDTO(id: "c1", front: "Q1", back: "A1", source: nil, tags: nil)]),
                TopicSectionDTO(id: "s2", title: "Two", cards: [CardDTO(id: "c2", front: "Q2", back: "A2", source: nil, tags: nil)])
            ]
        )

        var aggregated: [TopicSectionDTO] = [
            TopicSectionDTO(id: "existing", title: "Existing", cards: [CardDTO(id: "ex", front: "Q", back: "A", source: nil, tags: nil)])
        ]
        var sectionCounter = 1

        let result = FreshTopicsAssembly.appendSections(
            from: dto,
            baseID: "base_pack",
            into: &aggregated,
            targetSections: 2,
            sectionCounter: &sectionCounter
        )

        #expect(result.addedSections == 1)
        #expect(aggregated.count == 2)
    }

    @Test
    func validationFailureReasonIncludesMissingCards() {
        let dto = TopicPackDTO(
            id: "pack_a",
            title: "Feet",
            subtitle: "Basics",
            category: "Anatomy",
            difficulty: "Beginner",
            language: "en",
            description: nil,
            author: nil,
            version: nil,
            sections: [TopicSectionDTO(id: "s_empty", title: "Empty", cards: [])]
        )

        let reason = FreshTopicsAssembly.validationFailureReason(for: dto)
        #expect(reason.contains("no cards in any section"))
    }
}
