import Foundation
import Networking
import SharedModels

public protocol ChatLabServiceProtocol: Sendable {
    func listSimulations(
        limit: Int,
        cursor: String?,
        status: String?,
        query: String?,
        searchMessages: Bool
    ) async throws -> PaginatedResponse<ChatSimulation>
    func quickCreateSimulation(request: ChatQuickCreateRequest) async throws -> ChatSimulation
    func getSimulation(simulationID: Int) async throws -> ChatSimulation
    func endSimulation(simulationID: Int) async throws -> ChatSimulation
    func retryInitial(simulationID: Int) async throws -> ChatSimulation
    func retryFeedback(simulationID: Int) async throws -> ChatSimulation

    func listConversations(simulationID: Int) async throws -> ChatConversationListResponse
    func createConversation(simulationID: Int, request: ChatCreateConversationRequest) async throws -> ChatConversation
    func getConversation(simulationID: Int, conversationUUID: String) async throws -> ChatConversation

    func listMessages(
        simulationID: Int,
        conversationID: Int?,
        cursor: String?,
        order: String,
        limit: Int
    ) async throws -> PaginatedResponse<ChatMessage>
    func createMessage(simulationID: Int, request: ChatCreateMessageRequest) async throws -> ChatMessage
    func retryMessage(simulationID: Int, messageID: Int) async throws -> ChatMessage
    func getMessage(simulationID: Int, messageID: Int) async throws -> ChatMessage

    func listEvents(simulationID: Int, cursor: String?, limit: Int) async throws -> PaginatedResponse<ChatEventEnvelope>

    func listTools(simulationID: Int, names: [String]?) async throws -> ChatToolListResponse
    func getTool(simulationID: Int, toolName: String) async throws -> ChatToolState
    func signOrders(simulationID: Int, request: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse

    func listModifierGroups(groups: [String]?) async throws -> [ModifierGroup]
}

public final class ChatLabService: ChatLabServiceProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let encoder = JSONEncoder()

    public init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func listSimulations(
        limit: Int,
        cursor: String?,
        status: String?,
        query: String?,
        searchMessages: Bool
    ) async throws -> PaginatedResponse<ChatSimulation> {
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

        return try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/", query: queryItems),
            as: PaginatedResponse<ChatSimulation>.self
        )
    }

    public func quickCreateSimulation(request: ChatQuickCreateRequest) async throws -> ChatSimulation {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/quick-create/", method: .post, body: body),
            as: ChatSimulation.self
        )
    }

    public func getSimulation(simulationID: Int) async throws -> ChatSimulation {
        try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/"),
            as: ChatSimulation.self
        )
    }

    public func endSimulation(simulationID: Int) async throws -> ChatSimulation {
        _ = try await apiClient.requestData(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/end/", method: .post, body: Data())
        )
        return try await getSimulation(simulationID: simulationID)
    }

    public func retryInitial(simulationID: Int) async throws -> ChatSimulation {
        try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/retry-initial/", method: .post, body: Data()),
            as: ChatSimulation.self
        )
    }

    public func retryFeedback(simulationID: Int) async throws -> ChatSimulation {
        try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/retry-feedback/", method: .post, body: Data()),
            as: ChatSimulation.self
        )
    }

    public func listConversations(simulationID: Int) async throws -> ChatConversationListResponse {
        try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/conversations/"),
            as: ChatConversationListResponse.self
        )
    }

    public func createConversation(simulationID: Int, request: ChatCreateConversationRequest) async throws -> ChatConversation {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/conversations/", method: .post, body: body),
            as: ChatConversation.self
        )
    }

    public func getConversation(simulationID: Int, conversationUUID: String) async throws -> ChatConversation {
        try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/conversations/\(conversationUUID)/"),
            as: ChatConversation.self
        )
    }

    public func listMessages(
        simulationID: Int,
        conversationID: Int?,
        cursor: String?,
        order: String = "asc",
        limit: Int = 50
    ) async throws -> PaginatedResponse<ChatMessage> {
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
        return try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/", query: queryItems),
            as: PaginatedResponse<ChatMessage>.self
        )
    }

    public func createMessage(simulationID: Int, request: ChatCreateMessageRequest) async throws -> ChatMessage {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/", method: .post, body: body),
            as: ChatMessage.self
        )
    }

    public func retryMessage(simulationID: Int, messageID: Int) async throws -> ChatMessage {
        try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/\(messageID)/retry/", method: .post, body: Data()),
            as: ChatMessage.self
        )
    }

    public func getMessage(simulationID: Int, messageID: Int) async throws -> ChatMessage {
        try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/messages/\(messageID)/"),
            as: ChatMessage.self
        )
    }

    public func listEvents(simulationID: Int, cursor: String?, limit: Int = 50) async throws -> PaginatedResponse<ChatEventEnvelope> {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/events/", query: queryItems),
            as: PaginatedResponse<ChatEventEnvelope>.self
        )
    }

    public func listTools(simulationID: Int, names: [String]? = nil) async throws -> ChatToolListResponse {
        var queryItems: [URLQueryItem] = []
        if let names {
            queryItems.append(contentsOf: names.map { URLQueryItem(name: "names", value: $0) })
        }
        return try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/tools/", query: queryItems),
            as: ChatToolListResponse.self
        )
    }

    public func getTool(simulationID: Int, toolName: String) async throws -> ChatToolState {
        try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/tools/\(toolName)/"),
            as: ChatToolState.self
        )
    }

    public func signOrders(simulationID: Int, request: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            Endpoint(path: "/api/v1/simulations/\(simulationID)/tools/patient_results/orders/", method: .post, body: body),
            as: ChatSignOrdersResponse.self
        )
    }

    public func listModifierGroups(groups: [String]? = nil) async throws -> [ModifierGroup] {
        var queryItems: [URLQueryItem] = []
        if let groups {
            queryItems.append(contentsOf: groups.map { URLQueryItem(name: "groups", value: $0) })
        }
        return try await apiClient.request(
            Endpoint(path: "/api/v1/config/modifier-groups/", query: queryItems),
            as: [ModifierGroup].self
        )
    }
}
