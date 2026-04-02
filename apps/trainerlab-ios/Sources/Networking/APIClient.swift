import Foundation
import OSLog
import Persistence
import SharedModels

private let logger = Logger(subsystem: "com.jackfruit.medsim", category: "Networking")

public protocol AccountContextProvider: Sendable {
    func selectedAccountUUID() async -> String?
}

public struct EmptyAccountContextProvider: AccountContextProvider {
    public init() {}

    public func selectedAccountUUID() async -> String? {
        nil
    }
}

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
    public let requiresAccountContext: Bool
    public let idempotencyKey: String?
    public let correlationID: String?

    public init(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        requiresAuth: Bool = true,
        requiresAccountContext: Bool = true,
        idempotencyKey: String? = nil,
        correlationID: String? = nil,
    ) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.headers = headers
        self.requiresAuth = requiresAuth
        self.requiresAccountContext = requiresAccountContext
        self.idempotencyKey = idempotencyKey
        self.correlationID = correlationID
    }
}

public struct EventStreamRoute: Sendable, Equatable {
    public let path: String
    public let query: [URLQueryItem]
    public let requiresAccountContext: Bool

    public init(path: String, query: [URLQueryItem] = [], requiresAccountContext: Bool = true) {
        self.path = path
        self.query = query
        self.requiresAccountContext = requiresAccountContext
    }

    public func makeURLRequest(baseURL: URL, accessToken: String, accountUUID: String?) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = path
        var queryItems = query
        if requiresAccountContext, let accountUUID, !accountUUID.isEmpty {
            queryItems.append(URLQueryItem(name: "account_uuid", value: accountUUID))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.get.rawValue
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Correlation-ID")
        return request
    }
}

public enum AuthAPI {
    public static func signIn(body: Data) -> Endpoint {
        Endpoint(
            path: "/api/v1/auth/token/",
            method: .post,
            body: body,
            requiresAuth: false,
            requiresAccountContext: false,
        )
    }

    public static func signOut(body: Data) -> Endpoint {
        Endpoint(
            path: "/api/v1/auth/logout/",
            method: .post,
            body: body,
            requiresAuth: false,
            requiresAccountContext: false,
        )
    }

    public static func refresh(body: Data) -> Endpoint {
        Endpoint(
            path: "/api/v1/auth/token/refresh/",
            method: .post,
            body: body,
            requiresAuth: false,
            requiresAccountContext: false,
        )
    }
}

public enum AccountsAPI {
    public static func listAccounts() -> Endpoint {
        Endpoint(
            path: "/api/v1/accounts/",
            requiresAccountContext: false,
        )
    }

    public static func selectAccount(body: Data) -> Endpoint {
        Endpoint(
            path: "/api/v1/accounts/select/",
            method: .post,
            body: body,
            requiresAccountContext: false,
        )
    }

    public static func accessSnapshot() -> Endpoint {
        Endpoint(path: "/api/v1/accounts/me/access/")
    }
}

public enum BillingAPI {
    public static func appleSync(body: Data) -> Endpoint {
        Endpoint(
            path: "/api/v1/billing/apple/sync/",
            method: .post,
            body: body,
        )
    }
}

