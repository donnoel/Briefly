import Foundation

/// High-level service for generating TopicPackDTOs via OpenAI.
final class AIContentService {
    enum ServiceError: Error {
        case decodingFailed
        case emptyResponse
        case invalidResponse
    }

    private let client: OpenAIClient
    private let maxSections = 3
    private let maxCardsPerSection = 5
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
        estimatedMinutes: Int = 20
    ) async throws -> TopicPackDTO {
        let system = OpenAIChatMessage(
            role: "system",
            content: """
            You are an expert at creating concise Q&A flashcards.
            Return ONLY valid JSON for a TopicPackDTO with fields:
            id, title, subtitle, category, difficulty (Beginner|Intermediate|Advanced),
            estimatedMinutes, language, description, author, version,
            sections (id, title, cards),
            cards (id, front, back, tags).
            Constraints:
            - 2 to 3 sections max.
            - 3 to 5 cards per section.
            - Question/front <= \(maxFrontLength) characters, Answer/back <= \(maxBackLength) characters.
            - No markdown, no code fences, no extra text outside JSON.
            - IDs must be unique and URL-safe (use snake_case).
            """
        )

        let user = OpenAIChatMessage(
            role: "user",
            content: """
            Create a topic on "\(title)" for \(difficulty.rawValue.lowercased()) learners.
            Language: \(language). Target minutes: \(estimatedMinutes).
            """
        )

        let response = try await client.chatCompletion(messages: [system, user])

        guard let content = response.choices.first?.message.content.data(using: .utf8) else {
            throw ServiceError.emptyResponse
        }

        do {
            var dto = try JSONDecoder().decode(TopicPackDTO.self, from: content)
            dto = dto.trimmed(
                maxSections: maxSections,
                maxCardsPerSection: maxCardsPerSection,
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
