import Foundation
import Networking
import OSLog
import SharedModels

public protocol ChatRealtimeClientProtocol: Sendable {
    var events: AsyncStream<ChatEventEnvelope> { get }
    var connectionStates: AsyncStream<ChatRealtimeConnectionState> { get }
    func start(simulationID: Int, initialLastEventID: String?) async
    func reconnect(simulationID: Int, lastEventID: String?) async
    func updateReplayAnchor(_ lastEventID: String?) async
    func disconnect()
    func send(eventType: String, payload: [String: JSONValue]) async
}

private let realtimeLogger = Logger(subsystem: "com.jackfruit.medsim", category: "ChatRealtime")

private enum ChatRealtimeHandshakeMode: String {
    case hello
    case resume
}

private enum ChatRealtimeCoordinatorError: Error {
    case resyncRequired
    case terminal(String?)
}

protocol ChatWebSocketTaskProtocol: AnyObject, Sendable {
    var closeCode: URLSessionWebSocketTask.CloseCode { get }
    var closeReason: Data? { get }
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
}

protocol ChatWebSocketConnecting: Sendable {
    func makeWebSocketTask(with request: URLRequest) -> ChatWebSocketTaskProtocol
}

private final class URLSessionWebSocketTaskAdapter: ChatWebSocketTaskProtocol, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    var closeCode: URLSessionWebSocketTask.CloseCode {
        task.closeCode
    }

    var closeReason: Data? {
        task.closeReason
    }

    func resume() {
        task.resume()
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        task.cancel(with: closeCode, reason: reason)
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        try await task.send(message)
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try await task.receive()
    }
}

private struct URLSessionWebSocketConnector: ChatWebSocketConnecting {
    let session: URLSession

    func makeWebSocketTask(with request: URLRequest) -> ChatWebSocketTaskProtocol {
        URLSessionWebSocketTaskAdapter(task: session.webSocketTask(with: request))
    }
}

