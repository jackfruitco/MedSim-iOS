import Foundation
import Networking
import Persistence
import SharedModels
import XCTest

private final class FeedbackMockTokenProvider: AuthTokenProvider, @unchecked Sendable {
    private var stored: AuthTokens?

    init(tokens: AuthTokens?) {
        stored = tokens
    }

    func loadTokens() -> AuthTokens? {
        stored
    }

    func saveTokens(_ tokens: AuthTokens) {
        stored = tokens
    }

    func clearTokens() {
        stored = nil
    }
}

private struct FeedbackStaticAccountContextProvider: AccountContextProvider {
    let accountUUID: String?

    func selectedAccountUUID() async -> String? {
        accountUUID
    }
}

private final class FeedbackURLProtocolMock: URLProtocol {
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

final class FeedbackNetworkingTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        FeedbackURLProtocolMock.requestHandler = nil
    }

    func testFeedbackCategoryRoundTripsCodable() throws {
        for category in FeedbackCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(FeedbackCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }

    func testFeedbackCreateRequestEncodesExpectedKeysAndOmitsNilOptionals() throws {
        let request = FeedbackCreateRequest(
            category: .featureRequest,
            title: "Wish list",
            body: "Please add this.",
            simulationID: 42,
            conversationID: 7,
            rating: 5,
            allowFollowUp: true,
            context: [
                "source_screen": .string("settings"),
                "submission_scope": .string("general"),
            ],
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["category"] as? String, "feature_request")
        XCTAssertEqual(object["title"] as? String, "Wish list")
        XCTAssertEqual(object["body"] as? String, "Please add this.")
        XCTAssertEqual(object["simulation_id"] as? Int, 42)
        XCTAssertEqual(object["conversation_id"] as? Int, 7)
        XCTAssertEqual(object["rating"] as? Int, 5)
        XCTAssertEqual(object["allow_follow_up"] as? Bool, true)
        XCTAssertNotNil(object["context"])

        let sparse = FeedbackCreateRequest(category: .other, body: "Plain")
        let sparseData = try JSONEncoder().encode(sparse)
        let sparseObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sparseData) as? [String: Any])
        XCTAssertNil(sparseObject["title"])
        XCTAssertNil(sparseObject["simulation_id"])
        XCTAssertNil(sparseObject["conversation_id"])
        XCTAssertNil(sparseObject["rating"])
        XCTAssertNil(sparseObject["allow_follow_up"])
        XCTAssertNil(sparseObject["context"])
    }

    func testFeedbackAPIUsesExpectedPathsAndFlags() {
        let categories = FeedbackAPI.categories()
        XCTAssertEqual(categories.path, "/api/v1/feedback/categories/")
        XCTAssertFalse(categories.requiresAuth)
        XCTAssertFalse(categories.requiresAccountContext)

        let create = FeedbackAPI.create(body: Data("{}".utf8), headers: ["X-Platform": "ios"])
        XCTAssertEqual(create.path, "/api/v1/feedback/")
        XCTAssertEqual(create.method, .post)
        XCTAssertTrue(create.requiresAuth)
        XCTAssertFalse(create.requiresAccountContext)
        XCTAssertEqual(create.headers["X-Platform"], "ios")
    }

    func testFeedbackRequestHeaderProviderIncludesRequiredHeaders() {
        let provider = FeedbackRequestHeaderProvider(
            sessionID: "session-123",
            appVersion: "1.2.3 (45)",
            osVersion: "18.0",
            deviceModel: "iPhone17,1",
        )

        let headers = provider.requestHeaders()

        XCTAssertEqual(headers["X-Platform"], "ios")
        XCTAssertEqual(headers["X-App-Version"], "1.2.3 (45)")
        XCTAssertEqual(headers["X-OS-Version"], "18.0")
        XCTAssertEqual(headers["X-Device-Model"], "iPhone17,1")
        XCTAssertEqual(headers["X-Session-ID"], "session-123")
    }

    func testFeedbackServiceFetchCategoriesHitsExpectedEndpoint() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FeedbackURLProtocolMock.self]
        let session = URLSession(configuration: configuration)

        FeedbackURLProtocolMock.requestHandler = { request in
            XCTAssertEqual(self.normalizedPath(request.url?.path), "/api/v1/feedback/categories")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let body = Data(#"[{"value":"bug_report","label":"Bug Report"}]"#.utf8)
            return (
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!,
                body
            )
        }

        let client = APIClient(
            baseURLProvider: { URL(string: "https://example.com")! },
            tokenProvider: FeedbackMockTokenProvider(tokens: nil),
            session: session,
        )
        let service = FeedbackService(
            apiClient: client,
            headerProvider: FeedbackRequestHeaderProvider(
                sessionID: "session-1",
                appVersion: "1.0",
                osVersion: "18.0",
                deviceModel: "iPhone",
            ),
        )

        let categories = try await service.fetchFeedbackCategories()
        XCTAssertEqual(categories, [FeedbackCategoryDTO(value: .bugReport, label: "Bug Report")])
    }

    func testFeedbackServiceSubmitHitsEndpointWithMetadataHeaders() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FeedbackURLProtocolMock.self]
        let session = URLSession(configuration: configuration)

        FeedbackURLProtocolMock.requestHandler = { request in
            XCTAssertEqual(self.normalizedPath(request.url?.path), "/api/v1/feedback")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-1")
            XCTAssertNil(request.value(forHTTPHeaderField: "X-Account-UUID"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Platform"), "ios")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-Version"), "1.2.3 (45)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-OS-Version"), "18.0")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Model"), "iPhone17,1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Session-ID"), "session-123")

            let bodyData = try XCTUnwrap(self.requestBody(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            XCTAssertEqual(object["simulation_id"] as? Int, 9)
            XCTAssertEqual(object["conversation_id"] as? Int, 3)
            XCTAssertEqual(object["body"] as? String, "Helpful feedback")

            let responseData = Data(
                #"{"id":11,"category":"simulation_content","title":"Realism","body":"Helpful feedback","simulation_id":9,"conversation_id":3,"rating":4,"allow_follow_up":true,"created_at":"2026-04-19T12:00:00Z"}"#.utf8
            )
            return (
                HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 201, httpVersion: nil, headerFields: nil)!,
                responseData
            )
        }

        let client = APIClient(
            baseURLProvider: { URL(string: "https://example.com")! },
            tokenProvider: FeedbackMockTokenProvider(
                tokens: AuthTokens(accessToken: "token-1", refreshToken: "refresh-1", expiresIn: 3600, tokenType: "Bearer")
            ),
            accountContextProvider: FeedbackStaticAccountContextProvider(accountUUID: "acct-123"),
            session: session,
        )
        let service = FeedbackService(
            apiClient: client,
            headerProvider: FeedbackRequestHeaderProvider(
                sessionID: "session-123",
                appVersion: "1.2.3 (45)",
                osVersion: "18.0",
                deviceModel: "iPhone17,1",
            ),
        )

        let response = try await service.submitFeedback(
            FeedbackCreateRequest(
                category: .simulationContent,
                title: "Realism",
                body: "Helpful feedback",
                simulationID: 9,
                conversationID: 3,
                rating: 4,
                allowFollowUp: true,
            )
        )

        XCTAssertEqual(response.id, 11)
        XCTAssertEqual(response.category, FeedbackCategory.simulationContent)
        XCTAssertEqual(response.simulationID, 9)
        XCTAssertEqual(response.conversationID, 3)
    }

    private func normalizedPath(_ path: String?) -> String? {
        guard let path else { return nil }
        guard path.count > 1 else { return path }
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private func requestBody(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                return nil
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
}
