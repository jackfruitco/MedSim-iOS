import Foundation
import Networking
import Realtime
import Sessions
import SharedModels
import XCTest

private enum SessionHubMockError: Error {
    case unused
}

private final class MockSessionHubService: TrainerLabServiceProtocol, @unchecked Sendable {
    var listSessionsCalls: [(limit: Int, cursor: String?, status: String?, query: String?)] = []
    var listSessionsResults: [PaginatedResponse<TrainerSessionDTO>] = []
    var listSessionsResult = PaginatedResponse<TrainerSessionDTO>(items: [], nextCursor: nil, hasMore: false)
    var listSessionsError: Error?
    var listSessionsDelayNanoseconds: UInt64 = 0

    func listSessions(limit: Int, cursor: String?, status: String?, query: String?) async throws -> PaginatedResponse<TrainerSessionDTO> {
        listSessionsCalls.append((limit: limit, cursor: cursor, status: status, query: query))
        if listSessionsDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: listSessionsDelayNanoseconds)
        }
        if let listSessionsError {
            throw listSessionsError
        }
        if !listSessionsResults.isEmpty {
            return listSessionsResults.removeFirst()
        }
        return listSessionsResult
    }

    func accessMe() async throws -> LabAccess {
        throw SessionHubMockError.unused
    }

    func createSession(request _: TrainerSessionCreateRequest, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw SessionHubMockError.unused
    }

    func getSession(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw SessionHubMockError.unused
    }

    func retryInitialSimulation(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw SessionHubMockError.unused
    }

    func getRuntimeState(simulationID _: Int) async throws -> TrainerRestViewModelDTO {
        throw SessionHubMockError.unused
    }

    func getControlPlaneDebug(simulationID _: Int) async throws -> ControlPlaneDebugOut {
        throw SessionHubMockError.unused
    }

    func runCommand(simulationID _: Int, command _: RunCommand, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw SessionHubMockError.unused
    }

    func triggerRunTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func triggerVitalsTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<EventEnvelope> {
        throw SessionHubMockError.unused
    }

    func getRunSummary(simulationID _: Int) async throws -> RunSummary {
        throw SessionHubMockError.unused
    }

    func adjustSimulation(simulationID _: Int, request _: SimulationAdjustRequest, idempotencyKey _: String) async throws -> SimulationAdjustAck {
        throw SessionHubMockError.unused
    }

    func steerPrompt(simulationID _: Int, request _: SteerPromptRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func injectInjuryEvent(simulationID _: Int, request _: InjuryEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func injectIllnessEvent(simulationID _: Int, request _: IllnessEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func createProblem(simulationID _: Int, request _: ProblemCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func createAssessmentFinding(simulationID _: Int, request _: AssessmentFindingCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func createDiagnosticResult(simulationID _: Int, request _: DiagnosticResultCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func createResourceState(simulationID _: Int, request _: ResourceStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func createDispositionState(simulationID _: Int, request _: DispositionStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func injectVitalEvent(simulationID _: Int, request _: VitalEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func injectInterventionEvent(simulationID _: Int, request _: InterventionEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func listPresets(limit _: Int, cursor _: String?) async throws -> PaginatedResponse<ScenarioInstruction> {
        throw SessionHubMockError.unused
    }

    func createPreset(request _: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction {
        throw SessionHubMockError.unused
    }

    func getPreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw SessionHubMockError.unused
    }

    func updatePreset(presetID _: Int, request _: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction {
        throw SessionHubMockError.unused
    }

    func deletePreset(presetID _: Int) async throws {
        throw SessionHubMockError.unused
    }

    func duplicatePreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw SessionHubMockError.unused
    }

    func sharePreset(presetID _: Int, request _: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission {
        throw SessionHubMockError.unused
    }

    func unsharePreset(presetID _: Int, request _: ScenarioInstructionUnshareRequest) async throws {
        throw SessionHubMockError.unused
    }

    func applyPreset(presetID _: Int, request _: ScenarioInstructionApplyRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func injuryDictionary() async throws -> InjuryDictionary {
        throw SessionHubMockError.unused
    }

    func interventionDictionary() async throws -> [InterventionGroup] {
        throw SessionHubMockError.unused
    }

    func listAccounts(query _: String, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<AccountListUser> {
        throw SessionHubMockError.unused
    }

    func updateProblemStatus(simulationID _: Int, problemID _: Int, request _: ProblemStatusUpdateRequest, idempotencyKey _: String) async throws -> ProblemStatusOut {
        throw SessionHubMockError.unused
    }

    func createNoteEvent(simulationID _: Int, request _: SimulationNoteCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SessionHubMockError.unused
    }

    func createAnnotation(simulationID _: Int, request _: AnnotationCreateRequest, idempotencyKey _: String) async throws -> AnnotationOut {
        throw SessionHubMockError.unused
    }

    func listAnnotations(simulationID _: Int) async throws -> [AnnotationOut] {
        throw SessionHubMockError.unused
    }

    func updateScenarioBrief(simulationID _: Int, request _: ScenarioBriefUpdateRequest, idempotencyKey _: String) async throws -> ScenarioBriefOut {
        throw SessionHubMockError.unused
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        throw SessionHubMockError.unused
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        throw SessionHubMockError.unused
    }

    func replayPending(endpoint _: String, method _: String, body _: Data?, idempotencyKey _: String) async throws {
        throw SessionHubMockError.unused
    }
}

private final class MockHubRealtimeClient: TrainerLabHubRealtimeClientProtocol, @unchecked Sendable {
    let events: AsyncStream<TrainerLabHubEvent>
    let transportStates: AsyncStream<RealtimeTransportState>
    let failures: AsyncStream<TrainerLabHubRealtimeFailure>

    private(set) var connectCalls: [(cursor: String?, replay: Bool)] = []
    private(set) var disconnectCallCount = 0

    private let eventContinuation: AsyncStream<TrainerLabHubEvent>.Continuation
    private let stateContinuation: AsyncStream<RealtimeTransportState>.Continuation
    private let failureContinuation: AsyncStream<TrainerLabHubRealtimeFailure>.Continuation

    init() {
        var eventCont: AsyncStream<TrainerLabHubEvent>.Continuation!
        events = AsyncStream { continuation in
            eventCont = continuation
        }
        eventContinuation = eventCont

        var stateCont: AsyncStream<RealtimeTransportState>.Continuation!
        transportStates = AsyncStream { continuation in
            stateCont = continuation
            continuation.yield(.disconnected)
        }
        stateContinuation = stateCont

        var failureCont: AsyncStream<TrainerLabHubRealtimeFailure>.Continuation!
        failures = AsyncStream { continuation in
            failureCont = continuation
        }
        failureContinuation = failureCont
    }

    func connect(cursor: String?, replay: Bool) async {
        connectCalls.append((cursor: cursor, replay: replay))
        stateContinuation.yield(.connecting)
        stateContinuation.yield(.connectedSSE)
    }

    func disconnect() {
        disconnectCallCount += 1
        stateContinuation.yield(.disconnected)
    }

    func emit(event: TrainerLabHubEvent) {
        eventContinuation.yield(event)
    }

    func emit(state: RealtimeTransportState) {
        stateContinuation.yield(state)
    }

    func emit(failure: TrainerLabHubRealtimeFailure) {
        failureContinuation.yield(failure)
    }
}

@MainActor
final class SessionHubViewModelTests: XCTestCase {
    func testLoadSessionsPopulatesSessions() async {
        let service = MockSessionHubService()
        let loaded = session(simulationID: 99, status: .seeded)
        service.listSessionsResult = page(items: [loaded])
        let viewModel = SessionHubViewModel(service: service)

        await viewModel.loadSessions()

        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertEqual(viewModel.sessions.first?.simulationID, loaded.simulationID)
        XCTAssertEqual(service.listSessionsCalls.count, 1)
    }

    func testLoadSessionsReplacesStaleData() async {
        let service = MockSessionHubService()
        service.listSessionsResults = [
            page(items: [session(simulationID: 1, status: .seeded)]),
            page(items: [session(simulationID: 2, status: .running)]),
        ]
        let viewModel = SessionHubViewModel(service: service)

        await viewModel.loadSessions()
        XCTAssertEqual(viewModel.sessions.first?.simulationID, 1)

        await viewModel.loadSessions()

        XCTAssertEqual(viewModel.sessions.count, 1)
        XCTAssertEqual(viewModel.sessions.first?.simulationID, 2)
    }

    func testLoadSessionsIsLoadingFalseAfterSuccess() async {
        let service = MockSessionHubService()
        let viewModel = SessionHubViewModel(service: service)

        await viewModel.loadSessions()

        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadSessionsSetsErrorOnFailure() async {
        let service = MockSessionHubService()
        service.listSessionsError = NSError(domain: "test", code: 42)
        let viewModel = SessionHubViewModel(service: service)

        await viewModel.loadSessions()

        XCTAssertNotNil(viewModel.presentableError)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadSessionsClearsErrorBeforeRetry() async {
        let service = MockSessionHubService()
        service.listSessionsError = NSError(domain: "test", code: 1)
        let viewModel = SessionHubViewModel(service: service)
        await viewModel.loadSessions()
        XCTAssertNotNil(viewModel.presentableError)

        service.listSessionsError = nil
        service.listSessionsResult = page(items: [])
        await viewModel.loadSessions()

        XCTAssertNil(viewModel.presentableError)
    }

    func testStartLiveUpdatesConnectsHubStreamOnce() async {
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(
            service: MockSessionHubService(),
            hubRealtimeClient: realtime,
        )

        await viewModel.startLiveUpdates()
        await viewModel.startLiveUpdates()

        XCTAssertEqual(realtime.connectCalls.count, 1)
        XCTAssertNil(realtime.connectCalls.first?.cursor)
        XCTAssertEqual(realtime.connectCalls.first?.replay, false)
        viewModel.stopLiveUpdates()
    }

    func testStopLiveUpdatesDisconnectsAndCancelsTasks() async {
        let service = MockSessionHubService()
        service.listSessionsResults = [page(items: [session(simulationID: 420, status: .running)])]
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(service: service, hubRealtimeClient: realtime)
        await viewModel.loadSessions()
        await viewModel.startLiveUpdates()

        viewModel.stopLiveUpdates()
        realtime.emit(event: hubEvent(eventID: "event-after-stop", simulationID: 420, status: .failed))
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(realtime.disconnectCallCount, 1)
        XCTAssertFalse(viewModel.isRealtimeConnected)
        XCTAssertEqual(viewModel.sessions.first?.status, .running)
    }

    func testIncomingStatusEventUpdatesExistingSessionInPlace() async {
        let service = MockSessionHubService()
        let initial = Date(timeIntervalSince1970: 100)
        let updated = Date(timeIntervalSince1970: 200)
        service.listSessionsResults = [
            page(items: [session(simulationID: 420, status: .seeded, modifiedAt: initial)]),
        ]
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(service: service, hubRealtimeClient: realtime)
        await viewModel.loadSessions()
        await viewModel.startLiveUpdates()

        realtime.emit(event: hubEvent(
            eventID: "hub-1",
            simulationID: 420,
            status: .running,
            updatedAt: updated,
        ))

        await waitUntil {
            viewModel.sessions.first?.status == .running
        }

        XCTAssertEqual(viewModel.lastEventCursor, "hub-1")
        XCTAssertEqual(viewModel.sessions.first?.modifiedAt, updated)
        XCTAssertEqual(service.listSessionsCalls.count, 1)
        viewModel.stopLiveUpdates()
    }

    func testUnknownSimulationIDTriggersAuthoritativeReload() async {
        let service = MockSessionHubService()
        service.listSessionsResults = [
            page(items: [session(simulationID: 420, status: .running)]),
            page(items: [session(simulationID: 777, status: .seeding)]),
        ]
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(service: service, hubRealtimeClient: realtime)
        await viewModel.loadSessions()
        await viewModel.startLiveUpdates()

        realtime.emit(event: hubEvent(eventID: "hub-unknown", simulationID: 777, status: .seeding))

        await waitUntil {
            service.listSessionsCalls.count == 2
        }

        XCTAssertEqual(viewModel.sessions.map(\.simulationID), [777])
        XCTAssertEqual(viewModel.lastEventCursor, "hub-unknown")
        viewModel.stopLiveUpdates()
    }

    func testStaleCursorClearsCursorReloadsAndReconnectsTailOnly() async {
        let service = MockSessionHubService()
        service.listSessionsResults = [
            page(items: [session(simulationID: 420, status: .running)]),
            page(items: [session(simulationID: 420, status: .paused)]),
        ]
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(service: service, hubRealtimeClient: realtime)
        await viewModel.loadSessions()
        await viewModel.startLiveUpdates()
        realtime.emit(event: hubEvent(eventID: "hub-1", simulationID: 420, status: .running))
        await waitUntil {
            viewModel.lastEventCursor == "hub-1"
        }

        realtime.emit(failure: .staleCursor)

        await waitUntil {
            service.listSessionsCalls.count == 2 && realtime.connectCalls.count == 2
        }

        XCTAssertNil(viewModel.lastEventCursor)
        XCTAssertNil(realtime.connectCalls.last?.cursor)
        XCTAssertEqual(realtime.connectCalls.last?.replay, false)
        XCTAssertEqual(viewModel.sessions.first?.status, .paused)
        viewModel.stopLiveUpdates()
    }

    func testDecodeFailurePreservesCursorReloadsAndReconnectsWithCursor() async {
        let service = MockSessionHubService()
        service.listSessionsResults = [
            page(items: [session(simulationID: 420, status: .running)]),
            page(items: [session(simulationID: 420, status: .paused)]),
        ]
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(service: service, hubRealtimeClient: realtime)
        await viewModel.loadSessions()
        await viewModel.startLiveUpdates()
        realtime.emit(event: hubEvent(eventID: "hub-1", simulationID: 420, status: .running))
        await waitUntil {
            viewModel.lastEventCursor == "hub-1"
        }

        realtime.emit(failure: .decodeFailed)

        await waitUntil {
            service.listSessionsCalls.count == 2 && realtime.connectCalls.count == 2
        }

        XCTAssertEqual(viewModel.lastEventCursor, "hub-1")
        XCTAssertEqual(realtime.connectCalls.last?.cursor, "hub-1")
        XCTAssertEqual(realtime.connectCalls.last?.replay, false)
        XCTAssertEqual(viewModel.sessions.first?.status, .paused)
        viewModel.stopLiveUpdates()
    }

    func testTransportStateReconnectingMarksRealtimeDisconnected() async {
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(
            service: MockSessionHubService(),
            hubRealtimeClient: realtime,
        )

        await viewModel.startLiveUpdates()
        await waitUntil {
            viewModel.isRealtimeConnected
        }

        realtime.emit(state: .reconnecting(1))

        await waitUntil {
            !viewModel.isRealtimeConnected
        }
        viewModel.stopLiveUpdates()
    }

    func testLoadSessionsIsIgnoredWhileLoadingMore() async {
        let service = MockSessionHubService()
        service.listSessionsResults = [
            page(items: [session(simulationID: 420, status: .running)], nextCursor: "page-2", hasMore: true),
            page(items: [session(simulationID: 421, status: .paused)]),
            page(items: [session(simulationID: 999, status: .failed)]),
        ]
        let viewModel = SessionHubViewModel(service: service)
        await viewModel.loadSessions()

        service.listSessionsDelayNanoseconds = 300_000_000
        let loadMoreTask = Task {
            await viewModel.loadMoreSessions()
        }
        await waitUntil {
            viewModel.isLoadingMore
        }

        await viewModel.loadSessions()

        XCTAssertEqual(service.listSessionsCalls.count, 2)
        await loadMoreTask.value
        XCTAssertEqual(service.listSessionsCalls.count, 2)
    }

    func testLiveUpdatePreservesActiveSearchFiltering() async {
        let service = MockSessionHubService()
        service.listSessionsResults = [
            page(items: [session(simulationID: 420, status: .running)]),
            page(items: [session(simulationID: 420, status: .running)]),
        ]
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(service: service, hubRealtimeClient: realtime)
        viewModel.searchQuery = "shock"
        await viewModel.loadSessions()
        await viewModel.startLiveUpdates()

        realtime.emit(event: hubEvent(eventID: "hub-filtered-out", simulationID: 999, status: .running))

        await waitUntil {
            service.listSessionsCalls.count == 2
        }

        XCTAssertEqual(service.listSessionsCalls.map(\.query), ["shock", "shock"])
        XCTAssertEqual(viewModel.sessions.map(\.simulationID), [420])
        viewModel.stopLiveUpdates()
    }

    func testResetForAccountChangeStopsRealtimeAndClearsCursor() async {
        let service = MockSessionHubService()
        service.listSessionsResults = [page(items: [session(simulationID: 420, status: .running)])]
        let realtime = MockHubRealtimeClient()
        let viewModel = SessionHubViewModel(service: service, hubRealtimeClient: realtime)
        await viewModel.loadSessions()
        await viewModel.startLiveUpdates()
        realtime.emit(event: hubEvent(eventID: "hub-1", simulationID: 420, status: .paused))
        await waitUntil {
            viewModel.lastEventCursor == "hub-1"
        }

        viewModel.resetForAccountChange()

        XCTAssertNil(viewModel.lastEventCursor)
        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertEqual(realtime.disconnectCallCount, 1)
        XCTAssertFalse(viewModel.isRealtimeConnected)
    }

    private func page(
        items: [TrainerSessionDTO],
        nextCursor: String? = nil,
        hasMore: Bool = false,
    ) -> PaginatedResponse<TrainerSessionDTO> {
        PaginatedResponse(items: items, nextCursor: nextCursor, hasMore: hasMore)
    }

    private func session(
        simulationID: Int,
        status: TrainerSessionStatus,
        modifiedAt: Date = Date(timeIntervalSince1970: 100),
    ) -> TrainerSessionDTO {
        TrainerSessionDTO(
            simulationID: simulationID,
            status: status,
            scenarioSpec: [:],
            runtimeState: [:],
            initialDirectives: nil,
            tickIntervalSeconds: 15,
            runStartedAt: nil,
            runPausedAt: nil,
            runCompletedAt: nil,
            lastAITickAt: nil,
            createdAt: Date(timeIntervalSince1970: 50),
            modifiedAt: modifiedAt,
        )
    }

    private func hubEvent(
        eventID: String,
        simulationID: Int,
        status: TrainerSessionStatus,
        updatedAt: Date = Date(timeIntervalSince1970: 200),
    ) -> TrainerLabHubEvent {
        TrainerLabHubEvent(
            eventID: eventID,
            eventType: "simulation.status.updated",
            createdAt: updatedAt,
            simulationID: simulationID,
            status: status,
            to: status,
            updatedAt: updatedAt,
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 1.5,
        condition: @escaping @MainActor () -> Bool,
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }
}
