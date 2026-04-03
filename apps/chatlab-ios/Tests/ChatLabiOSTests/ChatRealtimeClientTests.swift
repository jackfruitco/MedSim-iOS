@testable import ChatLabiOS
import Foundation
import Networking
import SharedModels
import XCTest

private enum ChatRealtimeClientTestError: Error {
    case unexpectedCall
}

private final class ChatRealtimeURLProtocolMock: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("Missing request handler")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private actor RecordingAuthorizedResourceLoader: AuthorizedResourceLoading {
    private let baseURLValue: URL
    private let accountUUID: String?
    private var accessToken: String
    private(set) var refreshCalls = 0
    private(set) var routes: [EventStreamRoute] = []

    init(baseURL: URL, accessToken: String = "token-1", accountUUID: String? = "acct-1") {
        baseURLValue = baseURL
        self.accountUUID = accountUUID
        self.accessToken = accessToken
    }

    func baseURL() async -> URL {
        baseURLValue
    }

    func makeEventStreamRequest(for route: EventStreamRoute) async throws -> URLRequest {
        routes.append(route)
        return try route.makeURLRequest(
            baseURL: baseURLValue,
            accessToken: accessToken,
            accountUUID: accountUUID,
        )
    }

    func loadData(from _: URL, accept _: String?, requiresAccountContext _: Bool) async throws -> Data {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func refreshAccessToken() async throws {
        refreshCalls += 1
        accessToken = "token-refreshed"
    }

    func recordedRoutes() -> [EventStreamRoute] {
        routes
    }
}

private actor RealtimeClientServiceStub: ChatLabServiceProtocol {
    private(set) var listEventsCalls = 0
    var catchupResponse = PaginatedResponse<ChatEventEnvelope>(items: [], nextCursor: nil, hasMore: false)

    func listSimulations(
        limit _: Int,
        cursor _: String?,
        status _: String?,
        query _: String?,
        searchMessages _: Bool,
    ) async throws -> PaginatedResponse<ChatSimulation> {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func quickCreateSimulation(request _: ChatQuickCreateRequest) async throws -> ChatSimulation {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func getSimulation(simulationID _: Int) async throws -> ChatSimulation {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func endSimulation(simulationID _: Int) async throws -> ChatSimulation {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func retryInitial(simulationID _: Int) async throws -> ChatSimulation {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func retryFeedback(simulationID _: Int) async throws -> ChatSimulation {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func listConversations(simulationID _: Int) async throws -> ChatConversationListResponse {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func createConversation(simulationID _: Int, request _: ChatCreateConversationRequest) async throws -> ChatConversation {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func getConversation(simulationID _: Int, conversationUUID _: String) async throws -> ChatConversation {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func listMessages(
        simulationID _: Int,
        conversationID _: Int?,
        cursor _: String?,
        order _: String,
        limit _: Int,
    ) async throws -> PaginatedResponse<ChatMessage> {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func createMessage(simulationID _: Int, request _: ChatCreateMessageRequest) async throws -> ChatMessage {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func retryMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func getMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func markMessageRead(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<ChatEventEnvelope> {
        listEventsCalls += 1
        return catchupResponse
    }

    func listTools(simulationID _: Int, names _: [String]?) async throws -> ChatToolListResponse {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func getTool(simulationID _: Int, toolName _: String) async throws -> ChatToolState {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func signOrders(simulationID _: Int, request _: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func submitLabOrders(simulationID _: Int, request _: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        throw ChatRealtimeClientTestError.unexpectedCall
    }

    func listModifierGroups(groups _: [String]?) async throws -> [ModifierGroup] {
        throw ChatRealtimeClientTestError.unexpectedCall
    }
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

final class ChatRealtimeClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        ChatRealtimeURLProtocolMock.requestHandler = nil
    }

    func testParserProducesMessageEventFromValidEnvelope() throws {
        let eventJSON = try makeEnvelopeJSON(
            eventID: "evt-1",
            payload: ["message_id": 901, "conversation_id": 3, "content": "hello", "is_from_ai": true],
        )
        let items = ChatSSEParser.parseLines(
            [
                "event: simulation",
                "data: \(eventJSON)",
                "",
            ],
            decoder: makeDecoder(),
        )

        XCTAssertEqual(items.count, 1)
        guard case let .event(event) = items[0] else {
            return XCTFail("Expected a decoded event")
        }
        XCTAssertEqual(event.eventID, "evt-1")
        XCTAssertEqual(event.eventType, SimulationEventType.messageItemCreated)
        XCTAssertEqual(event.payload["message_id"], .number(901))
    }

    func testCommentLinesDoNotBlockSubsequentEventDelivery() throws {
        let eventJSON = try makeEnvelopeJSON(
            eventID: "evt-keepalive",
            payload: ["message_id": 902, "content": "after heartbeat"],
        )
        let items = ChatSSEParser.parseLines(
            [
                ": keep-alive",
                "",
                ": keep-alive",
                "",
                "event: simulation",
                "data: \(eventJSON)",
                "",
            ],
            decoder: makeDecoder(),
        )

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], .keepAlive)
        XCTAssertEqual(items[1], .keepAlive)
        guard case let .event(event) = items[2] else {
            return XCTFail("Expected the final item to be a decoded event")
        }
        XCTAssertEqual(event.eventID, "evt-keepalive")
    }

    func testMalformedEventIsSkippedAndValidEventStillArrives() throws {
        let validEventJSON = try makeEnvelopeJSON(
            eventID: "evt-good",
            payload: ["message_id": 903, "conversation_id": 4, "content": "still arrives", "is_from_ai": true],
        )
        let items = ChatSSEParser.parseLines(
            [
                "event: simulation",
                "data: {\"event_id\":\"evt-bad\",\"event_type\":\"message.item.created\"",
                "",
                "event: simulation",
                "data: \(validEventJSON)",
                "",
            ],
            decoder: makeDecoder(),
        )

        XCTAssertEqual(items.count, 1)
        guard case let .event(event) = items[0] else {
            return XCTFail("Expected the malformed payload to be skipped and the valid one to decode")
        }
        XCTAssertEqual(event.eventID, "evt-good")
    }

    func testParserHandlesSSEIDLinesAndCarriageReturnBoundaries() throws {
        let firstEventJSON = try makeEnvelopeJSON(
            eventID: "evt-first",
            payload: ["message_id": 904, "conversation_id": 5, "content": "first"],
        )
        let secondEventJSON = try makeEnvelopeJSON(
            eventID: "evt-second",
            payload: ["message_id": 905, "conversation_id": 5, "content": "second", "is_from_ai": true],
        )
        let items = ChatSSEParser.parseLines(
            [
                "id: upstream-first",
                "event: simulation",
                "data: \(firstEventJSON)",
                "\r",
                "id: upstream-second",
                "event: simulation",
                "data: \(secondEventJSON)",
                "\r",
            ],
            decoder: makeDecoder(),
        )

        XCTAssertEqual(items.count, 2)
        guard case let .event(firstEvent) = items[0] else {
            return XCTFail("Expected the first SSE event to decode")
        }
        guard case let .event(secondEvent) = items[1] else {
            return XCTFail("Expected the second SSE event to decode")
        }
        XCTAssertEqual(firstEvent.eventID, "evt-first")
        XCTAssertEqual(secondEvent.eventID, "evt-second")
    }

    func testNonSuccessStreamOpenTransitionsToReconnectAndCatchup() async throws {
        let baseURL = try XCTUnwrap(URL(string: "https://example.com"))
        let authLoader = RecordingAuthorizedResourceLoader(baseURL: baseURL)
        let service = RealtimeClientServiceStub()
        let session = makeSession { request in
            let url = try XCTUnwrap(request.url)
            return (
                HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!,
                Data(),
            )
        }
        let realtime = ChatRealtimeClient(authLoader: authLoader, service: service, session: session, staleThresholdSeconds: 5)

        let stateBuffer = AsyncBuffer<ChatRealtimeConnectionState>()
        let stateTask = Task {
            for await state in realtime.connectionStates {
                await stateBuffer.append(state)
            }
        }
        defer {
            realtime.disconnect()
            stateTask.cancel()
        }

        await realtime.connect(simulationID: 7, cursor: nil)

        try await waitUntil {
            let states = await stateBuffer.snapshot()
            let catchupCalls = await service.listEventsCalls
            return states.contains(.catchingUp) &&
                states.contains(where: {
                    if case .reconnecting(attempt: 1) = $0 { return true }
                    return false
                }) &&
                catchupCalls > 0
        }
    }

    private func makeSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChatRealtimeURLProtocolMock.self]
        ChatRealtimeURLProtocolMock.requestHandler = handler
        return URLSession(configuration: configuration)
    }

    private func makeEnvelopeJSON(
        eventID: String,
        eventType: String = SimulationEventType.messageItemCreated,
        payload: [String: Any],
    ) throws -> String {
        let envelope: [String: Any] = [
            "event_id": eventID,
            "event_type": eventType,
            "created_at": "2026-03-12T12:00:00Z",
            "correlation_id": NSNull(),
            "payload": payload,
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ChatRealtimeClientTestError.unexpectedCall
        }
        return string
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @escaping () async -> Bool,
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
