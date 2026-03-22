import Foundation
import Networking
import SharedModels

public protocol ChatLabServiceProtocol: Sendable {
    func listSimulations(
        limit: Int,
        cursor: String?,
        status: String?,
        query: String?,
        searchMessages: Bool,
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
        limit: Int,
    ) async throws -> PaginatedResponse<ChatMessage>
    func createMessage(simulationID: Int, request: ChatCreateMessageRequest) async throws -> ChatMessage
    func retryMessage(simulationID: Int, messageID: Int) async throws -> ChatMessage
    func getMessage(simulationID: Int, messageID: Int) async throws -> ChatMessage
    func markMessageRead(simulationID: Int, messageID: Int) async throws -> ChatMessage

    func listEvents(simulationID: Int, cursor: String?, limit: Int) async throws -> PaginatedResponse<ChatEventEnvelope>

    func listTools(simulationID: Int, names: [String]?) async throws -> ChatToolListResponse
    func getTool(simulationID: Int, toolName: String) async throws -> ChatToolState
    func signOrders(simulationID: Int, request: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse
    func submitLabOrders(simulationID: Int, request: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse

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
        searchMessages: Bool,
    ) async throws -> PaginatedResponse<ChatSimulation> {
        try await apiClient.request(
            ChatLabAPI.listSimulations(
                limit: limit,
                cursor: cursor,
                status: status,
                query: query,
                searchMessages: searchMessages,
            ),
            as: PaginatedResponse<ChatSimulation>.self,
        )
    }

    public func quickCreateSimulation(request: ChatQuickCreateRequest) async throws -> ChatSimulation {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            ChatLabAPI.quickCreateSimulation(body: body),
            as: ChatSimulation.self,
        )
    }

    public func getSimulation(simulationID: Int) async throws -> ChatSimulation {
        try await apiClient.request(
            ChatLabAPI.simulation(simulationID: simulationID),
            as: ChatSimulation.self,
        )
    }

    public func endSimulation(simulationID: Int) async throws -> ChatSimulation {
        _ = try await apiClient.requestData(ChatLabAPI.endSimulation(simulationID: simulationID))
        return try await getSimulation(simulationID: simulationID)
    }

    public func retryInitial(simulationID: Int) async throws -> ChatSimulation {
        try await apiClient.request(
            ChatLabAPI.retryInitial(simulationID: simulationID),
            as: ChatSimulation.self,
        )
    }

    public func retryFeedback(simulationID: Int) async throws -> ChatSimulation {
        try await apiClient.request(
            ChatLabAPI.retryFeedback(simulationID: simulationID),
            as: ChatSimulation.self,
        )
    }

    public func listConversations(simulationID: Int) async throws -> ChatConversationListResponse {
        try await apiClient.request(
            ChatLabAPI.conversations(simulationID: simulationID),
            as: ChatConversationListResponse.self,
        )
    }

    public func createConversation(simulationID: Int, request: ChatCreateConversationRequest) async throws -> ChatConversation {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            ChatLabAPI.createConversation(simulationID: simulationID, body: body),
            as: ChatConversation.self,
        )
    }

    public func getConversation(simulationID: Int, conversationUUID: String) async throws -> ChatConversation {
        try await apiClient.request(
            ChatLabAPI.conversation(simulationID: simulationID, conversationUUID: conversationUUID),
            as: ChatConversation.self,
        )
    }

    public func listMessages(
        simulationID: Int,
        conversationID: Int?,
        cursor: String?,
        order: String = "asc",
        limit: Int = 50,
    ) async throws -> PaginatedResponse<ChatMessage> {
        try await apiClient.request(
            ChatLabAPI.listMessages(
                simulationID: simulationID,
                conversationID: conversationID,
                cursor: cursor,
                order: order,
                limit: limit,
            ),
            as: PaginatedResponse<ChatMessage>.self,
        )
    }

    public func createMessage(simulationID: Int, request: ChatCreateMessageRequest) async throws -> ChatMessage {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            ChatLabAPI.createMessage(simulationID: simulationID, body: body),
            as: ChatMessage.self,
        )
    }

    public func retryMessage(simulationID: Int, messageID: Int) async throws -> ChatMessage {
        try await apiClient.request(
            ChatLabAPI.retryMessage(simulationID: simulationID, messageID: messageID),
            as: ChatMessage.self,
        )
    }

    public func getMessage(simulationID: Int, messageID: Int) async throws -> ChatMessage {
        try await apiClient.request(
            ChatLabAPI.message(simulationID: simulationID, messageID: messageID),
            as: ChatMessage.self,
        )
    }

    public func markMessageRead(simulationID: Int, messageID: Int) async throws -> ChatMessage {
        try await apiClient.request(
            ChatLabAPI.markMessageRead(simulationID: simulationID, messageID: messageID),
            as: ChatMessage.self,
        )
    }

    public func listEvents(simulationID: Int, cursor: String?, limit: Int = 50) async throws -> PaginatedResponse<ChatEventEnvelope> {
        try await apiClient.request(
            ChatLabAPI.listEvents(simulationID: simulationID, cursor: cursor, limit: limit),
            as: PaginatedResponse<ChatEventEnvelope>.self,
        )
    }

    public func listTools(simulationID: Int, names: [String]? = nil) async throws -> ChatToolListResponse {
        try await apiClient.request(
            ChatLabAPI.listTools(simulationID: simulationID, names: names),
            as: ChatToolListResponse.self,
        )
    }

    public func getTool(simulationID: Int, toolName: String) async throws -> ChatToolState {
        try await apiClient.request(
            ChatLabAPI.tool(simulationID: simulationID, toolName: toolName),
            as: ChatToolState.self,
        )
    }

    public func signOrders(simulationID: Int, request: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            ChatLabAPI.signOrders(simulationID: simulationID, body: body),
            as: ChatSignOrdersResponse.self,
        )
    }

    public func submitLabOrders(simulationID: Int, request: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse {
        let body = try encoder.encode(request)
        return try await apiClient.request(
            ChatLabAPI.submitLabOrders(simulationID: simulationID, body: body),
            as: ChatLabOrdersResponse.self,
        )
    }

    public func listModifierGroups(groups: [String]? = nil) async throws -> [ModifierGroup] {
        try await apiClient.request(
            ChatLabAPI.listModifierGroups(groups: groups),
            as: [ModifierGroup].self,
        )
    }
}
