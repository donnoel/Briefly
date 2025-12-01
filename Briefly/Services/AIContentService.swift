import Foundation

/// High-level service for generating TopicPackDTOs via OpenAI.
final class AIContentService {
    enum ServiceError: Error {
        case decodingFailed
        case emptyResponse
        case invalidResponse
    }

    private let client: OpenAIClient
    private let maxSectionsCap = 50
    private let maxCardsPerSectionCap = 50
    private let maxFrontLength = 160
    private let maxBackLength = 260

    init(client: OpenAIClient) {
        self.client = client
    }

    /// Generates a TopicPackDTO from a brief prompt and difficulty.
    func generateTopicPack(
        title: String,
        difficulty: Difficulty,
        language: String = "en",
        targetSections: Int = 3,
        targetCardsPerSection: Int = 5
    ) async throws -> TopicPackDTO {
        let clampedSections = max(1, min(targetSections, maxSectionsCap))
        let clampedCards = max(1, min(targetCardsPerSection, maxCardsPerSectionCap))

        let system = OpenAIChatMessage(
            role: "system",
            content: """
            You are an expert at creating concise Q&A flashcards.
            Return ONLY valid JSON for a TopicPackDTO with fields:
            id, title, subtitle, category, difficulty (Beginner|Intermediate|Advanced),
            language, description, author, version,
            sections (id, title, cards),
            cards (id, front, back, tags).
            Constraints:
            - Up to \(clampedSections) sections (aim for this count).
            - Up to \(clampedCards) cards per section (aim for this count).
            - Question/front <= \(maxFrontLength) characters, Answer/back <= \(maxBackLength) characters.
            - No markdown, no code fences, no extra text outside JSON.
            - IDs must be unique and URL-safe (use snake_case).
            """
        )

        let user = OpenAIChatMessage(
            role: "user",
            content: """
            Create a topic on "\(title)" for \(difficulty.rawValue.lowercased()) learners.
            Language: \(language).
            Aim for about \(clampedSections) sections with \(clampedCards) cards each.
            """
        )

        let response = try await client.chatCompletion(messages: [system, user])

        guard let content = response.choices.first?.message.content.data(using: .utf8) else {
            throw ServiceError.emptyResponse
        }

        do {
            var dto = try JSONDecoder().decode(TopicPackDTO.self, from: content)
            dto = dto.trimmed(
                maxSections: clampedSections,
                maxCardsPerSection: clampedCards,
                maxFrontLength: maxFrontLength,
                maxBackLength: maxBackLength
            )
            guard dto.isValid() else { throw ServiceError.invalidResponse }
            return dto
        } catch {
            throw ServiceError.decodingFailed
        }
    }
}
