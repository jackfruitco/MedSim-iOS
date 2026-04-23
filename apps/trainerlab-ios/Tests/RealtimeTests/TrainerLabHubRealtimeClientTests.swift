import Foundation
import Networking
import Persistence
import Realtime
import SharedModels
import XCTest

private final class HubMockTokenProvider: AuthTokenProvider, @unchecked Sendable {
    private var tokens: AuthTokens?

    init(tokens: AuthTokens?) {
        self.tokens = tokens
    }

    func loadTokens() -> AuthTokens? {
        tokens
    }

    func saveTokens(_ tokens: AuthTokens) {
        self.tokens = tokens
    }

    func clearTokens() {
        tokens = nil
    }
}

private struct HubStaticAccountContextProvider: AccountContextProvider {
    let accountUUID: String?

    func selectedAccountUUID() async -> String? {
        accountUUID
    }
}

private final class HubURLProtocolMock: URLProtocol {
    struct MockResponse {
        let response: HTTPURLResponse
        let body: Data
        let finishLoading: Bool
    }

    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> MockResponse)?

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
            let mock = try handler(request)
            client?.urlProtocol(self, didReceive: mock.response, cacheStoragePolicy: .notAllowed)
            if !mock.body.isEmpty {
                client?.urlProtocol(self, didLoad: mock.body)
            }
            if mock.finishLoading {
                client?.urlProtocolDidFinishLoading(self)
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class TrainerLabHubRealtimeClientTests: XCTestCase {
    override func tearDown() {
        HubURLProtocolMock.requestHandler = nil
        super.tearDown()
    }

    func testHubRealtimeClientParsesNormalEventFrame() async throws {
        HubURLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let body = """
            event: trainerlab
            data: {"event_id":"hub-1","simulation_id":420,"status":"running","updated_at":"2026-04-23T11:00:00Z"}

            """
            return Self.response(url: url, statusCode: 200, body: body, finishLoading: true)
        }
        let client = makeClient()

        await client.connect(cursor: nil, replay: false)

        let receivedEvent = await Self.awaitFirstValue(from: client.events)
        let event = try XCTUnwrap(receivedEvent)
        XCTAssertEqual(event.eventID, "hub-1")
        XCTAssertEqual(event.simulationID, 420)
        XCTAssertEqual(event.effectiveStatus, .running)
        client.disconnect()
    }

    func testHubRealtimeClientIgnoresKeepAliveComments() async throws {
        HubURLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let body = """
            : keep-alive

            event: trainerlab
            data: {"event_id":"hub-2","simulation_id":421,"status":"paused","updated_at":"2026-04-23T11:01:00Z"}

            """
            return Self.response(url: url, statusCode: 200, body: body, finishLoading: true)
        }
        let client = makeClient()

        await client.connect(cursor: nil, replay: false)

        let receivedEvent = await Self.awaitFirstValue(from: client.events)
        let event = try XCTUnwrap(receivedEvent)
        XCTAssertEqual(event.eventID, "hub-2")
        XCTAssertEqual(event.simulationID, 421)
        XCTAssertEqual(event.effectiveStatus, .paused)
        let failure = await Self.awaitFirstValue(from: client.failures, timeoutNanoseconds: 250_000_000)
        XCTAssertNil(failure)
        client.disconnect()
    }

    func testHubRealtimeClientMaps410ToStaleCursorFailure() async throws {
        HubURLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return Self.response(url: url, statusCode: 410, body: "", finishLoading: true)
        }
        let client = makeClient()

        await client.connect(cursor: "hub-stale", replay: false)

        let receivedFailure = await Self.awaitFirstValue(from: client.failures)
        let failure = try XCTUnwrap(receivedFailure)
        XCTAssertEqual(failure, .staleCursor)
        client.disconnect()
    }

    func testHubRealtimeClientMapsMalformedPayloadToDecodeFailed() async throws {
        HubURLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let body = """
            event: trainerlab
            data: {not-valid-json}

            """
            return Self.response(url: url, statusCode: 200, body: body, finishLoading: true)
        }
        let client = makeClient()

        await client.connect(cursor: "hub-1", replay: false)

        let receivedFailure = await Self.awaitFirstValue(from: client.failures)
        let failure = try XCTUnwrap(receivedFailure)
        XCTAssertEqual(failure, .decodeFailed)
        client.disconnect()
    }

    private func makeClient() -> TrainerLabHubRealtimeClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HubURLProtocolMock.self]
        let session = URLSession(configuration: configuration)
        let tokenProvider = HubMockTokenProvider(tokens: AuthTokens(
            accessToken: "token-1",
            refreshToken: "refresh-1",
            expiresIn: 3600,
            tokenType: "Bearer",
        ))

        return TrainerLabHubRealtimeClient(
            baseURLProvider: { URL(string: "https://example.com")! },
            tokenProvider: tokenProvider,
            accountContextProvider: HubStaticAccountContextProvider(accountUUID: "acct-123"),
            session: session,
            staleThresholdSeconds: 60,
        )
    }

    private static func response(
        url: URL,
        statusCode: Int,
        body: String,
        finishLoading: Bool,
    ) -> HubURLProtocolMock.MockResponse {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/event-stream"],
        )!
        return HubURLProtocolMock.MockResponse(
            response: response,
            body: Data(body.utf8),
            finishLoading: finishLoading,
        )
    }

    private static func awaitFirstValue<Value: Sendable>(
        from stream: AsyncStream<Value>,
        timeoutNanoseconds: UInt64 = 1_500_000_000,
    ) async -> Value? {
        await withTaskGroup(of: Value?.self) { group in
            group.addTask {
                for await value in stream {
                    return value
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
