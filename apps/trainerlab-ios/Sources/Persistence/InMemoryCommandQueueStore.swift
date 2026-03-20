import Foundation

public actor InMemoryCommandQueueStore: CommandQueueStoreProtocol {
    private var storage: [PendingCommandEnvelope] = []

    public init() {}

    public func enqueue(_ envelope: PendingCommandEnvelope) async throws {
        if let index = storage.firstIndex(where: { $0.idempotencyKey == envelope.idempotencyKey }) {
            storage[index] = envelope
        } else {
            storage.append(envelope)
        }
    }

    public func markAcked(idempotencyKey: String) async throws {
        storage.removeAll(where: { $0.idempotencyKey == idempotencyKey })
    }

    public func markFailed(idempotencyKey: String, error: String, nextRetryAt: Date) async throws {
        guard let index = storage.firstIndex(where: { $0.idempotencyKey == idempotencyKey }) else { return }
        storage[index].retryCount += 1
        storage[index].lastError = error
        storage[index].nextRetryAt = nextRetryAt
        storage[index].ackState = .failed
    }

    public func markTerminalFailure(idempotencyKey: String, error: String) async throws {
        guard let index = storage.firstIndex(where: { $0.idempotencyKey == idempotencyKey }) else { return }
        storage[index].retryCount = storage[index].maxRetries
        storage[index].lastError = error
        storage[index].nextRetryAt = Date.distantFuture
        storage[index].ackState = .failed
    }

    public func nextRetryBatch(limit: Int, now: Date, simulationID: Int?) async throws -> [PendingCommandEnvelope] {
        Array(storage
            .filter {
                ($0.nextRetryAt <= now || $0.ackState == .failed)
                    && $0.retryCount < $0.maxRetries
                    && (simulationID == nil || $0.simulationID == simulationID || $0.simulationID == nil)
            }
            .sorted(by: { $0.nextRetryAt < $1.nextRetryAt })
            .prefix(limit))
    }

    public func pendingCount(simulationID: Int?) async throws -> Int {
        storage.count(where: { $0.isActivePending && $0.matches(simulationID: simulationID) })
    }

    public func purgeAbandoned() async throws -> Int {
        let before = storage.count
        storage.removeAll(where: { $0.retryCount >= $0.maxRetries })
        return before - storage.count
    }
}
