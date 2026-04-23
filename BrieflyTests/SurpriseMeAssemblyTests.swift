import Foundation
import Testing
@testable import Briefly

struct SurpriseMeAssemblyTests {

    @Test
    func normalizedSectionsDropsEmptySectionsAndRenumbersIDs() {
        let sections: [TopicSectionDTO] = [
            TopicSectionDTO(id: "s_empty", title: "Empty", cards: []),
            TopicSectionDTO(
                id: "s_filled",
                title: "Filled",
                cards: [
                    CardDTO(id: "c1", front: "Q1", back: "A1", source: nil, tags: nil),
                    CardDTO(id: "c2", front: "Q2", back: "A2", source: nil, tags: nil)
                ]
            )
        ]

        let result = SurpriseMeAssembly.normalizedSections(
            from: sections,
            baseID: "topic_base",
            sectionStartIndex: 3
        )

        #expect(result.droppedEmptySections == 1)
        #expect(result.sections.count == 1)
        #expect(result.sections[0].id == "topic_base_section_3")
        #expect(result.sections[0].cards[0].id == "topic_base_section_3_card_0")
        #expect(result.sections[0].cards[1].id == "topic_base_section_3_card_1")
    }

    @Test
    func validationFailureReasonIncludesNoCardsReason() {
        let dto = TopicPackDTO(
            id: "topic_a",
            title: "Feet",
            subtitle: "Basics",
            category: "Anatomy",
            difficulty: "Beginner",
            language: "en",
            description: nil,
            author: nil,
            version: nil,
            sections: [TopicSectionDTO(id: "s1", title: "Intro", cards: [])]
        )

        let reason = SurpriseMeAssembly.validationFailureReason(for: dto)
        #expect(reason.contains("no cards in any section"))
    }
}
