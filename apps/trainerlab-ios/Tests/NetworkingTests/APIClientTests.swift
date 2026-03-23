import Foundation
import Networking
import Persistence
import SharedModels
import XCTest

private final class MockTokenProvider: AuthTokenProvider, @unchecked Sendable {
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

private struct StaticAccountContextProvider: AccountContextProvider {
    let accountUUID: String?

    func selectedAccountUUID() async -> String? {
        accountUUID
    }
}

private final class URLProtocolMock: URLProtocol {
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

private struct ProtectedResponse: Decodable {
    let value: String
}

final class APIClientTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        URLProtocolMock.requestHandler = nil
    }

    func test401TriggersRefreshAndRetry() async throws {
        let initial = AuthTokens(accessToken: "old-token", refreshToken: "refresh-1", expiresIn: 3600, tokenType: "Bearer")
        let tokenProvider = MockTokenProvider(tokens: initial)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)

        URLProtocolMock.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let path = normalizedPath(url.path)
            let method = request.httpMethod ?? "GET"
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""

            if path == "/api/v1/protected" {
                if auth == "Bearer old-token" {
                    let body = Data("{\"type\":\"http_error\",\"title\":\"Unauthorized\",\"status\":401,\"detail\":\"expired\",\"instance\":\"/api/v1/protected/\",\"correlation_id\":\"abc\"}".utf8)
                    return (HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!, body)
                }
                if auth == "Bearer new-token" {
                    let body = Data("{\"value\":\"ok\"}".utf8)
                    return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
                }
            }

            if path == "/api/v1/auth/token/refresh" {
                XCTAssertEqual(method, "POST")
                let body = Data("{\"access_token\":\"new-token\",\"refresh_token\":\"refresh-2\",\"expires_in\":3600,\"token_type\":\"Bearer\"}".utf8)
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            }

            XCTFail("Unhandled request in URLProtocolMock: method=\(method), path=\(url.path), auth=\(auth)")
            let body = Data("{\"type\":\"http_error\",\"title\":\"Unhandled request\",\"status\":500,\"detail\":\"Unhandled request in test mock\",\"instance\":\"\(url.path)\"}".utf8)
            return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, body)
        }

        let client = APIClient(
            baseURLProvider: { URL(string: "https://example.com")! },
            tokenProvider: tokenProvider,
            session: session,
        )

        let endpoint = Endpoint(path: "/api/v1/protected/")
        let result: ProtectedResponse = try await client.request(endpoint, as: ProtectedResponse.self)

        XCTAssertEqual(result.value, "ok")
        XCTAssertEqual(tokenProvider.loadTokens()?.accessToken, "new-token")
        XCTAssertEqual(tokenProvider.loadTokens()?.refreshToken, "refresh-2")
    }

    func testScopedRequestAddsAccountHeader() async throws {
        let tokens = AuthTokens(accessToken: "token-1", refreshToken: "refresh-1", expiresIn: 3600, tokenType: "Bearer")
        let tokenProvider = MockTokenProvider(tokens: tokens)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)

        URLProtocolMock.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Account-UUID"), "acct-123")
            let url = try XCTUnwrap(request.url)
            let body = Data("{\"value\":\"ok\"}".utf8)
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let client = APIClient(
            baseURLProvider: { URL(string: "https://example.com")! },
            tokenProvider: tokenProvider,
            accountContextProvider: StaticAccountContextProvider(accountUUID: "acct-123"),
            session: session,
        )

        let endpoint = Endpoint(path: "/api/v1/protected/")
        let result: ProtectedResponse = try await client.request(endpoint, as: ProtectedResponse.self)
        XCTAssertEqual(result.value, "ok")
    }

    func testAccountUnscopedRequestOmitsAccountHeader() async throws {
        let tokens = AuthTokens(accessToken: "token-1", refreshToken: "refresh-1", expiresIn: 3600, tokenType: "Bearer")
        let tokenProvider = MockTokenProvider(tokens: tokens)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)

        URLProtocolMock.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "X-Account-UUID"))
            let url = try XCTUnwrap(request.url)
            let body = Data("[]".utf8)
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let client = APIClient(
            baseURLProvider: { URL(string: "https://example.com")! },
            tokenProvider: tokenProvider,
            accountContextProvider: StaticAccountContextProvider(accountUUID: "acct-123"),
            session: session,
        )

        let result: [AccountOut] = try await client.request(AccountsAPI.listAccounts(), as: [AccountOut].self)
        XCTAssertTrue(result.isEmpty)
    }
}

private func normalizedPath(_ path: String) -> String {
    guard path.count > 1 else { return path }
    return path.hasSuffix("/") ? String(path.dropLast()) : path
}
