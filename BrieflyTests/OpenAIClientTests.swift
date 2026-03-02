import Foundation
import Testing
@testable import Briefly

struct OpenAIClientTests {

    @Test
    func nonRetriableStatusDoesNotRetry() async throws {
        let transport = makeTransport(responses: [
            .http(status: 401, body: #"{"error":"unauthorized"}"#)
        ])
        let client = makeClient(session: transport.session, host: transport.host)

        do {
            _ = try await client.chatCompletion(messages: sampleMessages)
            #expect(false)
            return
        } catch let error as OpenAIClient.ClientError {
            guard case let .badResponse(status, body) = error else {
                #expect(false)
                return
            }

            #expect(status == 401)
            #expect(body == #"{"error":"unauthorized"}"#)
        }

        #expect(MockURLProtocol.currentRequestCount(for: transport.host) == 1)
    }

    @Test
    func timeoutMapsToRequestTimedOutWithoutRetry() async throws {
        let transport = makeTransport(responses: [
            .error(URLError(.timedOut))
        ])
        let client = makeClient(session: transport.session, host: transport.host)

        do {
            _ = try await client.chatCompletion(messages: sampleMessages)
            #expect(false)
            return
        } catch let error as OpenAIClient.ClientError {
            guard case .requestTimedOut = error else {
                #expect(false)
                return
            }
        }

        #expect(MockURLProtocol.currentRequestCount(for: transport.host) == 1)
    }

    @Test
    func offlineErrorDoesNotRetry() async throws {
        let transport = makeTransport(responses: [
            .error(URLError(.notConnectedToInternet))
        ])
        let client = makeClient(session: transport.session, host: transport.host)

        do {
            _ = try await client.chatCompletion(messages: sampleMessages)
            #expect(false)
            return
        } catch let error as OpenAIClient.ClientError {
            guard case let .transport(underlying) = error else {
                #expect(false)
                return
            }

            let urlError = try #require(underlying as? URLError)
            #expect(urlError.code == .notConnectedToInternet)
        }

        #expect(MockURLProtocol.currentRequestCount(for: transport.host) == 1)
    }

    @Test
    func networkDropRetriesAndCanRecover() async throws {
        let transport = makeTransport(responses: [
            .error(URLError(.networkConnectionLost)),
            .http(status: 200, body: successfulChatResponseBody)
        ])
        let client = makeClient(session: transport.session, host: transport.host)

        let response = try await client.chatCompletion(messages: sampleMessages)

        #expect(response.choices.count == 1)
        #expect(response.choices.first?.message.content == "{\"ok\":true}")
        #expect(MockURLProtocol.currentRequestCount(for: transport.host) == 2)
    }

    private func makeClient(session: URLSession, host: String) -> OpenAIClient {
        let configuration = OpenAIClient.Configuration(
            apiKeyProvider: { "test-key" },
            model: "gpt-4.1-mini",
            baseURL: URL(string: "https://\(host)/v1")!
        )
        return OpenAIClient(configuration: configuration, urlSession: session)
    }

    private func makeTransport(responses: [MockURLProtocol.MockResponse]) -> MockTransport {
        let host = UUID().uuidString.lowercased() + ".example.com"
        MockURLProtocol.configure(responses, for: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return MockTransport(session: URLSession(configuration: configuration), host: host)
    }

    private var sampleMessages: [OpenAIChatMessage] {
        [OpenAIChatMessage(role: "user", content: "Hello")]
    }

    private var successfulChatResponseBody: String {
        #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#
    }
}

private struct MockTransport {
    let session: URLSession
    let host: String
}

private final class MockURLProtocol: URLProtocol {
    enum MockResponse {
        case http(status: Int, body: String)
        case error(URLError)
    }

    private static let lock = NSLock()
    private static var queuedResponsesByHost: [String: [MockResponse]] = [:]
    private static var requestCountsByHost: [String: Int] = [:]

    static func configure(_ responses: [MockResponse], for host: String) {
        lock.lock()
        defer { lock.unlock() }

        queuedResponsesByHost[host] = responses
        requestCountsByHost[host] = 0
    }

    static func currentRequestCount(for host: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCountsByHost[host, default: 0]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let response = Self.nextResponse(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        switch response {
        case .http(let status, let body):
            let headers = ["Content-Type": "application/json"]
            let httpResponse = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .error(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func nextResponse(for request: URLRequest) -> MockResponse? {
        lock.lock()
        defer { lock.unlock() }

        guard let host = request.url?.host else {
            return nil
        }

        requestCountsByHost[host, default: 0] += 1
        guard var queuedResponses = queuedResponsesByHost[host], !queuedResponses.isEmpty else {
            return nil
        }

        let response = queuedResponses.removeFirst()
        queuedResponsesByHost[host] = queuedResponses
        return response
    }
}
