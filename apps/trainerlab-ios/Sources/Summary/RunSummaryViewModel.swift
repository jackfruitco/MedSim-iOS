import Foundation
import Networking
import Persistence
import SharedModels

@MainActor
public final class RunSummaryViewModel: ObservableObject {
    public static let notReadyCopy = "Summary is still being prepared. Check back in a moment."

    @Published public private(set) var summary: RunSummary?
    @Published public private(set) var isLoading = false
    @Published public private(set) var presentableError: PresentableAppError?
    @Published public private(set) var notReadyMessage: String?
    @Published public private(set) var isWaitingForDebrief = false
    @Published public private(set) var isSubmittingReview = false
    @Published public private(set) var hasQueuedReview = false
    @Published public private(set) var reviewError: PresentableAppError?
    @Published public private(set) var rejectedCorrection: String?
    private var loadGeneration = 0
    private let commandQueue: CommandQueueStoreProtocol
    private let accountUUID: String?

    private var observationGeneration: UUID?

    private let service: TrainerLabServiceProtocol
    public let simulationID: Int

    public init(
        service: TrainerLabServiceProtocol, simulationID: Int,
        commandQueue: CommandQueueStoreProtocol = InMemoryCommandQueueStore(),
        accountUUID: String? = nil,
    ) {
        self.service = service
        self.simulationID = simulationID
        self.commandQueue = commandQueue
        self.accountUUID = accountUUID
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public func load() async {
        guard !Task.isCancelled else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = summary == nil
        presentableError = nil
        notReadyMessage = nil
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            let loaded = try await service.getRunSummary(simulationID: simulationID)
            guard !Task.isCancelled, generation == loadGeneration else { return }
            summary = loaded
        } catch let APIClientError.http(statusCode, _, _) where statusCode == 404 {
            guard !Task.isCancelled, generation == loadGeneration else { return }
            notReadyMessage = Self.notReadyCopy
        } catch {
            guard !Task.isCancelled, generation == loadGeneration else { return }
            presentableError = AppErrorPresenter.present(error)
        }
    }

    /// Poll only while the server reports generation in progress; older servers retain bounded polling.
    public func loadUntilReady(maxAttempts: Int = 20, delayNanoseconds: UInt64 = 3_000_000_000) async {
        guard !Task.isCancelled else { return }
        let generation = UUID()
        observationGeneration = generation
        isWaitingForDebrief = true
        defer {
            if observationGeneration == generation {
                observationGeneration = nil
                isWaitingForDebrief = false
            }
        }
        for attempt in 0 ..< max(1, maxAttempts) {
            guard !Task.isCancelled, observationGeneration == generation else { return }
            await retryQueuedReviews()
            guard !Task.isCancelled, observationGeneration == generation else { return }
            await load()
            guard !Task.isCancelled, observationGeneration == generation else { return }
            guard presentableError == nil else { return }
            if let status = summary?.debriefStatus {
                if status != "generating", !hasQueuedReview {
                    return
                }
            } else if summary?.aiDebrief != nil {
                return
            }
            if attempt + 1 < maxAttempts {
                do {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                } catch {
                    return
                }
            }
        }
    }

    private var reviewEndpoint: String {
        "/api/v1/trainerlab/simulations/\(simulationID)/summary/review/"
    }

    public func submitReview(correction: String? = nil, claimID: String? = nil) async {
        guard !isSubmittingReview, !hasQueuedReview, let revision = summary?.evidenceRevision else { return }
        isSubmittingReview = true
        defer { isSubmittingReview = false }
        reviewError = nil
        rejectedCorrection = nil
        do {
            let request = DebriefReviewRequest(evidenceRevision: revision, correction: correction, claimID: claimID)
            let body = try JSONEncoder().encode(request)
            let envelope = CommandEnvelopeBuilder.make(
                endpoint: reviewEndpoint, method: "POST", body: body,
                simulationID: simulationID, accountUUID: accountUUID,
            )
            try await commandQueue.enqueue(envelope)
            hasQueuedReview = true
            await deliverReview(envelope)
            await load()
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    private func retryQueuedReviews() async {
        guard !isSubmittingReview else { return }
        isSubmittingReview = true
        defer { isSubmittingReview = false }
        do {
            let batch = try await commandQueue.nextRetryBatch(
                limit: 100, now: .distantFuture, simulationID: simulationID, accountUUID: accountUUID,
            ).filter { $0.endpoint == reviewEndpoint }
            hasQueuedReview = !batch.isEmpty
            for envelope in batch where envelope.nextRetryAt <= Date() {
                guard !Task.isCancelled else { return }
                hasQueuedReview = true
                await deliverReview(envelope)
            }
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    private func deliverReview(_ envelope: PendingCommandEnvelope) async {
        do {
            try await service.replayPending(
                endpoint: envelope.endpoint, method: envelope.method,
                body: envelope.bodyBase64.flatMap { Data(base64Encoded: $0) },
                idempotencyKey: envelope.idempotencyKey,
            )
            try await commandQueue.markAcked(idempotencyKey: envelope.idempotencyKey)
            hasQueuedReview = false
            reviewError = nil
        } catch let APIClientError.http(status, detail, correlationID) where [400, 403, 404, 409, 422].contains(status) {
            try? await commandQueue.markTerminalFailure(idempotencyKey: envelope.idempotencyKey, error: detail)
            hasQueuedReview = false
            if let data = envelope.bodyBase64.flatMap({ Data(base64Encoded: $0) }) {
                rejectedCorrection = try? JSONDecoder().decode(DebriefReviewRequest.self, from: data).correction
            }
            reviewError = AppErrorPresenter.present(APIClientError.http(statusCode: status, detail: detail, correlationID: correlationID))
        } catch {
            // Keep the exact persisted body/key for ambiguous network outcomes.
            try? await commandQueue.markFailed(
                idempotencyKey: envelope.idempotencyKey, error: error.localizedDescription,
                nextRetryAt: Date().addingTimeInterval(3),
            )
            reviewError = AppErrorPresenter.present(error)
        }
    }
}
