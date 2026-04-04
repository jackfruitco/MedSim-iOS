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
    var markReadCalls: [(simulationID: Int, messageID: Int)] = []

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
        if let createMessageError {
            throw createMessageError
        }
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

    func markMessageRead(simulationID: Int, messageID: Int) async throws -> ChatMessage {
        markReadCalls.append((simulationID, messageID))
        for (conversationID, messages) in messagesByConversation {
            if let index = messages.firstIndex(where: { $0.id == messageID }) {
                var updated = messages[index]
                updated = ChatMessage(
                    id: updated.id,
                    simulationID: updated.simulationID,
                    conversationID: updated.conversationID,
                    conversationType: updated.conversationType,
                    senderID: updated.senderID,
                    content: updated.content,
                    role: updated.role,
                    messageType: updated.messageType,
                    timestamp: updated.timestamp,
                    isFromAI: updated.isFromAI,
                    displayName: updated.displayName,
                    deliveryStatus: updated.deliveryStatus,
                    deliveryErrorCode: updated.deliveryErrorCode,
                    deliveryErrorText: updated.deliveryErrorText,
                    deliveryRetryable: updated.deliveryRetryable,
                    deliveryRetryCount: updated.deliveryRetryCount,
                    isRead: true,
                    mediaList: updated.mediaList,
                )
                messagesByConversation[conversationID]?[index] = updated
                return updated
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

    func submitLabOrders(simulationID _: Int, request: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse {
        ChatLabOrdersResponse(status: "accepted", callID: "call-1", orders: request.orders)
    }

    func listModifierGroups(groups _: [String]?) async throws -> [ModifierGroup] {
        []
    }

    var createMessageError: Error?
    var guardStateDenial: GuardSignal?
    private(set) var getGuardStateCalls = 0

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        getGuardStateCalls += 1
        let denial = guardStateDenial
        return GuardStateDTO(
            guardState: denial != nil ? "locked_usage" : "active",
            guardReason: denial != nil ? "usage_limit" : "none",
            engineRunnable: denial == nil,
            activeElapsedSeconds: 0,
            runtimeCapSeconds: nil,
            wallClockExpiresAt: nil,
            warnings: [],
            denial: denial,
        )
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        try await getGuardState(simulationID: 0)
    }
}

private final class TestRealtimeClient: ChatRealtimeClientProtocol, @unchecked Sendable {
    let events: AsyncStream<ChatEventEnvelope>
    let connectionStates: AsyncStream<ChatRealtimeConnectionState>

    private let eventContinuation: AsyncStream<ChatEventEnvelope>.Continuation
    private let stateContinuation: AsyncStream<ChatRealtimeConnectionState>.Continuation
    private(set) var connectCalls = 0
    private(set) var disconnectCalls = 0
    private(set) var connectCursors: [String?] = []

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

    func connect(simulationID _: Int, cursor: String?) async {
        connectCalls += 1
        connectCursors.append(cursor)
        stateContinuation.yield(.connected)
    }

    func disconnect() {
        disconnectCalls += 1
        stateContinuation.yield(.disconnected)
    }

    func send(eventType _: String, payload _: [String: JSONValue]) async {}

    func pushEvent(_ event: ChatEventEnvelope) {
        eventContinuation.yield(event)
    }

    func pushState(_ state: ChatRealtimeConnectionState) {
        stateContinuation.yield(state)
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
                type: SimulationEventType.messageItemCreated,
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
                type: SimulationEventType.messageDeliveryUpdated,
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
                type: SimulationEventType.simulationStatusUpdated,
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

    func testOpeningConversationMarksUnreadIncomingMessagesRead() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let unreadMessage = makeMessage(
            id: 99,
            conversationID: patientConversation.id,
            isFromAI: true,
            content: "Unread reply",
        )
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [unreadMessage]

        let store = ChatRunStore(service: service, realtimeClient: TestRealtimeClient(), simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil {
            service.markReadCalls.contains(where: { $0.messageID == 99 }) &&
                store.activeMessages.first?.isRead == true
        }
    }

    func testCanonicalFeedbackAndPatientRefreshEventsUpdateToolRefreshState() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        let initialToken = store.toolRefreshToken
        realtime.pushEvent(makeEvent(type: SimulationEventType.feedbackGenerationFailed, payload: [
            "error_text": .string("Feedback failed"),
            "retryable": .bool(true),
        ]))

        try await waitUntil { store.feedbackFailureText == "Feedback failed" }

        realtime.pushEvent(makeEvent(type: SimulationEventType.feedbackGenerationUpdated, payload: [:]))
        realtime.pushEvent(makeEvent(type: SimulationEventType.feedbackItemCreated, payload: [:]))
        realtime.pushEvent(makeEvent(type: SimulationEventType.patientMetadataCreated, payload: [:]))
        realtime.pushEvent(makeEvent(type: SimulationEventType.patientResultsUpdated, payload: [:]))

        try await waitUntil {
            store.feedbackFailureText == nil && store.toolRefreshToken != initialToken
        }
    }

    func testRepresentativeLegacyAliasesStillCanonicalizeAcrossFamilies() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        let initialToken = store.toolRefreshToken
        realtime.pushEvent(makeEvent(type: "feedback.created", payload: [:]))
        realtime.pushEvent(makeEvent(type: "simulation.metadata.results_created", payload: [:]))

        try await waitUntil {
            store.toolRefreshToken != initialToken
        }
    }

    func testNonMessageCanonicalEventsCreateChatActivityItems() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(type: SimulationEventType.feedbackGenerationFailed, payload: [
            "error_text": .string("Feedback timed out"),
            "retryable": .bool(true),
        ]))
        realtime.pushEvent(makeEvent(type: SimulationEventType.patientResultsUpdated, payload: [:]))

        try await waitUntil {
            store.activityItems.count == 2 &&
                store.activityItems.map(\.eventType).contains(SimulationEventType.feedbackGenerationFailed) &&
                store.activityItems.map(\.eventType).contains(SimulationEventType.patientResultsUpdated)
        }

        XCTAssertEqual(store.activityItems.first?.title, "Patient Results Updated")
        XCTAssertTrue(store.activityItems.contains(where: {
            $0.eventType == SimulationEventType.feedbackGenerationFailed &&
                $0.message == "Feedback timed out"
        }))
    }

    func testMessageEventsStayInMessageTimelineAndDoNotCreateActivityItems() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(
            makeEvent(
                type: SimulationEventType.messageItemCreated,
                payload: [
                    "id": .number(301),
                    "message_id": .number(301),
                    "conversation_id": .number(Double(patientConversation.id)),
                    "content": .string("Hello again"),
                    "is_from_ai": .bool(true),
                    "display_name": .string(patientConversation.displayName),
                    "timestamp": .string(isoTimestamp()),
                    "delivery_status": .string("sent"),
                ],
            ),
        )

        try await waitUntil { store.activeMessages.contains(where: { $0.serverID == 301 }) }
        XCTAssertTrue(store.activityItems.isEmpty)
    }

    func testTransientNoOpEventsDoNotCreateActivityItems() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(type: SimulationEventType.connected, payload: [:]))
        realtime.pushEvent(makeEvent(type: SimulationEventType.error, payload: ["message": .string("ignored")]))

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(store.activityItems.isEmpty)
    }

    func testSendDraftWithGuardDenied403SetsGuardDenialAndMarksFailed() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let initialMessage = makeMessage(id: 1, conversationID: patientConversation.id, isFromAI: true, content: "How can I help you?")
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [initialMessage]

        let signal = GuardSignal(
            code: "runtime_cap_reached",
            severity: "error",
            title: "Session Ended",
            message: "The runtime cap was reached.",
            resumable: false,
            terminal: true,
            expiresInSeconds: nil,
            metadata: nil,
        )
        service.createMessageError = APIClientError.guardDenied(
            statusCode: 403,
            detail: "The runtime cap has been exceeded.",
            correlationID: nil,
            signal: signal,
        )

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        try await waitUntil { store.activeTypingUsers.isEmpty }

        // Set after bootstrap so the initial refreshGuardState doesn't pre-lock the store
        service.guardStateDenial = signal
        store.draftText = "Hello"
        store.sendDraft()

        try await waitUntil { store.guardDenial != nil }

        XCTAssertEqual(store.guardDenial?.code, "runtime_cap_reached")
        XCTAssertTrue(store.guardDenial?.isTerminal == true)
        let messages = store.messagesByConversation[patientConversation.id] ?? []
        let failed = messages.first(where: { $0.deliveryStatus == .failed })
        XCTAssertNotNil(failed)
        XCTAssertEqual(failed?.errorText, "The runtime cap was reached.")
    }

    func testTerminalGuardDenialLocksConversation() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let initialMessage = makeMessage(id: 1, conversationID: patientConversation.id, isFromAI: true, content: "How can I help you?")
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [initialMessage]

        let signal = GuardSignal(
            code: "runtime_cap_reached",
            severity: "error",
            title: "Session Ended",
            message: "The runtime cap was reached.",
            resumable: false,
            terminal: true,
            expiresInSeconds: nil,
            metadata: nil,
        )
        service.createMessageError = APIClientError.guardDenied(
            statusCode: 403,
            detail: "blocked",
            correlationID: nil,
            signal: signal,
        )
        service.guardStateDenial = signal

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        try await waitUntil { store.activeTypingUsers.isEmpty }

        store.draftText = "Hello"
        store.sendDraft()

        try await waitUntil { store.guardDenial?.isTerminal == true }

        XCTAssertTrue(store.activeConversationLocked)
    }

    func testTranscriptRemainsReadableAfterDenial() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let existingMessage = makeMessage(
            id: 1,
            conversationID: patientConversation.id,
            isFromAI: true,
            content: "How can I help you today?",
        )
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [existingMessage]

        let signal = GuardSignal(
            code: "runtime_cap_reached",
            severity: "error",
            title: nil,
            message: "Blocked.",
            resumable: false,
            terminal: true,
            expiresInSeconds: nil,
            metadata: nil,
        )
        service.createMessageError = APIClientError.guardDenied(
            statusCode: 403,
            detail: "blocked",
            correlationID: nil,
            signal: signal,
        )
        service.guardStateDenial = signal

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        store.draftText = "Hello"
        store.sendDraft()

        try await waitUntil { store.guardDenial?.isTerminal == true }

        // Existing transcript message is still accessible
        let messages = store.messagesByConversation[patientConversation.id] ?? []
        XCTAssertTrue(messages.contains(where: { $0.serverID == 1 && $0.content == "How can I help you today?" }))
    }

    func testNonTerminalGuardDenialBlocksSend() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let initialMessage = makeMessage(id: 1, conversationID: patientConversation.id, isFromAI: true, content: "How can I help you?")
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [initialMessage]

        let signal = GuardSignal(
            code: "usage_limit_reached",
            severity: "error",
            title: "Usage Limit",
            message: "You have reached your usage limit.",
            resumable: true,
            terminal: false,
            expiresInSeconds: nil,
            metadata: nil,
        )
        service.createMessageError = APIClientError.guardDenied(
            statusCode: 403,
            detail: "blocked",
            correlationID: nil,
            signal: signal,
        )
        service.guardStateDenial = signal

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        try await waitUntil { store.activeTypingUsers.isEmpty }

        store.draftText = "Hello"
        store.sendDraft()

        try await waitUntil { store.guardDenial?.code == "usage_limit_reached" }

        // Non-terminal denial still blocks further sends
        XCTAssertTrue(store.activeConversationLocked)
        // Transcript remains readable
        XCTAssertFalse((store.messagesByConversation[patientConversation.id] ?? []).isEmpty)
    }

    func testGuardDeniedSendTriggersGuardStateRefresh() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let initialMessage = makeMessage(id: 1, conversationID: patientConversation.id, isFromAI: true, content: "How can I help you?")
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [initialMessage]

        let signal = GuardSignal(
            code: "runtime_cap_reached",
            severity: "error",
            title: "Session Ended",
            message: "The runtime cap was reached.",
            resumable: false,
            terminal: true,
            expiresInSeconds: nil,
            metadata: nil,
        )
        service.createMessageError = APIClientError.guardDenied(
            statusCode: 403,
            detail: "blocked",
            correlationID: nil,
            signal: signal,
        )

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        try await waitUntil { store.activeTypingUsers.isEmpty }

        // Set after bootstrap so the initial refreshGuardState doesn't pre-lock the store
        service.guardStateDenial = signal
        let callsBefore = service.getGuardStateCalls
        store.draftText = "Hello"
        store.sendDraft()

        try await waitUntil { service.getGuardStateCalls > callsBefore }
        XCTAssertGreaterThan(service.getGuardStateCalls, callsBefore)
    }

    func testRefreshReconcilesActiveConversationStatusesAndMedia() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let initialMessage = makeMessage(
            id: 44,
            conversationID: patientConversation.id,
            isFromAI: false,
            role: "user",
            content: "Checking in",
            displayName: "Student",
            deliveryStatus: .sending,
        )
        let refreshedMedia = ChatMessageMedia(
            id: 7,
            uuid: UUID().uuidString.lowercased(),
            originalURL: "https://example.com/image-full.png",
            thumbnailURL: "https://example.com/image-thumb.png",
            url: "https://example.com/image-thumb.png",
            mimeType: "image/png",
            description: "Portable chest x-ray",
        )

        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [initialMessage]

        let store = ChatRunStore(service: service, realtimeClient: TestRealtimeClient(), simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        try await waitUntil { store.activeMessages.first?.deliveryStatus == .sending }

        service.messagesByConversation[patientConversation.id] = [
            makeMessage(
                id: 44,
                conversationID: patientConversation.id,
                isFromAI: false,
                role: "user",
                content: "Checking in",
                displayName: "Student",
                deliveryStatus: .failed,
                deliveryErrorText: "Delivery timed out.",
                mediaList: [refreshedMedia],
            ),
        ]

        store.refreshAfterForegroundOrReconnect()

        try await waitUntil {
            guard let refreshed = store.activeMessages.first else {
                return false
            }
            return refreshed.deliveryStatus == .failed &&
                refreshed.errorText == "Delivery timed out." &&
                refreshed.mediaList == [refreshedMedia]
        }
    }

    func testDisconnectedForegroundRefreshForcesReconnectAndLogsActivity() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        let initialConnects = realtime.connectCalls

        realtime.pushState(.disconnected)
        try await waitUntil { store.transportState == .disconnected }
        store.refreshAfterForegroundOrReconnect()

        try await waitUntil {
            realtime.connectCalls > initialConnects &&
                store.activityItems.contains(where: { $0.eventType == "chat.refresh.foreground_recovery" })
        }
    }

    func testRealtimeEventUpdatesHealthMetadata() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(
            makeEvent(
                type: SimulationEventType.feedbackGenerationFailed,
                payload: [
                    "error_text": .string("Feedback timed out"),
                    "retryable": .bool(true),
                ],
            ),
        )

        try await waitUntil {
            store.lastEventCursor != nil && store.lastRealtimeSignalAt != nil
        }
    }

    func testBootstrapCheckpointCursorIsUsedForInitialConnect() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(
            items: [patientConversation],
            latestEventCursor: "evt-bootstrap-9",
        )
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil {
            realtime.connectCursors.first == "evt-bootstrap-9"
        }
    }

    func testReconnectUsesLatestCommittedCursor() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation], latestEventCursor: "evt-bootstrap-1")
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        realtime.pushEvent(makeEvent(type: SimulationEventType.feedbackGenerationFailed, payload: [
            "error_text": .string("x"),
            "retryable": .bool(true),
        ]))
        let committedCursor = store.lastEventCursor
        store.reconnectRealtimeAndRefresh()

        try await waitUntil { realtime.connectCursors.count >= 2 }
        XCTAssertEqual(realtime.connectCursors.last, committedCursor)
    }

    func testDuplicateMessageEventFastSkipsWithoutToolRefreshSpam() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        let initialToken = store.toolRefreshToken
        let duplicatePayload: [String: JSONValue] = [
            "id": .number(801),
            "message_id": .number(801),
            "conversation_id": .number(Double(patientConversation.id)),
            "content": .string("same"),
            "is_from_ai": .bool(true),
            "display_name": .string(patientConversation.displayName),
            "timestamp": .string(isoTimestamp()),
            "delivery_status": .string("sent"),
        ]
        realtime.pushEvent(makeEvent(type: SimulationEventType.messageItemCreated, payload: duplicatePayload))
        realtime.pushEvent(makeEvent(type: SimulationEventType.messageItemCreated, payload: duplicatePayload))

        try await waitUntil {
            (store.messagesByConversation[patientConversation.id] ?? []).count == 1
        }
        XCTAssertEqual(store.toolRefreshToken, initialToken)
    }

    func testStaleCursorStateTriggersRebootstrapAndReconnectFromFreshCheckpoint() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil)
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation], latestEventCursor: "evt-bootstrap-a")
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(service: service, realtimeClient: realtime, simulation: simulation)
        store.start()
        defer { store.stop() }
        try await waitUntil { realtime.connectCursors.first == "evt-bootstrap-a" }

        service.conversations = ChatConversationListResponse(items: [patientConversation], latestEventCursor: "evt-bootstrap-b")
        realtime.pushState(.staleCursor)

        try await waitUntil { realtime.connectCursors.count >= 2 }
        XCTAssertEqual(realtime.connectCursors.last, "evt-bootstrap-b")
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
        deliveryErrorText: String = "",
        mediaList: [ChatMessageMedia] = [],
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
            deliveryErrorText: deliveryErrorText,
            deliveryRetryable: true,
            deliveryRetryCount: 0,
            isRead: false,
            mediaList: mediaList,
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
