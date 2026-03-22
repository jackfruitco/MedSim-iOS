import Foundation
import OSLog
import SharedModels

private let logger = Logger(subsystem: "com.jackfruit.medsim", category: "Realtime")

public protocol RealtimeClientProtocol: Sendable {
    var events: AsyncStream<EventEnvelope> { get }
    var transportStates: AsyncStream<RealtimeTransportState> { get }
    func connect(simulationID: Int, cursor: String?) async
    func disconnect()
}

public final class RealtimeClient: RealtimeClientProtocol, @unchecked Sendable {
    public let events: AsyncStream<EventEnvelope>
    public let transportStates: AsyncStream<RealtimeTransportState>

    private let sseTransport: SSETransportProtocol
    private let pollingTransport: PollingTransportProtocol

    private let eventContinuation: AsyncStream<EventEnvelope>.Continuation
    private let stateContinuation: AsyncStream<RealtimeTransportState>.Continuation

    private var runTask: Task<Void, Never>?

    private var seenEventIDs = Set<String>()
    private var seenEventOrder: [String] = []
    private let seenCapacity = 2000

    public init(sseTransport: SSETransportProtocol, pollingTransport: PollingTransportProtocol) {
        self.sseTransport = sseTransport
        self.pollingTransport = pollingTransport

        var eventCont: AsyncStream<EventEnvelope>.Continuation!
        events = AsyncStream<EventEnvelope> { continuation in
            eventCont = continuation
        }
        eventContinuation = eventCont

        var stateCont: AsyncStream<RealtimeTransportState>.Continuation!
        transportStates = AsyncStream<RealtimeTransportState> { continuation in
            stateCont = continuation
            continuation.yield(.disconnected)
        }
        stateContinuation = stateCont
    }

    public func connect(simulationID: Int, cursor: String?) async {
        disconnect()
        seenEventIDs.removeAll(keepingCapacity: true)
        seenEventOrder.removeAll(keepingCapacity: true)

        runTask = Task { [weak self] in
            guard let self else { return }
            var currentCursor = cursor
            var reconnectAttempt = 0

            logger.info("Connecting to simulation \(simulationID)")

            while !Task.isCancelled {
                do {
                    stateContinuation.yield(.connecting)
                    try await consumeSSE(
                        simulationID: simulationID,
                        cursor: currentCursor,
                        currentCursor: &currentCursor,
                    )
                    reconnectAttempt = 0
                } catch {
                    if Task.isCancelled {
                        break
                    }

                    reconnectAttempt += 1
                    logger.warning("SSE disconnected (attempt \(reconnectAttempt)): \(error.localizedDescription)")
                    stateContinuation.yield(.polling)

                    let retryWindowSeconds = nextRetryWindowSeconds(attempt: reconnectAttempt) + jitterSeconds()
                    let retryDeadline = Date().addingTimeInterval(retryWindowSeconds)
                    logger.info("Polling fallback for \(String(format: "%.1f", retryWindowSeconds))s before SSE retry")
                    do {
                        try await consumePollingUntilRetry(
                            simulationID: simulationID,
                            currentCursor: &currentCursor,
                            retryDeadline: retryDeadline,
                        )
                    } catch {
                        // Keep retry loop alive.
                    }

                    if Task.isCancelled {
                        break
                    }
                    stateContinuation.yield(.reconnecting(reconnectAttempt))
                }
            }

            logger.info("Disconnected from simulation \(simulationID)")
            stateContinuation.yield(.disconnected)
        }
    }

    public func disconnect() {
        runTask?.cancel()
        runTask = nil
        stateContinuation.yield(.disconnected)
    }

    private func consumeSSE(
        simulationID: Int,
        cursor: String?,
        currentCursor: inout String?,
    ) async throws {
        logger.info("SSE connected to simulation \(simulationID) cursor=\(cursor ?? "nil")")
        stateContinuation.yield(.connectedSSE)
        for try await item in sseTransport.stream(simulationID: simulationID, cursor: cursor) {
            switch item {
            case let .event(event):
                currentCursor = event.eventID
                emitIfNew(event)
            case .keepAlive:
                continue
            }
        }
        throw URLError(.networkConnectionLost)
    }

    private func consumePollingUntilRetry(
        simulationID: Int,
        currentCursor: inout String?,
        retryDeadline: Date,
    ) async throws {
        while Date() < retryDeadline {
            let page = try await pollingTransport.fetch(
                simulationID: simulationID,
                cursor: currentCursor,
            )
            if !page.items.isEmpty {
                for event in page.items {
                    currentCursor = event.eventID
                    emitIfNew(event)
                }
            } else if let nextCursor = page.nextCursor {
                currentCursor = nextCursor
            }

            if page.hasMore {
                continue
            }

            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }

    private func emitIfNew(_ event: EventEnvelope) {
        guard !seenEventIDs.contains(event.eventID) else {
            return
        }

        seenEventIDs.insert(event.eventID)
        seenEventOrder.append(event.eventID)
        if seenEventOrder.count > seenCapacity, let oldest = seenEventOrder.first {
            seenEventOrder.removeFirst()
            seenEventIDs.remove(oldest)
        }

        eventContinuation.yield(event)
    }

    private func nextRetryWindowSeconds(attempt: Int) -> TimeInterval {
        let safeAttempt = max(1, attempt)
        let base = pow(2.0, Double(safeAttempt - 1))
        return min(base, 15)
    }

    private func jitterSeconds() -> TimeInterval {
        Double.random(in: 0.0 ... 0.25)
    }
}
