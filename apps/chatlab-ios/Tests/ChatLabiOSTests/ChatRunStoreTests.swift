@testable import ChatLabiOS
import Networking
import SharedModels
import XCTest

private final class TestChatService: ChatLabServiceProtocol, @unchecked Sendable {
    var simulations: [Int: ChatSimulation] = [:]
    var conversations = ChatConversationListResponse(items: [])
    var messagesByConversation: [Int: [ChatMessage]] = [:]
    var createdMessage: ChatMessage?
    var retriedMessage: ChatMessage?
    var retriedSimulation: ChatSimulation?

    func listSimulations(
        limit _: Int,
        cursor _: String?,
        status _: String?,
        query _: String?,
        searchMessages _: Bool,
    ) async throws -> PaginatedResponse<ChatSimulation> {
        PaginatedResponse(items: Array(simulations.values), nextCursor: nil, hasMore: false)
    }

    func quickCreateSimulation(request _: ChatQuickCreateRequest) async throws -> ChatSimulation {
        throw NSError(domain: "unused", code: 1)
    }

    func getSimulation(simulationID: Int) async throws -> ChatSimulation {
        guard let simulation = simulations[simulationID] else {
            throw NSError(domain: "missing-simulation", code: 404)
        }
        return simulation
    }

    func endSimulation(simulationID: Int) async throws -> ChatSimulation {
        guard let simulation = simulations[simulationID] else {
            throw NSError(domain: "missing-simulation", code: 404)
        }
        return simulation
    }

    func retryInitial(simulationID: Int) async throws -> ChatSimulation {
        guard let retriedSimulation else {
            throw NSError(domain: "missing-retry-simulation", code: 404)
        }
        simulations[simulationID] = retriedSimulation
        return retriedSimulation
    }

    func retryFeedback(simulationID: Int) async throws -> ChatSimulation {
        guard let simulation = simulations[simulationID] else {
            throw NSError(domain: "missing-simulation", code: 404)
        }
        return simulation
    }

    func listConversations(simulationID _: Int) async throws -> ChatConversationListResponse {
        conversations
    }

    func createConversation(simulationID _: Int, request _: ChatCreateConversationRequest) async throws -> ChatConversation {
        throw NSError(domain: "unused", code: 1)
    }

    func getConversation(simulationID _: Int, conversationUUID _: String) async throws -> ChatConversation {
        throw NSError(domain: "unused", code: 1)
    }

    func listMessages(
        simulationID _: Int,
        conversationID: Int?,
        cursor _: String?,
        order _: String,
        limit _: Int,
    ) async throws -> PaginatedResponse<ChatMessage> {
        let conversationKey = conversationID ?? -1
        return PaginatedResponse(
            items: messagesByConversation[conversationKey] ?? [],
            nextCursor: nil,
            hasMore: false,
        )
    }

    func createMessage(simulationID _: Int, request _: ChatCreateMessageRequest) async throws -> ChatMessage {
        guard let createdMessage else {
            throw NSError(domain: "missing-created-message", code: 404)
        }
        return createdMessage
    }

