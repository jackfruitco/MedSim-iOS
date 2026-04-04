import Foundation
import Networking
import OSLog
import SharedModels

public protocol ChatRealtimeClientProtocol: Sendable {
    var events: AsyncStream<ChatEventEnvelope> { get }
    var connectionStates: AsyncStream<ChatRealtimeConnectionState> { get }
    func connect(simulationID: Int, cursor: String?) async
    func disconnect()
    func send(eventType: String, payload: [String: JSONValue]) async
}

private let realtimeLogger = Logger(subsystem: "com.jackfruit.medsim", category: "ChatRealtime")

enum ChatRealtimeError: Error {
    case staleCursor
}

private enum ChatSSEStreamItem {
    case event(ChatEventEnvelope)
    case keepAlive
}

private actor ChatSSEFreshnessTracker {
    private var lastSignalAt = Date()
    private var staleTriggered = false

    func markSignal() {
        lastSignalAt = Date()
    }

    func shouldTriggerStale(threshold: TimeInterval) -> Bool {
        guard !staleTriggered else { return false }
        if Date().timeIntervalSince(lastSignalAt) > threshold {
            staleTriggered = true
            return true
        }
        return false
    }

    func didTriggerStale() -> Bool {
        staleTriggered
    }
}

enum ChatSSEParser {
    static func parseEvent(dataString: String, decoder: JSONDecoder) throws -> ChatEventEnvelope? {
        guard let data = dataString.data(using: .utf8) else {
            return nil
        }
        return try decoder.decode(ChatEventEnvelope.self, from: data)
    }
}

public final class ChatRealtimeClient: ChatRealtimeClientProtocol, @unchecked Sendable {
    public let events: AsyncStream<ChatEventEnvelope>
    public let connectionStates: AsyncStream<ChatRealtimeConnectionState>

    private let authLoader: AuthorizedResourceLoading
    private let service: ChatLabServiceProtocol
    private let session: URLSession
    private let decoder: JSONDecoder
    private let staleThresholdSeconds: TimeInterval

    private let eventContinuation: AsyncStream<ChatEventEnvelope>.Continuation
    private let stateContinuation: AsyncStream<ChatRealtimeConnectionState>.Continuation

    private var runTask: Task<Void, Never>?
    private var simulationID: Int?
    private var cursor: String?
    private var reconnectAttempt = 0

    private var seenEventIDs = Set<String>()
    private var seenOrder: [String] = []
    private let seenCapacity = 2000

    public init(
        authLoader: AuthorizedResourceLoading,
        service: ChatLabServiceProtocol,
        session: URLSession = .shared,
        staleThresholdSeconds: TimeInterval = 45,
    ) {
        self.authLoader = authLoader
        self.service = service
        self.session = session
        self.staleThresholdSeconds = staleThresholdSeconds

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.parseISO8601(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date string: \(value)",
            )
        }
        self.decoder = decoder

        var eventCont: AsyncStream<ChatEventEnvelope>.Continuation!
        events = AsyncStream<ChatEventEnvelope> { continuation in
            eventCont = continuation
        }
        eventContinuation = eventCont

