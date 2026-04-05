@testable import ChatLabiOS
import Foundation
import Networking
import SharedModels
import XCTest

private final class ChatRealtimeAuthorizedResourceLoader: AuthorizedResourceLoading, @unchecked Sendable {
    private let baseURLValue: URL
    private let accountUUID: String?
    private let accessToken: String
    private(set) var webSocketRoutes: [WebSocketRoute] = []

    init(baseURL: URL, accessToken: String = "token-1", accountUUID: String? = "acct-1") {
        baseURLValue = baseURL
        self.accountUUID = accountUUID
        self.accessToken = accessToken
    }

    func baseURL() async -> URL {
        baseURLValue
    }

    func makeEventStreamRequest(for route: EventStreamRoute) async throws -> URLRequest {
        try route.makeURLRequest(
            baseURL: baseURLValue,
            accessToken: accessToken,
            accountUUID: accountUUID,
        )
    }

    func makeWebSocketRequest(for route: WebSocketRoute) async throws -> URLRequest {
        webSocketRoutes.append(route)
        return try route.makeURLRequest(
            baseURL: baseURLValue,
            accessToken: accessToken,
            accountUUID: accountUUID,
        )
    }

    func loadData(from _: URL, accept _: String?, requiresAccountContext _: Bool) async throws -> Data {
        throw URLError(.badURL)
    }

    func refreshAccessToken() async throws {}
}

private actor AsyncBuffer<Element: Sendable> {
    private var items: [Element] = []

    func append(_ item: Element) {
        items.append(item)
    }

    func snapshot() -> [Element] {
        items
    }
}

private final class MockWebSocketTask: ChatWebSocketTaskProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var queuedResults: [Result<URLSessionWebSocketTask.Message, Error>] = []
    private var waitingContinuation: CheckedContinuation<Result<URLSessionWebSocketTask.Message, Error>, Never>?
    private var sentMessagesStorage: [URLSessionWebSocketTask.Message] = []

    var closeCode: URLSessionWebSocketTask.CloseCode = .invalid
    var closeReason: Data?

    func resume() {}

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let continuation = lock.withLock { () -> CheckedContinuation<Result<URLSessionWebSocketTask.Message, Error>, Never>? in
            self.closeCode = closeCode
            closeReason = reason
            let continuation = waitingContinuation
            waitingContinuation = nil
            return continuation
        }
        continuation?.resume(returning: .failure(URLError(.cancelled)))
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        lock.withLock {
            sentMessagesStorage.append(message)
        }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        let result: Result<URLSessionWebSocketTask.Message, Error> = if let queued = lock.withLock({ queuedResults.isEmpty ? nil : queuedResults.removeFirst() }) {
            queued
        } else {
            await withCheckedContinuation { continuation in
                lock.withLock {
                    waitingContinuation = continuation
                }
            }
        }
        return try result.get()
    }

    func enqueue(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<Result<URLSessionWebSocketTask.Message, Error>, Never>? in
            if let waitingContinuation {
                self.waitingContinuation = nil
                return waitingContinuation
            }
            queuedResults.append(result)
            return nil
        }
        continuation?.resume(returning: result)
    }

    func setClose(code: URLSessionWebSocketTask.CloseCode, reason: String? = nil) {
        lock.withLock {
            closeCode = code
            closeReason = reason?.data(using: .utf8)
        }
    }

    func sentMessages() -> [URLSessionWebSocketTask.Message] {
        lock.withLock { sentMessagesStorage }
    }
}

private final class MockWebSocketConnector: ChatWebSocketConnecting, @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [MockWebSocketTask]
    private var requests: [URLRequest] = []

    init(tasks: [MockWebSocketTask]) {
        self.tasks = tasks
    }

    func makeWebSocketTask(with request: URLRequest) -> ChatWebSocketTaskProtocol {
        lock.withLock {
            requests.append(request)
            return tasks.removeFirst()
        }
    }

    func snapshotRequests() -> [URLRequest] {
        lock.withLock { requests }
    }
}

final class ChatRealtimeClientTests: XCTestCase {
    func testStartSendsSessionHelloWithInitialLastEventID() async throws {
        let task = MockWebSocketTask()
        let connector = MockWebSocketConnector(tasks: [task])
        let loader = try ChatRealtimeAuthorizedResourceLoader(baseURL: XCTUnwrap(URL(string: "https://example.com")))
        let client = ChatRealtimeClient(authLoader: loader, session: .shared, connector: connector)

        await client.start(simulationID: 42, initialLastEventID: "evt-bootstrap")
        defer { client.disconnect() }

        try await waitUntil { task.sentMessages().count == 1 }
        let outbound = try decodeOutbound(task.sentMessages()[0])

        XCTAssertEqual(loader.webSocketRoutes.first?.path, "/ws/v1/chatlab/")
        XCTAssertEqual(outbound.eventType, ChatRealtimeEventType.sessionHello)
        XCTAssertEqual(outbound.payload["simulation_id"], .number(42))
        XCTAssertEqual(outbound.payload["last_event_id"], .string("evt-bootstrap"))
    }

    func testReconnectSendsSessionResumeWithLastEventID() async throws {
        let task = MockWebSocketTask()
        let connector = MockWebSocketConnector(tasks: [task])
        let loader = try ChatRealtimeAuthorizedResourceLoader(baseURL: XCTUnwrap(URL(string: "https://example.com")))
        let client = ChatRealtimeClient(authLoader: loader, session: .shared, connector: connector)

        await client.reconnect(simulationID: 42, lastEventID: "evt-9")
        defer { client.disconnect() }

        try await waitUntil { task.sentMessages().count == 1 }
        let outbound = try decodeOutbound(task.sentMessages()[0])

        XCTAssertEqual(outbound.eventType, ChatRealtimeEventType.sessionResume)
        XCTAssertEqual(outbound.payload["simulation_id"], .number(42))
        XCTAssertEqual(outbound.payload["last_event_id"], .string("evt-9"))
    }

