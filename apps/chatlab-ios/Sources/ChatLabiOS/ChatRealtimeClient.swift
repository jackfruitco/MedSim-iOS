import Foundation
import Networking
import OSLog
import SharedModels

private let chatRealtimeLogger = Logger(subsystem: "com.jackfruit.medsim", category: "ChatRealtime")

public protocol ChatRealtimeClientProtocol: Sendable {
    var events: AsyncStream<ChatEventEnvelope> { get }
    var connectionStates: AsyncStream<ChatRealtimeConnectionState> { get }
    func connect(simulationID: Int, cursor: String?) async
    func disconnect()
    func send(eventType: String, payload: [String: JSONValue]) async
}

enum ChatSSEStreamItem: Equatable {
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
            chatRealtimeLogger.error("[ChatRealtime] SSE payload was not valid UTF-8; dropping payload prefix=\(String(dataString.prefix(256)), privacy: .public)")
            return nil
        }
        return try decoder.decode(ChatEventEnvelope.self, from: data)
    }

    static func parseLines(_ lines: [String], decoder: JSONDecoder) -> [ChatSSEStreamItem] {
        var dataLines: [String] = []
        var currentEventType: String?
        var items: [ChatSSEStreamItem] = []

        for line in lines {
            if let item = consumeLine(
                line,
                decoder: decoder,
                dataLines: &dataLines,
                currentEventType: &currentEventType,
            ) {
                items.append(item)
            }
        }

        return items
    }

    static func consumeLine(
        _ line: String,
        decoder: JSONDecoder,
        dataLines: inout [String],
        currentEventType: inout String?,
    ) -> ChatSSEStreamItem? {
        if line.hasPrefix(":") {
            chatRealtimeLogger.debug("[ChatRealtime] comment/heartbeat line \(ChatRealtimeClient.truncate(line), privacy: .public)")
            return .keepAlive
        }

        if line.isEmpty {
            defer {
                dataLines.removeAll(keepingCapacity: true)
                currentEventType = nil
            }

            if currentEventType == "heartbeat" {
                chatRealtimeLogger.debug("[ChatRealtime] named heartbeat boundary received")
                return .keepAlive
            }
            guard !dataLines.isEmpty else {
                return nil
            }

            let payload = dataLines.joined(separator: "\n")
            let eventTypeSnapshot = currentEventType
            chatRealtimeLogger.debug("[ChatRealtime] assembled SSE payload eventName=\(eventTypeSnapshot ?? "nil", privacy: .public) payload=\(ChatRealtimeClient.truncate(payload), privacy: .public)")
            do {
                if let event = try parseEvent(dataString: payload, decoder: decoder) {
                    chatRealtimeLogger.info("[ChatRealtime] decoded envelope eventID=\(event.eventID, privacy: .public) eventType=\(event.eventType, privacy: .public) conversationID=\(ChatRealtimeClient.payloadInt(event.payload, keys: ["conversation_id"]) ?? -1)")
                    return .event(event)
                }
                chatRealtimeLogger.error("[ChatRealtime] parseEvent returned nil; dropping payload=\(ChatRealtimeClient.truncate(payload), privacy: .public)")
                return nil
            } catch {
                chatRealtimeLogger.error("[ChatRealtime] failed to decode SSE payload error=\(ChatRealtimeClient.describe(error), privacy: .public) payload=\(ChatRealtimeClient.truncate(payload), privacy: .public)")
                return nil
            }
        }

        if line.hasPrefix("event:") {
            currentEventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            let eventTypeSnapshot = currentEventType
            chatRealtimeLogger.debug("[ChatRealtime] event line eventName=\(eventTypeSnapshot ?? "nil", privacy: .public)")
            return nil
        }

        if line.hasPrefix("data:") {
            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            chatRealtimeLogger.debug("[ChatRealtime] data line payload=\(ChatRealtimeClient.truncate(value), privacy: .public)")
            dataLines.append(value)
            return nil
        }

        chatRealtimeLogger.debug("[ChatRealtime] ignored SSE line \(ChatRealtimeClient.truncate(line), privacy: .public)")
        return nil
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
        chatRealtimeLogger.info("[ChatRealtime] connect(simulationID=\(simulationID), cursor=\(cursor ?? "nil", privacy: .public))")
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
        chatRealtimeLogger.info("[ChatRealtime] disconnect()")
        runTask?.cancel()
        runTask = nil
        logConnectionState(.disconnected, reason: "disconnect requested")
        stateContinuation.yield(.disconnected)
    }

    public func send(eventType _: String, payload _: [String: JSONValue]) async {
        // Generic simulation realtime is SSE-only in the backend contract.
        // Typing remains a local UI affordance until a supported upstream channel exists.
    }

    private func runLoop() async {
        guard let simulationID else {
            chatRealtimeLogger.warning("[ChatRealtime] runLoop() exited before start because simulationID was nil")
            return
        }
        var currentCursor = cursor
        var connectionAttempt = 0

        chatRealtimeLogger.info("[ChatRealtime] runLoop() started simulationID=\(simulationID) cursor=\(currentCursor ?? "nil", privacy: .public)")

        while !Task.isCancelled {
            connectionAttempt += 1
            do {
                chatRealtimeLogger.info("[ChatRealtime] runLoop() connection attempt \(connectionAttempt) simulationID=\(simulationID) cursor=\(currentCursor ?? "nil", privacy: .public)")
                logConnectionState(.connecting, reason: "attempt \(connectionAttempt)")
                stateContinuation.yield(.connecting)
                try await consumeSSE(simulationID: simulationID, currentCursor: &currentCursor)
                reconnectAttempt = 0
            } catch {
                if Task.isCancelled {
                    chatRealtimeLogger.info("[ChatRealtime] runLoop() cancelled during attempt \(connectionAttempt)")
                    break
                }
                chatRealtimeLogger.error("[ChatRealtime] runLoop() attempt \(connectionAttempt) failed: \(Self.describe(error), privacy: .public)")
                reconnectAttempt += 1
                logConnectionState(.reconnecting(attempt: reconnectAttempt), reason: Self.describe(error))
                stateContinuation.yield(.reconnecting(attempt: reconnectAttempt))
                await performCatchup(simulationID: simulationID, currentCursor: &currentCursor)

                let delaySeconds = min(pow(2.0, Double(max(reconnectAttempt - 1, 0))), 15.0)
                let jitter = Double.random(in: 0 ... 0.35)
                chatRealtimeLogger.info("[ChatRealtime] reconnect backoff attempt=\(self.reconnectAttempt) delay=\(String(format: "%.2f", delaySeconds + jitter), privacy: .public)s")
                try? await Task.sleep(nanoseconds: UInt64((delaySeconds + jitter) * 1_000_000_000))
            }
        }

        cursor = currentCursor
        chatRealtimeLogger.info("[ChatRealtime] runLoop() stopped finalCursor=\(currentCursor ?? "nil", privacy: .public)")
        logConnectionState(.disconnected, reason: "runLoop ended")
        stateContinuation.yield(.disconnected)
    }

    private func consumeSSE(simulationID: Int, currentCursor: inout String?) async throws {
        let cursorSnapshot = currentCursor
        chatRealtimeLogger.info("[ChatRealtime] consumeSSE(simulationID=\(simulationID), cursor=\(cursorSnapshot ?? "nil", privacy: .public))")
        logConnectionState(.connected, reason: "SSE opened")
        stateContinuation.yield(.connected)
        for try await item in streamSSE(simulationID: simulationID, cursor: currentCursor) {
            switch item {
            case let .event(event):
                stateContinuation.yield(.connected)
                currentCursor = event.eventID
                cursor = event.eventID
                chatRealtimeLogger.debug("[ChatRealtime] emitting live event eventID=\(event.eventID, privacy: .public) eventType=\(event.eventType, privacy: .public)")
                emitIfNew(event)
            case .keepAlive:
                chatRealtimeLogger.debug("[ChatRealtime] keep-alive signal received")
                stateContinuation.yield(.connected)
                continue
            }
        }
        chatRealtimeLogger.warning("[ChatRealtime] SSE stream finished without explicit error; treating as disconnect")
        throw URLError(.networkConnectionLost)
    }

    private func streamSSE(simulationID: Int, cursor: String?) -> AsyncThrowingStream<ChatSSEStreamItem, Error> {
        AsyncThrowingStream { continuation in
            let freshness = ChatSSEFreshnessTracker()
            let task = Task {
                do {
                    let (bytes, response) = try await openSSEBytes(simulationID: simulationID, cursor: cursor)
                    chatRealtimeLogger.info("[ChatRealtime] SSE stream consuming lines status=\(response.statusCode)")

                    var dataLines: [String] = []
                    var currentEventType: String?

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            break
                        }
                        guard let item = ChatSSEParser.consumeLine(
                            line,
                            decoder: decoder,
                            dataLines: &dataLines,
                            currentEventType: &currentEventType,
                        ) else {
                            continue
                        }
                        await freshness.markSignal()
                        continuation.yield(item)
                    }

                    if await freshness.didTriggerStale() {
                        chatRealtimeLogger.warning("[ChatRealtime] SSE watchdog triggered stale timeout after stream completion")
                        continuation.finish(throwing: URLError(.timedOut))
                    } else {
                        chatRealtimeLogger.info("[ChatRealtime] SSE stream finished normally")
                        continuation.finish()
                    }
                } catch {
                    if await freshness.didTriggerStale() {
                        chatRealtimeLogger.warning("[ChatRealtime] SSE stream threw after stale timeout error=\(Self.describe(error), privacy: .public)")
                        continuation.finish(throwing: URLError(.timedOut))
                    } else if Task.isCancelled {
                        chatRealtimeLogger.info("[ChatRealtime] SSE stream task cancelled")
                        continuation.finish()
                    } else {
                        chatRealtimeLogger.error("[ChatRealtime] SSE stream threw error=\(Self.describe(error), privacy: .public)")
                        continuation.finish(throwing: error)
                    }
                }
            }

            let watchdog = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if await freshness.shouldTriggerStale(threshold: self.staleThresholdSeconds) {
                        chatRealtimeLogger.warning("[ChatRealtime] SSE watchdog cancelling stale stream threshold=\(String(format: "%.1f", self.staleThresholdSeconds), privacy: .public)s")
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
            chatRealtimeLogger.info("[ChatRealtime] openSSEBytes() opening URL=\(request.url?.absoluteString ?? route.path, privacy: .public)")
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                chatRealtimeLogger.error("[ChatRealtime] SSE open returned non-HTTP response")
                throw URLError(.badServerResponse)
            }
            chatRealtimeLogger.info("[ChatRealtime] SSE open completed status=\(http.statusCode)")
            return (bytes, http)
        }

        chatRealtimeLogger.info("[ChatRealtime] openSSEBytes(simulationID=\(simulationID), cursor=\(cursor ?? "nil", privacy: .public))")
        let initial = try await open()
        if initial.1.statusCode == 401 {
            chatRealtimeLogger.warning("[ChatRealtime] SSE open returned 401; refreshing access token")
            try await authLoader.refreshAccessToken()
            let refreshed = try await open()
            guard (200 ..< 300).contains(refreshed.1.statusCode) else {
                chatRealtimeLogger.error("[ChatRealtime] SSE open after refresh still failed status=\(refreshed.1.statusCode)")
                throw URLError(.userAuthenticationRequired)
            }
            return refreshed
        }

        guard (200 ..< 300).contains(initial.1.statusCode) else {
            chatRealtimeLogger.error("[ChatRealtime] SSE open failed status=\(initial.1.statusCode)")
            throw URLError(.badServerResponse)
        }
        chatRealtimeLogger.info("[ChatRealtime] openSSEBytes() succeeded status=\(initial.1.statusCode)")
        return initial
    }

    private func emitIfNew(_ event: ChatEventEnvelope) {
        guard !seenEventIDs.contains(event.eventID) else {
            chatRealtimeLogger.debug("[ChatRealtime] duplicate event ignored eventID=\(event.eventID, privacy: .public) eventType=\(event.eventType, privacy: .public)")
            return
        }
        seenEventIDs.insert(event.eventID)
        seenOrder.append(event.eventID)
        if seenOrder.count > seenCapacity, let oldest = seenOrder.first {
            seenOrder.removeFirst()
            seenEventIDs.remove(oldest)
        }
        chatRealtimeLogger.debug("[ChatRealtime] yielding event eventID=\(event.eventID, privacy: .public) eventType=\(event.eventType, privacy: .public)")
        eventContinuation.yield(event)
    }

    private func performCatchup(simulationID: Int, currentCursor: inout String?) async {
        let initialCursor = currentCursor
        chatRealtimeLogger.info("[ChatRealtime] catch-up started simulationID=\(simulationID) cursor=\(initialCursor ?? "nil", privacy: .public)")
        logConnectionState(.catchingUp, reason: "starting catch-up")
        stateContinuation.yield(.catchingUp)
        do {
            var pagesFetched = 0
            var eventsFetched = 0
            while !Task.isCancelled {
                let page = try await service.listEvents(
                    simulationID: simulationID,
                    cursor: currentCursor,
                    limit: 50,
                )
                pagesFetched += 1
                eventsFetched += page.items.count
                chatRealtimeLogger.info("[ChatRealtime] catch-up page=\(pagesFetched) returned=\(page.items.count) hasMore=\(page.hasMore) nextCursor=\(page.nextCursor ?? "nil", privacy: .public)")
                if page.items.isEmpty, !page.hasMore {
                    break
                }

                for event in page.items {
                    currentCursor = event.eventID
                    emitIfNew(event)
                }
                if !page.hasMore {
                    break
                }
                currentCursor = page.nextCursor
            }
            cursor = currentCursor
            let finalCursor = currentCursor
            chatRealtimeLogger.info("[ChatRealtime] catch-up finished pages=\(pagesFetched) events=\(eventsFetched) finalCursor=\(finalCursor ?? "nil", privacy: .public)")
        } catch {
            chatRealtimeLogger.error("[ChatRealtime] catch-up failed error=\(Self.describe(error), privacy: .public)")
        }
    }

    private func logConnectionState(_ state: ChatRealtimeConnectionState, reason: String) {
        chatRealtimeLogger.info("[ChatRealtime] state -> \(Self.describe(state), privacy: .public) reason=\(reason, privacy: .public)")
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

    fileprivate static func describe(_ state: ChatRealtimeConnectionState) -> String {
        switch state {
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case let .reconnecting(attempt):
            return "reconnecting(\(attempt))"
        case .catchingUp:
            return "catchingUp"
        }
    }

    fileprivate static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return "URLError(\(urlError.code.rawValue)): \(urlError.localizedDescription)"
        }
        return String(describing: error)
    }

    fileprivate static func truncate(_ value: String, limit: Int = 256) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "..."
    }

    fileprivate static func payloadInt(_ payload: [String: JSONValue], keys: [String]) -> Int? {
        for key in keys {
            guard let value = payload[key] else { continue }
            switch value {
            case let .number(number):
                return Int(number)
            case let .string(text):
                return Int(text)
            default:
                continue
            }
        }
        return nil
    }
}