        var stateCont: AsyncStream<ChatRealtimeConnectionState>.Continuation!
        connectionStates = AsyncStream<ChatRealtimeConnectionState> { continuation in
            stateCont = continuation
            continuation.yield(.disconnected)
        }
        stateContinuation = stateCont
    }

    public func connect(simulationID: Int, cursor: String?) async {
        disconnect()
        self.simulationID = simulationID
        self.cursor = cursor
        reconnectAttempt = 0
        seenEventIDs.removeAll(keepingCapacity: true)
        seenOrder.removeAll(keepingCapacity: true)

        runTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    public func disconnect() {
        runTask?.cancel()
        runTask = nil
        stateContinuation.yield(.disconnected)
    }

    public func send(eventType _: String, payload _: [String: JSONValue]) async {
        // Generic simulation realtime is SSE-only in the backend contract.
        // Typing remains a local UI affordance until a supported upstream channel exists.
    }

    private func runLoop() async {
        guard let simulationID else { return }
        var currentCursor = cursor

        while !Task.isCancelled {
            do {
                stateContinuation.yield(.connecting)
                realtimeLogger.debug(
                    "Connecting chat SSE for simulation \(simulationID, privacy: .public) with cursor \(currentCursor ?? "nil", privacy: .public)",
                )
                try await consumeSSE(simulationID: simulationID, currentCursor: &currentCursor)
                reconnectAttempt = 0
            } catch ChatRealtimeError.staleCursor {
                stateContinuation.yield(.staleCursor)
                realtimeLogger.warning(
                    "Detected stale cursor for simulation \(simulationID, privacy: .public). Waiting for re-bootstrap.",
                )
                break
            } catch {
                if Task.isCancelled {
                    break
                }
                reconnectAttempt += 1
                stateContinuation.yield(.reconnecting(attempt: reconnectAttempt))
                realtimeLogger.warning(
                    "Chat SSE reconnect attempt \(reconnectAttempt, privacy: .public) for simulation \(simulationID, privacy: .public) using cursor \(currentCursor ?? "nil", privacy: .public)",
                )

                let delaySeconds = min(pow(2.0, Double(max(reconnectAttempt - 1, 0))), 15.0)
                let jitter = Double.random(in: 0 ... 0.35)
                try? await Task.sleep(nanoseconds: UInt64((delaySeconds + jitter) * 1_000_000_000))
            }
        }

        cursor = currentCursor
        stateContinuation.yield(.disconnected)
    }

    private func consumeSSE(simulationID: Int, currentCursor: inout String?) async throws {
        stateContinuation.yield(.connected)
        for try await item in streamSSE(simulationID: simulationID, cursor: currentCursor) {
            switch item {
            case let .event(event):
                stateContinuation.yield(.connected)
                currentCursor = event.eventID
                cursor = event.eventID
                realtimeLogger.debug("Chat SSE cursor advanced to \(event.eventID, privacy: .public)")
                emitIfNew(event)
            case .keepAlive:
                stateContinuation.yield(.connected)
                continue
            }
        }
        throw URLError(.networkConnectionLost)
    }

    private func streamSSE(simulationID: Int, cursor: String?) -> AsyncThrowingStream<ChatSSEStreamItem, Error> {
        AsyncThrowingStream { continuation in
            let freshness = ChatSSEFreshnessTracker()
            let task = Task {
                do {
                    let (bytes, _) = try await openSSEBytes(simulationID: simulationID, cursor: cursor)

                    var dataLines: [String] = []
                    var currentEventType: String?

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            break
                        }

                        if line.hasPrefix(":") {
                            await freshness.markSignal()
                            continuation.yield(.keepAlive)
                            continue
                        }

                        if line.isEmpty {
                            let isHeartbeat = currentEventType == "heartbeat"
                            if isHeartbeat {
                                await freshness.markSignal()
                                continuation.yield(.keepAlive)
                            } else if !dataLines.isEmpty {
                                let payload = dataLines.joined(separator: "\n")
                                if let event = try ChatSSEParser.parseEvent(dataString: payload, decoder: decoder) {
                                    await freshness.markSignal()
                                    continuation.yield(.event(event))
                                }
                            }
                            dataLines.removeAll(keepingCapacity: true)
                            currentEventType = nil
                            continue
                        }

                        if line.hasPrefix("event:") {
                            currentEventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                            continue
                        }

                        if line.hasPrefix("data:") {
                            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            dataLines.append(value)
                        }
                    }

                    if await freshness.didTriggerStale() {
                        continuation.finish(throwing: URLError(.timedOut))
                    } else {
                        continuation.finish()
                    }
                } catch {
                    if await freshness.didTriggerStale() {
                        continuation.finish(throwing: URLError(.timedOut))
                    } else if Task.isCancelled {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }

            let watchdog = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if await freshness.shouldTriggerStale(threshold: staleThresholdSeconds) {
                        task.cancel()
                        return
                    }
                }
            }

            continuation.onTermination = { _ in
                watchdog.cancel()
                task.cancel()
            }
        }
    }

    private func openSSEBytes(
        simulationID: Int,
        cursor: String?,
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let route = ChatLabAPI.eventStream(simulationID: simulationID, cursor: cursor)

        func open() async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
            let request = try await authLoader.makeEventStreamRequest(for: route)
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            return (bytes, http)
        }

        let initial = try await open()
        if initial.1.statusCode == 401 {
            try await authLoader.refreshAccessToken()
            let refreshed = try await open()
            if [409, 410, 422].contains(refreshed.1.statusCode) {
                throw ChatRealtimeError.staleCursor
            }
            guard (200 ..< 300).contains(refreshed.1.statusCode) else {
                throw URLError(.userAuthenticationRequired)
            }
            return refreshed
        }

        if [409, 410, 422].contains(initial.1.statusCode) {
            throw ChatRealtimeError.staleCursor
        }
        guard (200 ..< 300).contains(initial.1.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return initial
    }

    private func emitIfNew(_ event: ChatEventEnvelope) {
        guard !seenEventIDs.contains(event.eventID) else {
            return
        }
        seenEventIDs.insert(event.eventID)
        seenOrder.append(event.eventID)
        if seenOrder.count > seenCapacity, let oldest = seenOrder.first {
            seenOrder.removeFirst()
            seenEventIDs.remove(oldest)
        }
        eventContinuation.yield(event)
    }

    private nonisolated static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}
