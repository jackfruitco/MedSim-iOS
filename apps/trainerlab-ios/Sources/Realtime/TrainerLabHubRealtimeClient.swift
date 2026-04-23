import Foundation
import Networking
import OSLog
import Persistence
import SharedModels

private let hubLogger = Logger(subsystem: "com.jackfruit.medsim", category: "TrainerHubRealtime")

public enum TrainerLabHubRealtimeFailure: Equatable, Sendable {
    case staleCursor
    case decodeFailed
}

public protocol TrainerLabHubRealtimeClientProtocol: Sendable {
    var events: AsyncStream<TrainerLabHubEvent> { get }
    var transportStates: AsyncStream<RealtimeTransportState> { get }
    var failures: AsyncStream<TrainerLabHubRealtimeFailure> { get }
    func connect(cursor: String?, replay: Bool) async
    func disconnect()
}

public final class TrainerLabHubRealtimeClient: TrainerLabHubRealtimeClientProtocol, @unchecked Sendable {
    public let events: AsyncStream<TrainerLabHubEvent>
    public let transportStates: AsyncStream<RealtimeTransportState>
    public let failures: AsyncStream<TrainerLabHubRealtimeFailure>

    private let baseURLProvider: () -> URL
    private let tokenProvider: AuthTokenProvider
    private let accountContextProvider: AccountContextProvider
    private let session: URLSession
    private let decoder: JSONDecoder
    private let staleThresholdSeconds: TimeInterval

    private let eventContinuation: AsyncStream<TrainerLabHubEvent>.Continuation
    private let stateContinuation: AsyncStream<RealtimeTransportState>.Continuation
    private let failureContinuation: AsyncStream<TrainerLabHubRealtimeFailure>.Continuation

    private var runTask: Task<Void, Never>?

