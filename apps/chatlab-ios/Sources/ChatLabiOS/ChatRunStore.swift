import Foundation
import Networking
import OSLog
import SharedModels

private let chatRunStoreLogger = Logger(subsystem: "com.jackfruit.medsim", category: "ChatRunStore")

private actor ChatRealtimeCursorCache {
    private var cursorBySimulationID: [Int: String] = [:]

    func cursor(for simulationID: Int) -> String? {
        cursorBySimulationID[simulationID]
    }

    func setCursor(_ cursor: String, for simulationID: Int) {
        cursorBySimulationID[simulationID] = cursor
    }
}

private enum AwaitingReplyReason: Equatable {
    case initialGeneration
    case conversationReply(messageID: Int)
}

private struct AwaitingReplyState: Equatable {
    let participantName: String
    let reason: AwaitingReplyReason
    var isStale: Bool
}

private enum RefreshTrigger {
    case foregroundHealthCheck
    case manualStatusRefresh
    case manualReconnect
    case automaticReconnect
}

private enum EventHandlingOutcome {
    case applied(String)
    case duplicate(String)
    case ignored(String)

    var label: String {
        switch self {
        case .applied:
            "applied"
        case .duplicate:
            "duplicate"
        case .ignored:
            "ignored"
        }
    }

    var detail: String {
        switch self {
        case let .applied(detail), let .duplicate(detail), let .ignored(detail):
            detail
        }
    }
}

public struct ChatMessageItem: Identifiable, Sendable, Equatable {
    public var id: String
    public var serverID: Int?
    public let conversationID: Int
    public var content: String
    public let isFromSelf: Bool
    public var displayName: String
    public var timestamp: Date
    public var deliveryStatus: DeliveryStatus
    public var retryable: Bool
    public var errorText: String?
    public var retryDraft: String?
    public var isRead: Bool
    public var mediaList: [ChatMessageMedia]
}

public struct ChatActivityItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let eventType: String
    public let title: String
    public let message: String
    public let timestamp: Date
}

@MainActor
public final class ChatRunStore: ObservableObject {
    @Published public private(set) var simulation: ChatSimulation
    @Published public private(set) var conversations: [ChatConversation] = []
    @Published public var activeConversationID: Int?
    @Published public private(set) var unreadByConversation: [Int: Int] = [:]
    @Published public private(set) var messagesByConversation: [Int: [ChatMessageItem]] = [:]
    @Published public private(set) var activityItems: [ChatActivityItem] = []
    @Published public private(set) var typingUsersByConversation: [Int: [String]] = [:]
    @Published public private(set) var hasMoreByConversation: [Int: Bool] = [:]

    @Published public private(set) var isMessagesLoading = false
    @Published public private(set) var isOlderLoading = false
    @Published public private(set) var socketDisconnected = false
    @Published public private(set) var transportState: ChatRealtimeConnectionState = .disconnected
    @Published public private(set) var lastRealtimeSignalAt: Date?
    @Published public private(set) var lastEventCursor: String?

    @Published public private(set) var simulationFailureText: String?
    @Published public private(set) var simulationRetryable = true
    @Published public private(set) var feedbackFailureText: String?
    @Published public private(set) var feedbackRetryable = true
    @Published public private(set) var presentableError: PresentableAppError?
    @Published public private(set) var guardState: GuardStateDTO?
    @Published public private(set) var guardDenial: GuardSignal?
    @Published public private(set) var toolRefreshToken = UUID()
    @Published private var awaitingReplyByConversation: [Int: AwaitingReplyState] = [:]

    @Published public var draftText = ""

    private let service: ChatLabServiceProtocol
    private let realtimeClient: ChatRealtimeClientProtocol
    private var eventTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var typingStopTask: Task<Void, Never>?
    private var hasStarted = false
    private var olderCursorByConversation: [Int: String?] = [:]
    private var seenMessageIDs = Set<Int>()
    private var pendingLocalByKey: [String: (conversationID: Int, content: String)] = [:]
    private var pendingConversationRefreshIDs = Set<Int>()
    private let localUserMarker = "local-user"
    private var awaitingReplyTasks: [Int: Task<Void, Never>] = [:]
    private var lastConnectionState: ChatRealtimeConnectionState = .disconnected
    private let awaitingReplyTimeoutNanoseconds: UInt64 = 20_000_000_000
    private let maxActivityItems = 30
    private var markReadInFlight = Set<Int>()
    private let foregroundRecoveryGraceSeconds: TimeInterval = 12
    private var pendingTransportRecovery = false
    private var pendingToolRefreshReasons = Set<String>()
    private var pendingToolRefreshTask: Task<Void, Never>?
    private let toolRefreshDebounceNanoseconds: UInt64 = 250_000_000

    private static let realtimeCursorCache = ChatRealtimeCursorCache()

    public init(
        service: ChatLabServiceProtocol,
        realtimeClient: ChatRealtimeClientProtocol,
        simulation: ChatSimulation,
    ) {
        self.service = service
        self.realtimeClient = realtimeClient
        self.simulation = simulation
        if simulation.status == .failed {
            simulationFailureText = simulation.terminalReasonText.isEmpty
                ? "Initial patient generation failed."
                : simulation.terminalReasonText
            simulationRetryable = simulation.retryable ?? defaultRetryability(for: simulation)
        }
    }

    deinit {
        eventTask?.cancel()
        stateTask?.cancel()
        heartbeatTask?.cancel()
        typingStopTask?.cancel()
        for task in awaitingReplyTasks.values {
            task.cancel()
        }
        pendingToolRefreshTask?.cancel()
    }

    public var activeMessages: [ChatMessageItem] {
        guard let activeConversationID else { return [] }
        return messagesByConversation[activeConversationID] ?? []
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public var activeTypingUsers: [String] {
        guard let activeConversationID else { return [] }
        var users = typingUsersByConversation[activeConversationID] ?? []
        if let awaiting = awaitingReplyByConversation[activeConversationID], awaiting.isStale == false,
           users.contains(awaiting.participantName) == false
        {
            users.append(awaiting.participantName)
        }
        return users
    }

    public var activeConversationLocked: Bool {
        guard let activeConversation else { return false }
        return isConversationLocked(activeConversation)
    }

    public var activeAwaitingReplyWarningText: String? {
        guard let activeConversationID,
              let awaiting = awaitingReplyByConversation[activeConversationID],
              awaiting.isStale
        else {
            return nil
        }
        return "Still waiting for \(awaiting.participantName). Refresh status or reconnect if nothing changes."
    }

    public var showsInitialGenerationFailureScreen: Bool {
        simulation.status == .failed &&
            isInitialGenerationFailure(simulation) &&
            hasReceivedInitialPatientReply == false
    }

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task {
            await bootstrap()
        }

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in realtimeClient.events {
                await processRealtimeEvent(event)
            }
        }