private actor ChatRealtimeCoordinator {
    private let authLoader: AuthorizedResourceLoading
    private let connector: ChatWebSocketConnecting
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let emitEvent: @Sendable (ChatEventEnvelope) -> Void
    private let emitState: @Sendable (ChatRealtimeConnectionState) -> Void

    private var runTask: Task<Void, Never>?
    private var socketTask: ChatWebSocketTaskProtocol?
    private var simulationID: Int?
    private var lastEventID: String?
    private var nextHandshakeMode: ChatRealtimeHandshakeMode = .hello
    private var reconnectAttempt = 0
    private var isRunning = false
    private var resyncRequested = false

    init(
        authLoader: AuthorizedResourceLoading,
        connector: ChatWebSocketConnecting,
        decoder: JSONDecoder,
        encoder: JSONEncoder,
        emitEvent: @escaping @Sendable (ChatEventEnvelope) -> Void,
        emitState: @escaping @Sendable (ChatRealtimeConnectionState) -> Void,
    ) {
        self.authLoader = authLoader
        self.connector = connector
        self.decoder = decoder
        self.encoder = encoder
        self.emitEvent = emitEvent
        self.emitState = emitState
    }

    func start(simulationID: Int, initialLastEventID: String?) {
        stopCurrentRun(closeCode: .goingAway, reason: "restart")
        self.simulationID = simulationID
        lastEventID = initialLastEventID
        nextHandshakeMode = .hello
        reconnectAttempt = 0
        resyncRequested = false
        isRunning = true
        emitState(.connecting)
        runTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func reconnect(simulationID: Int, lastEventID: String?) {
        stopCurrentRun(closeCode: .goingAway, reason: "reconnect")
        self.simulationID = simulationID
        self.lastEventID = lastEventID
        nextHandshakeMode = .resume
        reconnectAttempt = 0
        resyncRequested = false
        isRunning = true
        emitState(.connecting)
        runTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func updateReplayAnchor(_ lastEventID: String?) {
        self.lastEventID = lastEventID
    }

    func disconnect() {
        isRunning = false
        resyncRequested = false
        reconnectAttempt = 0
        stopCurrentRun(closeCode: .normalClosure, reason: "disconnect")
        emitState(.idle)
    }

    func send(eventType: String, payload: [String: JSONValue]) async {
        let currentSimulationID = simulationID ?? -1
        let currentLastEventID = lastEventID ?? "nil"
        guard let socketTask else {
            realtimeLogger.warning(
                "Dropping outbound ChatLab event because no active socket exists. event_type=\(eventType, privacy: .public) simulation_id=\(currentSimulationID, privacy: .public) last_event_id=\(currentLastEventID, privacy: .public)",
            )
            return
        }

        let correlationID = UUID().uuidString.lowercased()
        let message = ChatRealtimeOutboundMessage(
            eventType: eventType,
            correlationID: correlationID,
            payload: payload,
        )

        do {
            let data = try encoder.encode(message)
            guard let text = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            try await socketTask.send(.string(text))
            realtimeLogger.info(
                "Sent ChatLab outbound event event_type=\(eventType, privacy: .public) correlation_id=\(correlationID, privacy: .public) simulation_id=\(currentSimulationID, privacy: .public) last_event_id=\(currentLastEventID, privacy: .public)",
            )
        } catch {
            realtimeLogger.error(
                "Failed sending ChatLab outbound event event_type=\(eventType, privacy: .public) correlation_id=\(correlationID, privacy: .public) simulation_id=\(currentSimulationID, privacy: .public) error=\(error.localizedDescription, privacy: .public)",
            )
        }
    }

    private func runLoop() async {
        defer {
            stopCurrentRun(closeCode: .normalClosure, reason: "run_loop_complete")
            emitState(.idle)
        }

        while isRunning, !Task.isCancelled {
            let handshakeMode = nextHandshakeMode

            do {
                try await openSocketAndRun(handshakeMode: handshakeMode)
                if !isRunning || Task.isCancelled {
                    return
                }
                reconnectAttempt += 1
                emitState(.reconnecting(attempt: reconnectAttempt))
                let currentReconnectAttempt = reconnectAttempt
                let currentSimulationID = simulationID ?? -1
                let currentLastEventID = lastEventID ?? "nil"
                realtimeLogger.warning(
                    "ChatLab socket ended unexpectedly; scheduling reconnect attempt=\(currentReconnectAttempt, privacy: .public) simulation_id=\(currentSimulationID, privacy: .public) last_event_id=\(currentLastEventID, privacy: .public)",
                )
            } catch ChatRealtimeCoordinatorError.resyncRequired {
                emitState(.resyncing)
                return
            } catch let ChatRealtimeCoordinatorError.terminal(message) {
                emitState(.failed(message: message))
                return
            } catch {
                if !isRunning || Task.isCancelled {
                    return
                }

                reconnectAttempt += 1
                emitState(.reconnecting(attempt: reconnectAttempt))
                let currentReconnectAttempt = reconnectAttempt
                let currentSimulationID = simulationID ?? -1
                let currentLastEventID = lastEventID ?? "nil"
                realtimeLogger.error(
                    "ChatLab socket failure; scheduling reconnect attempt=\(currentReconnectAttempt, privacy: .public) simulation_id=\(currentSimulationID, privacy: .public) last_event_id=\(currentLastEventID, privacy: .public) error=\(error.localizedDescription, privacy: .public)",
                )
            }

            nextHandshakeMode = resolvedHandshakeMode(requested: .resume)
            let delaySeconds = min(pow(2.0, Double(max(reconnectAttempt - 1, 0))), 15.0)
            let jitter = Double.random(in: 0 ... 0.35)
            try? await Task.sleep(nanoseconds: UInt64((delaySeconds + jitter) * 1_000_000_000))
        }
    }

    private func openSocketAndRun(handshakeMode: ChatRealtimeHandshakeMode) async throws {
        guard let simulationID else {
            return
        }

        let resolvedHandshakeMode = resolvedHandshakeMode(requested: handshakeMode)
        let route = ChatLabAPI.realtimeSocket()
        let request = try await authLoader.makeWebSocketRequest(for: route)
        let socketTask = connector.makeWebSocketTask(with: request)
        self.socketTask = socketTask
        let currentLastEventID = lastEventID ?? "nil"

        realtimeLogger.info(
            "Opening ChatLab WebSocket simulation_id=\(simulationID, privacy: .public) handshake=\(resolvedHandshakeMode.rawValue, privacy: .public) last_event_id=\(currentLastEventID, privacy: .public)",
        )
        socketTask.resume()

        try await sendHandshake(
            resolvedHandshakeMode,
            simulationID: simulationID,
            socketTask: socketTask,
        )
        try await receiveLoop(socketTask: socketTask)
    }

    private func sendHandshake(
        _ handshakeMode: ChatRealtimeHandshakeMode,
        simulationID: Int,
        socketTask: ChatWebSocketTaskProtocol,
    ) async throws {
        let correlationID = UUID().uuidString.lowercased()
        var payload: [String: JSONValue] = [
            "simulation_id": .number(Double(simulationID)),
        ]
        let currentLastEventID = lastEventID ?? "nil"
        switch handshakeMode {
        case .hello:
            if let lastEventID {
                payload["last_event_id"] = .string(lastEventID)
            }
        case .resume:
            payload["last_event_id"] = lastEventID.map(JSONValue.string) ?? .null
        }

        let eventType = handshakeMode == .hello
            ? ChatRealtimeEventType.sessionHello
            : ChatRealtimeEventType.sessionResume
        let outbound = ChatRealtimeOutboundMessage(
            eventType: eventType,
            correlationID: correlationID,
            payload: payload,
        )
        let data = try encoder.encode(outbound)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        try await socketTask.send(.string(text))
        realtimeLogger.info(
            "Sent ChatLab handshake event_type=\(eventType, privacy: .public) correlation_id=\(correlationID, privacy: .public) simulation_id=\(simulationID, privacy: .public) last_event_id=\(currentLastEventID, privacy: .public)",
        )
    }

    private func receiveLoop(socketTask: ChatWebSocketTaskProtocol) async throws {
        while isRunning, !Task.isCancelled {
            do {
                let message = try await socketTask.receive()
                let text = try messageText(message)
                guard let event = decodeEnvelope(from: text) else {
                    continue
                }
                try handleInboundEnvelope(event)
            } catch {
                let closeCode = socketTask.closeCode.rawValue
                let closeReason = decodeCloseReason(socketTask.closeReason)
                let currentSimulationID = simulationID ?? -1
                let currentLastEventID = lastEventID ?? "nil"
                let currentReconnectAttempt = reconnectAttempt
                realtimeLogger.info(
                    "ChatLab socket closed simulation_id=\(currentSimulationID, privacy: .public) close_code=\(closeCode, privacy: .public) reason=\(closeReason ?? "nil", privacy: .public) last_event_id=\(currentLastEventID, privacy: .public) reconnect_attempt=\(currentReconnectAttempt, privacy: .public)",
                )

                self.socketTask = nil

                if resyncRequested || closeCode == 4409 {
                    throw ChatRealtimeCoordinatorError.resyncRequired
                }
                if !isRunning || Task.isCancelled {
                    return
                }
                throw error
            }
        }
    }

    private func handleInboundEnvelope(_ event: ChatEventEnvelope) throws {
        emitEvent(event)
        let currentSimulationID = simulationID ?? -1
        let currentLastEventID = lastEventID ?? "nil"
        let currentReconnectAttempt = reconnectAttempt

        realtimeLogger.info(
            "Received ChatLab event event_id=\(event.eventID, privacy: .public) event_type=\(event.eventType, privacy: .public) correlation_id=\(event.correlationID ?? "nil", privacy: .public) simulation_id=\(currentSimulationID, privacy: .public) last_event_id=\(currentLastEventID, privacy: .public) reconnect_attempt=\(currentReconnectAttempt, privacy: .public)",
        )

        switch event.eventType {
        case ChatRealtimeEventType.sessionReady, ChatRealtimeEventType.sessionResumed:
            reconnectAttempt = 0
            nextHandshakeMode = resolvedHandshakeMode(requested: .resume)
            emitState(.connected)

        case ChatRealtimeEventType.sessionResyncRequired:
            resyncRequested = true
            emitState(.resyncing)
            realtimeLogger.warning(
                "ChatLab server requested hard resync simulation_id=\(currentSimulationID, privacy: .public) event_id=\(event.eventID, privacy: .public) correlation_id=\(event.correlationID ?? "nil", privacy: .public) last_event_id=\(currentLastEventID, privacy: .public)",
            )

        case ChatRealtimeEventType.error:
            let payload = try? event.errorPayload()
            let terminalCodes: Set = [
                "access_denied",
                "session_already_established",
                "session_required",
                "invalid_json",
                "invalid_shape",
                "invalid_payload",
                "invalid_last_event_id",
                "unsupported_event_type",
            ]
            if let payload, terminalCodes.contains(payload.code) {
                realtimeLogger.error(
                    "Received terminal ChatLab error code=\(payload.code, privacy: .public) simulation_id=\(currentSimulationID, privacy: .public) correlation_id=\(event.correlationID ?? "nil", privacy: .public)",
                )
                throw ChatRealtimeCoordinatorError.terminal(payload.message)
            }

        case ChatRealtimeEventType.pong:
            emitState(.connected)

        default:
            break
        }
    }

    private func resolvedHandshakeMode(requested requestedMode: ChatRealtimeHandshakeMode) -> ChatRealtimeHandshakeMode {
        guard requestedMode == .resume else {
            return .hello
        }
        guard let lastEventID, !lastEventID.isEmpty else {
            return .hello
        }
        return .resume
    }

    private func decodeEnvelope(from text: String) -> ChatEventEnvelope? {
        guard let data = text.data(using: .utf8) else {
            realtimeLogger.error("Failed parsing ChatLab envelope because payload was not UTF-8")
            return nil
        }

        do {
            return try decoder.decode(ChatEventEnvelope.self, from: data)
        } catch {
            realtimeLogger.error(
                "Failed parsing ChatLab envelope error=\(error.localizedDescription, privacy: .public) payload_prefix=\(String(text.prefix(256)), privacy: .public)",
            )
            return nil
        }
    }

    private func messageText(_ message: URLSessionWebSocketTask.Message) throws -> String {
        switch message {
        case let .string(text):
            return text
        case let .data(data):
            guard let text = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            return text
        @unknown default:
            throw URLError(.unsupportedURL)
        }
    }

    private func stopCurrentRun(closeCode: URLSessionWebSocketTask.CloseCode, reason: String) {
        runTask?.cancel()
        runTask = nil
        if let socketTask {
            socketTask.cancel(with: closeCode, reason: reason.data(using: .utf8))
        }
        socketTask = nil
    }

    private func decodeCloseReason(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

public final class ChatRealtimeClient: ChatRealtimeClientProtocol, @unchecked Sendable {
    public let events: AsyncStream<ChatEventEnvelope>
    public let connectionStates: AsyncStream<ChatRealtimeConnectionState>

    private let coordinator: ChatRealtimeCoordinator

    public convenience init(
        authLoader: AuthorizedResourceLoading,
        session: URLSession = .shared,
    ) {
        self.init(
            authLoader: authLoader,
            session: session,
            connector: nil,
        )
    }

    init(
        authLoader: AuthorizedResourceLoading,
        session: URLSession = .shared,
        connector: ChatWebSocketConnecting? = nil,
    ) {
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

        let encoder = JSONEncoder()

        var eventCont: AsyncStream<ChatEventEnvelope>.Continuation!
        events = AsyncStream<ChatEventEnvelope> { continuation in
            eventCont = continuation
        }
        let eventContinuation = eventCont!

        var stateCont: AsyncStream<ChatRealtimeConnectionState>.Continuation!
        connectionStates = AsyncStream<ChatRealtimeConnectionState> { continuation in
            stateCont = continuation
            continuation.yield(.idle)
        }
        let stateContinuation = stateCont!

        coordinator = ChatRealtimeCoordinator(
            authLoader: authLoader,
            connector: connector ?? URLSessionWebSocketConnector(session: session),
            decoder: decoder,
            encoder: encoder,
            emitEvent: { continuationEvent in
                eventContinuation.yield(continuationEvent)
            },
            emitState: { state in
                stateContinuation.yield(state)
            },
        )
    }

    public func start(simulationID: Int, initialLastEventID: String?) async {
        await coordinator.start(simulationID: simulationID, initialLastEventID: initialLastEventID)
    }

    public func reconnect(simulationID: Int, lastEventID: String?) async {
        await coordinator.reconnect(simulationID: simulationID, lastEventID: lastEventID)
    }

    public func updateReplayAnchor(_ lastEventID: String?) async {
        await coordinator.updateReplayAnchor(lastEventID)
    }

    public func disconnect() {
        Task {
            await coordinator.disconnect()
        }
    }

    public func send(eventType: String, payload: [String: JSONValue]) async {
        await coordinator.send(eventType: eventType, payload: payload)
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
