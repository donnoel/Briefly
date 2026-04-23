import Foundation
import os

/// High-level service for generating TopicPackDTOs via backend text generation.
final class AIContentService {
    enum RequestSizing {
        static let preferredMaxSectionsPerRequest = 3
        static let preferredMaxCardsPerSectionPerRequest = 6

        static func sectionsPerRequest(for requested: Int) -> Int {
            max(1, min(requested, preferredMaxSectionsPerRequest))
        }

        static func cardsPerSection(for requested: Int) -> Int {
            max(1, min(requested, preferredMaxCardsPerSectionPerRequest))
        }
    }

    enum ServiceError: LocalizedError {
        case emptyResponse
        case invalidJSON(details: String)
        case dtoDecodingFailed(details: String)
        case validationFailed(details: String)

        var errorDescription: String? {
            switch self {
            case .emptyResponse:
                return "The generation service returned empty content. Please try again."
            case .invalidJSON:
                return "The generated content could not be read. Please try again."
            case .dtoDecodingFailed:
                return "The generated content format was unexpected. Please try again."
            case .validationFailed:
                return "The generated topic was incomplete. Please try again."
            }
        }
    }

    private static let logger = Logger(subsystem: "dn.Briefly", category: "AIContentService")

    private let transport: AIGenerationTransport
    private let maxSectionsCap = 50
    private let maxCardsPerSectionCap = 50
    private let maxFrontLength = 140
    private let maxBackLength = 220

    init(transport: AIGenerationTransport) {
        self.transport = transport
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

        let prompt = buildPrompt(
            title: title,
            difficulty: difficulty,
            language: language,
            sections: clampedSections,
            cardsPerSection: clampedCards
        )
        Self.logger.debug(
            "Starting generation: promptLength=\(prompt.count, privacy: .public) sections=\(clampedSections, privacy: .public) cardsPerSection=\(clampedCards, privacy: .public)"
        )
        let responseText = try await transport.generateText(prompt: prompt)
        let rawPreview = self.preview(responseText)
        Self.logger.debug(
            "Received backend output: length=\(responseText.count, privacy: .public) preview=\(rawPreview, privacy: .public)"
        )

        let normalizedText = normalizedJSONText(from: responseText)
        Self.logger.debug(
            "Normalized backend output: changed=\(normalizedText != responseText, privacy: .public) normalizedLength=\(normalizedText.count, privacy: .public) preview=\(self.preview(normalizedText), privacy: .public)"
        )

        let contentData = normalizedText.data(using: .utf8)

        guard let content = contentData else {
            Self.logger.error("Failed to encode normalized output as UTF-8 data.")
            throw ServiceError.emptyResponse
        }

        return try decodeDTO(
            from: content,
            maxSections: clampedSections,
            maxCardsPerSection: clampedCards
        )
    }

    private func decodeDTO(
        from data: Data,
        maxSections: Int,
        maxCardsPerSection: Int
    ) throws -> TopicPackDTO {
        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            let details = "Malformed JSON payload: \(error.localizedDescription)"
            Self.logger.error("JSON parsing failed: \(details, privacy: .public)")
            throw ServiceError.invalidJSON(details: details)
        }

        do {
            var dto = try JSONDecoder().decode(TopicPackDTO.self, from: data)
            dto = dto.trimmed(
                maxSections: maxSections,
                maxCardsPerSection: maxCardsPerSection,
                maxFrontLength: maxFrontLength,
                maxBackLength: maxBackLength
            )
            guard dto.isValid() else {
                let validationDetails = validationFailureDetails(for: dto)
                Self.logger.error("DTO validation failed: \(validationDetails, privacy: .public)")
                throw ServiceError.validationFailed(details: validationDetails)
            }
            return dto
        } catch let serviceError as ServiceError {
            throw serviceError
        } catch let decodingError as DecodingError {
            let details = describe(decodingError: decodingError)
            Self.logger.error("DTO decoding failed: \(details, privacy: .public)")
            throw ServiceError.dtoDecodingFailed(details: details)
        } catch {
            let details = "Unexpected decode failure: \(error.localizedDescription)"
            Self.logger.error("DTO decoding failed: \(details, privacy: .public)")
            throw ServiceError.dtoDecodingFailed(details: details)
        }
    }

    private func buildPrompt(
        title: String,
        difficulty: Difficulty,
        language: String,
        sections: Int,
        cardsPerSection: Int
    ) -> String {
        """
        You are an expert at creating concise Q&A flashcards.
        Return ONLY valid JSON for a TopicPackDTO with these fields:
        id, title, subtitle, category, difficulty (Beginner|Intermediate|Advanced),
        language, description, author, version,
        sections (id, title, cards),
        cards (id, front, back, tags).
        Constraints:
        - Up to \(sections) sections (aim for this count).
        - Up to \(cardsPerSection) cards per section (aim for this count).
        - Question/front <= \(maxFrontLength) characters, Answer/back <= \(maxBackLength) characters.
        - No markdown, no code fences, no extra text outside JSON.
        - IDs must be unique and URL-safe (use snake_case).
        Create a topic on "\(title)" for \(difficulty.rawValue.lowercased()) learners.
        Language: \(language).
        Difficulty guidance: \(difficultyGuidance(for: difficulty))
        """
    }

    private func difficultyGuidance(for difficulty: Difficulty) -> String {
        switch difficulty {
        case .beginner:
            return "Use simple language, one-line answers, no jargon."
        case .intermediate:
            return "Assume some background, concise but more specific terminology."
        case .advanced:
            return "Use precise terminology, include nuance and edge cases briefly."
        }
    }

    private func normalizedJSONText(from responseText: String) -> String {
        let trimmed = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutFence = stripMarkdownFence(from: trimmed)
        if let extractedObject = extractJSONObject(from: withoutFence) {
            return extractedObject
        }
        return withoutFence
    }

    private func stripMarkdownFence(from text: String) -> String {
        guard text.hasPrefix("```"), text.hasSuffix("```") else {
            return text
        }

        var content = text
        content.removeFirst(3)
        content.removeLast(3)
        content = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if content.lowercased().hasPrefix("json") {
            content = String(content.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}"),
              firstBrace <= lastBrace else {
            return nil
        }
        return String(text[firstBrace...lastBrace])
    }

    private func validationFailureDetails(for dto: TopicPackDTO) -> String {
        var reasons: [String] = []
        if dto.id.isEmpty { reasons.append("missing id") }
        if dto.title.isEmpty { reasons.append("missing title") }
        if dto.subtitle.isEmpty { reasons.append("missing subtitle") }
        if dto.category.isEmpty { reasons.append("missing category") }
        if dto.sections.isEmpty { reasons.append("no sections") }
        if !dto.sections.contains(where: { !$0.cards.isEmpty }) { reasons.append("no cards in any section") }

        if reasons.isEmpty {
            return "unknown validation failure after trimming"
        }
        return reasons.joined(separator: ", ")
    }

    private func describe(decodingError: DecodingError) -> String {
        switch decodingError {
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(codingPathDescription(context.codingPath)); \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(codingPathDescription(context.codingPath)); \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing value for \(type) at \(codingPathDescription(context.codingPath)); \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Data corrupted at \(codingPathDescription(context.codingPath)); \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error."
        }
    }

    private func codingPathDescription(_ path: [CodingKey]) -> String {
        if path.isEmpty {
            return "root"
        }
        return path.map(\.stringValue).joined(separator: ".")
    }

    private func preview(_ text: String, limit: Int = 400) -> String {
        let compact = text.replacingOccurrences(of: "\n", with: "\\n")
        return String(compact.prefix(limit))
    }
}