        stateTask = Task { [weak self] in
            guard let self else { return }
            for await state in realtimeClient.connectionStates {
                await MainActor.run {
                    self.processRealtimeState(state)
                }
            }
        }

        heartbeatTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if !Task.isCancelled {
                    await runHeartbeat()
                }
            }
        }
    }

    public func stop() {
        hasStarted = false
        eventTask?.cancel()
        stateTask?.cancel()
        heartbeatTask?.cancel()
        typingStopTask?.cancel()
        eventTask = nil
        stateTask = nil
        heartbeatTask = nil
        typingStopTask = nil
        pendingToolRefreshTask?.cancel()
        pendingToolRefreshTask = nil
        pendingToolRefreshReasons.removeAll()
        stopAwaitingReply()
        realtimeClient.disconnect()
    }

    private func bootstrap() async {
        do {
            let list = try await service.listConversations(simulationID: simulation.id)
            conversations = list.items
            if activeConversationID == nil {
                activeConversationID = conversations.first?.id
            }

            if let activeConversationID {
                await loadInitialMessages(conversationID: activeConversationID)
                markConversationRead(conversationID: activeConversationID)
            }

            startInitialAwaitingReplyIfNeeded()
            let cursor = await preferredRealtimeCursor(reason: "bootstrap")
            await realtimeClient.connect(simulationID: simulation.id, cursor: cursor)
            await refreshGuardState()
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func switchConversation(_ conversationID: Int) {
        guard conversationID != activeConversationID else { return }
        activeConversationID = conversationID
        unreadByConversation[conversationID] = 0
        if messagesByConversation[conversationID] == nil || pendingConversationRefreshIDs.contains(conversationID) {
            Task { await self.loadInitialMessages(conversationID: conversationID) }
        } else {
            markConversationRead(conversationID: conversationID)
        }
    }

    public func createStitchConversationIfNeeded() {
        Task {
            do {
                let created = try await service.createConversation(
                    simulationID: simulation.id,
                    request: ChatCreateConversationRequest(conversationType: "simulated_feedback"),
                )
                if !conversations.contains(where: { $0.id == created.id }) {
                    conversations.append(created)
                }
                switchConversation(created.id)
            } catch {
                presentableError = AppErrorPresenter.present(error)
            }
        }
    }

    public func loadInitialMessages(conversationID: Int) async {
        isMessagesLoading = true
        defer { isMessagesLoading = false }

        do {
            let page = try await service.listMessages(
                simulationID: simulation.id,
                conversationID: conversationID,
                cursor: nil,
                order: "desc",
                limit: 40,
            )
            let ordered = page.items.reversed().map { self.mapMessage($0) }
            messagesByConversation[conversationID] = ordered
            olderCursorByConversation[conversationID] = page.nextCursor
            hasMoreByConversation[conversationID] = page.hasMore
            for msg in page.items {
                seenMessageIDs.insert(msg.id)
            }
            pendingConversationRefreshIDs.remove(conversationID)
            reconcileAwaitingReplyAfterMessageLoad(conversationID: conversationID)
            markConversationRead(conversationID: conversationID)
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func loadOlderMessages() async {
        guard let activeConversationID else { return }
        guard isOlderLoading == false else { return }
        guard hasMoreByConversation[activeConversationID] == true else { return }

        isOlderLoading = true
        defer { isOlderLoading = false }
        do {
            let page = try await service.listMessages(
                simulationID: simulation.id,
                conversationID: activeConversationID,
                cursor: olderCursorByConversation[activeConversationID] ?? nil,
                order: "desc",
                limit: 30,
            )
            let older = page.items.reversed().map { mapMessage($0) }
            var current = messagesByConversation[activeConversationID] ?? []
            current.insert(contentsOf: older, at: 0)
            messagesByConversation[activeConversationID] = dedupeMessages(current)
            olderCursorByConversation[activeConversationID] = page.nextCursor
            hasMoreByConversation[activeConversationID] = page.hasMore
            for msg in page.items {
                seenMessageIDs.insert(msg.id)
            }
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func sendDraft() {
        guard let activeConversationID else { return }
        guard let conversation = conversations.first(where: { $0.id == activeConversationID }) else { return }
        guard !isConversationLocked(conversation) else { return }

        let content = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        draftText = ""

        let localID = "local-\(UUID().uuidString.lowercased())"
        pendingLocalByKey[localID] = (conversationID: activeConversationID, content: content)
        let optimistic = ChatMessageItem(
            id: localID,
            serverID: nil,
            conversationID: activeConversationID,
            content: content,
            isFromSelf: true,
            displayName: localUserMarker,
            timestamp: Date(),
            deliveryStatus: .sending,
            retryable: true,
            errorText: nil,
            retryDraft: content,
            isRead: true,
            mediaList: [],
        )
        appendMessage(optimistic)

        Task {
            do {
                let created = try await service.createMessage(
                    simulationID: simulation.id,
                    request: ChatCreateMessageRequest(
                        content: content,
                        messageType: "text",
                        conversationID: activeConversationID,
                    ),
                )
                reconcilePending(localID: localID, with: created)
                if let conversation = conversations.first(where: { $0.id == activeConversationID }),
                   supportsAwaitingReply(conversation)
                {
                    startAwaitingReply(
                        for: activeConversationID,
                        participantName: conversation.displayName,
                        reason: .conversationReply(messageID: created.id),
                    )
                }
            } catch let error as APIClientError {
                if case let .guardDenied(_, _, _, signal) = error {
                    guardDenial = signal
                    markPendingFailed(localID: localID, errorText: signal.message)
                    Task { await self.refreshGuardState() }
                } else {
                    markPendingFailed(localID: localID, errorText: messageText(for: error))
                }
            } catch {
                markPendingFailed(localID: localID, errorText: messageText(for: error))
            }
        }
    }

    public func retry(_ item: ChatMessageItem) {
        if let serverID = item.serverID {
            Task {
                do {
                    let retried = try await service.retryMessage(
                        simulationID: simulation.id,
                        messageID: serverID,
                    )
                    upsertMessage(mapMessage(retried))
                    let conversationID = retried.conversationID ?? item.conversationID
                    if let conversation = conversations.first(where: { $0.id == conversationID }),
                       supportsAwaitingReply(conversation)
                    {
                        startAwaitingReply(
                            for: conversationID,
                            participantName: conversation.displayName,
                            reason: .conversationReply(messageID: retried.id),
                        )
                    }
                } catch {
                    presentableError = AppErrorPresenter.present(error)
                }
            }
            return
        }

        if let retryDraft = item.retryDraft {
            draftText = retryDraft
            sendDraft()
        }
    }

    public func notifyTypingChanged() {
        typingStopTask?.cancel()
    }

    public func endSimulation() {
        Task {
            do {
                let updated = try await service.endSimulation(simulationID: simulation.id)
                applySimulation(updated)
            } catch {
                presentableError = AppErrorPresenter.present(error)
            }
        }
    }

    public func retryInitialSimulation() {
        Task {
            do {
                let updated = try await service.retryInitial(simulationID: simulation.id)
                applySimulation(updated)
                simulationFailureText = nil
                startInitialAwaitingReplyIfNeeded(forceRestart: true)
            } catch {
                presentableError = AppErrorPresenter.present(error)
            }
        }
    }

    public func retryFeedback() {
        Task {
            do {
                _ = try await service.retryFeedback(simulationID: simulation.id)
                feedbackFailureText = nil
            } catch {
                presentableError = AppErrorPresenter.present(error)
            }
        }
    }

    private func handleEvent(_ event: ChatEventEnvelope) -> EventHandlingOutcome {
        let canonicalEvent = event.canonicalized()
        switch canonicalEvent.eventType {
        case SimulationEventType.messageItemCreated:
            return handleMessageCreated(eventID: canonicalEvent.eventID, payload: canonicalEvent.payload)

        case SimulationEventType.messageDeliveryUpdated:
            chatRunStoreLogger.info("[ChatRunStore] handleEvent eventID=\(event.eventID, privacy: .public) rawType=\(event.eventType, privacy: .public) canonicalType=\(canonicalEvent.eventType, privacy: .public) payload=\(Self.summarizePayload(canonicalEvent.payload), privacy: .public)")
            return handleMessageStatusUpdate(eventID: canonicalEvent.eventID, payload: canonicalEvent.payload)

        case SimulationEventType.typing:
            chatRunStoreLogger.info("[ChatRunStore] handleEvent eventID=\(event.eventID, privacy: .public) rawType=\(event.eventType, privacy: .public) canonicalType=\(canonicalEvent.eventType, privacy: .public) payload=\(Self.summarizePayload(canonicalEvent.payload), privacy: .public)")
            setTyping(canonicalEvent.payload, started: true)
            return .applied("typing started")

        case SimulationEventType.stoppedTyping:
            chatRunStoreLogger.info("[ChatRunStore] handleEvent eventID=\(event.eventID, privacy: .public) rawType=\(event.eventType, privacy: .public) canonicalType=\(canonicalEvent.eventType, privacy: .public) payload=\(Self.summarizePayload(canonicalEvent.payload), privacy: .public)")
            setTyping(canonicalEvent.payload, started: false)
            return .applied("typing stopped")

        case SimulationEventType.simulationStatusUpdated:
            chatRunStoreLogger.info("[ChatRunStore] handleEvent eventID=\(event.eventID, privacy: .public) rawType=\(event.eventType, privacy: .public) canonicalType=\(canonicalEvent.eventType, privacy: .public) payload=\(Self.summarizePayload(canonicalEvent.payload), privacy: .public)")
            captureActivity(from: canonicalEvent)
            handleSimulationStatusUpdated(canonicalEvent.payload)
            return .applied("simulation status updated")

        case SimulationEventType.feedbackGenerationFailed:
            chatRunStoreLogger.info("[ChatRunStore] handleEvent eventID=\(event.eventID, privacy: .public) rawType=\(event.eventType, privacy: .public) canonicalType=\(canonicalEvent.eventType, privacy: .public) payload=\(Self.summarizePayload(canonicalEvent.payload), privacy: .public)")
            captureActivity(from: canonicalEvent)
            feedbackFailureText = string(canonicalEvent.payload, keys: ["error_text"]) ?? "Feedback generation failed."
            feedbackRetryable = bool(canonicalEvent.payload, key: "retryable") ?? true
            return .applied("feedback generation failed")

        case SimulationEventType.feedbackGenerationUpdated:
            chatRunStoreLogger.info("[ChatRunStore] handleEvent eventID=\(event.eventID, privacy: .public) rawType=\(event.eventType, privacy: .public) canonicalType=\(canonicalEvent.eventType, privacy: .public) payload=\(Self.summarizePayload(canonicalEvent.payload), privacy: .public)")
            feedbackFailureText = nil
            requestToolRefresh(reason: canonicalEvent.eventType)
            return .applied("feedback generation updated")

        case SimulationEventType.feedbackItemCreated,
             SimulationEventType.patientMetadataCreated,
             SimulationEventType.patientResultsUpdated:
            chatRunStoreLogger.info("[ChatRunStore] handleEvent eventID=\(event.eventID, privacy: .public) rawType=\(event.eventType, privacy: .public) canonicalType=\(canonicalEvent.eventType, privacy: .public) payload=\(Self.summarizePayload(canonicalEvent.payload), privacy: .public)")
            captureActivity(from: canonicalEvent)
            feedbackFailureText = nil
            requestToolRefresh(reason: canonicalEvent.eventType)
            return .applied("tool-affecting event \(canonicalEvent.eventType)")

        case SimulationEventType.guardStateUpdated, SimulationEventType.guardWarningUpdated:
            Task { await refreshGuardState() }
            return .applied("guard refresh requested")

        case SimulationEventType.connected,
             SimulationEventType.disconnected,
             SimulationEventType.initMessage,
             SimulationEventType.error,
             SimulationEventType.simulationFeedbackContinueConversation,
             SimulationEventType.simulationHotwashContinueConversation:
            return .ignored("no-op event type \(canonicalEvent.eventType)")

        default:
            return .ignored("unhandled event type \(canonicalEvent.eventType)")
        }
    }

    private func captureActivity(from event: ChatEventEnvelope) {
        guard SimulationEventRegistry.shouldPresentInChatActivity(event.eventType) else {
            return
        }

        let previousStatus = lifecyclePresentationStatus
        let canonicalEventType = SimulationEventRegistry.canonicalize(event.eventType)
        let item = ChatActivityItem(
            id: event.eventID,
            eventType: canonicalEventType,
            title: SimulationEventRegistry.displayTitle(
                for: canonicalEventType,
                payload: event.payload,
                previousStatus: previousStatus,
            ),
            message: SimulationEventRegistry.displayMessage(
                for: canonicalEventType,
                payload: event.payload,
                previousStatus: previousStatus,
            ),
            timestamp: event.createdAt,
        )
        upsertActivity(item)
    }

    public func refreshAfterForegroundOrReconnect() {
        let transportStateDescription = Self.describe(transportState)
        let realtimeSignalDescription = lastRealtimeSignalAt?.ISO8601Format() ?? "nil"
        chatRunStoreLogger.info("[ChatRunStore] refreshAfterForegroundOrReconnect() transportState=\(transportStateDescription, privacy: .public) lastRealtimeSignalAt=\(realtimeSignalDescription, privacy: .public)")
        Task {
            await refreshServerState(
                reconnectRealtime: shouldForceRealtimeRecovery(),
                trigger: .foregroundHealthCheck,
            )
        }
    }

    public func refreshAwaitingReplyStatus() {
        let activeConversationIDSnapshot = activeConversationID ?? -1
        chatRunStoreLogger.info("[ChatRunStore] refreshAwaitingReplyStatus() activeConversationID=\(activeConversationIDSnapshot)")
        Task {
            await refreshServerState(
                reconnectRealtime: false,
                trigger: .manualStatusRefresh,
            )
        }
    }

    public func reconnectRealtimeAndRefresh() {
        let activeConversationIDSnapshot = activeConversationID ?? -1
        chatRunStoreLogger.info("[ChatRunStore] reconnectRealtimeAndRefresh() activeConversationID=\(activeConversationIDSnapshot)")
        Task {
            await refreshServerState(
                reconnectRealtime: true,
                trigger: .manualReconnect,
            )
        }
    }

    private func handleMessageCreated(eventID: String, payload: [String: JSONValue]) -> EventHandlingOutcome {
        let serverID = int(payload, keys: ["message_id", "id"])
        guard let serverID else {
            chatRunStoreLogger.error("[ChatRunStore] skipping live message: missing message_id/id")
            return .ignored("missing message_id/id")
        }
        guard !seenMessageIDs.contains(serverID) else {
            chatRunStoreLogger.info("[ChatRunStore] duplicate event fast-skip eventID=\(eventID, privacy: .public) serverID=\(serverID)")
            return .duplicate("duplicate serverID=\(serverID)")
        }
        chatRunStoreLogger.info("[ChatRunStore] handleMessageCreated eventID=\(eventID, privacy: .public) payload=\(Self.summarizePayload(payload), privacy: .public)")
        seenMessageIDs.insert(serverID)

        let explicitConversationID = int(payload, keys: ["conversation_id"])
        let conversationID = explicitConversationID ?? activeConversationID ?? 0
        guard conversationID > 0 else {
            chatRunStoreLogger.error("[ChatRunStore] skipping live message serverID=\(serverID) because conversationID was unresolved")
            return .ignored("unresolved conversation for serverID=\(serverID)")
        }
        let rawIsFromAI = bool(payload, key: "is_from_ai")
            ?? bool(payload, key: "isFromAi")
            ?? bool(payload, key: "isFromAI")
        let isFromAI = rawIsFromAI ?? false
        let senderID = int(payload, keys: ["sender_id", "senderId"]) ?? -1
        let content = string(payload, keys: ["content"]) ?? ""
        let displayName = string(payload, keys: ["display_name", "displayName"]) ?? (isFromAI ? "AI" : localUserMarker)
        let statusRaw = string(payload, keys: ["delivery_status", "status"])
        let status = DeliveryStatus(rawValue: statusRaw ?? "sent") ?? .sent
        chatRunStoreLogger.info("[ChatRunStore] live message resolved serverID=\(serverID) conversationID=\(conversationID) fallbackConversation=\(explicitConversationID == nil) isFromAI=\(isFromAI) rawAI=\(String(describing: rawIsFromAI), privacy: .public) senderID=\(senderID) status=\(status.rawValue, privacy: .public)")

        if isFromAI {
            stopAwaitingReply(for: conversationID)
        }

        if displayName == localUserMarker || senderID >= 0, let activeConversationID {
            if reconcileLocalEcho(
                conversationID: conversationID,
                serverID: serverID,
                content: content,
                status: status,
            ) {
                chatRunStoreLogger.info("[ChatRunStore] reconciled local echo serverID=\(serverID) conversationID=\(conversationID)")
                if conversationID == activeConversationID {
                    chatRunStoreLogger.debug("[ChatRunStore] skipping append after local echo reconciliation for active conversation serverID=\(serverID)")
                    return .applied("reconciled local echo serverID=\(serverID)")
                }
            }
        }

        let item = ChatMessageItem(
            id: "server-\(serverID)",
            serverID: serverID,
            conversationID: conversationID,
            content: content,
            isFromSelf: !isFromAI,
            displayName: displayName,
            timestamp: date(payload, keys: ["timestamp", "created_at"]) ?? Date(),
            deliveryStatus: status,
            retryable: bool(payload, key: "delivery_retryable") ?? true,
            errorText: string(payload, keys: ["delivery_error_text", "error_text"]),
            retryDraft: nil,
            isRead: bool(payload, key: "is_read") ?? false,
            mediaList: decodeMediaList(from: payload),
        )

        if conversationID != activeConversationID {
            unreadByConversation[conversationID, default: 0] += 1
            let activeConversationIDSnapshot = activeConversationID ?? -1
            let unreadCount = unreadByConversation[conversationID] ?? 0
            chatRunStoreLogger.info("[ChatRunStore] live message targeted non-active conversation conversationID=\(conversationID) activeConversationID=\(activeConversationIDSnapshot) unreadCount=\(unreadCount)")
        }
        appendMessage(item)
        if conversationID == activeConversationID, !item.isFromSelf {
            chatRunStoreLogger.info("[ChatRunStore] marking active conversation read after incoming live message conversationID=\(conversationID) serverID=\(serverID)")
            markConversationRead(conversationID: conversationID)
        }
        return .applied("appended live message serverID=\(serverID)")
    }

    private func handleMessageStatusUpdate(eventID: String, payload: [String: JSONValue]) -> EventHandlingOutcome {
        chatRunStoreLogger.info("[ChatRunStore] handleMessageStatusUpdate payload=\(Self.summarizePayload(payload), privacy: .public)")
        guard let serverID = int(payload, keys: ["id", "message_id"]) else {
            chatRunStoreLogger.error("[ChatRunStore] skipping message status update: missing id/message_id")
            return .ignored("missing id/message_id")
        }
        let status = DeliveryStatus(rawValue: string(payload, keys: ["status"]) ?? "sent") ?? .sent
        let retryable = bool(payload, key: "retryable") ?? true
        let errorText = string(payload, keys: ["error_text"])

        for (conversationID, var items) in messagesByConversation {
            guard let index = items.firstIndex(where: { $0.serverID == serverID }) else { continue }
            if items[index].deliveryStatus == status,
               items[index].retryable == retryable,
               items[index].errorText == errorText
            {
                chatRunStoreLogger.info("[ChatRunStore] duplicate event fast-skip eventID=\(eventID, privacy: .public) message status unchanged serverID=\(serverID)")
                return .duplicate("message status unchanged serverID=\(serverID)")
            }
            items[index].deliveryStatus = status
            items[index].retryable = retryable
            items[index].errorText = errorText
            messagesByConversation[conversationID] = items
            chatRunStoreLogger.info("[ChatRunStore] applied message status update serverID=\(serverID) conversationID=\(conversationID) status=\(status.rawValue, privacy: .public) retryable=\(retryable)")
            if status == .failed {
                stopAwaitingReply(for: conversationID)
            }
            return .applied("message status updated serverID=\(serverID)")
        }
        chatRunStoreLogger.info("[ChatRunStore] duplicate event fast-skip eventID=\(eventID, privacy: .public) missing local message for status update serverID=\(serverID)")
        return .duplicate("missing local message for status update serverID=\(serverID)")
    }

    private func setTyping(_ payload: [String: JSONValue], started: Bool) {
        guard let user = string(payload, keys: ["user"]) else { return }
        let conversationID = int(payload, keys: ["conversation_id"]) ?? activeConversationID ?? 0
        guard conversationID > 0 else { return }

        var users = typingUsersByConversation[conversationID] ?? []
        if started {
            if !users.contains(user), user != localUserMarker {
                users.append(user)
            }
        } else {
            users.removeAll(where: { $0 == user })
        }
        typingUsersByConversation[conversationID] = users
    }

    private func handleSimulationStatusUpdated(_ payload: [String: JSONValue]) {
        guard let statusPayload = try? payload.decodedPayload(as: SimulationStatusUpdatedPayload.self),
              let status = simulationStatus(from: statusPayload)
        else {
            return
        }

        let isTerminal = status != .inProgress
        let updated = ChatSimulation(
            id: simulation.id,
            userID: simulation.userID,
            startTimestamp: simulation.startTimestamp,
            endTimestamp: isTerminal ? (statusPayload.terminalAt ?? simulation.endTimestamp ?? Date()) : nil,
            timeLimitSeconds: simulation.timeLimitSeconds,
            diagnosis: simulation.diagnosis,
            chiefComplaint: simulation.chiefComplaint,
            patientDisplayName: simulation.patientDisplayName,
            patientInitials: simulation.patientInitials,
            status: status,
            terminalReasonCode: isTerminal ? (statusPayload.effectiveReasonCode ?? simulation.terminalReasonCode) : "",
            terminalReasonText: isTerminal ? (statusPayload.effectiveReasonText ?? simulation.terminalReasonText) : "",
            terminalAt: isTerminal ? (statusPayload.terminalAt ?? simulation.terminalAt ?? Date()) : nil,
            retryable: isTerminal ? (statusPayload.retryable ?? simulation.retryable) : nil,
        )
        applySimulation(updated)

        if updated.status == .inProgress {
            startInitialAwaitingReplyIfNeeded()
        }
    }

    private func simulationStatus(from payload: SimulationStatusUpdatedPayload) -> SimulationTerminalState? {
        switch payload.normalizedStatus {
        case "timed_out":
            return .timedOut
        case "canceled", "cancelled":
            return .canceled
        default:
            break
        }

        switch payload.trainerSessionStatus() {
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .seeding, .seeded, .running, .paused:
            return .inProgress
        case nil:
            return nil
        }
    }

    private var lifecyclePresentationStatus: TrainerSessionStatus? {
        switch simulation.status {
        case .inProgress:
            .running
        case .completed, .timedOut, .canceled:
            .completed
        case .failed:
            .failed
        case .unknown:
            nil
        }
    }

    private func mapMessage(_ message: ChatMessage) -> ChatMessageItem {
        ChatMessageItem(
            id: "server-\(message.id)",
            serverID: message.id,
            conversationID: message.conversationID ?? activeConversationID ?? 0,
            content: message.content ?? "",
            isFromSelf: message.isFromAI == false && message.role == "user",
            displayName: message.displayName.isEmpty ? (message.isFromAI ? "AI" : localUserMarker) : message.displayName,
            timestamp: message.timestamp,
            deliveryStatus: message.deliveryStatus,
            retryable: message.deliveryRetryable,
            errorText: message.deliveryErrorText.isEmpty ? nil : message.deliveryErrorText,
            retryDraft: nil,
            isRead: message.isRead,
            mediaList: message.mediaList,
        )
    }

    private func appendMessage(_ item: ChatMessageItem) {
        var items = messagesByConversation[item.conversationID] ?? []
        items.append(item)
        messagesByConversation[item.conversationID] = dedupeMessages(items)
        let totalMessages = (messagesByConversation[item.conversationID] ?? []).count
        chatRunStoreLogger.info("[ChatRunStore] appended live message conversationID=\(item.conversationID) serverID=\(item.serverID ?? -1) isFromSelf=\(item.isFromSelf) totalMessages=\(totalMessages)")
    }

    private var activeConversation: ChatConversation? {
        conversations.first(where: { $0.id == activeConversationID })
    }

    private var simulationHasEnded: Bool {
        simulation.status != .inProgress
    }

    private func isConversationLocked(_ conversation: ChatConversation) -> Bool {
        if conversation.isLocked {
            return true
        }
        // Simulation-level guard block: engine is not runnable or an active denial exists.
        // This is distinct from the per-conversation backend lock (conversation.isLocked above).
        if guardDenial != nil || guardState?.engineRunnable == false {
            return true
        }
        return simulationHasEnded && isPatientConversation(conversation)
    }

    private func isPatientConversation(_ conversation: ChatConversation) -> Bool {
        let normalizedType = conversation.conversationType.lowercased()
        if normalizedType == "simulated_feedback" {
            return false
        }
        return conversation.displayName == simulation.patientDisplayName || conversation.displayInitials == simulation.patientInitials
    }

    private func upsertMessage(_ item: ChatMessageItem) {
        var items = messagesByConversation[item.conversationID] ?? []
        if let serverID = item.serverID,
           let index = items.firstIndex(where: { $0.serverID == serverID })
        {
            items[index] = item
        } else {
            items.append(item)
        }
        messagesByConversation[item.conversationID] = dedupeMessages(items)
    }

    private func dedupeMessages(_ items: [ChatMessageItem]) -> [ChatMessageItem] {
        var seen = Set<String>()
        var ordered: [ChatMessageItem] = []
        for item in items {
            let key = item.serverID.map { "server-\($0)" } ?? item.id
            if seen.contains(key) { continue }
            seen.insert(key)
            ordered.append(item)
        }
        return ordered.sorted { $0.timestamp < $1.timestamp }
    }

    private func upsertActivity(_ item: ChatActivityItem) {
        activityItems.removeAll(where: { $0.id == item.id })
        activityItems.insert(item, at: 0)
        if activityItems.count > maxActivityItems {
            activityItems.removeLast(activityItems.count - maxActivityItems)
        }
    }

    private func addLocalActivity(eventType: String, title: String, message: String) {
        upsertActivity(
            ChatActivityItem(
                id: "local-\(UUID().uuidString.lowercased())",
                eventType: eventType,
                title: title,
                message: message,
                timestamp: Date(),
            ),
        )
    }

    private func handleTransportState(
        _ state: ChatRealtimeConnectionState,
        previousState: ChatRealtimeConnectionState,
    ) {
        chatRunStoreLogger.info("[ChatRunStore] transport state \(Self.describe(previousState), privacy: .public) -> \(Self.describe(state), privacy: .public)")
        switch state {
        case .connected:
            lastRealtimeSignalAt = Date()
            socketDisconnected = false
            if pendingTransportRecovery, previousState != .connected {
                addLocalActivity(
                    eventType: "chat.realtime.recovered",
                    title: "Realtime Recovered",
                    message: "Live updates are healthy again.",
                )
                pendingTransportRecovery = false
                if previousState == .catchingUp {
                    addLocalActivity(
                        eventType: "chat.realtime.catchup.complete",
                        title: "Catch-up Complete",
                        message: "Missed updates were reconciled after reconnecting.",
                    )
                }
            } else if previousState != .connected, previousState != .connecting {
                refreshAfterForegroundOrReconnect()
            }

        case .reconnecting:
            socketDisconnected = true
            if previousState != state {
                pendingTransportRecovery = true
                addLocalActivity(
                    eventType: "chat.realtime.reconnecting",
                    title: "Realtime Recovering",
                    message: "Connection dropped. Reconnecting automatically.",
                )
            }

        case .catchingUp:
            socketDisconnected = true
            pendingTransportRecovery = true
            if previousState != .catchingUp {
                addLocalActivity(
                    eventType: "chat.realtime.catching_up",
                    title: "Syncing Missed Updates",
                    message: "Replaying missed events before live updates resume.",
                )
            }

        case .connecting:
            socketDisconnected = true

        case .disconnected:
            socketDisconnected = true
        }
    }

    private func reconcilePending(localID: String, with message: ChatMessage) {
        guard let pending = pendingLocalByKey[localID] else { return }
        pendingLocalByKey.removeValue(forKey: localID)
        var items = messagesByConversation[pending.conversationID] ?? []
        let mapped = mapMessage(message)
        if let index = items.firstIndex(where: { $0.id == localID }) {
            items[index] = mapped
        } else {
            items.append(mapped)
        }
        messagesByConversation[pending.conversationID] = dedupeMessages(items)
        seenMessageIDs.insert(message.id)
    }

    private func markPendingFailed(localID: String, errorText: String) {
        guard let pending = pendingLocalByKey[localID] else { return }
        var items = messagesByConversation[pending.conversationID] ?? []
        if let index = items.firstIndex(where: { $0.id == localID }) {
            items[index].deliveryStatus = .failed
            items[index].retryable = true
            items[index].errorText = errorText
            items[index].retryDraft = pending.content
        }
        messagesByConversation[pending.conversationID] = items
    }

    private func messageText(for error: Error) -> String {
        AppErrorPresenter.present(error)?.message ?? "Something went wrong."
    }

    private func reconcileLocalEcho(
        conversationID: Int,
        serverID: Int,
        content: String,
        status: DeliveryStatus,
    ) -> Bool {
        var items = messagesByConversation[conversationID] ?? []
        guard let index = items.firstIndex(where: {
            $0.serverID == nil && $0.retryDraft == content
        }) else {
            return false
        }
        items[index].id = "server-\(serverID)"
        items[index].serverID = serverID
        items[index].deliveryStatus = status
        items[index].retryDraft = nil
        messagesByConversation[conversationID] = items
        return true
    }

    private func applySimulation(_ updated: ChatSimulation) {
        simulation = updated
        switch updated.status {
        case .failed:
            simulationFailureText = updated.terminalReasonText.isEmpty
                ? "Simulation failed."
                : updated.terminalReasonText
            simulationRetryable = updated.retryable ?? defaultRetryability(for: updated)
            stopAwaitingReply()

        case .inProgress:
            simulationFailureText = nil
            simulationRetryable = updated.retryable ?? false

        default:
            simulationFailureText = nil
            simulationRetryable = updated.retryable ?? false
            stopAwaitingReply()
        }

        if activeConversationLocked {
            draftText = ""
        }
    }

    private func startAwaitingReply(
        for conversationID: Int,
        participantName: String,
        reason: AwaitingReplyReason,
    ) {
        awaitingReplyByConversation[conversationID] = AwaitingReplyState(
            participantName: participantName,
            reason: reason,
            isStale: false,
        )
        armAwaitingReplyTimeout(for: conversationID)
    }

    private func stopAwaitingReply(for conversationID: Int) {
        let hadState = awaitingReplyByConversation[conversationID] != nil
        chatRunStoreLogger.info("[ChatRunStore] stopAwaitingReply(for:) conversationID=\(conversationID) hadState=\(hadState)")
        awaitingReplyTasks[conversationID]?.cancel()
        awaitingReplyTasks.removeValue(forKey: conversationID)
        awaitingReplyByConversation.removeValue(forKey: conversationID)
    }

    private func stopAwaitingReply() {
        let awaitingReplyCount = awaitingReplyByConversation.count
        chatRunStoreLogger.info("[ChatRunStore] stopAwaitingReply() clearingAll count=\(awaitingReplyCount)")
        cancelAwaitingReplyTasks()
        awaitingReplyByConversation.removeAll()
    }

    private func cancelAwaitingReplyTasks() {
        for task in awaitingReplyTasks.values {
            task.cancel()
        }
        awaitingReplyTasks.removeAll()
    }

    private func armAwaitingReplyTimeout(for conversationID: Int) {
        let timeout = awaitingReplyTimeoutNanoseconds
        awaitingReplyTasks[conversationID]?.cancel()
        awaitingReplyTasks[conversationID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeout)
            guard let self else { return }
            await MainActor.run {
                guard var awaiting = self.awaitingReplyByConversation[conversationID] else { return }
                awaiting.isStale = true
                self.awaitingReplyByConversation[conversationID] = awaiting
            }
        }
    }

    private func refreshGuardState() async {
        do {
            let dto = try await service.getGuardState(simulationID: simulation.id)
            guardState = dto
            guardDenial = dto.denial
        } catch {
            // Non-fatal: keep current guard state on failure
        }
    }

    private func runHeartbeat() async {
        do {
            let dto = try await service.sendHeartbeat(simulationID: simulation.id)
            guardState = dto
            guardDenial = dto.denial
        } catch {
            // Non-fatal: maintain current guard state on heartbeat failure
        }
    }

    private func refreshServerState(reconnectRealtime: Bool, trigger: RefreshTrigger) async {
        chatRunStoreLogger.info("[ChatRunStore] refreshServerState(trigger=\(Self.describe(trigger), privacy: .public), reconnectRealtime=\(reconnectRealtime))")
        do {
            let updated = try await service.getSimulation(simulationID: simulation.id)
            applySimulation(updated)

            if let activeConversationID {
                await loadInitialMessages(conversationID: activeConversationID)
                if var awaiting = awaitingReplyByConversation[activeConversationID], awaiting.isStale {
                    awaiting.isStale = false
                    awaitingReplyByConversation[activeConversationID] = awaiting
                    armAwaitingReplyTimeout(for: activeConversationID)
                }
            }

            let inactiveUnreadConversationIDs = unreadByConversation
                .filter { $0.key != activeConversationID && $0.value > 0 }
                .map(\.key)
            pendingConversationRefreshIDs.formUnion(inactiveUnreadConversationIDs)

            await refreshGuardState()

            switch trigger {
            case .foregroundHealthCheck:
                if reconnectRealtime {
                    addLocalActivity(
                        eventType: "chat.refresh.foreground_recovery",
                        title: "Foreground Health Check",
                        message: "Connection was stale, so ChatLab refreshed and reconnected automatically.",
                    )
                }
            case .manualStatusRefresh:
                addLocalActivity(
                    eventType: "chat.refresh.manual",
                    title: "Status Refreshed",
                    message: "Latest message delivery and simulation state were reloaded.",
                )
            case .manualReconnect:
                addLocalActivity(
                    eventType: "chat.refresh.reconnect",
                    title: "Reconnect Requested",
                    message: "Forcing a fresh realtime connection and message refresh.",
                )
            case .automaticReconnect:
                break
            }

            if reconnectRealtime {
                let simulationID = simulation.id
                chatRunStoreLogger.info("[ChatRunStore] refreshServerState reconnecting realtime simulationID=\(simulationID)")
                realtimeClient.disconnect()
                let cursor = await preferredRealtimeCursor(reason: "refreshServerState:\(Self.describe(trigger))")
                await realtimeClient.connect(simulationID: simulation.id, cursor: cursor)
                if trigger == .foregroundHealthCheck {
                    pendingTransportRecovery = true
                }
            }
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    private func shouldForceRealtimeRecovery() -> Bool {
        guard transportState == .connected else {
            return true
        }
        guard let lastRealtimeSignalAt else {
            return true
        }
        return Date().timeIntervalSince(lastRealtimeSignalAt) > foregroundRecoveryGraceSeconds
    }

    private func reconcileAwaitingReplyAfterMessageLoad(conversationID: Int) {
        if conversationHasAIMessage(conversationID: conversationID) {
            stopAwaitingReply(for: conversationID)
            return
        }

        guard let patientConversation, patientConversation.id == conversationID else {
            return
        }
        startInitialAwaitingReplyIfNeeded()
    }

    private func startInitialAwaitingReplyIfNeeded(forceRestart: Bool = false) {
        guard simulation.status == .inProgress,
              let patientConversation,
              isConversationLocked(patientConversation) == false,
              (messagesByConversation[patientConversation.id] ?? []).isEmpty,
              conversationHasAIMessage(conversationID: patientConversation.id) == false
        else {
            return
        }
        if forceRestart == false,
           case .initialGeneration? = awaitingReplyByConversation[patientConversation.id]?.reason
        {
            return
        }
        startAwaitingReply(
            for: patientConversation.id,
            participantName: patientConversation.displayName,
            reason: .initialGeneration,
        )
    }

    private var patientConversation: ChatConversation? {
        conversations.first(where: isPatientConversation)
    }

    private var hasReceivedInitialPatientReply: Bool {
        guard let patientConversation else { return false }
        return conversationHasAIMessage(conversationID: patientConversation.id)
    }

    private func conversationHasAIMessage(conversationID: Int) -> Bool {
        (messagesByConversation[conversationID] ?? []).contains(where: { $0.isFromSelf == false })
    }

    private func supportsAwaitingReply(_ conversation: ChatConversation) -> Bool {
        let normalizedType = conversation.conversationType.lowercased()
        return normalizedType == "simulated_feedback" || isPatientConversation(conversation)
    }

    private func isInitialGenerationFailure(_ simulation: ChatSimulation) -> Bool {
        let code = simulation.terminalReasonCode
        return code.hasPrefix("initial_generation") ||
            code == "provider_timeout" ||
            code == "provider_transient_error"
    }

    private func defaultRetryability(for simulation: ChatSimulation) -> Bool {
        isInitialGenerationFailure(simulation)
    }

    private func markConversationRead(conversationID: Int) {
        let unreadMessageIDs = (messagesByConversation[conversationID] ?? [])
            .filter { !$0.isFromSelf && !$0.isRead }
            .compactMap(\.serverID)

        guard !unreadMessageIDs.isEmpty else { return }
        unreadByConversation[conversationID] = 0

        for messageID in unreadMessageIDs where !markReadInFlight.contains(messageID) {
            markReadInFlight.insert(messageID)
            Task {
                do {
                    let updated = try await service.markMessageRead(
                        simulationID: simulation.id,
                        messageID: messageID,
                    )
                    await MainActor.run {
                        self.upsertMessage(self.mapMessage(updated))
                        self.markReadInFlight.remove(messageID)
                    }
                } catch {
                    await MainActor.run {
                        self.markReadInFlight.remove(messageID)
                        self.unreadByConversation[conversationID] = (self.messagesByConversation[conversationID] ?? [])
                            .count(where: { !$0.isFromSelf && !$0.isRead })
                    }
                }
            }
        }
    }

    private func decodeMediaList(from payload: [String: JSONValue]) -> [ChatMessageMedia] {
        for key in ["media_list", "mediaList"] {
            guard let value = payload[key] else { continue }
            let raw = value.rawValue
            guard JSONSerialization.isValidJSONObject(raw),
                  let data = try? JSONSerialization.data(withJSONObject: raw),
                  let media = try? JSONDecoder().decode([ChatMessageMedia].self, from: data)
            else {
                continue
            }
            return media
        }
        return []
    }

    private func int(_ payload: [String: JSONValue], keys: [String]) -> Int? {
        for key in keys {
            guard let value = payload[key] else { continue }
            switch value {
            case let .number(number):
                return Int(number)
            case let .string(text):
                return Int(text)
            default:
                continue
            }
        }
        return nil
    }

    private func string(_ payload: [String: JSONValue], keys: [String]) -> String? {
        for key in keys {
            guard let value = payload[key] else { continue }
            if case let .string(text) = value {
                return text
            }
        }
        return nil
    }

    private func bool(_ payload: [String: JSONValue], key: String) -> Bool? {
        guard let value = payload[key] else { return nil }
        switch value {
        case let .bool(flag):
            return flag
        case let .string(text):
            return ["true", "1", "yes"].contains(text.lowercased())
        default:
            return nil
        }
    }

    private func date(_ payload: [String: JSONValue], keys: [String]) -> Date? {
        for key in keys {
            guard let value = payload[key] else { continue }
            if case let .string(text) = value {
                if let parsed = ISO8601DateFormatter().date(from: text) {
                    return parsed
                }
            }
        }
        return nil
    }

    private static func summarizePayload(_ payload: [String: JSONValue], limit: Int = 256) -> String {
        let sorted = payload.keys.sorted().reduce(into: [String: Any]()) { result, key in
            result[key] = payload[key]?.rawValue
        }
        guard JSONSerialization.isValidJSONObject(sorted),
              let data = try? JSONSerialization.data(withJSONObject: sorted),
              var text = String(data: data, encoding: .utf8)
        else {
            return String(describing: sorted)
        }
        if text.count > limit {
            text = String(text.prefix(limit)) + "..."
        }
        return text
    }

    private static func describe(_ state: ChatRealtimeConnectionState) -> String {
        switch state {
        case .disconnected:
            "disconnected"
        case .connecting:
            "connecting"
        case .connected:
            "connected"
        case let .reconnecting(attempt):
            "reconnecting(\(attempt))"
        case .catchingUp:
            "catchingUp"
        }
    }

    private static func describe(_ trigger: RefreshTrigger) -> String {
        switch trigger {
        case .foregroundHealthCheck:
            "foregroundHealthCheck"
        case .manualStatusRefresh:
            "manualStatusRefresh"
        case .manualReconnect:
            "manualReconnect"
        case .automaticReconnect:
            "automaticReconnect"
        }
    }

    private func processRealtimeEvent(_ event: ChatEventEnvelope) async {
        let outcome = handleEvent(event)
        lastRealtimeSignalAt = Date()
        lastEventCursor = event.eventID
        await Self.realtimeCursorCache.setCursor(event.eventID, for: simulation.id)
        chatRunStoreLogger.info("[ChatRunStore] advanced cursor -> \(event.eventID, privacy: .public) outcome=\(outcome.label, privacy: .public) detail=\(outcome.detail, privacy: .public)")
    }

    private func processRealtimeState(_ state: ChatRealtimeConnectionState) {
        let previousState = lastConnectionState
        lastConnectionState = state
        transportState = state
        socketDisconnected = state != .connected
        handleTransportState(state, previousState: previousState)
    }

    private func requestToolRefresh(reason: String) {
        let inserted = pendingToolRefreshReasons.insert(reason).inserted
        if inserted {
            chatRunStoreLogger.info("[ChatRunStore] tool refresh requested reason=\(reason, privacy: .public)")
        } else {
            chatRunStoreLogger.debug("[ChatRunStore] tool refresh duplicate request ignored reason=\(reason, privacy: .public)")
        }
        guard pendingToolRefreshTask == nil else {
            let pendingReasons = pendingToolRefreshReasons.sorted().joined(separator: ",")
            chatRunStoreLogger.debug("[ChatRunStore] tool refresh coalesced pendingReasons=\(pendingReasons, privacy: .public)")
            return
        }

        pendingToolRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.toolRefreshDebounceNanoseconds ?? 0)
            guard let self else { return }
            await MainActor.run {
                let reasons = self.pendingToolRefreshReasons.sorted().joined(separator: ",")
                self.pendingToolRefreshReasons.removeAll()
                self.pendingToolRefreshTask = nil
                chatRunStoreLogger.info("[ChatRunStore] tool refresh invoked reason=\(reasons, privacy: .public)")
                self.toolRefreshToken = UUID()
            }
        }
    }

    private func preferredRealtimeCursor(reason: String) async -> String? {
        if let lastEventCursor {
            chatRunStoreLogger.info("[ChatRunStore] reconnect cursor reason=\(reason, privacy: .public) source=store cursor=\(lastEventCursor, privacy: .public)")
            return lastEventCursor
        }
        if let cachedCursor = await Self.realtimeCursorCache.cursor(for: simulation.id) {
            chatRunStoreLogger.info("[ChatRunStore] reconnect cursor reason=\(reason, privacy: .public) source=cache cursor=\(cachedCursor, privacy: .public)")
            return cachedCursor
        }

        let hydratedMessageCount = messagesByConversation.values.reduce(0) { $0 + $1.count }
        let activityItemCount = activityItems.count
        let hadHydratedState = hydratedMessageCount > 0 || activityItemCount > 0
        if hadHydratedState {
            chatRunStoreLogger.warning("[ChatRunStore] reconnect cursor reason=\(reason, privacy: .public) source=nil hydratedMessages=\(hydratedMessageCount) activityItems=\(activityItemCount) ; replay may occur")
        } else {
            chatRunStoreLogger.info("[ChatRunStore] reconnect cursor reason=\(reason, privacy: .public) source=nil")
        }
        return nil
    }
}
