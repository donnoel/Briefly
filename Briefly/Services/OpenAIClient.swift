import Foundation

/// Minimal OpenAI chat client for JSON-mode completions.
final class OpenAIClient {
    struct Configuration {
        let apiKeyProvider: () -> String?
        let model: String
        let baseURL: URL

        init(
            apiKeyProvider: @escaping () -> String?,
            model: String = "gpt-4o-mini",
            baseURL: URL = URL(string: "https://api.openai.com/v1")!
        ) {
            self.apiKeyProvider = apiKeyProvider
            self.model = model
            self.baseURL = baseURL
        }
    }

    enum ClientError: LocalizedError {
        case missingAPIKey
        case badResponse(status: Int, body: String)
        case decodingFailed
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing OpenAI API key."
            case .badResponse(let status, let body):
                return "OpenAI responded with status \(status): \(body)"
            case .decodingFailed:
                return "Failed to decode OpenAI response."
            case .transport(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    private let config: Configuration
    private let urlSession: URLSession

    init(configuration: Configuration, urlSession: URLSession = .shared) {
        self.config = configuration
        self.urlSession = urlSession
    }

    func chatCompletion(
        messages: [OpenAIChatMessage],
        responseFormat: OpenAIResponseFormat = OpenAIResponseFormat(type: "json_object"),
        temperature: Double = 0.5
    ) async throws -> OpenAIChatResponse {
        guard let apiKey = config.apiKeyProvider(), !apiKey.isEmpty else {
            throw ClientError.missingAPIKey
        }

        var request = URLRequest(url: config.baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = OpenAIChatRequest(
            model: config.model,
            messages: messages,
            temperature: temperature,
            response_format: responseFormat
        )

        request.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ClientError.badResponse(status: -1, body: "No HTTP response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("OpenAI error \(http.statusCode): \(body)")
                throw ClientError.badResponse(status: http.statusCode, body: body)
            }

            return try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        } catch let clientError as ClientError {
            throw clientError
        } catch let decodingError as DecodingError {
            print("OpenAI decode error: \(decodingError)")
            throw ClientError.decodingFailed
        } catch {
            throw ClientError.transport(error)
        }
    }
}

// MARK: - API Models

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double
    let response_format: OpenAIResponseFormat
}

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponseFormat: Codable {
    let type: String

    static let jsonObject = OpenAIResponseFormat(type: "json_object")
}

struct OpenAIChatResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}
