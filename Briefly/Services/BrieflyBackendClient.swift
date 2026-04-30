import Foundation
import os

protocol AIGenerationTransport {
    func generateText(prompt: String) async throws -> String
}

/// Thin backend client for Briefly generation and async job endpoints.
final class BrieflyBackendClient: AIGenerationTransport, AIGenerationJobTransport {
    private static let logger = Logger(subsystem: "dn.Briefly", category: "BrieflyBackendClient")
    private static let clientRequestIDHeader = "X-Client-Request-ID"

    struct Configuration {
        let generateEndpoint: URL
        let jobsEndpoint: URL
        let timeout: TimeInterval

        init(
            generateEndpoint: URL = URL(string: "https://sxbgtlgsaf.execute-api.us-west-2.amazonaws.com/prod/generate")!,
            jobsEndpoint: URL = URL(string: "https://sxbgtlgsaf.execute-api.us-west-2.amazonaws.com/prod/jobs")!,
            timeout: TimeInterval = 60
        ) {
            self.generateEndpoint = generateEndpoint
            self.jobsEndpoint = jobsEndpoint
            self.timeout = timeout
        }
    }

    enum ClientError: LocalizedError {
        case badResponse(status: Int, body: String)
        case invalidResponse
        case requestTimedOut
        case jobNotFound(id: String)
        case jobNotReady
        case jobFailed(reason: String)
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case .badResponse(let status, _):
                switch status {
                case 400:
                    return "The request could not be processed. Try a clearer topic title."
                case 401, 403:
                    return "Generation service authorization failed. Please try again shortly."
                case 404:
                    return "The generation job could not be found. Please try again."
                case 409:
                    return "The generation job is still in progress. Please wait and try again."
                case 429:
                    return "Too many generation requests right now. Please wait a moment and try again."
                case 500 ... 599:
                    return "The generation service is temporarily unavailable. Please try again."
                default:
                    return "Generation failed with status \(status). Please try again."
                }
            case .invalidResponse:
                return "The generation service returned an unexpected response. Please try again."
            case .requestTimedOut:
                return "The generation request timed out. Try again or request fewer sections."
            case .jobNotFound:
                return "The generation job could not be found. Please try again."
            case .jobNotReady:
                return "The generation job is still in progress. Please wait and try again."
            case .jobFailed(let reason):
                return "The generation job failed: \(reason)"
            case .transport(let error):
                if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                    return "You appear to be offline. Check your connection and try again."
                }
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    private struct GenerateRequestBody: Encodable {
        let prompt: String
    }

    private struct GenerateResponseBody: Decodable {
        let ok: Bool?
        let outputText: String?
    }

    private struct CreateJobResponseBody: Decodable {
        let jobId: String
        let status: String
        let statusUrl: String?
        let resultUrl: String?
    }

    private struct JobStatusResponseBody: Decodable {
        let jobId: String
        let status: String
        let progress: ProgressBody?
        let error: JobErrorBody?
        let createdAt: Int?
        let updatedAt: Int?

        struct ProgressBody: Decodable {
            let totalChunks: Int?
            let completedChunks: Int?
            let failedChunks: Int?
            let currentStage: String?
            let assembledSections: Int?
        }

        struct JobErrorBody: Decodable {
            let code: String?
            let message: String?
            let retryable: Bool?
            let stage: String?
        }
    }

    private let config: Configuration
    private let urlSession: URLSession