    func testLifecycleEventsDriveConnectedAndResyncingStates() async throws {
        let task = MockWebSocketTask()
        let connector = MockWebSocketConnector(tasks: [task])
        let loader = try ChatRealtimeAuthorizedResourceLoader(baseURL: XCTUnwrap(URL(string: "https://example.com")))
        let client = ChatRealtimeClient(authLoader: loader, session: .shared, connector: connector)

        let stateBuffer = AsyncBuffer<ChatRealtimeConnectionState>()
        let stateTask = Task {
            for await state in client.connectionStates {
                await stateBuffer.append(state)
            }
        }
        defer { stateTask.cancel() }

        await client.start(simulationID: 42, initialLastEventID: "evt-bootstrap")
        defer { client.disconnect() }

        try task.enqueue(.success(.string(makeEnvelopeJSON(
            eventID: "evt-ready",
            eventType: ChatRealtimeEventType.sessionReady,
            payload: ["simulation_id": .number(42)],
        ))))
        try task.enqueue(.success(.string(makeEnvelopeJSON(
            eventID: "evt-resync",
            eventType: ChatRealtimeEventType.sessionResyncRequired,
            payload: ["reason": .string("replay_gap"), "last_event_id": .string("evt-bootstrap")],
        ))))
        task.setClose(code: URLSessionWebSocketTask.CloseCode(rawValue: 4409) ?? .invalid, reason: "resync")
        task.enqueue(.failure(URLError(.networkConnectionLost)))

        try await waitUntil {
            let states = await stateBuffer.snapshot()
            return states.contains(.connected) && states.contains(.resyncing)
        }
    }

    func testUnexpectedDisconnectReconnectsWithResumeHandshake() async throws {
        let firstTask = MockWebSocketTask()
        let secondTask = MockWebSocketTask()
        let connector = MockWebSocketConnector(tasks: [firstTask, secondTask])
        let loader = try ChatRealtimeAuthorizedResourceLoader(baseURL: XCTUnwrap(URL(string: "https://example.com")))
        let client = ChatRealtimeClient(authLoader: loader, session: .shared, connector: connector)

        await client.start(simulationID: 42, initialLastEventID: "evt-1")
        defer { client.disconnect() }

        try firstTask.enqueue(.success(.string(makeEnvelopeJSON(
            eventID: "evt-ready",
            eventType: ChatRealtimeEventType.sessionReady,
            payload: ["simulation_id": .number(42)],
        ))))
        firstTask.setClose(code: .goingAway, reason: "network")
        firstTask.enqueue(.failure(URLError(.networkConnectionLost)))

        try await waitUntil { secondTask.sentMessages().count == 1 }
        let outbound = try decodeOutbound(secondTask.sentMessages()[0])

        XCTAssertEqual(outbound.eventType, ChatRealtimeEventType.sessionResume)
        XCTAssertEqual(outbound.payload["last_event_id"], .string("evt-1"))
    }

    func testSendUsesCanonicalOutboundEnvelope() async throws {
        let task = MockWebSocketTask()
        let connector = MockWebSocketConnector(tasks: [task])
        let loader = try ChatRealtimeAuthorizedResourceLoader(baseURL: XCTUnwrap(URL(string: "https://example.com")))
        let client = ChatRealtimeClient(authLoader: loader, session: .shared, connector: connector)

        await client.start(simulationID: 42, initialLastEventID: "evt-1")
        defer { client.disconnect() }
        try await waitUntil { task.sentMessages().count == 1 }

        await client.send(
            eventType: ChatRealtimeEventType.typingStarted,
            payload: ["conversation_id": .number(3)],
        )

        try await waitUntil { task.sentMessages().count == 2 }
        let outbound = try decodeOutbound(task.sentMessages()[1])

        XCTAssertEqual(outbound.eventType, ChatRealtimeEventType.typingStarted)
        XCTAssertEqual(outbound.payload["conversation_id"], .number(3))
        XCTAssertNotNil(outbound.correlationID)
    }

    private func decodeOutbound(_ message: URLSessionWebSocketTask.Message) throws -> ChatRealtimeOutboundMessageCapture {
        switch message {
        case let .string(text):
            return try JSONDecoder().decode(ChatRealtimeOutboundMessageCapture.self, from: Data(text.utf8))
        case let .data(data):
            return try JSONDecoder().decode(ChatRealtimeOutboundMessageCapture.self, from: data)
        @unknown default:
            XCTFail("Unexpected websocket message kind")
            throw URLError(.unsupportedURL)
        }
    }

    private func makeEnvelopeJSON(
        eventID: String,
        eventType: String,
        payload: [String: JSONValue],
    ) throws -> String {
        let envelope = ChatEventEnvelope(
            eventID: eventID,
            eventType: eventType,
            createdAt: Date(timeIntervalSince1970: 1_742_000_000),
            correlationID: "corr-\(eventID)",
            payload: payload,
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        guard let text = String(bytes: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return text
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @escaping @Sendable () async -> Bool,
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }
}

private struct ChatRealtimeOutboundMessageCapture: Decodable, Equatable {
    let eventType: String
    let correlationID: String?
    let payload: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case correlationID = "correlation_id"
        case payload
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