public enum TrainerLabAPI {
    public static func accessMe() -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/access/me/")
    }

    public static func listSessions(limit: Int, cursor: String?, status: String?, query searchQuery: String?) -> Endpoint {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let searchQuery, !searchQuery.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: searchQuery))
        }
        return Endpoint(path: "/api/v1/trainerlab/simulations/", query: queryItems)
    }

    public static func createSession(body: Data, idempotencyKey: String) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/",
            method: .post,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func session(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/")
    }

    public static func retryInitial(simulationID: Int) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/retry-initial/",
            method: .post,
            body: Data(),
        )
    }

    public static func runtimeState(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/state/")
    }

    public static func controlPlaneDebug(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/control-plane/")
    }

    public static func runCommand(simulationID: Int, command: String, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/run/\(command)/",
            method: .post,
            body: Data(),
            idempotencyKey: idempotencyKey,
        )
    }

    public static func triggerRunTick(simulationID: Int, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/run/tick/",
            method: .post,
            body: Data(),
            idempotencyKey: idempotencyKey,
        )
    }

    public static func triggerVitalsTick(simulationID: Int, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/run/tick/vitals/",
            method: .post,
            body: Data(),
            idempotencyKey: idempotencyKey,
        )
    }

    public static func listEvents(simulationID: Int, cursor: String?, limit: Int) -> Endpoint {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/events/", query: queryItems)
    }

    public static func eventStream(simulationID: Int, cursor: String?) -> EventStreamRoute {
        let query = cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? []
        return EventStreamRoute(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/stream/",
            query: query,
        )
    }

    public static func runSummary(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/summary/")
    }

    public static func adjustSimulation(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/adjust/",
            method: .post,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func steerPrompt(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/steer/prompt/",
            method: .post,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func injuries(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/injuries/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func illnesses(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/illnesses/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func problems(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/problems/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func assessmentFindings(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/assessment-findings/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func diagnosticResults(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/diagnostic-results/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func resources(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/resources/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func disposition(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/disposition/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func vitals(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/vitals/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func interventions(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        eventMutation(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/interventions/",
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func listPresets(limit: Int, cursor: String?) -> Endpoint {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(path: "/api/v1/trainerlab/presets/", query: queryItems)
    }

    public static func presets(body: Data? = nil, method: HTTPMethod = .get) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/presets/", method: method, body: body)
    }

    public static func preset(presetID: Int, body: Data? = nil, method: HTTPMethod = .get) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/", method: method, body: body)
    }

    public static func duplicatePreset(presetID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/duplicate/", method: .post, body: Data())
    }

    public static func sharePreset(presetID: Int, body: Data) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/share/", method: .post, body: body)
    }

    public static func unsharePreset(presetID: Int, body: Data) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/presets/\(presetID)/unshare/", method: .post, body: body)
    }

    public static func applyPreset(presetID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/presets/\(presetID)/apply/",
            method: .post,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func injuryDictionary() -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/dictionaries/injuries/")
    }

    public static func interventionDictionary() -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/dictionaries/interventions/")
    }

    public static func listAccounts(query: String, cursor: String?, limit: Int) -> Endpoint {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(path: "/api/v1/account/list/", query: queryItems)
    }

    public static func problemStatus(simulationID: Int, problemID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/problems/\(problemID)/",
            method: .patch,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func notes(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/events/notes/",
            method: .post,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func annotations(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/trainerlab/simulations/\(simulationID)/annotations/")
    }

    public static func createAnnotation(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/annotations/",
            method: .post,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func scenarioBrief(simulationID: Int, body: Data, idempotencyKey: String? = nil) -> Endpoint {
        Endpoint(
            path: "/api/v1/trainerlab/simulations/\(simulationID)/scenario-brief/",
            method: .patch,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }

    public static func guardState(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/guard-state/")
    }

    public static func heartbeat(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/heartbeat/", method: .post, body: Data())
    }

    private static func eventMutation(path: String, body: Data, idempotencyKey: String?) -> Endpoint {
        Endpoint(
            path: path,
            method: .post,
            body: body,
            idempotencyKey: idempotencyKey,
        )
    }
}

public enum ChatLabAPI {
    public static func listSimulations(
        limit: Int,
        cursor: String?,
        status: String?,
        query: String?,
        searchMessages: Bool,
    ) -> Endpoint {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let status, !status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        if searchMessages {
            queryItems.append(URLQueryItem(name: "search_messages", value: "true"))
        }
        return Endpoint(path: "/api/v1/simulations/", query: queryItems)
    }

    public static func quickCreateSimulation(body: Data) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/quick-create/", method: .post, body: body)
    }

    public static func simulation(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/")
    }

    public static func endSimulation(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/end/", method: .post, body: Data())
    }

    public static func retryInitial(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/retry-initial/", method: .post, body: Data())
    }

    public static func retryFeedback(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/retry-feedback/", method: .post, body: Data())
    }

    public static func conversations(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/conversations/")
    }

    public static func createConversation(simulationID: Int, body: Data) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/conversations/", method: .post, body: body)
    }

    public static func conversation(simulationID: Int, conversationUUID: String) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/conversations/\(conversationUUID)/")
    }

    public static func listMessages(
        simulationID: Int,
        conversationID: Int?,
        cursor: String?,
        order: String,
        limit: Int,
    ) -> Endpoint {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "order", value: order),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let conversationID {
            queryItems.append(URLQueryItem(name: "conversation_id", value: String(conversationID)))
        }
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/", query: queryItems)
    }

    public static func createMessage(simulationID: Int, body: Data) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/", method: .post, body: body)
    }

    public static func retryMessage(simulationID: Int, messageID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/\(messageID)/retry/", method: .post, body: Data())
    }

    public static func message(simulationID: Int, messageID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/\(messageID)/")
    }

    public static func markMessageRead(simulationID: Int, messageID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/\(messageID)/read/", method: .patch, body: Data())
    }

    public static func listEvents(simulationID: Int, cursor: String?, limit: Int) -> Endpoint {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return Endpoint(path: "/api/v1/simulations/\(simulationID)/events/", query: queryItems)
    }

    public static func eventStream(simulationID: Int, cursor: String?) -> EventStreamRoute {
        let query = cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? []
        return EventStreamRoute(path: "/api/v1/simulations/\(simulationID)/events/stream/", query: query)
    }

    public static func listTools(simulationID: Int, names: [String]?) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let names {
            queryItems.append(contentsOf: names.map { URLQueryItem(name: "names", value: $0) })
        }
        return Endpoint(path: "/api/v1/simulations/\(simulationID)/tools/", query: queryItems)
    }

    public static func tool(simulationID: Int, toolName: String) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/tools/\(toolName)/")
    }

    public static func signOrders(simulationID: Int, body: Data) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/tools/patient_results/orders/", method: .post, body: body)
    }

    public static func submitLabOrders(simulationID: Int, body: Data) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/lab-orders/", method: .post, body: body)
    }

    public static func guardState(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/guard-state/")
    }

    public static func heartbeat(simulationID: Int) -> Endpoint {
        Endpoint(path: "/api/v1/simulations/\(simulationID)/heartbeat/", method: .post, body: Data())
    }

    public static func listModifierGroups(groups: [String]?) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let groups {
            queryItems.append(contentsOf: groups.map { URLQueryItem(name: "groups", value: $0) })
        }
        return Endpoint(path: "/api/v1/config/modifier-groups/", query: queryItems)
    }
}

