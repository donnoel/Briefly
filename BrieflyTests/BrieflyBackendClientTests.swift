import Foundation
import Testing
@testable import Briefly

struct BrieflyBackendClientTests {

    @Test
    func successfulResponseReturnsOutputTextAndSendsPrompt() async throws {
        let transport = makeTransport(responses: [
            .http(status: 200, body: #"{"ok":true,"outputText":"{\"id\":\"sample\"}"}"#)
        ])
        let client = makeClient(session: transport.session, transport: transport)

        let result = try await client.generateText(prompt: "Generate sample")

        #expect(result == #"{"id":"sample"}"#)
        let request = try #require(MockBackendURLProtocol.lastRequest(for: transport.host))
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/prod/generate")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let correlationID = try #require(request.value(forHTTPHeaderField: "X-Client-Request-ID"))
        #expect(UUID(uuidString: correlationID) != nil)

        let bodyData = try #require(requestBodyData(from: request))
        let body = try JSONDecoder().decode(RequestPayload.self, from: bodyData)
        #expect(body.prompt == "Generate sample")
    }

    @Test
    func nonSuccessStatusMapsToBadResponse() async throws {
        let transport = makeTransport(responses: [
            .http(status: 503, body: #"{"message":"unavailable"}"#)
        ])
        let client = makeClient(session: transport.session, transport: transport)

        do {
            _ = try await client.generateText(prompt: "test")
            #expect(Bool(false))
            return
        } catch let error as BrieflyBackendClient.ClientError {
            guard case let .badResponse(status, body) = error else {
                #expect(Bool(false))
                return
            }

            #expect(status == 503)
            #expect(body == #"{"message":"unavailable"}"#)
        }
    }

    @Test
    func invalidEnvelopeMapsToInvalidResponse() async throws {
        let transport = makeTransport(responses: [
            .http(status: 200, body: #"{"ok":true,"outputText":""}"#)
        ])
        let client = makeClient(session: transport.session, transport: transport)

        do {
            _ = try await client.generateText(prompt: "test")
            #expect(Bool(false))
            return
        } catch let error as BrieflyBackendClient.ClientError {
            guard case .invalidResponse = error else {
                #expect(Bool(false))
                return
            }
        }
    }

    @Test
    func timeoutMapsToRequestTimedOut() async throws {
        let transport = makeTransport(responses: [
            .error(URLError(.timedOut))
        ])
        let client = makeClient(session: transport.session, transport: transport)

        do {
            _ = try await client.generateText(prompt: "test")
            #expect(Bool(false))
            return
        } catch let error as BrieflyBackendClient.ClientError {
            guard case .requestTimedOut = error else {
                #expect(Bool(false))
                return
            }
        }
    }

    @Test
    func jobLifecycleCompletesAndReturnsResult() async throws {
        let transport = makeTransport(responses: [
            .http(status: 200, body: #"{"jobId":"job-success","status":"QUEUED"}"#),
            .http(status: 200, body: #"{"jobId":"job-success","status":"SUCCEEDED"}"#),
            .http(status: 200, body: #"{"status":"SUCCEEDED","result":{"id":"from_job"}}"#)
        ])
        let client = makeClient(session: transport.session, transport: transport)

        let jobID = try await client.startGenerationJob(request: makeJobRequest())

        var status = try await client.fetchGenerationJobStatus(id: jobID)
        var attempts = 0
        while status.state != .completed && attempts < 20 {
            try await Task.sleep(nanoseconds: 20_000_000)
            status = try await client.fetchGenerationJobStatus(id: jobID)
            attempts += 1
        }

        #expect(status.state == .completed)
        let result = try await client.fetchGenerationJobResult(id: jobID)
        #expect(result == #"{"id":"from_job"}"#)
    }

    @Test
    func jobLifecyclePropagatesBackendFailure() async throws {
        let transport = makeTransport(responses: [
            .http(status: 200, body: #"{"jobId":"job-fail","status":"QUEUED"}"#),
            .http(status: 200, body: #"{"jobId":"job-fail","status":"FAILED","error":{"message":"unavailable"}}"#),
            .http(status: 200, body: #"{"status":"FAILED","message":"unavailable"}"#)
        ])
        let client = makeClient(session: transport.session, transport: transport)

        let jobID = try await client.startGenerationJob(request: makeJobRequest())

        var status = try await client.fetchGenerationJobStatus(id: jobID)
        var attempts = 0
        while attempts < 20 {
            if case .failed = status.state {
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
            status = try await client.fetchGenerationJobStatus(id: jobID)
            attempts += 1
        }

        if case .failed(let reason) = status.state {
            #expect(!reason.isEmpty)
        } else {
            #expect(Bool(false))
        }

        do {
            _ = try await client.fetchGenerationJobResult(id: jobID)
            #expect(Bool(false))
            return
        } catch let error as BrieflyBackendClient.ClientError {
            guard case .jobFailed = error else {
                #expect(Bool(false))
                return
            }
        }
    }

    private func makeClient(session: URLSession, transport: MockTransport) -> BrieflyBackendClient {
        let config = BrieflyBackendClient.Configuration(
            generateEndpoint: transport.generateEndpoint,
            jobsEndpoint: transport.jobsEndpoint
        )
        return BrieflyBackendClient(configuration: config, urlSession: session)
    }

    private func makeTransport(responses: [MockBackendURLProtocol.MockResponse]) -> MockTransport {
        let host = UUID().uuidString.lowercased() + ".example.com"
        MockBackendURLProtocol.configure(responses, for: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockBackendURLProtocol.self]
        let generateEndpoint = URL(string: "https://\(host)/prod/generate")!
        let jobsEndpoint = URL(string: "https://\(host)/prod/jobs")!
        return MockTransport(
            session: URLSession(configuration: configuration),
            host: host,
            generateEndpoint: generateEndpoint,
            jobsEndpoint: jobsEndpoint
        )
    }

    private func makeJobRequest() -> AIGenerationJobRequestPayload {
        AIGenerationJobRequestPayload(
            title: "Generate job payload",
            difficulty: "Beginner",
            language: "en",
            targetSections: 1,
            targetCardsPerSection: 1,
            model: nil
        )
    }

    private func requestBodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount < 0 {
                return nil
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }

        return data.isEmpty ? nil : data
    }
}

private struct RequestPayload: Decodable {
    let prompt: String
}

private struct MockTransport {
    let session: URLSession
    let host: String
    let generateEndpoint: URL
    let jobsEndpoint: URL
}

private final class MockBackendURLProtocol: URLProtocol {
    enum MockResponse {
        case http(status: Int, body: String)
        case error(URLError)
    }

    private static let lock = NSLock()
    private static var queuedResponsesByHost: [String: [MockResponse]] = [:]
    private static var lastRequestsByHost: [String: URLRequest] = [:]

    static func configure(_ responses: [MockResponse], for host: String) {
        lock.lock()
        defer { lock.unlock() }

        queuedResponsesByHost[host] = responses
        lastRequestsByHost.removeValue(forKey: host)
    }

    static func lastRequest(for host: String) -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return lastRequestsByHost[host]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.lock.lock()
        Self.lastRequestsByHost[host] = request
        var queue = Self.queuedResponsesByHost[host] ?? []
        let response = queue.isEmpty ? nil : queue.removeFirst()
        Self.queuedResponsesByHost[host] = queue
        Self.lock.unlock()

        guard let response else {
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
}
