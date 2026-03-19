import Foundation
import OSLog
import Persistence
import SharedModels

private let logger = Logger(subsystem: "com.jackfruit.medsim", category: "Networking")

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

public struct Endpoint: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let query: [URLQueryItem]
    public let body: Data?
    public let headers: [String: String]
    public let requiresAuth: Bool
    public let idempotencyKey: String?
    public let correlationID: String?

    public init(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        requiresAuth: Bool = true,
        idempotencyKey: String? = nil,
        correlationID: String? = nil,
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.headers = headers
        self.requiresAuth = requiresAuth
        self.idempotencyKey = idempotencyKey
        self.correlationID = correlationID
    }
}

public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

public enum APIClientError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case http(statusCode: Int, detail: String, correlationID: String?)
    case decoding(String)
    case missingRefreshToken
}

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func requestData(_ endpoint: Endpoint) async throws -> Data
    func baseURL() async -> URL
}

public final class APIClient: APIClientProtocol, @unchecked Sendable {
    private let baseURLProvider: () -> URL
    private let tokenProvider: AuthTokenProvider
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let refreshCoordinator = RefreshCoordinator()

    public init(
        baseURLProvider: @escaping () -> URL,
        tokenProvider: AuthTokenProvider,
        session: URLSession = .shared,
    ) {
        self.baseURLProvider = baseURLProvider
        self.tokenProvider = tokenProvider
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.parseISO8601(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO date: \(value)")
        }
        self.decoder = decoder
    }

    public func baseURL() async -> URL {
        baseURLProvider()
    }

    public func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as _: T.Type = T.self) async throws -> T {
        let data = try await requestData(endpoint)
        if T.self == EmptyResponse.self, data.isEmpty {
            guard let emptyResponse = EmptyResponse() as? T else {
                throw APIClientError.decoding("Unable to cast EmptyResponse to \(T.self)")
            }
            return emptyResponse
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decoding(error.localizedDescription)
        }
    }

    public func requestData(_ endpoint: Endpoint) async throws -> Data {
        try await execute(endpoint: endpoint, allowRefreshRetry: endpoint.requiresAuth)
    }

    private func execute(endpoint: Endpoint, allowRefreshRetry: Bool, retryCount: Int = 0) async throws -> Data {
        let request = try await buildRequest(for: endpoint)
        logger.debug("\(endpoint.method.rawValue) \(request.url?.absoluteString ?? endpoint.path)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if http.statusCode == 401, allowRefreshRetry {
            logger.info("401 on \(endpoint.path) — attempting token refresh")
            _ = try await refreshAccessTokenSingleFlight()
            return try await execute(endpoint: endpoint, allowRefreshRetry: false)
        }

        if http.statusCode == 503, retryCount < 3 {
            let delay = pow(2.0, Double(retryCount)) + Double.random(in: 0 ... 0.5)
            logger.warning("503 on \(endpoint.path) — retrying in \(delay)s (attempt \(retryCount + 1)/3)")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await execute(endpoint: endpoint, allowRefreshRetry: allowRefreshRetry, retryCount: retryCount + 1)
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            logger.error("HTTP \(http.statusCode) \(endpoint.method.rawValue) \(endpoint.path): \(body)")
            if http.statusCode == 503 {
                throw APIClientError.http(statusCode: 503, detail: "Service temporarily unavailable. Please try again.", correlationID: nil)
            }
            throw parseHTTPError(data: data, response: http)
        }

        logger.debug("HTTP \(http.statusCode) \(endpoint.method.rawValue) \(endpoint.path)")
        return data
    }

    private func buildRequest(for endpoint: Endpoint) async throws -> URLRequest {
        let base = await baseURL()
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidURL
        }

        let joinedPath: String = if endpoint.path.hasPrefix("/") {
            endpoint.path
        } else {
            base.path + endpoint.path
        }
        components.path = joinedPath

        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
        }

        guard let url = components.url else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let correlationID = endpoint.correlationID ?? UUID().uuidString.lowercased()
        request.setValue(correlationID, forHTTPHeaderField: "X-Correlation-ID")

        if let idempotencyKey = endpoint.idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        if endpoint.requiresAuth {
            guard let tokens = tokenProvider.loadTokens() else {
                throw APIClientError.unauthorized
            }
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        }

        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private func parseHTTPError(data: Data, response: HTTPURLResponse) -> APIClientError {
        if let payload = try? decoder.decode(APIErrorPayload.self, from: data) {
            if response.statusCode == 401 {
                return .unauthorized
            }
            return .http(statusCode: response.statusCode, detail: payload.detail, correlationID: payload.correlationID)
        }

        let detail = String(data: data, encoding: .utf8) ?? "Request failed"
        if response.statusCode == 401 {
            return .unauthorized
        }
        return .http(statusCode: response.statusCode, detail: detail, correlationID: nil)
    }

    private func refreshAccessTokenSingleFlight() async throws -> AuthTokens {
        try await refreshCoordinator.runOrJoin { [self] in
            guard let current = tokenProvider.loadTokens() else {
                throw APIClientError.missingRefreshToken
            }

            let payload = try encoder.encode(["refresh_token": current.refreshToken])
            let endpoint = Endpoint(
                path: "/api/v1/auth/token/refresh/",
                method: .post,
                body: payload,
                requiresAuth: false,
            )

            let data = try await execute(endpoint: endpoint, allowRefreshRetry: false)
            let refresh = try decoder.decode(RefreshTokenResponse.self, from: data)
            let nextTokens = AuthTokens(
                accessToken: refresh.accessToken,
                refreshToken: refresh.refreshToken ?? current.refreshToken,
                expiresIn: refresh.expiresIn,
                tokenType: refresh.tokenType,
            )
            tokenProvider.saveTokens(nextTokens)
            return nextTokens
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
}

private actor RefreshCoordinator {
    private var task: Task<AuthTokens, Error>?

    func runOrJoin(_ operation: @escaping @Sendable () async throws -> AuthTokens) async throws -> AuthTokens {
        if let task {
            return try await task.value
        }

        let newTask = Task {
            try await operation()
        }
        task = newTask
        defer { task = nil }
        return try await newTask.value
    }
}
