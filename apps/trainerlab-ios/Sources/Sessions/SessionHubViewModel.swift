import Foundation
import Networking
import Realtime
import SharedModels

@MainActor
public final class SessionHubViewModel: ObservableObject {
    @Published public private(set) var sessions: [TrainerSessionDTO] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingMore = false
    @Published public private(set) var hasMore = false
    @Published public private(set) var presentableError: PresentableAppError?
    @Published public private(set) var isRealtimeConnected = false
    @Published public var searchQuery: String = ""

    private var nextCursor: String?
    public private(set) var lastEventCursor: String?
    private let service: TrainerLabServiceProtocol
    private let hubRealtimeClient: TrainerLabHubRealtimeClientProtocol?
    private let accountUUIDProvider: () -> String?
    private var searchDebounceTask: Task<Void, Never>?
    private var hubEventTask: Task<Void, Never>?
    private var hubTransportTask: Task<Void, Never>?
    private var hubFailureTask: Task<Void, Never>?
    private var isLiveUpdatesActive = false
    private var pendingAuthoritativeReloadReason: String?

    public init(
        service: TrainerLabServiceProtocol,
        hubRealtimeClient: TrainerLabHubRealtimeClientProtocol? = nil,
        accountUUIDProvider: @escaping () -> String? = { nil },
    ) {
        self.service = service
        self.hubRealtimeClient = hubRealtimeClient
        self.accountUUIDProvider = accountUUIDProvider
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public func resetForAccountChange() {
        stopLiveUpdates()
        sessions = []
        nextCursor = nil
        lastEventCursor = nil
        hasMore = false
        presentableError = nil
    }

    public func onSearchQueryChanged() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await loadSessions()
        }
    }

    public func loadSessions() async {
        guard !isLoading, !isLoadingMore else { return }
        await performAuthoritativeReload(reason: "manual")
    }

    public func reloadAuthoritativeSessions(reason: String) async {
        if isLoadingMore {
            pendingAuthoritativeReloadReason = reason
            return
        }
        guard !isLoading else { return }
        await performAuthoritativeReload(reason: reason)
    }

    private func performAuthoritativeReload(reason _: String) async {
        isLoading = true
        presentableError = nil
        nextCursor = nil
        defer { isLoading = false }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let response = try await service.listSessions(limit: 50, cursor: nil, status: nil, query: q.isEmpty ? nil : q)
            sessions = response.items
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func loadMoreSessions() async {
        guard hasMore, let cursor = nextCursor, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer {
            isLoadingMore = false
            runPendingAuthoritativeReloadIfNeeded()
        }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let response = try await service.listSessions(limit: 50, cursor: cursor, status: nil, query: q.isEmpty ? nil : q)
            sessions.append(contentsOf: response.items)
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func startLiveUpdates() async {
        guard !isLiveUpdatesActive, let hubRealtimeClient else { return }

        isLiveUpdatesActive = true

        hubEventTask = Task { [weak self] in
            guard let self else { return }
            for await event in hubRealtimeClient.events {
                await handleHubEvent(event)
            }
        }

        hubTransportTask = Task { [weak self] in
            guard let self else { return }
            for await state in hubRealtimeClient.transportStates {
                guard !Task.isCancelled, isLiveUpdatesActive else { break }
                handleTransportState(state)
            }
        }

        hubFailureTask = Task { [weak self] in
            guard let self else { return }
            for await failure in hubRealtimeClient.failures {
                await handleRealtimeFailure(failure)
            }
        }

        await hubRealtimeClient.connect(cursor: lastEventCursor, replay: false)
    }

    public func stopLiveUpdates() {
        isLiveUpdatesActive = false
        hubEventTask?.cancel()
        hubTransportTask?.cancel()
        hubFailureTask?.cancel()
        hubEventTask = nil
        hubTransportTask = nil
        hubFailureTask = nil
        hubRealtimeClient?.disconnect()
        isRealtimeConnected = false
    }

    public func handleHubEvent(_ event: TrainerLabHubEvent) async {
        guard isLiveUpdatesActive else { return }
        lastEventCursor = event.eventID

        guard let index = sessions.firstIndex(where: { $0.simulationID == event.simulationID }) else {
            await reloadAuthoritativeSessions(reason: "hub.unknown_session")
            return
        }

        guard let nextStatus = event.effectiveStatus else {
            await reloadAuthoritativeSessions(reason: "hub.missing_status")
            return
        }

        sessions[index] = applyHubSessionUpdate(session: sessions[index], status: nextStatus, event: event)
    }

    public func applyHubSessionUpdate(
        session: TrainerSessionDTO,
        status: TrainerSessionStatus,
        event: TrainerLabHubEvent,
    ) -> TrainerSessionDTO {
        let isTerminal = status == .completed || status == .failed
        let modifiedAt = [session.modifiedAt, event.updatedAt, event.createdAt]
            .compactMap(\.self)
            .max() ?? session.modifiedAt

        return TrainerSessionDTO(
            simulationID: session.simulationID,
            status: status,
            scenarioSpec: session.scenarioSpec,
            runtimeState: session.runtimeState,
            initialDirectives: session.initialDirectives,
            tickIntervalSeconds: session.tickIntervalSeconds,
            runStartedAt: session.runStartedAt,
            runPausedAt: session.runPausedAt,
            runCompletedAt: session.runCompletedAt,
            lastAITickAt: session.lastAITickAt,
            createdAt: session.createdAt,
            modifiedAt: modifiedAt,
            terminalReasonCode: isTerminal ? event.terminalReasonCode ?? session.terminalReasonCode : nil,
            terminalReasonText: isTerminal ? event.terminalReasonText ?? session.terminalReasonText : nil,
            retryable: isTerminal ? event.retryable ?? session.retryable : nil,
        )
    }

    public func createSession() async {
        isLoading = true
        presentableError = nil
        defer { isLoading = false }

        let request = TrainerSessionCreateRequest(
            scenarioSpec: [
                "diagnosis": .string("Undifferentiated trauma"),
                "chief_complaint": .string("Altered mental status"),
                "tick_interval_seconds": .number(10),
            ],
            directives: "Begin with unstable vitals and evolving airway compromise.",
            modifiers: ["night-ops", "limited-resources"],
        )

        do {
            let idempotencyKey = makeIdempotencyKey(scope: "session.create")
            let session = try await service.createSession(request: request, idempotencyKey: idempotencyKey)
            sessions.insert(session, at: 0)
        } catch {
            presentableError = AppErrorPresenter.present(error)
        }
    }

    private func handleTransportState(_ state: RealtimeTransportState) {
        switch state {
        case .connectedSSE:
            isRealtimeConnected = true
        case .disconnected, .connecting, .polling, .reconnecting:
            isRealtimeConnected = false
        }
    }

    private func handleRealtimeFailure(_ failure: TrainerLabHubRealtimeFailure) async {
        guard isLiveUpdatesActive else { return }
        let reconnectCursor: String?
        switch failure {
        case .staleCursor:
            lastEventCursor = nil
            await reloadAuthoritativeSessions(reason: "hub.stale_cursor")
            reconnectCursor = nil
        case .decodeFailed:
            reconnectCursor = lastEventCursor
            await reloadAuthoritativeSessions(reason: "hub.decode_failed")
        }

        guard isLiveUpdatesActive, let hubRealtimeClient else { return }
        await hubRealtimeClient.connect(cursor: reconnectCursor, replay: false)
    }

    private func runPendingAuthoritativeReloadIfNeeded() {
        guard let reason = pendingAuthoritativeReloadReason else { return }
        pendingAuthoritativeReloadReason = nil
        Task { [weak self] in
            await self?.reloadAuthoritativeSessions(reason: reason)
        }
    }

    private func makeIdempotencyKey(scope: String) -> String {
        let accountFragment = accountUUIDProvider()?
            .split(separator: "-")
            .first
            .map(String.init)
            .flatMap { $0.isEmpty ? nil : $0.lowercased() } ?? "global"
        return "ios.\(scope).\(accountFragment).\(UUID().uuidString.lowercased())"
    }
}
