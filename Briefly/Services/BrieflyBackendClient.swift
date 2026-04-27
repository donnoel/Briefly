import Foundation
import os

protocol AIGenerationTransport {
    func generateText(prompt: String) async throws -> String
}

/// Thin backend client for Briefly generation endpoint.
final class BrieflyBackendClient: AIGenerationTransport, AIGenerationJobTransport {
    private static let logger = Logger(subsystem: "dn.Briefly", category: "BrieflyBackendClient")
    private static let clientRequestIDHeader = "X-Client-Request-ID"

    struct Configuration {
        let endpoint: URL
        let timeout: TimeInterval

        init(
            endpoint: URL = URL(string: "https://sxbgtlgsaf.execute-api.us-west-2.amazonaws.com/prod/generate")!,
            timeout: TimeInterval = 60
        ) {
            self.endpoint = endpoint
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
                case 429:
                    return "Too many generation requests right now. Please wait a moment and try again."
                case 500...599:
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

    private struct RequestBody: Encodable {
        let prompt: String
    }

    private struct ResponseBody: Decodable {
        let ok: Bool?
        let outputText: String?
    }

    private actor JobStore {
        enum State {
            case queued
            case running
            case completed(result: String)
            case failed(reason: String)
        }

        private var states: [AIGenerationJobID: State] = [:]

        func create(jobID: AIGenerationJobID) {
            states[jobID] = .queued
        }

        func markRunning(jobID: AIGenerationJobID) {
            states[jobID] = .running
        }

        func markCompleted(jobID: AIGenerationJobID, result: String) {
            states[jobID] = .completed(result: result)
        }

        func markFailed(jobID: AIGenerationJobID, reason: String) {
            states[jobID] = .failed(reason: reason)
        }

        func status(for jobID: AIGenerationJobID) -> AIGenerationJobStatus? {
            guard let state = states[jobID] else { return nil }

            let mappedState: AIGenerationJobState
            switch state {
            case .queued:
                mappedState = .queued
            case .running:
                mappedState = .running
            case .completed:
                mappedState = .completed
            case .failed(let reason):
                mappedState = .failed(reason: reason)
            }

            return AIGenerationJobStatus(id: jobID, state: mappedState)
        }

        func result(for jobID: AIGenerationJobID) -> Result<String, ClientError>? {
            guard let state = states[jobID] else { return .failure(.jobNotFound(id: jobID.rawValue)) }

            switch state {
            case .queued, .running:
                return .failure(.jobNotReady)
            case .completed(let result):
                return .success(result)
            case .failed(let reason):
                return .failure(.jobFailed(reason: reason))
            }
        }
    }

    private let config: Configuration
    private let urlSession: URLSession
    private let jobStore = JobStore()

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

    func startGenerationJob(prompt: String) async throws -> AIGenerationJobID {
        let jobID = AIGenerationJobID()
        await jobStore.create(jobID: jobID)
        Self.logger.debug("Backend job start: jobID=\(jobID.rawValue, privacy: .public) promptLength=\(prompt.count, privacy: .public)")

        Task {
            await self.jobStore.markRunning(jobID: jobID)
            do {
                let output = try await self.generateText(prompt: prompt)
                await self.jobStore.markCompleted(jobID: jobID, result: output)
                Self.logger.debug("Backend job completed: jobID=\(jobID.rawValue, privacy: .public) outputLength=\(output.count, privacy: .public)")
            } catch {
                await self.jobStore.markFailed(jobID: jobID, reason: error.localizedDescription)
                Self.logger.error("Backend job failed: jobID=\(jobID.rawValue, privacy: .public) reason=\(error.localizedDescription, privacy: .public)")
            }
        }

        return jobID
    }

    func fetchGenerationJobStatus(id: AIGenerationJobID) async throws -> AIGenerationJobStatus {
        if let status = await jobStore.status(for: id) {
            return status
        }
        throw ClientError.jobNotFound(id: id.rawValue)
    }

    func fetchGenerationJobResult(id: AIGenerationJobID) async throws -> String {
        guard let result = await jobStore.result(for: id) else {
            throw ClientError.jobNotFound(id: id.rawValue)
        }

        switch result {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    private func sendGenerateRequest(prompt: String, requestID: String) async throws -> String {
        Self.logger.debug(
            "Backend request start: requestID=\(requestID, privacy: .public) endpoint=\(self.config.endpoint.absoluteString, privacy: .public) promptLength=\(prompt.count, privacy: .public)"
        )

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(requestID, forHTTPHeaderField: Self.clientRequestIDHeader)
        request.httpBody = try JSONEncoder().encode(RequestBody(prompt: prompt))

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                Self.logger.error("Backend request failed: requestID=\(requestID, privacy: .public) reason=invalid_http_response")
                throw ClientError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                Self.logger.error(
                    "Backend non-success response: requestID=\(requestID, privacy: .public) status=\(http.statusCode, privacy: .public) body=\(body, privacy: .public)"
                )
                throw ClientError.badResponse(status: http.statusCode, body: body)
            }

            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            guard decoded.ok == true, let outputText = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines), !outputText.isEmpty else {
                Self.logger.error("Backend request failed: requestID=\(requestID, privacy: .public) reason=invalid_response_envelope")
                throw ClientError.invalidResponse
            }
            let lambdaRequestID = (http.value(forHTTPHeaderField: "X-Lambda-Request-ID") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let echoedClientID = (http.value(forHTTPHeaderField: Self.clientRequestIDHeader) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            Self.logger.debug(
                "Backend request success: requestID=\(requestID, privacy: .public) echoedClientRequestID=\(echoedClientID, privacy: .public) lambdaRequestID=\(lambdaRequestID, privacy: .public) outputLength=\(outputText.count, privacy: .public)"
            )
            return outputText
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
}
