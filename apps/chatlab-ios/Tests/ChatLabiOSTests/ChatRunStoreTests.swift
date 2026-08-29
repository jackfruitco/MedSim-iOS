@testable import ChatLabiOS
import Networking
import SharedModels
import XCTest

private final class TestChatService: ChatLabServiceProtocol, @unchecked Sendable {
    var simulations: [Int: ChatSimulation] = [:]
    var conversations = ChatConversationListResponse(items: [])
    var messagesByConversation: [Int: [ChatMessage]] = [:]
    var createdMessage: ChatMessage?
    var markReadCalls: [(simulationID: Int, messageID: Int)] = []
    var startedVoiceSessions: [(simulationID: Int, request: ChatVoiceSessionCreateRequest)] = []
    var voiceSession: ChatVoiceSession?
    var startVoiceSessionDelayNanoseconds: UInt64?
    var endedVoiceSessions: [(simulationID: Int, uuid: String)] = []
    var persistedVoiceTranscripts: [(simulationID: Int, uuid: String, request: ChatVoiceTranscriptCreateRequest)] = []
    var voiceTranscriptResponse: ChatVoiceTranscriptResponse?
    var executedVoiceToolCalls: [(simulationID: Int, uuid: String, request: ChatVoiceToolCallRequest)] = []
    var voiceToolCallResponse: ChatVoiceToolCallResponse?

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
        try await getSimulation(simulationID: simulationID)
    }

    func retryInitial(simulationID: Int) async throws -> ChatSimulation {
        try await getSimulation(simulationID: simulationID)
    }

    func retryFeedback(simulationID: Int) async throws -> ChatSimulation {
        try await getSimulation(simulationID: simulationID)
    }

    func listConversations(simulationID _: Int) async throws -> ChatConversationListResponse {
        conversations
    }

    func createConversation(simulationID _: Int, request _: ChatCreateConversationRequest) async throws -> ChatConversation {
        conversations.items.first ?? fallbackConversation()
    }

    func getConversation(simulationID _: Int, conversationUUID _: String) async throws -> ChatConversation {
        conversations.items.first ?? fallbackConversation()
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
        guard let createdMessage else {
            throw NSError(domain: "missing-created-message", code: 404)
        }
        return createdMessage
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
        return try await getMessage(simulationID: simulationID, messageID: messageID)
    }

    func listEvents(simulationID _: Int, lastEventID _: String?, limit _: Int) async throws -> ChatEventReplayResponse {
        ChatEventReplayResponse(items: [], nextEventID: nil, hasMore: false)
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

    func startVoiceSession(simulationID: Int, request: ChatVoiceSessionCreateRequest) async throws -> ChatVoiceSession {
        startedVoiceSessions.append((simulationID, request))
        if let startVoiceSessionDelayNanoseconds {
            try await Task.sleep(nanoseconds: startVoiceSessionDelayNanoseconds)
        }
        guard let voiceSession else {
            throw NSError(domain: "missing-voice-session", code: 404)
        }
        return voiceSession
    }

    func endVoiceSession(simulationID: Int, voiceSessionUUID: String) async throws -> ChatVoiceSession {
        endedVoiceSessions.append((simulationID, voiceSessionUUID))
        guard let voiceSession else {
            throw NSError(domain: "missing-voice-session", code: 404)
        }
        return voiceSession
    }

    func persistVoiceTranscript(
        simulationID: Int,
        voiceSessionUUID: String,
        request: ChatVoiceTranscriptCreateRequest,
    ) async throws -> ChatVoiceTranscriptResponse {
        persistedVoiceTranscripts.append((simulationID, voiceSessionUUID, request))
        guard let voiceTranscriptResponse else {
            throw NSError(domain: "missing-voice-transcript", code: 404)
        }
        return voiceTranscriptResponse
    }

    func executeVoiceToolCall(
        simulationID: Int,
        voiceSessionUUID: String,
        request: ChatVoiceToolCallRequest,
    ) async throws -> ChatVoiceToolCallResponse {
        executedVoiceToolCalls.append((simulationID, voiceSessionUUID, request))
        guard let voiceToolCallResponse else {
            throw NSError(domain: "missing-voice-tool-call", code: 404)
        }
        return voiceToolCallResponse
    }

    func listModifierGroups(labType _: String) async throws -> [ModifierGroup] {
        []
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        GuardStateDTO(
            guardState: "active",
            guardReason: "none",
            engineRunnable: true,
            activeElapsedSeconds: 0,
            runtimeCapSeconds: nil,
            wallClockExpiresAt: nil,
            warnings: [],
            denial: nil,
        )
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        try await getGuardState(simulationID: 0)
    }

    private func fallbackConversation() -> ChatConversation {
        ChatConversation(
            id: 1,
            uuid: UUID().uuidString.lowercased(),
            simulationID: 42,
            conversationType: "simulated_patient",
            conversationTypeDisplay: "simulated_patient",
            icon: "bubble.left",
            displayName: "Jordan Lee",
            displayInitials: "JL",
            isLocked: false,
            createdAt: Date(),
        )
    }
}

