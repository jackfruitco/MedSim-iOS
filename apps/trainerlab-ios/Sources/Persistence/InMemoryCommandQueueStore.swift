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

    public func nextRetryBatch(limit: Int, now: Date) async throws -> [PendingCommandEnvelope] {
        Array(storage
            .filter { ($0.nextRetryAt <= now || $0.ackState == .failed) && $0.retryCount < $0.maxRetries }
            .sorted(by: { $0.nextRetryAt < $1.nextRetryAt })
            .prefix(limit))
    }

    public func pendingCount() async throws -> Int {
        storage.count
    }

    public func purgeAbandoned() async throws -> Int {
        let before = storage.count
        storage.removeAll(where: { $0.retryCount >= $0.maxRetries })
        return before - storage.count
    }
}
