import Foundation
import Networking
import Persistence
import SharedModels

public protocol ChatRealtimeClientProtocol: Sendable {
    var events: AsyncStream<ChatEventEnvelope> { get }
    var connectionStates: AsyncStream<ChatRealtimeConnectionState> { get }
    func connect(simulationID: Int, cursor: String?) async
    func disconnect()
    func send(eventType: String, payload: [String: JSONValue]) async
}

public final class ChatRealtimeClient: ChatRealtimeClientProtocol, @unchecked Sendable {
    public let events: AsyncStream<ChatEventEnvelope>
    public let connectionStates: AsyncStream<ChatRealtimeConnectionState>

    private let baseURLProvider: () -> URL
    private let tokenProvider: AuthTokenProvider
    private let service: ChatLabServiceProtocol
    private let session: URLSession
    private let decoder: JSONDecoder

    private let eventContinuation: AsyncStream<ChatEventEnvelope>.Continuation
    private let stateContinuation: AsyncStream<ChatRealtimeConnectionState>.Continuation

    private var runTask: Task<Void, Never>?
    private var socketTask: URLSessionWebSocketTask?
    private var simulationID: Int?
    private var cursor: String?
    private var reconnectAttempt = 0

    private var seenEventIDs = Set<String>()
    private var seenOrder: [String] = []
    private let seenCapacity = 2000

    public init(
        baseURLProvider: @escaping () -> URL,
        tokenProvider: AuthTokenProvider,
        service: ChatLabServiceProtocol,
        session: URLSession = .shared,
    ) {
        self.baseURLProvider = baseURLProvider
        self.tokenProvider = tokenProvider
        self.service = service
        self.session = session

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
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        stateContinuation.yield(.disconnected)
    }

    public func send(eventType: String, payload: [String: JSONValue]) async {
        guard let socketTask else {
            return
        }
        var wirePayload: [String: Any] = ["type": eventType]
        for (key, value) in payload {
            wirePayload[key] = value.rawValue
        }
        guard JSONSerialization.isValidJSONObject(wirePayload),
              let data = try? JSONSerialization.data(withJSONObject: wirePayload),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        do {
            try await socketTask.send(.string(text))
        } catch {
            // Socket send failures are handled by reconnect loop.
        }
    }

    private func runLoop() async {
        guard let simulationID else { return }
        while !Task.isCancelled {
            do {
                stateContinuation.yield(.connecting)
                try await connectAndConsume(simulationID: simulationID)
                reconnectAttempt = 0
            } catch {
                if Task.isCancelled {
                    break
                }
                reconnectAttempt += 1
                stateContinuation.yield(.reconnecting(attempt: reconnectAttempt))
                await performCatchup(simulationID: simulationID)

                let delaySeconds = min(pow(2.0, Double(max(reconnectAttempt - 1, 0))), 15.0)
                let jitter = Double.random(in: 0 ... 0.35)
                try? await Task.sleep(nanoseconds: UInt64((delaySeconds + jitter) * 1_000_000_000))
            }
        }
        stateContinuation.yield(.disconnected)
    }

    private func connectAndConsume(simulationID: Int) async throws {
        let request = try makeWebSocketRequest(simulationID: simulationID)
        let task = session.webSocketTask(with: request)
        socketTask = task
        task.resume()
        stateContinuation.yield(.connected)

        let readyPayload = #"{"type":"client_ready","content_mode":"rawOutput"}"#
        try await task.send(.string(readyPayload))

        while !Task.isCancelled {
            let message = try await task.receive()
            switch message {
            case let .string(text):
                try handleSocketText(text)
            case let .data(data):
                guard let text = String(data: data, encoding: .utf8) else { continue }
                try handleSocketText(text)
            @unknown default:
                continue
            }
        }
    }

    private func makeWebSocketRequest(simulationID: Int) throws -> URLRequest {
        guard let tokens = tokenProvider.loadTokens() else {
            throw URLError(.userAuthenticationRequired)
        }

        let base = baseURLProvider()
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = "/ws/simulation/\(simulationID)/"
        if let scheme = components.scheme {
            components.scheme = scheme == "https" ? "wss" : "ws"
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Correlation-ID")
        return request
    }

    private func handleSocketText(_ text: String) throws {
        guard let data = text.data(using: .utf8) else { return }
        if let envelope = try? decoder.decode(ChatEventEnvelope.self, from: data) {
            cursor = envelope.eventID
            emitIfNew(envelope)
            return
        }

        // Legacy web socket payload format: {"type":"typing", ...}
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        guard let type = object["type"] as? String else { return }

        var payload: [String: JSONValue] = [:]
        for (key, value) in object where key != "type" {
            payload[key] = Self.toJSONValue(value)
        }

        let legacyEnvelope = ChatEventEnvelope(
            eventID: UUID().uuidString.lowercased(),
            eventType: type,
            createdAt: Date(),
            correlationID: nil,
            payload: payload,
        )
        emitIfNew(legacyEnvelope)
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

    private func performCatchup(simulationID: Int) async {
        stateContinuation.yield(.catchingUp)
        var currentCursor = cursor
        do {
            while !Task.isCancelled {
                let page = try await service.listEvents(
                    simulationID: simulationID,
                    cursor: currentCursor,
                    limit: 50,
                )
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
        } catch {
            // Ignore catch-up failures and continue reconnect attempts.
        }
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

    private nonisolated static func toJSONValue(_ any: Any) -> JSONValue {
        if any is NSNull { return .null }
        if let value = any as? Bool { return .bool(value) }
        if let value = any as? Double { return .number(value) }
        if let value = any as? Int { return .number(Double(value)) }
        if let value = any as? String { return .string(value) }
        if let value = any as? [Any] {
            return .array(value.map(toJSONValue))
        }
        if let value = any as? [String: Any] {
            return .object(value.mapValues(toJSONValue))
        }
        return .null
    }
}