private final class TestRealtimeClient: ChatRealtimeClientProtocol, @unchecked Sendable {
    struct StartCall: Equatable {
        let simulationID: Int
        let lastEventID: String?
    }

    struct SentMessage: Equatable {
        let eventType: String
        let payload: [String: JSONValue]
    }

    let events: AsyncStream<ChatEventEnvelope>
    let connectionStates: AsyncStream<ChatRealtimeConnectionState>

    private let eventContinuation: AsyncStream<ChatEventEnvelope>.Continuation
    private let stateContinuation: AsyncStream<ChatRealtimeConnectionState>.Continuation

    private(set) var startCalls: [StartCall] = []
    private(set) var reconnectCalls: [StartCall] = []
    private(set) var replayAnchors: [String?] = []
    private(set) var sentMessages: [SentMessage] = []

    init() {
        var eventCont: AsyncStream<ChatEventEnvelope>.Continuation!
        events = AsyncStream<ChatEventEnvelope> { continuation in
            eventCont = continuation
        }
        eventContinuation = eventCont

        var stateCont: AsyncStream<ChatRealtimeConnectionState>.Continuation!
        connectionStates = AsyncStream<ChatRealtimeConnectionState> { continuation in
            stateCont = continuation
            continuation.yield(.idle)
        }
        stateContinuation = stateCont
    }

    func start(simulationID: Int, initialLastEventID: String?) async {
        startCalls.append(StartCall(simulationID: simulationID, lastEventID: initialLastEventID))
        stateContinuation.yield(.connecting)
        stateContinuation.yield(.connected)
    }

    func reconnect(simulationID: Int, lastEventID: String?) async {
        reconnectCalls.append(StartCall(simulationID: simulationID, lastEventID: lastEventID))
        stateContinuation.yield(.reconnecting(attempt: reconnectCalls.count))
        stateContinuation.yield(.connected)
    }

    func updateReplayAnchor(_ lastEventID: String?) async {
        replayAnchors.append(lastEventID)
    }

    func disconnect() {
        stateContinuation.yield(.idle)
    }

    func send(eventType: String, payload: [String: JSONValue]) async {
        sentMessages.append(SentMessage(eventType: eventType, payload: payload))
    }

    func pushEvent(_ event: ChatEventEnvelope) {
        eventContinuation.yield(event)
    }

    func pushState(_ state: ChatRealtimeConnectionState) {
        stateContinuation.yield(state)
    }
}

@MainActor
private final class TestVoiceRealtimeClient: ChatVoiceRealtimeClientProtocol, @unchecked Sendable {
    let events: AsyncStream<ChatVoiceRealtimeEvent>
    let connectionStates: AsyncStream<ChatVoiceConnectionState>

    private let eventContinuation: AsyncStream<ChatVoiceRealtimeEvent>.Continuation
    private let stateContinuation: AsyncStream<ChatVoiceConnectionState>.Continuation

    private(set) var connectCalls: [ChatVoiceSession] = []
    private(set) var mutedValues: [Bool] = []
    private(set) var toolResults: [(toolCallID: String, output: [String: JSONValue])] = []
    private(set) var disconnectCount = 0

    init() {
        var eventCont: AsyncStream<ChatVoiceRealtimeEvent>.Continuation!
        events = AsyncStream<ChatVoiceRealtimeEvent> { continuation in
            eventCont = continuation
        }
        eventContinuation = eventCont

        var stateCont: AsyncStream<ChatVoiceConnectionState>.Continuation!
        connectionStates = AsyncStream<ChatVoiceConnectionState> { continuation in
            stateCont = continuation
            continuation.yield(.idle)
        }
        stateContinuation = stateCont
    }

