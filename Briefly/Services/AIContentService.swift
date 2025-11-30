import Foundation

/// High-level service for generating TopicPackDTOs via OpenAI.
final class AIContentService {
    enum ServiceError: Error {
        case decodingFailed
        case emptyResponse
    }

    private let client: OpenAIClient

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
            You are an expert at creating concise Q&A flashcards. Return JSON for a TopicPackDTO with:
            id, title, subtitle, category, difficulty (Beginner|Intermediate|Advanced),
            estimatedMinutes, language, description, author, version, sections (with id, title, cards), and cards (id, front, back, tags).
            Keep 2-3 sections, 3-5 cards each, terse wording, no markdown.
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
            return try JSONDecoder().decode(TopicPackDTO.self, from: content)
        } catch {
            throw ServiceError.decodingFailed
        }
    }
}