    func retryMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        guard let retriedMessage else {
            throw NSError(domain: "missing-retried-message", code: 404)
        }
        return retriedMessage
    }

    func getMessage(simulationID _: Int, messageID: Int) async throws -> ChatMessage {
        for messages in messagesByConversation.values {
            if let message = messages.first(where: { $0.id == messageID }) {
                return message
            }
        }
        throw NSError(domain: "missing-message", code: 404)
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<ChatEventEnvelope> {
        PaginatedResponse(items: [], nextCursor: nil, hasMore: false)
    }

    func listTools(simulationID _: Int, names _: [String]?) async throws -> ChatToolListResponse {
        ChatToolListResponse(items: [])
    }

    func getTool(simulationID _: Int, toolName: String) async throws -> ChatToolState {
        ChatToolState(name: toolName, displayName: toolName, data: [], isGeneric: false, checksum: "")
    }

    func signOrders(simulationID _: Int, request _: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse {
        ChatSignOrdersResponse(status: "ok", orders: [])
    }

    func listModifierGroups(groups _: [String]?) async throws -> [ModifierGroup] {
        []
    }
}

private final class TestRealtimeClient: ChatRealtimeClientProtocol, @unchecked Sendable {
    let events: AsyncStream<ChatEventEnvelope>
    let connectionStates: AsyncStream<ChatRealtimeConnectionState>

    private let eventContinuation: AsyncStream<ChatEventEnvelope>.Continuation
    private let stateContinuation: AsyncStream<ChatRealtimeConnectionState>.Continuation

    init() {
        var eventCont: AsyncStream<ChatEventEnvelope>.Continuation!
        events = AsyncStream { continuation in
            eventCont = continuation
        }
        eventContinuation = eventCont

        var stateCont: AsyncStream<ChatRealtimeConnectionState>.Continuation!
        connectionStates = AsyncStream { continuation in
            stateCont = continuation
            continuation.yield(.disconnected)
        }
        stateContinuation = stateCont
    }

    func connect(simulationID _: Int, cursor _: String?) async {
        stateContinuation.yield(.connected)
    }

    func disconnect() {
        stateContinuation.yield(.disconnected)
    }

    func send(eventType _: String, payload _: [String: JSONValue]) async {}

    func pushEvent(_ event: ChatEventEnvelope) {
        eventContinuation.yield(event)
    }
}

@MainActor
final class ChatRunStoreTests: XCTestCase {
    func testOpeningInProgressSimulationShowsSyntheticTypingUntilInitialReplyArrives() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)

        store.start()
        try await waitUntil { store.activeTypingUsers == [patientConversation.displayName] }

        realtime.pushEvent(
            makeEvent(
                type: "chat.message_created",
                payload: [
                    "id": .number(200),
                    "message_id": .number(200),
                    "conversation_id": .number(Double(patientConversation.id)),
                    "content": .string("Hello there"),
                    "is_from_ai": .bool(true),
                    "display_name": .string(patientConversation.displayName),
                    "timestamp": .string(isoTimestamp()),
                    "delivery_status": .string("sent"),
                ],
            ),
        )

        try await waitUntil { store.activeTypingUsers.isEmpty }
        store.stop()
    }

    func testMessageFailureClearsSyntheticTypingAndMarksExistingMessageFailed() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let initialPatientMessage = makeMessage(
            id: 1,
            conversationID: patientConversation.id,
            isFromAI: true,
            content: "How can I help?",
        )
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [initialPatientMessage]
        service.createdMessage = makeMessage(
            id: 10,
            conversationID: patientConversation.id,
            isFromAI: false,
            role: "user",
            content: "Need help",
            displayName: "Student",
        )

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)

        store.start()
        try await waitUntil { store.activeConversationID == patientConversation.id }
        try await waitUntil { store.activeTypingUsers.isEmpty }

        store.draftText = "Need help"
        store.sendDraft()

        try await waitUntil { store.activeTypingUsers == [patientConversation.displayName] }

        realtime.pushEvent(
            makeEvent(
                type: "message_status_update",
                payload: [
                    "id": .number(10),
                    "status": .string("failed"),
                    "retryable": .bool(true),
                    "error_text": .string("Message failed to deliver to the AI service. Try again."),
                ],
            ),
        )

        try await waitUntil {
            guard let failedMessage = store.activeMessages.first(where: { $0.serverID == 10 }) else {
                return false
            }
            return store.activeTypingUsers.isEmpty && failedMessage.deliveryStatus == .failed
        }
        store.stop()
    }

    func testSimulationFailureAfterConversationStartedUsesBannerStateInsteadOfDedicatedFailureScreen() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let initialPatientMessage = makeMessage(
            id: 1,
            conversationID: patientConversation.id,
            isFromAI: true,
            content: "Opening line",
        )
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [initialPatientMessage]

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)

        store.start()
        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(
            makeEvent(
                type: "simulation.state_changed",
                payload: [
                    "status": .string("failed"),
                    "terminal_reason_code": .string("provider_timeout"),
                    "terminal_reason_text": .string("Simulation failed."),
                    "retryable": .bool(true),
                ],
            ),
        )

        try await waitUntil {
            store.simulationFailureText == "Simulation failed." && store.showsInitialGenerationFailureScreen == false
        }
        store.stop()
    }

    func testRetryInitialRestartsSyntheticTyping() async throws {
        let failedSimulation = makeSimulation(
            status: .failed,
            terminalReasonCode: "initial_generation_enqueue_failed",
            terminalReasonText: "We could not start this simulation. Please try again.",
            retryable: true,
        )
        let retriedSimulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[failedSimulation.id] = failedSimulation
        service.retriedSimulation = retriedSimulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: failedSimulation)

        store.start()
        try await waitUntil { store.showsInitialGenerationFailureScreen }

        store.retryInitialSimulation()

        try await waitUntil {
            store.simulation.status == .inProgress &&
                store.simulationFailureText == nil &&
                store.activeTypingUsers == [patientConversation.displayName]
        }
        store.stop()
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        condition: @escaping @MainActor () -> Bool,
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }

    private func makeSimulation(
        id: Int = 42,
        status: SimulationTerminalState,
        terminalReasonCode: String = "",
        terminalReasonText: String = "",
        retryable: Bool?,
    ) -> ChatSimulation {
        ChatSimulation(
            id: id,
            userID: 7,
            startTimestamp: Date(),
            endTimestamp: status == .inProgress ? nil : Date(),
            timeLimitSeconds: 600,
            diagnosis: "Diagnosis",
            chiefComplaint: "Chief complaint",
            patientDisplayName: "Jordan Lee",
            patientInitials: "JL",
            status: status,
            terminalReasonCode: terminalReasonCode,
            terminalReasonText: terminalReasonText,
            terminalAt: status == .inProgress ? nil : Date(),
            retryable: retryable,
        )
    }

    private func makeConversation(
        id: Int = 1,
        type: String = "simulated_patient",
        name: String = "Jordan Lee",
    ) -> ChatConversation {
        ChatConversation(
            id: id,
            uuid: UUID().uuidString.lowercased(),
            simulationID: 42,
            conversationType: type,
            conversationTypeDisplay: type,
            icon: "bubble.left",
            displayName: name,
            displayInitials: "JL",
            isLocked: false,
            createdAt: Date(),
        )
    }

    private func makeMessage(
        id: Int,
        conversationID: Int,
        isFromAI: Bool,
        role: String = "assistant",
        content: String,
        displayName: String = "Jordan Lee",
        deliveryStatus: DeliveryStatus = .sent,
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            simulationID: 42,
            conversationID: conversationID,
            conversationType: "simulated_patient",
            senderID: isFromAI ? 0 : 7,
            content: content,
            role: role,
            messageType: "text",
            timestamp: Date(),
            isFromAI: isFromAI,
            displayName: displayName,
            deliveryStatus: deliveryStatus,
            deliveryErrorCode: "",
            deliveryErrorText: "",
            deliveryRetryable: true,
            deliveryRetryCount: 0,
        )
    }

    private func makeEvent(type: String, payload: [String: JSONValue]) -> ChatEventEnvelope {
        ChatEventEnvelope(
            eventID: UUID().uuidString.lowercased(),
            eventType: type,
            createdAt: Date(),
            correlationID: nil,
            payload: payload,
        )
    }

    private func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