    func connect(session: ChatVoiceSession) async throws {
        connectCalls.append(session)
        stateContinuation.yield(.connecting)
        stateContinuation.yield(.live)
    }

    func setMuted(_ isMuted: Bool) async {
        mutedValues.append(isMuted)
        stateContinuation.yield(isMuted ? .muted : .live)
    }

    func sendToolResult(toolCallID: String, output: [String: JSONValue]) async throws {
        toolResults.append((toolCallID, output))
    }

    func disconnect() async {
        disconnectCount += 1
        stateContinuation.yield(.idle)
    }

    func pushEvent(_ event: ChatVoiceRealtimeEvent) {
        eventContinuation.yield(event)
    }

    func pushState(_ state: ChatVoiceConnectionState) {
        stateContinuation.yield(state)
    }
}

@MainActor
final class ChatRunStoreTests: XCTestCase {
    func testBootstrapUsesSimulationLatestEventIDForInitialStart() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil {
            realtime.startCalls.first?.lastEventID == "evt-bootstrap" && store.lastEventID == "evt-bootstrap"
        }
    }

    func testStartVoiceSessionUsesWebSocketTransportAndConnectsVoiceClient() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []
        service.voiceSession = makeVoiceSession(conversationID: patientConversation.id)

        let realtime = TestRealtimeClient()
        let voice = TestVoiceRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            voiceClient: voice,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        store.startVoiceSession()

        try await waitUntil { voice.connectCalls.count == 1 && store.voiceConnectionState == .live }
        XCTAssertEqual(service.startedVoiceSessions.first?.simulationID, simulation.id)
        XCTAssertEqual(service.startedVoiceSessions.first?.request.conversationID, patientConversation.id)
        XCTAssertEqual(service.startedVoiceSessions.first?.request.transport, .webSocket)
        XCTAssertFalse(service.startedVoiceSessions.first?.request.idempotencyKey.isEmpty ?? true)
    }

    func testStopCancelsInFlightVoiceStartBeforeConnecting() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []
        service.voiceSession = makeVoiceSession(conversationID: patientConversation.id)
        service.startVoiceSessionDelayNanoseconds = 300_000_000

        let realtime = TestRealtimeClient()
        let voice = TestVoiceRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            voiceClient: voice,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()

        try await waitUntil { store.activeConversationID == patientConversation.id }
        store.startVoiceSession()
        try await waitUntil { service.startedVoiceSessions.count == 1 }
        store.stop()
        try await Task.sleep(nanoseconds: 450_000_000)

        XCTAssertTrue(voice.connectCalls.isEmpty)
        XCTAssertNil(store.activeVoiceSession)
        XCTAssertEqual(store.voiceConnectionState, .idle)
    }

    func testVoiceTranscriptEventPersistsThroughBackendAndUpsertsMessage() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []
        service.voiceSession = makeVoiceSession(conversationID: patientConversation.id)
        service.voiceTranscriptResponse = ChatVoiceTranscriptResponse(
            persisted: true,
            message: makeMessage(
                id: 990,
                conversationID: patientConversation.id,
                isFromAI: false,
                role: "user",
                content: "I feel dizzy.",
                displayName: "Learner",
                deliveryStatus: .delivered,
            ),
        )

        let realtime = TestRealtimeClient()
        let voice = TestVoiceRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            voiceClient: voice,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        store.startVoiceSession()
        try await waitUntil { voice.connectCalls.count == 1 }

        voice.pushEvent(
            .transcript(
                ChatVoiceTranscriptEvent(
                    role: "user",
                    transcript: "I feel dizzy.",
                    providerItemID: "item-user-1",
                    providerResponseID: nil,
                    providerEventID: "event-user-1",
                    metadata: ["provider_event_type": .string("conversation.item.input_audio_transcription.completed")],
                ),
            ),
        )

        try await waitUntil { store.activeMessages.contains(where: { $0.serverID == 990 }) }
        XCTAssertEqual(service.persistedVoiceTranscripts.first?.uuid, service.voiceSession?.uuid)
        XCTAssertEqual(service.persistedVoiceTranscripts.first?.request.providerItemID, "item-user-1")
        XCTAssertEqual(store.activeMessages.last?.content, "I feel dizzy.")
    }

    func testVoiceToolCallExecutesBackendAndReturnsOutputToRealtime() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []
        service.voiceSession = makeVoiceSession(conversationID: patientConversation.id)
        service.voiceToolCallResponse = ChatVoiceToolCallResponse(
            toolCallID: "call-1",
            name: "patient_history",
            status: "completed",
            output: ["name": .string("patient_history"), "data": .array([])],
        )

        let realtime = TestRealtimeClient()
        let voice = TestVoiceRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            voiceClient: voice,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        store.startVoiceSession()
        try await waitUntil { voice.connectCalls.count == 1 }

        voice.pushEvent(
            .toolCall(
                ChatVoiceToolCallEvent(
                    toolCallID: "call-1",
                    name: "patient_history",
                    arguments: [:],
                    providerResponseID: "response-1",
                    providerEventID: "event-tool-1",
                ),
            ),
        )

        try await waitUntil { voice.toolResults.count == 1 }
        XCTAssertEqual(service.executedVoiceToolCalls.first?.request.name, "patient_history")
        XCTAssertEqual(voice.toolResults.first?.toolCallID, "call-1")
        XCTAssertEqual(voice.toolResults.first?.output["name"], .string("patient_history"))
    }

    func testDurableEventAdvancesLastEventIDAndReplayAnchor() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        let event = makeEvent(
            id: "evt-durable-1",
            type: SimulationEventType.feedbackGenerationFailed,
            payload: [
                "error_text": .string("Feedback timed out"),
                "retryable": .bool(true),
            ],
        )
        realtime.pushEvent(event)

        try await waitUntil {
            store.lastEventID == event.eventID &&
                realtime.replayAnchors.last == event.eventID &&
                store.feedbackFailureText == "Feedback timed out"
        }
    }

    func testTransientEventsDoNotAdvanceReplayAnchorOrCreateTranscriptMessages() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        let bootstrapAnchor = store.lastEventID

        realtime.pushEvent(makeEvent(
            id: "evt-typing-1",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("Jordan Lee"),
            ],
        ))

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(store.lastEventID, bootstrapAnchor)
        XCTAssertTrue(store.activeMessages.isEmpty)
        XCTAssertTrue(store.activeTypingUsers.contains("Jordan Lee"))
    }

    func testDuplicateDurableEventsAreIgnored() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        let payload: [String: JSONValue] = [
            "id": .number(801),
            "message_id": .number(801),
            "conversation_id": .number(Double(patientConversation.id)),
            "content": .string("same"),
            "is_from_ai": .bool(true),
            "display_name": .string(patientConversation.displayName),
            "timestamp": .string(isoTimestamp()),
            "delivery_status": .string("sent"),
        ]
        let event = makeEvent(id: "evt-msg-1", type: SimulationEventType.messageItemCreated, payload: payload)

        realtime.pushEvent(event)
        realtime.pushEvent(event)

        try await waitUntil {
            (store.messagesByConversation[patientConversation.id] ?? []).count == 1
        }
        XCTAssertEqual(realtime.replayAnchors.count(where: { $0 == event.eventID }), 1)
    }

    func testDurableNoOpEventStillAdvancesReplayAnchor() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        let event = makeEvent(
            id: "evt-brief-1",
            type: SimulationEventType.simulationBriefUpdated,
            payload: ["summary": .string("Updated brief")],
        )
        realtime.pushEvent(event)

        try await waitUntil {
            store.lastEventID == event.eventID &&
                realtime.replayAnchors.last == event.eventID
        }
        XCTAssertTrue(store.activeMessages.isEmpty)
    }

    func testLifecycleErrorSetsPresentableErrorWithoutTranscriptMutation() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(
            id: "evt-error-1",
            type: ChatRealtimeEventType.error,
            payload: [
                "code": .string("invalid_payload"),
                "message": .string("Bad resume anchor"),
            ],
        ))

        try await waitUntil { store.presentableError?.title == "Realtime Error" }
        XCTAssertTrue(store.activeMessages.isEmpty)
    }

    func testLifecycleErrorRetainsCorrelationIDInDebugDetails() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(
            id: "evt-error-corr",
            type: ChatRealtimeEventType.error,
            correlationID: "corr-rt-1",
            payload: [
                "code": .string("invalid_payload"),
                "message": .string("Bad resume anchor"),
                "details": .object(["field": .string("last_event_id")]),
            ],
        ))

        try await waitUntil { store.presentableError?.correlationID == "corr-rt-1" }
        XCTAssertTrue(store.presentableError?.debugDetailsText.contains("Correlation ID: corr-rt-1") == true)
    }

    func testSessionResyncRequiredTriggersHardBootstrap() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap-a")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { realtime.startCalls.count == 1 }
        service.simulations[simulation.id] = makeSimulation(
            id: simulation.id,
            status: .inProgress,
            retryable: nil,
            latestEventID: "evt-bootstrap-b",
        )

        realtime.pushEvent(makeEvent(
            id: "evt-resync-1",
            type: ChatRealtimeEventType.sessionResyncRequired,
            payload: ["reason": .string("replay_gap"), "last_event_id": .string("evt-bootstrap-a")],
        ))

        try await waitUntil {
            realtime.startCalls.count == 2 &&
                realtime.startCalls.last?.lastEventID == "evt-bootstrap-b" &&
                store.lastEventID == "evt-bootstrap-b"
        }
    }

    func testHardResyncPreservesDurableDeduplicationState() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap-a")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        let durableEvent = makeEvent(
            id: "evt-msg-resync-safe",
            type: SimulationEventType.messageItemCreated,
            payload: [
                "id": .number(901),
                "message_id": .number(901),
                "conversation_id": .number(Double(patientConversation.id)),
                "content": .string("safe replay"),
                "is_from_ai": .bool(true),
                "display_name": .string(patientConversation.displayName),
                "timestamp": .string(isoTimestamp()),
                "delivery_status": .string("sent"),
            ],
        )

        realtime.pushEvent(durableEvent)
        try await waitUntil {
            (store.messagesByConversation[patientConversation.id] ?? []).count == 1 &&
                store.lastEventID == durableEvent.eventID
        }

        service.simulations[simulation.id] = makeSimulation(
            id: simulation.id,
            status: .inProgress,
            retryable: nil,
            latestEventID: "evt-bootstrap-b",
        )
        service.messagesByConversation[patientConversation.id] = [
            makeMessage(
                id: 901,
                conversationID: patientConversation.id,
                isFromAI: true,
                content: "safe replay",
            ),
        ]
        realtime.pushEvent(makeEvent(
            id: "evt-resync-keep-dedupe",
            type: ChatRealtimeEventType.sessionResyncRequired,
            payload: [
                "reason": .string("replay_gap"),
                "last_event_id": .string(durableEvent.eventID),
            ],
        ))

        try await waitUntil { realtime.startCalls.count == 2 }
        realtime.pushEvent(durableEvent)
        try await Task.sleep(nanoseconds: 75_000_000)

        XCTAssertEqual(store.messagesByConversation[patientConversation.id]?.count, 1)
        XCTAssertEqual(realtime.replayAnchors.count(where: { $0 == durableEvent.eventID }), 1)
    }

    func testReconnectUsesLatestCommittedLastEventID() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        let event = makeEvent(
            id: "evt-durable-9",
            type: SimulationEventType.feedbackGenerationFailed,
            payload: [
                "error_text": .string("Feedback timed out"),
                "retryable": .bool(true),
            ],
        )
        realtime.pushEvent(event)
        try await waitUntil { store.lastEventID == event.eventID }

        store.reconnectRealtimeAndRefresh()

        try await waitUntil {
            realtime.reconnectCalls.last?.lastEventID == event.eventID
        }
    }

    func testTypingUsesCanonicalOutboundEventTypes() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let initialAIMessage = makeMessage(
            id: 1,
            conversationID: patientConversation.id,
            isFromAI: true,
            content: "How can I help?",
        )
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = [initialAIMessage]

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        store.draftText = "Hello"
        store.notifyTypingChanged()
        try await waitUntil {
            realtime.sentMessages.contains(where: { $0.eventType == ChatRealtimeEventType.typingStarted })
        }

        store.draftText = ""
        store.notifyTypingChanged()
        try await waitUntil {
            realtime.sentMessages.contains(where: { $0.eventType == ChatRealtimeEventType.typingStopped })
        }

        XCTAssertEqual(
            realtime.sentMessages.first(where: { $0.eventType == ChatRealtimeEventType.typingStarted })?.payload["conversation_id"],
            .number(Double(patientConversation.id)),
        )
    }

    func testReconnectClearsTransientTypingUsers() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(
            id: "evt-typing-remote",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("consultant@example.com"),
            ],
        ))

        try await waitUntil { store.activeTypingUsers.contains("consultant@example.com") }

        realtime.pushState(.reconnecting(attempt: 1))

        try await waitUntil { !store.activeTypingUsers.contains("consultant@example.com") }
    }

    func testPatientResultsUpdatedEventAdvancesToolRefreshToken() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }
        let initialToken = store.toolRefreshToken

        realtime.pushEvent(makeEvent(
            id: "evt-results-1",
            type: SimulationEventType.patientResultsUpdated,
            payload: ["result_count": .number(2)],
        ))

        try await waitUntil { store.toolRefreshToken != initialToken }
    }

    func testTransportStateTracksConnectingReplayingConnectedResyncingAndFailure() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }

        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushState(.connecting)
        try await waitUntil { store.transportState == .connecting && store.socketDisconnected }

        realtime.pushState(.replaying)
        try await waitUntil { store.transportState == .replaying && !store.socketDisconnected }

        realtime.pushState(.connected)
        try await waitUntil { store.transportState == .connected && !store.socketDisconnected }

        realtime.pushState(.resyncing)
        try await waitUntil { store.transportState == .resyncing && store.socketDisconnected }

        realtime.pushState(.failed(message: "Socket failed"))
        try await waitUntil {
            store.transportState == .failed(message: "Socket failed") && store.socketDisconnected
        }
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
        latestEventID: String? = nil,
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
            latestEventID: latestEventID,
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

    private func makeVoiceSession(conversationID: Int) -> ChatVoiceSession {
        ChatVoiceSession(
            id: 501,
            uuid: "voice-session-uuid",
            simulationID: 42,
            conversationID: conversationID,
            status: .active,
            transport: .webSocket,
            provider: "openai",
            providerSessionID: "realtime-session-1",
            model: "gpt-realtime-test",
            voice: "verse",
            createdAt: Date(),
            updatedAt: Date(),
            endedAt: nil,
            expiresAt: Date().addingTimeInterval(300),
            realtimeURL: "https://api.openai.test/v1/realtime/client_secrets",
            callsURL: nil,
            websocketURL: "wss://api.openai.test/v1/realtime",
            clientSecret: ["value": .string("ek_test")],
            sessionConfig: ["type": .string("realtime"), "model": .string("gpt-realtime-test")],
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

    private func makeEvent(
        id: String,
        type: String,
        correlationID: String? = nil,
        payload: [String: JSONValue],
    ) -> ChatEventEnvelope {
        ChatEventEnvelope(
            eventID: id,
            eventType: type,
            createdAt: Date(),
            correlationID: correlationID,
            payload: payload,
        )
    }

    private func isoTimestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    // MARK: - Self-typing suppression

    func testSelfTypingByActorUserIdIsNotDisplayed() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        // Identity explicitly set to match the payload's actor_user_id
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(id: 7),
        )
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(
            id: "evt-self-typing-1",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("me@example.com"),
                "actor_type": .string("user"),
                "actor_user_id": .number(7),
            ],
        ))

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(store.typingUsersByConversation[patientConversation.id], "Self typing via actor_user_id must not appear")
    }

    func testSelfTypingBySenderIdIsNotDisplayed() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        // Identity explicitly set to match the payload's sender_id
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(id: 7),
        )
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(
            id: "evt-self-typing-2",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("me@example.com"),
                "actor_type": .string("user"),
                "sender_id": .number(7),
            ],
        ))

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(store.typingUsersByConversation[patientConversation.id], "Self typing via sender_id must not appear")
    }

    func testLegacyEmailOnlySelfTypingIsNotDisplayed() async throws {
        // Older payloads have no actor_type or IDs; only the user email field.
        // The store must still suppress them when the email matches the current user.
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(email: "me@example.com"),
        )
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        // Legacy payload: only user field, no IDs, no actor_type
        realtime.pushEvent(makeEvent(
            id: "evt-legacy-self-typing",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("me@example.com"),
                "display_initials": .string("ME"),
            ],
        ))

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(store.typingUsersByConversation[patientConversation.id], "Legacy email-only self typing must not appear")
    }

    func testUuidOnlySelfTypingIsNotDisplayed() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let myUUID = "abc-def-123"
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(uuid: myUUID),
        )
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(
            id: "evt-uuid-self-typing",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("me@example.com"),
                "actor_type": .string("user"),
                "actor_user_uuid": .string(myUUID),
            ],
        ))

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(store.typingUsersByConversation[patientConversation.id], "UUID-only self typing must not appear")
    }

    func testSimulationOwnerMismatchDoesNotSuppressOtherUser() async throws {
        // If authenticated user ID differs from simulation.userID, a typing event
        // whose sender_id matches simulation.userID must NOT be suppressed.
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        // Authenticated user is 99, but simulation.userID is 7
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(id: 99),
        )
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        // Payload from user 7 (simulation owner, not the current authenticated user)
        realtime.pushEvent(makeEvent(
            id: "evt-owner-typing",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("owner@example.com"),
                "actor_type": .string("user"),
                "sender_id": .number(7),
            ],
        ))

        try await waitUntil { store.activeTypingUsers.contains("owner@example.com") }
        XCTAssertFalse(store.activeTypingUsers.isEmpty, "Typing from simulation owner must appear when current user differs")
    }

    func testSystemTypingIsDisplayed() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(
            id: "evt-system-typing-1",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("system@medsim.local"),
                "display_initials": .string("TP"),
                "actor_type": .string("system"),
                "sender_id": JSONValue.null,
                "actor_user_id": JSONValue.null,
                "actor_user_uuid": JSONValue.null,
            ],
        ))

        try await waitUntil { !store.activeTypingUsers.isEmpty }
        // System actor maps to patientDisplayName ("Jordan Lee" in test fixtures)
        XCTAssertTrue(store.activeTypingUsers.contains(simulation.patientDisplayName))
    }

    func testAnotherUserTypingIsDisplayed() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        realtime.pushEvent(makeEvent(
            id: "evt-other-typing-1",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("other@example.com"),
                "actor_type": .string("user"),
                "sender_id": .number(55),
            ],
        ))

        try await waitUntil { store.activeTypingUsers.contains("other@example.com") }
        XCTAssertFalse(store.activeTypingUsers.isEmpty)
    }

    func testTwoUsersWithSameInitialsTrackedSeparatelyByIdNotInitials() async throws {
        let simulation = makeSimulation(status: .inProgress, retryable: nil, latestEventID: "evt-bootstrap")
        let patientConversation = makeConversation()
        let service = TestChatService()
        service.simulations[simulation.id] = simulation
        service.conversations = ChatConversationListResponse(items: [patientConversation])
        service.messagesByConversation[patientConversation.id] = []

        let realtime = TestRealtimeClient()
        let store = ChatRunStore(
            service: service,
            realtimeClient: realtime,
            simulation: simulation,
            currentUserIdentity: ChatCurrentUserIdentity(),
        )
        store.start()
        defer { store.stop() }
        try await waitUntil { store.activeConversationID == patientConversation.id }

        // Two different users, same initials
        realtime.pushEvent(makeEvent(
            id: "evt-user-a",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("alpha@example.com"),
                "display_initials": .string("JD"),
                "actor_type": .string("user"),
                "sender_id": .number(10),
            ],
        ))
        realtime.pushEvent(makeEvent(
            id: "evt-user-b",
            type: ChatRealtimeEventType.typingStarted,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("beta@example.com"),
                "display_initials": .string("JD"),
                "actor_type": .string("user"),
                "sender_id": .number(20),
            ],
        ))

        try await waitUntil {
            store.activeTypingUsers.contains("alpha@example.com") && store.activeTypingUsers.contains("beta@example.com")
        }
        XCTAssertTrue(store.activeTypingUsers.contains("alpha@example.com"))
        XCTAssertTrue(store.activeTypingUsers.contains("beta@example.com"))

        // Stop one; the other should remain
        realtime.pushEvent(makeEvent(
            id: "evt-user-a-stop",
            type: ChatRealtimeEventType.typingStopped,
            payload: [
                "conversation_id": .number(Double(patientConversation.id)),
                "user": .string("alpha@example.com"),
                "display_initials": .string("JD"),
                "actor_type": .string("user"),
                "sender_id": .number(10),
            ],
        ))

        try await waitUntil {
            !store.activeTypingUsers.contains("alpha@example.com") && store.activeTypingUsers.contains("beta@example.com")
        }
        XCTAssertFalse(store.activeTypingUsers.contains("alpha@example.com"))
        XCTAssertTrue(store.activeTypingUsers.contains("beta@example.com"))
    }
}
