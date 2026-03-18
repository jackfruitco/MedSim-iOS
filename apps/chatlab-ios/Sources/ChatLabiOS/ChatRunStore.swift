import Foundation
import Networking
import SharedModels

private enum AwaitingReplyReason: Sendable, Equatable {
    case initialGeneration
    case conversationReply(messageID: Int)
}

private struct AwaitingReplyState: Sendable, Equatable {
    let participantName: String
    let reason: AwaitingReplyReason
    var isStale: Bool
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
}

@MainActor
public final class ChatRunStore: ObservableObject {
    @Published public private(set) var simulation: ChatSimulation
    @Published public private(set) var conversations: [ChatConversation] = []
    @Published public var activeConversationID: Int?
    @Published public private(set) var unreadByConversation: [Int: Int] = [:]
    @Published public private(set) var messagesByConversation: [Int: [ChatMessageItem]] = [:]
    @Published public private(set) var typingUsersByConversation: [Int: [String]] = [:]
    @Published public private(set) var hasMoreByConversation: [Int: Bool] = [:]

    @Published public private(set) var isMessagesLoading = false
    @Published public private(set) var isOlderLoading = false
    @Published public private(set) var socketDisconnected = false
    @Published public private(set) var transportState: ChatRealtimeConnectionState = .disconnected

    @Published public private(set) var simulationFailureText: String?
    @Published public private(set) var simulationRetryable = true
    @Published public private(set) var feedbackFailureText: String?
    @Published public private(set) var feedbackRetryable = true
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var toolRefreshToken = UUID()
    @Published private var awaitingReplyByConversation: [Int: AwaitingReplyState] = [:]

    @Published public var draftText = ""

    private let service: ChatLabServiceProtocol
    private let realtimeClient: ChatRealtimeClientProtocol
    private var eventTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var typingStopTask: Task<Void, Never>?
    private var hasStarted = false
    private var olderCursorByConversation: [Int: String?] = [:]
    private var seenMessageIDs = Set<Int>()
    private var pendingLocalByKey: [String: (conversationID: Int, content: String)] = [:]
    private let localUserMarker = "local-user"
    private var awaitingReplyTasks: [Int: Task<Void, Never>] = [:]
    private var lastConnectionState: ChatRealtimeConnectionState = .disconnected
    private let awaitingReplyTimeoutNanoseconds: UInt64 = 20_000_000_000

    public init(
        service: ChatLabServiceProtocol,
        realtimeClient: ChatRealtimeClientProtocol,
        simulation: ChatSimulation
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
        typingStopTask?.cancel()
        for task in awaitingReplyTasks.values {
            task.cancel()
        }
    }

    public var activeMessages: [ChatMessageItem] {
        guard let activeConversationID else { return [] }
        return messagesByConversation[activeConversationID] ?? []
    }

    public var activeTypingUsers: [String] {
        guard let activeConversationID else { return [] }
        var users = typingUsersByConversation[activeConversationID] ?? []
        if let awaiting = awaitingReplyByConversation[activeConversationID], awaiting.isStale == false,
           users.contains(awaiting.participantName) == false {
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
              awaiting.isStale else {
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
                await MainActor.run {
                    self.handleEvent(event)
                }
            }
        }

        stateTask = Task { [weak self] in
            guard let self else { return }
            for await state in realtimeClient.connectionStates {
                await MainActor.run {
                    let previousState = self.lastConnectionState
                    self.lastConnectionState = state
                    self.transportState = state
                    self.socketDisconnected = state != .connected
                    if state == .connected, previousState != .connected {
                        self.refreshAfterForegroundOrReconnect()
                    }
                }
            }
        }
    }

    public func stop() {
        hasStarted = false
        eventTask?.cancel()
        stateTask?.cancel()
        typingStopTask?.cancel()
        eventTask = nil
        stateTask = nil
        typingStopTask = nil
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
            }