public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

public enum APIClientError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case http(statusCode: Int, detail: String, correlationID: String?)
    case decoding(String)
    case missingRefreshToken
    case guardDenied(statusCode: Int, detail: String, correlationID: String?, signal: GuardSignal)

    public var statusCode: Int? {
        switch self {
        case let .http(statusCode, _, _):
            statusCode
        case .unauthorized:
            401
        case let .guardDenied(statusCode, _, _, _):
            statusCode
        default:
            nil
        }
    }

    public var backendDetail: String? {
        switch self {
        case let .http(_, detail, _):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let .guardDenied(_, detail, _, _):
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            return nil
        }
    }

    public var correlationID: String? {
        switch self {
        case let .http(_, _, correlationID):
            return correlationID
        case let .guardDenied(_, _, correlationID, _):
            return correlationID
        default:
            return nil
        }
    }

    public var isAuthorizationFailure: Bool {
        switch self {
        case .unauthorized, .missingRefreshToken:
            true
        case let .http(statusCode, _, _):
            statusCode == 401
        default:
            false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The app generated an invalid request."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .missingRefreshToken:
            return "Your session is incomplete. Please sign in again."
        case .decoding:
            return "The app couldn’t read the server response."
        case let .http(statusCode, detail, _):
            if let safeDetail = Self.safeUserFacingDetail(statusCode: statusCode, detail: detail) {
                return safeDetail
            }
            return Self.fallbackMessage(forHTTPStatus: statusCode)
        case let .guardDenied(_, _, _, signal):
            return signal.message
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unauthorized, .missingRefreshToken:
            "Please sign in again."
        case let .http(statusCode, _, _) where statusCode == 429:
            "Please try again shortly."
        case let .http(statusCode, _, _) where statusCode >= 500:
            "Please try again."
        default:
            nil
        }
    }

    public static func fallbackMessage(forHTTPStatus statusCode: Int) -> String {
        switch statusCode {
        case 400:
            "The request was invalid."
        case 401:
            "Please sign in again."
        case 403:
            "You don’t have permission to do that."
        case 404:
            "That item could not be found."
        case 409:
            "That change conflicts with the current state."
        case 422:
            "The submitted data was invalid."
        case 429:
            "Too many requests. Please try again shortly."
        case 500...:
            "Something went wrong on the server."
        default:
            "Something went wrong."
        }
    }

    static func safeUserFacingDetail(statusCode: Int, detail: String) -> String? {
        guard (400 ..< 500).contains(statusCode), statusCode != 401 else {
            return nil
        }

        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 180 else {
            return nil
        }

        let blockedMarkers = [
            "traceback",
            "exception",
            "nserror",
            "nslocalizeddescription",
            "<html",
            "<!doctype html",
            "stack trace",
        ]
        let normalized = trimmed.lowercased()
        guard trimmed.contains(where: \.isNewline) == false,
              blockedMarkers.allSatisfy({ normalized.contains($0) == false })
        else {
            return nil
        }

        return trimmed
    }
}

public protocol APIClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func requestData(_ endpoint: Endpoint) async throws -> Data
    func baseURL() async -> URL
}