    init(configuration: Configuration = .init(), urlSession: URLSession? = nil) {
        self.config = configuration
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.timeoutIntervalForRequest = configuration.timeout
            sessionConfig.timeoutIntervalForResource = configuration.timeout
            sessionConfig.waitsForConnectivity = false
            self.urlSession = URLSession(configuration: sessionConfig)
        }
    }

    func generateText(prompt: String) async throws -> String {
        let requestID = UUID().uuidString
        return try await sendGenerateRequest(prompt: prompt, requestID: requestID)
    }

    func startGenerationJob(request: AIGenerationJobRequestPayload) async throws -> AIGenerationJobID {
        let requestID = UUID().uuidString
        Self.logger.debug(
            "Backend job create start: requestID=\(requestID, privacy: .public) jobsEndpoint=\(self.config.jobsEndpoint.absoluteString, privacy: .public) titleLength=\(request.title.count, privacy: .public)"
        )

        var urlRequest = URLRequest(url: config.jobsEndpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(requestID, forHTTPHeaderField: Self.clientRequestIDHeader)
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data = try await sendRequest(urlRequest, requestID: requestID)
        let decoded = try decode(CreateJobResponseBody.self, from: data, requestID: requestID)

        let jobID = AIGenerationJobID(rawValue: decoded.jobId)
        Self.logger.debug(
            "Backend job create success: requestID=\(requestID, privacy: .public) jobID=\(jobID.rawValue, privacy: .public) status=\(decoded.status, privacy: .public)"
        )
        return jobID
    }

    func fetchGenerationJobStatus(id: AIGenerationJobID) async throws -> AIGenerationJobStatus {
        let requestID = UUID().uuidString
        let endpoint = config.jobsEndpoint.appendingPathComponent(id.rawValue)

        Self.logger.debug(
            "Backend job status start: requestID=\(requestID, privacy: .public) jobID=\(id.rawValue, privacy: .public) endpoint=\(endpoint.absoluteString, privacy: .public)"
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(requestID, forHTTPHeaderField: Self.clientRequestIDHeader)

        let data = try await sendRequest(request, requestID: requestID)
        let decoded = try decode(JobStatusResponseBody.self, from: data, requestID: requestID)

        let state: AIGenerationJobState
        switch decoded.status.uppercased() {
        case "QUEUED":
            state = .queued
        case "RUNNING", "ASSEMBLING":
            state = .running
        case "SUCCEEDED":
            state = .completed
        case "FAILED", "EXPIRED":
            let reason = decoded.error?.message ?? decoded.error?.code ?? "Unknown failure"
            state = .failed(reason: reason)
        default:
            throw ClientError.invalidResponse
        }

        return AIGenerationJobStatus(id: AIGenerationJobID(rawValue: decoded.jobId), state: state)
    }

    func fetchGenerationJobResult(id: AIGenerationJobID) async throws -> String {
        let maxAttempts = 6

        for attempt in 1...maxAttempts {
            let requestID = UUID().uuidString
            let endpoint = config.jobsEndpoint
                .appendingPathComponent(id.rawValue)
                .appendingPathComponent("result")

            Self.logger.debug(
                "Backend job result start: requestID=\(requestID, privacy: .public) jobID=\(id.rawValue, privacy: .public) attempt=\(attempt, privacy: .public) endpoint=\(endpoint.absoluteString, privacy: .public)"
            )

            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.setValue(requestID, forHTTPHeaderField: Self.clientRequestIDHeader)

            do {
                let data = try await sendRequest(request, requestID: requestID)

                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw ClientError.invalidResponse
                }

                if let status = jsonObject["status"] as? String,
                   status.uppercased() != "SUCCEEDED" {
                    if let message = jsonObject["message"] as? String {
                        throw ClientError.jobFailed(reason: message)
                    }
                    throw ClientError.jobNotReady
                }

                guard let resultObject = jsonObject["result"] else {
                    throw ClientError.invalidResponse
                }

                let resultData = try JSONSerialization.data(withJSONObject: resultObject, options: [.sortedKeys])

                guard let resultString = String(data: resultData, encoding: .utf8) else {
                    throw ClientError.invalidResponse
                }

                Self.logger.debug(
                    "Backend job result success: requestID=\(requestID, privacy: .public) jobID=\(id.rawValue, privacy: .public) attempt=\(attempt, privacy: .public) resultLength=\(resultString.count, privacy: .public)"
                )
                return resultString
            } catch let error as ClientError {
                let shouldRetry: Bool

                switch error {
                case .jobNotFound, .jobNotReady:
                    shouldRetry = attempt < maxAttempts
                default:
                    shouldRetry = false
                }

                if shouldRetry {
                    Self.logger.debug(
                        "Backend job result retry: jobID=\(id.rawValue, privacy: .public) attempt=\(attempt, privacy: .public)"
                    )
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }

                throw error
            }
        }

        throw ClientError.jobNotReady
    }

    private func sendGenerateRequest(prompt: String, requestID: String) async throws -> String {
        Self.logger.debug(
            "Backend request start: requestID=\(requestID, privacy: .public) endpoint=\(self.config.generateEndpoint.absoluteString, privacy: .public) promptLength=\(prompt.count, privacy: .public)"
        )

        var request = URLRequest(url: config.generateEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(requestID, forHTTPHeaderField: Self.clientRequestIDHeader)
        request.httpBody = try JSONEncoder().encode(GenerateRequestBody(prompt: prompt))

        let data = try await sendRequest(request, requestID: requestID)
        let decoded = try decode(GenerateResponseBody.self, from: data, requestID: requestID)

        guard decoded.ok == true,
              let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !outputText.isEmpty else {
            Self.logger.error("Backend request failed: requestID=\(requestID, privacy: .public) reason=invalid_response_envelope")
            throw ClientError.invalidResponse
        }

        Self.logger.debug(
            "Backend request success: requestID=\(requestID, privacy: .public) outputLength=\(outputText.count, privacy: .public)"
        )
        return outputText
    }

    private func sendRequest(_ request: URLRequest, requestID: String) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                Self.logger.error("Backend request failed: requestID=\(requestID, privacy: .public) reason=invalid_http_response")
                throw ClientError.invalidResponse
            }

            guard (200 ..< 300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                Self.logger.error(
                    "Backend non-success response: requestID=\(requestID, privacy: .public) status=\(http.statusCode, privacy: .public) body=\(body, privacy: .public)"
                )

                switch http.statusCode {
                case 404:
                    throw ClientError.jobNotFound(id: "unknown")
                case 409:
                    throw ClientError.jobNotReady
                default:
                    throw ClientError.badResponse(status: http.statusCode, body: body)
                }
            }

            return data
        } catch let clientError as ClientError {
            throw clientError
        } catch is DecodingError {
            Self.logger.error("Backend request failed: requestID=\(requestID, privacy: .public) reason=response_decode_error")
            throw ClientError.invalidResponse
        } catch let urlError as URLError where urlError.code == .timedOut {
            Self.logger.error("Backend request failed: requestID=\(requestID, privacy: .public) reason=request_timed_out")
            throw ClientError.requestTimedOut
        } catch {
            Self.logger.error(
                "Backend request failed: requestID=\(requestID, privacy: .public) reason=transport_error details=\(error.localizedDescription, privacy: .public)"
            )
            throw ClientError.transport(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, requestID: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            Self.logger.error(
                "Backend decode failed: requestID=\(requestID, privacy: .public) body=\(body, privacy: .public)"
            )
            throw ClientError.invalidResponse
        }
    }
}
