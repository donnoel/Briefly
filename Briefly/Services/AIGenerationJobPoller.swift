import Foundation

/// Polls backend generation jobs off the main actor and emits progress updates.
actor AIGenerationJobPoller {
    struct Configuration: Sendable {
        let pollInterval: Duration
        let timeout: Duration

        init(
            pollInterval: Duration = .seconds(1),
            timeout: Duration = .seconds(90)
        ) {
            self.pollInterval = pollInterval
            self.timeout = timeout
        }
    }

    enum PollerError: LocalizedError, Sendable {
        case timedOut

        var errorDescription: String? {
            switch self {
            case .timedOut:
                return "The generation job took too long. Please try again."
            }
        }
    }

    enum Update: Sendable, Equatable {
        case started(jobID: AIGenerationJobID)
        case queued(jobID: AIGenerationJobID)
        case running(jobID: AIGenerationJobID, progressFraction: Double)
        case finalizing(jobID: AIGenerationJobID)
        case completed(jobID: AIGenerationJobID, dto: TopicPackDTO)
    }

    private let service: AIContentService
    private let config: Configuration
    private let clock: ContinuousClock

    init(
        service: AIContentService,
        configuration: Configuration = .init(),
        clock: ContinuousClock = ContinuousClock()
    ) {
        self.service = service
        self.config = configuration
        self.clock = clock
    }

    func updates(
        handle: AIContentService.GenerationJobHandle,
        timeout: Duration? = nil
    ) -> AsyncThrowingStream<Update, Error> {
        let timeout = timeout ?? config.timeout
        return AsyncThrowingStream { continuation in
            let pollTask = Task {
                do {
                    continuation.yield(.started(jobID: handle.id))
                    let dto = try await self.waitForCompletion(handle: handle, timeout: timeout) { update in
                        continuation.yield(update)
                    }
                    continuation.yield(.completed(jobID: handle.id, dto: dto))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                pollTask.cancel()
            }
        }
    }

    func awaitResult(
        handle: AIContentService.GenerationJobHandle,
        timeout: Duration? = nil
    ) async throws -> TopicPackDTO {
        let timeout = timeout ?? config.timeout
        return try await waitForCompletion(handle: handle, timeout: timeout, onUpdate: { _ in })
    }

    private func waitForCompletion(
        handle: AIContentService.GenerationJobHandle,
        timeout: Duration,
        onUpdate: @Sendable (Update) -> Void
    ) async throws -> TopicPackDTO {
        let deadline = clock.now.advanced(by: timeout)
        var runningTick: Double = 0.0

        while true {
            try Task.checkCancellation()

            if clock.now >= deadline {
                throw PollerError.timedOut
            }

            let status = try await service.fetchTopicPackGenerationJobStatus(jobID: handle.id)
            switch status.state {
            case .queued:
                onUpdate(.queued(jobID: handle.id))
            case .running:
                // The backend currently does not expose percent complete; provide a bounded,
                // monotonic estimate so the UI can show forward motion.
                runningTick = min(max(runningTick, 0.2) + 0.08, 0.9)
                onUpdate(.running(jobID: handle.id, progressFraction: runningTick))
            case .completed:
                onUpdate(.finalizing(jobID: handle.id))
                return try await service.fetchTopicPackGenerationJobResult(handle: handle)
            case .failed(let reason):
                throw BrieflyBackendClient.ClientError.jobFailed(reason: reason)
            }

            try await clock.sleep(for: config.pollInterval)
        }
    }
}