public final class APIClient: APIClientProtocol, @unchecked Sendable {
    private let baseURLProvider: () -> URL
    private let tokenProvider: AuthTokenProvider
    private let accountContextProvider: AccountContextProvider
    private let session: URLSession
    private let authorizationFailureHandler: (@Sendable (APIClientError) async -> Void)?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let refreshCoordinator = RefreshCoordinator()

    public init(
        baseURLProvider: @escaping () -> URL,
        tokenProvider: AuthTokenProvider,
        accountContextProvider: AccountContextProvider = EmptyAccountContextProvider(),
        session: URLSession = .shared,
        authorizationFailureHandler: (@Sendable (APIClientError) async -> Void)? = nil,
    ) {
        self.baseURLProvider = baseURLProvider
        self.tokenProvider = tokenProvider
        self.accountContextProvider = accountContextProvider
        self.session = session
        self.authorizationFailureHandler = authorizationFailureHandler

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
        let request: URLRequest
        do {
            request = try await buildRequest(for: endpoint)
        } catch let error as APIClientError {
            if endpoint.requiresAuth, error.isAuthorizationFailure {
                await notifyAuthorizationFailure(error)
            }
            throw error
        }
        logger.debug("\(endpoint.method.rawValue) \(request.url?.absoluteString ?? endpoint.path)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if http.statusCode == 401, allowRefreshRetry {
            logger.info("401 on \(endpoint.path) — attempting token refresh")
            do {
                _ = try await refreshAccessTokenSingleFlight()
            } catch let error as APIClientError {
                if error.isAuthorizationFailure {
                    await notifyAuthorizationFailure(error)
                }
                throw error
            }
            return try await execute(endpoint: endpoint, allowRefreshRetry: false)
        }

        if http.statusCode == 503, retryCount < 3 {
            let delay = pow(2.0, Double(retryCount)) + Double.random(in: 0 ... 0.5)
            logger.warning("503 on \(endpoint.path) — retrying in \(delay)s (attempt \(retryCount + 1)/3)")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await execute(endpoint: endpoint, allowRefreshRetry: allowRefreshRetry, retryCount: retryCount + 1)
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            let apiError = parseHTTPError(data: data, response: http)
            logFailure(for: endpoint, error: apiError)
            if endpoint.requiresAuth, apiError.isAuthorizationFailure {
                await notifyAuthorizationFailure(apiError)
            }
            throw apiError
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

        if endpoint.requiresAccountContext,
           let accountUUID = await accountContextProvider.selectedAccountUUID(),
           !accountUUID.isEmpty
        {
            request.setValue(accountUUID, forHTTPHeaderField: "X-Account-UUID")
        }

        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private func parseHTTPError(data: Data, response: HTTPURLResponse) -> APIClientError {
        let responseCorrelationID = response.value(forHTTPHeaderField: "X-Correlation-ID")

        if response.statusCode == 403,
           let guardPayload = try? decoder.decode(GuardDeniedPayload.self, from: data),
           guardPayload.type == "guard_denied"
        {
            return .guardDenied(
                statusCode: 403,
                detail: guardPayload.detail,
                correlationID: responseCorrelationID,
                signal: guardPayload.guardDenial,
            )
        }

        if let payload = try? decoder.decode(APIErrorPayload.self, from: data) {
            return .http(
                statusCode: response.statusCode,
                detail: payload.detail,
                correlationID: payload.correlationID ?? responseCorrelationID,
            )
        }

        let detail = String(data: data, encoding: .utf8) ?? "Request failed"
        return .http(statusCode: response.statusCode, detail: detail, correlationID: responseCorrelationID)
    }

    private func logFailure(for endpoint: Endpoint, error: APIClientError) {
        logger.error(
            "HTTP failure method=\(endpoint.method.rawValue, privacy: .public) path=\(endpoint.path, privacy: .public) status=\(error.statusCode ?? -1, privacy: .public) correlation_id=\(error.correlationID ?? "-", privacy: .public) detail=\(error.backendDetail ?? String(reflecting: error), privacy: .private)",
        )
    }

    private func notifyAuthorizationFailure(_ error: APIClientError) async {
        await authorizationFailureHandler?(error)
    }

    private func refreshAccessTokenSingleFlight() async throws -> AuthTokens {
        try await refreshCoordinator.runOrJoin { [self] in
            guard let current = tokenProvider.loadTokens() else {
                throw APIClientError.missingRefreshToken
            }

            let payload = try encoder.encode(["refresh_token": current.refreshToken])
            let endpoint = AuthAPI.refresh(body: payload)

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
