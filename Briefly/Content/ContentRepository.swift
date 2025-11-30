import Foundation

final class ContentRepository {
    static let shared = ContentRepository()

    private(set) var topics: [TopicPack] = []
    private let diskStore: ContentDiskStore

    private init(diskStore: ContentDiskStore = ContentDiskStore()) {
        self.diskStore = diskStore
        loadContent()
    }

    // MARK: - Loading

    private func loadContent() {
        let seedDTOs = diskStore.loadSeedPacks()
        let userDTOs = diskStore.loadUserPacks()
        let allDTOs = seedDTOs + userDTOs

        let loadedTopics = allDTOs.compactMap { $0.toModel() }
        topics = loadedTopics.isEmpty ? Self.sampleTopics : loadedTopics
    }

    // MARK: - Sample Content

    private static let sampleTopics: [TopicPack] = [
        TopicPack(
            id: "astronomy_foundations",
            title: "Astronomy – Foundations",
            subtitle: "Understand the cosmos in small steps.",
            category: "Science",
            difficulty: .beginner,
            estimatedMinutes: 45,
            sections: [
                TopicSection(
                    id: "astro_scale",
                    title: "Scale of the Universe",
                    cards: [
                        Card(
                            id: "astro_scale_au",
                            front: "What is an astronomical unit (AU)?",
                            back: "The average distance between Earth and the Sun (~150 million km)."
                        ),
                        Card(
                            id: "astro_scale_ly",
                            front: "What is a light-year?",
                            back: "The distance light travels in one year, about 9.46 trillion km."
                        ),
                        Card(
                            id: "astro_scale_galaxy",
                            front: "What is a galaxy?",
                            back: "A massive system of stars, gas, dust, and dark matter bound together by gravity."
                        )
                    ]
                ),
                TopicSection(
                    id: "astro_stars",
                    title: "Stars & Galaxies",
                    cards: [
                        Card(
                            id: "astro_star_def",
                            front: "What is a star?",
                            back: "A huge ball of hot, glowing gas held together by gravity and powered by nuclear fusion."
                        ),
                        Card(
                            id: "astro_milky_way",
                            front: "What is the Milky Way?",
                            back: "The galaxy that contains our Solar System, with hundreds of billions of stars."
                        )
                    ]
                )
            ]
        ),
        TopicPack(
            id: "logic_basics",
            title: "Logic – Basics",
            subtitle: "Learn how arguments really work.",
            category: "Thinking",
            difficulty: .beginner,
            estimatedMinutes: 30,
            sections: [
                TopicSection(
                    id: "logic_argument",
                    title: "Arguments & Claims",
                    cards: [
                        Card(
                            id: "logic_argument_def",
                            front: "What is an argument in logic?",
                            back: "A set of statements where some (premises) are offered as support for another (the conclusion)."
                        ),
                        Card(
                            id: "logic_premise",
                            front: "What is a premise?",
                            back: "A statement that provides a reason or evidence for accepting a conclusion."
                        )
                    ]
                ),
                TopicSection(
                    id: "logic_fallacies",
                    title: "Common Fallacies",
                    cards: [
                        Card(
                            id: "logic_strawman",
                            front: "What is a straw man fallacy?",
                            back: "Misrepresenting an opponent’s position to make it easier to attack instead of addressing their actual argument."
                        ),
                        Card(
                            id: "logic_ad_hominem",
                            front: "What is an ad hominem?",
                            back: "Attacking the person making the argument rather than the argument itself."
                        )
                    ]
                )
            ]
        )
    ]
}