            startInitialAwaitingReplyIfNeeded()
            await realtimeClient.connect(simulationID: simulation.id, cursor: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func switchConversation(_ conversationID: Int) {
        guard conversationID != activeConversationID else { return }
        activeConversationID = conversationID
        unreadByConversation[conversationID] = 0
        if messagesByConversation[conversationID] == nil {
            Task { await self.loadInitialMessages(conversationID: conversationID) }
        }
    }

    public func createStitchConversationIfNeeded() {
        Task {
            do {
                let created = try await service.createConversation(
                    simulationID: simulation.id,
                    request: ChatCreateConversationRequest(conversationType: "simulated_feedback")
                )
                if !conversations.contains(where: { $0.id == created.id }) {
                    conversations.append(created)
                }
                switchConversation(created.id)
            } catch {
                errorMessage = error.localizedDescription
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
                limit: 40
            )
            let ordered = page.items.reversed().map { self.mapMessage($0) }
            messagesByConversation[conversationID] = ordered
            olderCursorByConversation[conversationID] = page.nextCursor
            hasMoreByConversation[conversationID] = page.hasMore
            for msg in page.items {
                seenMessageIDs.insert(msg.id)
            }
            reconcileAwaitingReplyAfterMessageLoad(conversationID: conversationID)
        } catch {
            errorMessage = error.localizedDescription
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
                limit: 30
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
            errorMessage = error.localizedDescription
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
            retryDraft: content
        )
        appendMessage(optimistic)

        Task {
            do {
                let created = try await service.createMessage(
                    simulationID: simulation.id,
                    request: ChatCreateMessageRequest(
                        content: content,
                        messageType: "text",
                        conversationID: activeConversationID
                    )
                )
                reconcilePending(localID: localID, with: created)
                if let conversation = conversations.first(where: { $0.id == activeConversationID }),
                   supportsAwaitingReply(conversation) {
                    startAwaitingReply(
                        for: activeConversationID,
                        participantName: conversation.displayName,
                        reason: .conversationReply(messageID: created.id)
                    )
                }
            } catch {
                markPendingFailed(localID: localID, errorText: error.localizedDescription)
            }
        }
    }

    public func retry(_ item: ChatMessageItem) {
        if let serverID = item.serverID {
            Task {
                do {
                    let retried = try await service.retryMessage(
                        simulationID: simulation.id,
                        messageID: serverID
                    )
                    upsertMessage(mapMessage(retried))
                    let conversationID = retried.conversationID ?? item.conversationID
                    if let conversation = conversations.first(where: { $0.id == conversationID }),
                       supportsAwaitingReply(conversation) {
                        startAwaitingReply(
                            for: conversationID,
                            participantName: conversation.displayName,
                            reason: .conversationReply(messageID: retried.id)
                        )
                    }
                } catch {
                    errorMessage = error.localizedDescription
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
        guard let activeConversationID else { return }
        guard !activeConversationLocked else { return }
        Task {
            await realtimeClient.send(
                eventType: "typing",
                payload: ["conversation_id": .number(Double(activeConversationID))]
            )
        }

        typingStopTask?.cancel()
        typingStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self, let conversationID = self.activeConversationID else { return }
            await self.realtimeClient.send(
                eventType: "stopped_typing",
                payload: ["conversation_id": .number(Double(conversationID))]
            )
        }
    }

    public func endSimulation() {
        Task {
            do {
                let updated = try await service.endSimulation(simulationID: simulation.id)
                applySimulation(updated)
            } catch {
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
            }
        }
    }

    public func retryFeedback() {
        Task {
            do {
                _ = try await service.retryFeedback(simulationID: simulation.id)
                feedbackFailureText = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleEvent(_ event: ChatEventEnvelope) {
        switch event.eventType {
        case "chat.message_created":
            handleMessageCreated(event.payload)
            toolRefreshToken = UUID()

        case "message_status_update":
            handleMessageStatusUpdate(event.payload)

        case "typing", "typing.started":
            setTyping(event.payload, started: true)

        case "stopped_typing", "typing.stopped":
            setTyping(event.payload, started: false)

        case "simulation.state_changed":
            handleSimulationStateChanged(event.payload)

        case "feedback.failed":
            feedbackFailureText = string(event.payload, keys: ["error_text"]) ?? "Feedback generation failed."
            feedbackRetryable = bool(event.payload, key: "retryable") ?? true

        case "feedback.retrying":
            feedbackFailureText = nil

        case "simulation.metadata.results_created",
             "simulation.feedback_created",
             "feedback.created",
             "simulation.hotwash.created":
            toolRefreshToken = UUID()

        default:
            break
        }
    }

    public func refreshAfterForegroundOrReconnect() {
        Task {
            await refreshServerState(reconnectRealtime: false)
        }
    }

    public func refreshAwaitingReplyStatus() {
        Task {
            await refreshServerState(reconnectRealtime: false)
        }
    }

    public func reconnectRealtimeAndRefresh() {
        Task {
            await refreshServerState(reconnectRealtime: true)
        }
    }

    private func handleMessageCreated(_ payload: [String: JSONValue]) {
        let serverID = int(payload, keys: ["message_id", "id"])
        guard let serverID else { return }
        guard !seenMessageIDs.contains(serverID) else { return }
        seenMessageIDs.insert(serverID)

        let conversationID = int(payload, keys: ["conversation_id"]) ?? activeConversationID ?? 0
        let isFromAI = bool(payload, key: "is_from_ai")
            ?? bool(payload, key: "isFromAi")
            ?? bool(payload, key: "isFromAI")
            ?? false
        let senderID = int(payload, keys: ["sender_id", "senderId"]) ?? -1
        let content = string(payload, keys: ["content"]) ?? ""
        let displayName = string(payload, keys: ["display_name", "displayName"]) ?? (isFromAI ? "AI" : localUserMarker)
        let statusRaw = string(payload, keys: ["delivery_status", "status"])
        let status = DeliveryStatus(rawValue: statusRaw ?? "sent") ?? .sent

        if isFromAI {
            stopAwaitingReply(for: conversationID)
        }

        if displayName == localUserMarker || senderID >= 0, let activeConversationID {
            if reconcileLocalEcho(
                conversationID: conversationID,
                serverID: serverID,
                content: content,
                status: status
            ) {
                if conversationID == activeConversationID {
                    return
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
            retryDraft: nil
        )

        if conversationID != activeConversationID {
            unreadByConversation[conversationID, default: 0] += 1
        }
        appendMessage(item)
    }

    private func handleMessageStatusUpdate(_ payload: [String: JSONValue]) {
        guard let serverID = int(payload, keys: ["id", "message_id"]) else { return }
        let status = DeliveryStatus(rawValue: string(payload, keys: ["status"]) ?? "sent") ?? .sent
        let retryable = bool(payload, key: "retryable") ?? true
        let errorText = string(payload, keys: ["error_text"])

        for (conversationID, var items) in messagesByConversation {
            guard let index = items.firstIndex(where: { $0.serverID == serverID }) else { continue }
            items[index].deliveryStatus = status
            items[index].retryable = retryable
            items[index].errorText = errorText
            messagesByConversation[conversationID] = items
            if status == .failed {
                stopAwaitingReply(for: conversationID)
            }
            break
        }
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

    private func handleSimulationStateChanged(_ payload: [String: JSONValue]) {
        if let raw = string(payload, keys: ["status"]),
           let status = SimulationTerminalState(rawValue: raw) {
            let updated = ChatSimulation(
                id: simulation.id,
                userID: simulation.userID,
                startTimestamp: simulation.startTimestamp,
                endTimestamp: simulation.endTimestamp,
                timeLimitSeconds: simulation.timeLimitSeconds,
                diagnosis: simulation.diagnosis,
                chiefComplaint: simulation.chiefComplaint,
                patientDisplayName: simulation.patientDisplayName,
                patientInitials: simulation.patientInitials,
                status: status,
                terminalReasonCode: string(payload, keys: ["terminal_reason_code"]) ?? simulation.terminalReasonCode,
                terminalReasonText: string(payload, keys: ["terminal_reason_text"]) ?? simulation.terminalReasonText,
                terminalAt: date(payload, keys: ["terminal_at"]) ?? simulation.terminalAt,
                retryable: bool(payload, key: "retryable") ?? simulation.retryable
            )
            applySimulation(updated)
        }

        if simulation.status == .inProgress {
            startInitialAwaitingReplyIfNeeded()
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
            retryDraft: nil
        )
    }

    private func appendMessage(_ item: ChatMessageItem) {
        var items = messagesByConversation[item.conversationID] ?? []
        items.append(item)
        messagesByConversation[item.conversationID] = dedupeMessages(items)
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
           let index = items.firstIndex(where: { $0.serverID == serverID }) {
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

    private func reconcilePending(localID: String, with message: ChatMessage) {
        guard let pending = pendingLocalByKey[localID] else { return }
        pendingLocalByKey.removeValue(forKey: localID)
        var items = messagesByConversation[pending.conversationID] ?? []
        if let index = items.firstIndex(where: { $0.id == localID }) {
            items[index].id = "server-\(message.id)"
            items[index].serverID = message.id
            items[index].deliveryStatus = message.deliveryStatus
            items[index].retryDraft = nil
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

    private func reconcileLocalEcho(
        conversationID: Int,
        serverID: Int,
        content: String,
        status: DeliveryStatus
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
        reason: AwaitingReplyReason
    ) {
        awaitingReplyByConversation[conversationID] = AwaitingReplyState(
            participantName: participantName,
            reason: reason,
            isStale: false
        )
        armAwaitingReplyTimeout(for: conversationID)
    }

    private func stopAwaitingReply(for conversationID: Int) {
        awaitingReplyTasks[conversationID]?.cancel()
        awaitingReplyTasks.removeValue(forKey: conversationID)
        awaitingReplyByConversation.removeValue(forKey: conversationID)
    }

    private func stopAwaitingReply() {
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

    private func refreshServerState(reconnectRealtime: Bool) async {
        do {
            let updated = try await service.getSimulation(simulationID: simulation.id)
            applySimulation(updated)

            let conversationIDs = Set(awaitingReplyByConversation.keys)
            for conversationID in conversationIDs {
                await loadInitialMessages(conversationID: conversationID)
                if var awaiting = awaitingReplyByConversation[conversationID], awaiting.isStale {
                    awaiting.isStale = false
                    awaitingReplyByConversation[conversationID] = awaiting
                    armAwaitingReplyTimeout(for: conversationID)
                }
            }

            if reconnectRealtime {
                realtimeClient.disconnect()
                await realtimeClient.connect(simulationID: simulation.id, cursor: nil)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
              conversationHasAIMessage(conversationID: patientConversation.id) == false else {
            return
        }
        if forceRestart == false,
           case .initialGeneration? = awaitingReplyByConversation[patientConversation.id]?.reason {
            return
        }
        startAwaitingReply(
            for: patientConversation.id,
            participantName: patientConversation.displayName,
            reason: .initialGeneration
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
}
