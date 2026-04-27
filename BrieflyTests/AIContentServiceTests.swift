import Foundation
import Testing
@testable import Briefly

struct AIContentServiceTests {

    @Test
    func requestSizingCapsSectionsPerRequest() {
        #expect(AIContentService.RequestSizing.sectionsPerRequest(for: 7) == 3)
        #expect(AIContentService.RequestSizing.sectionsPerRequest(for: 2) == 2)
        #expect(AIContentService.RequestSizing.sectionsPerRequest(for: 0) == 1)
    }

    @Test
    func requestSizingCapsCardsPerSectionPerRequest() {
        #expect(AIContentService.RequestSizing.cardsPerSection(for: 10) == 6)
        #expect(AIContentService.RequestSizing.cardsPerSection(for: 4) == 4)
        #expect(AIContentService.RequestSizing.cardsPerSection(for: 0) == 1)
    }

    @Test
    func malformedJSONReturnsInvalidJSONError() async throws {
        let service = AIContentService(transport: MockTransport(output: "not-json"))

        do {
            _ = try await service.generateTopicPack(title: "Feet", difficulty: .beginner)
            #expect(Bool(false))
        } catch let error as AIContentService.ServiceError {
            guard case let .invalidJSON(details) = error else {
                #expect(Bool(false))
                return
            }
            #expect(details.contains("Malformed JSON payload"))
        }
    }

    @Test
    func validJSONWithWrongShapeReturnsDTODecodingFailure() async throws {
        let service = AIContentService(transport: MockTransport(output: #"{"id":123}"#))

        do {
            _ = try await service.generateTopicPack(title: "Feet", difficulty: .beginner)
            #expect(Bool(false))
        } catch let error as AIContentService.ServiceError {
            guard case let .dtoDecodingFailed(details) = error else {
                #expect(Bool(false))
                return
            }
            #expect(!details.isEmpty)
        }
    }

    @Test
    func decodedDTOWithoutCardsReturnsValidationFailure() async throws {
        let json = #"{"id":"feet_pack","title":"Feet","subtitle":"Intro","category":"Anatomy","difficulty":"Beginner","language":"en","description":"","author":"Briefly","version":"1.0","sections":[{"id":"s1","title":"Basics","cards":[]}]}"#
        let service = AIContentService(transport: MockTransport(output: json))

        do {
            _ = try await service.generateTopicPack(title: "Feet", difficulty: .beginner)
            #expect(Bool(false))
        } catch let error as AIContentService.ServiceError {
            guard case let .validationFailed(details) = error else {
                #expect(Bool(false))
                return
            }
            #expect(details.contains("no cards in any section"))
        }
    }

    @Test
    func extractsJSONObjectFromWrappedOutputAndDecodes() async throws {
        let wrapped = "Here is your topic pack:\n```json\n\(validDTOJSON)\n```\n"
        let service = AIContentService(transport: MockTransport(output: wrapped))

        let dto = try await service.generateTopicPack(title: "Feet", difficulty: .beginner)

        #expect(dto.id == "feet_pack")
        #expect(dto.sections.count == 1)
        #expect(dto.sections.first?.cards.count == 1)
    }

    @Test
    func localDecodeAndValidationMessagesDoNotReportServiceOutage() {
        let invalidJSONMessage = AIContentService.ServiceError.invalidJSON(details: "bad").localizedDescription
        let decodeMessage = AIContentService.ServiceError.dtoDecodingFailed(details: "bad").localizedDescription
        let validationMessage = AIContentService.ServiceError.validationFailed(details: "bad").localizedDescription

        #expect(!invalidJSONMessage.localizedCaseInsensitiveContains("temporarily unavailable"))
        #expect(!decodeMessage.localizedCaseInsensitiveContains("temporarily unavailable"))
        #expect(!validationMessage.localizedCaseInsensitiveContains("temporarily unavailable"))
    }

    @Test
    func startAndResolveJobUsesSameDecodeValidationPath() async throws {
        let jobID = AIGenerationJobID(rawValue: "job-1")
        let transport = MockJobTransport(
            output: validDTOJSON,
            status: .completed,
            fixedJobID: jobID
        )
        let service = AIContentService(transport: transport, jobTransport: transport)

        let handle = try await service.startTopicPackGenerationJob(
            title: "Feet",
            difficulty: .beginner
        )
        #expect(handle.id == jobID)

        let status = try await service.fetchTopicPackGenerationJobStatus(jobID: handle.id)
        #expect(status.state == .completed)

        let dto = try await service.fetchTopicPackGenerationJobResult(handle: handle)
        #expect(dto.id == "feet_pack")
        #expect(dto.sections.count == 1)
    }

    @Test
    func jobAPIsReturnUnavailableWhenTransportDoesNotSupportJobs() async throws {
        let service = AIContentService(transport: MockTransport(output: validDTOJSON))

        do {
            _ = try await service.startTopicPackGenerationJob(title: "Feet", difficulty: .beginner)
            #expect(Bool(false))
            return
        } catch let error as AIContentService.ServiceError {
            guard case .jobTransportUnavailable = error else {
                #expect(Bool(false))
                return
            }
        }
    }

    private var validDTOJSON: String {
        #"{"id":"feet_pack","title":"Feet","subtitle":"Intro","category":"Anatomy","difficulty":"Beginner","language":"en","description":"","author":"Briefly","version":"1.0","sections":[{"id":"s1","title":"Basics","cards":[{"id":"c1","front":"What are feet?","back":"Feet support standing and movement.","source":null,"tags":["anatomy"]}]}]}"#
    }
}

private struct MockTransport: AIGenerationTransport {
    let output: String

    func generateText(prompt: String) async throws -> String {
        output
    }
}

private struct MockJobTransport: AIGenerationTransport, AIGenerationJobTransport {
    let output: String
    let status: AIGenerationJobState
    let fixedJobID: AIGenerationJobID

    func generateText(prompt: String) async throws -> String {
        output
    }

    func startGenerationJob(prompt: String) async throws -> AIGenerationJobID {
        fixedJobID
    }

    func fetchGenerationJobStatus(id: AIGenerationJobID) async throws -> AIGenerationJobStatus {
        AIGenerationJobStatus(id: id, state: status)
    }

    func fetchGenerationJobResult(id: AIGenerationJobID) async throws -> String {
        output
    }
}