    public init(
        baseURLProvider: @escaping () -> URL,
        tokenProvider: AuthTokenProvider,
        accountContextProvider: AccountContextProvider = EmptyAccountContextProvider(),
        session: URLSession = .shared,
        staleThresholdSeconds: TimeInterval = 45,
    ) {
        self.baseURLProvider = baseURLProvider
        self.tokenProvider = tokenProvider
        self.accountContextProvider = accountContextProvider
        self.session = session
        self.staleThresholdSeconds = staleThresholdSeconds

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.parseISO8601(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        self.decoder = decoder

        var eventCont: AsyncStream<TrainerLabHubEvent>.Continuation!
        events = AsyncStream<TrainerLabHubEvent> { continuation in
            eventCont = continuation
        }
        eventContinuation = eventCont

        var stateCont: AsyncStream<RealtimeTransportState>.Continuation!
        transportStates = AsyncStream<RealtimeTransportState> { continuation in
            stateCont = continuation
            continuation.yield(.disconnected)
        }
        stateContinuation = stateCont

        var failureCont: AsyncStream<TrainerLabHubRealtimeFailure>.Continuation!
        failures = AsyncStream<TrainerLabHubRealtimeFailure> { continuation in
            failureCont = continuation
        }
        failureContinuation = failureCont
    }

    public func connect(cursor: String?, replay: Bool) async {
        disconnect()

        runTask = Task { [weak self] in
            guard let self else { return }
            var currentCursor = cursor
            var currentReplay = replay
            var reconnectAttempt = 0

            while !Task.isCancelled {
                do {
                    stateContinuation.yield(.connecting)
                    try await consumeSSE(cursor: currentCursor, replay: currentReplay, currentCursor: &currentCursor)
                    currentReplay = false
                    reconnectAttempt = 0
                    throw URLError(.networkConnectionLost)
                } catch HubStreamError.staleCursor {
                    hubLogger.warning("TrainerLab hub SSE cursor is stale")
                    failureContinuation.yield(.staleCursor)
                    break
                } catch HubStreamError.decodeFailed {
                    hubLogger.warning("TrainerLab hub SSE event decode failed")
                    failureContinuation.yield(.decodeFailed)
                    break
                } catch {
                    if Task.isCancelled {
                        break
                    }

                    currentReplay = false
                    reconnectAttempt += 1
                    hubLogger.warning("TrainerLab hub SSE disconnected (attempt \(reconnectAttempt)): \(error.localizedDescription)")
                    stateContinuation.yield(.reconnecting(reconnectAttempt))
                    try? await Task.sleep(nanoseconds: retryDelayNanoseconds(attempt: reconnectAttempt))
                }
            }

            stateContinuation.yield(.disconnected)
        }
    }

    public func disconnect() {
        runTask?.cancel()
        runTask = nil
        stateContinuation.yield(.disconnected)
    }

    private func consumeSSE(cursor: String?, replay: Bool, currentCursor: inout String?) async throws {
        hubLogger.info("TrainerLab hub SSE connected cursor=\(cursor ?? "nil", privacy: .public) replay=\(replay, privacy: .public)")
        stateContinuation.yield(.connectedSSE)
        for try await item in stream(cursor: cursor, replay: replay) {
            switch item {
            case let .event(event):
                currentCursor = event.eventID
                eventContinuation.yield(event)
            case .keepAlive:
                continue
            }
        }
    }

    private func stream(cursor: String?, replay: Bool) -> AsyncThrowingStream<HubSSEStreamItem, Error> {
        AsyncThrowingStream { continuation in
            let freshness = HubFreshnessTracker()
            let task = Task {
                do {
                    let request = try await makeRequest(cursor: cursor, replay: replay)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    if http.statusCode == 410 {
                        throw HubStreamError.staleCursor
                    }
                    guard (200 ..< 300).contains(http.statusCode) else {
                        throw URLError(.badServerResponse)
                    }

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
                                let event = try parseEvent(dataString: payload)
                                await freshness.markSignal()
                                continuation.yield(.event(event))
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
                            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
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

    private func makeRequest(cursor: String?, replay: Bool) async throws -> URLRequest {
        guard let tokens = tokenProvider.loadTokens() else {
            throw URLError(.userAuthenticationRequired)
        }

        let route = TrainerLabAPI.hubEventStream(cursor: cursor, replay: replay)
        let accountUUID = await accountContextProvider.selectedAccountUUID()
        return try route.makeURLRequest(
            baseURL: baseURLProvider(),
            accessToken: tokens.accessToken,
            accountUUID: accountUUID,
        )
    }

    private func parseEvent(dataString: String) throws -> TrainerLabHubEvent {
        guard let data = dataString.data(using: .utf8) else {
            throw HubStreamError.decodeFailed
        }
        do {
            return try decoder.decode(TrainerLabHubEvent.self, from: data)
        } catch {
            hubLogger.error(
                "Failed to decode TrainerLab hub event: \(error.localizedDescription, privacy: .public). Payload prefix: \(String(dataString.prefix(256)), privacy: .public)",
            )
            throw HubStreamError.decodeFailed
        }
    }

    private func retryDelayNanoseconds(attempt: Int) -> UInt64 {
        let safeAttempt = max(1, attempt)
        let baseSeconds = min(pow(2.0, Double(safeAttempt - 1)), 15)
        let jitterSeconds = Double.random(in: 0.0 ... 0.25)
        return UInt64((baseSeconds + jitterSeconds) * 1_000_000_000)
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

private enum HubStreamError: Error {
    case staleCursor
    case decodeFailed
}

private enum HubSSEStreamItem: Sendable {
    case event(TrainerLabHubEvent)
    case keepAlive
}

private actor HubFreshnessTracker {
    private var lastSignalAt = Date()
    private var staleTriggered = false

    func markSignal() {
        lastSignalAt = Date()
    }

    func shouldTriggerStale(threshold: TimeInterval) -> Bool {
        guard !staleTriggered else {
            return false
        }
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
