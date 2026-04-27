import Foundation

struct AIGenerationJobID: Hashable, Codable, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String = UUID().uuidString) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

enum AIGenerationJobState: Equatable {
    case queued
    case running
    case completed
    case failed(reason: String)
}

struct AIGenerationJobStatus: Equatable {
    let id: AIGenerationJobID
    let state: AIGenerationJobState
}

protocol AIGenerationJobTransport {
    func startGenerationJob(prompt: String) async throws -> AIGenerationJobID
    func fetchGenerationJobStatus(id: AIGenerationJobID) async throws -> AIGenerationJobStatus
    func fetchGenerationJobResult(id: AIGenerationJobID) async throws -> String
}
