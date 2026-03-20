import Foundation
import Networking
import Persistence
import Realtime
import Sessions
import SharedModels
import XCTest

private enum MockServiceError: Error {
    case unused
}

private struct ReplayPendingCall: Equatable {
    let endpoint: String
    let method: String
    let body: Data?
    let idempotencyKey: String
}

private final class MockTrainerLabService: TrainerLabServiceProtocol, @unchecked Sendable {
    var getSessionCalls: [Int] = []
    var getSessionResult: Result<TrainerSessionDTO, Error> = .failure(MockServiceError.unused)
    var retryInitialCalls: [Int] = []
    var retryInitialResult: Result<TrainerSessionDTO, Error> = .failure(MockServiceError.unused)
    var getRuntimeStateCalls: [Int] = []
    var getRuntimeStateResult: Result<TrainerRuntimeStateOut, Error> = .failure(MockServiceError.unused)
    var listAnnotationsCalls: [Int] = []
    var listAnnotationsResult: Result<[AnnotationOut], Error> = .failure(MockServiceError.unused)
    var replayPendingCalls: [ReplayPendingCall] = []
    var replayPendingErrorByEndpoint: [String: Error] = [:]
    var runCommandCalls: [(simulationID: Int, command: RunCommand)] = []
    var runCommandResult: Result<TrainerSessionDTO, Error> = .failure(MockServiceError.unused)
    var injectInterventionCalls: [InterventionEventRequest] = []
    var injectInterventionResult: Result<TrainerCommandAck, Error> = .failure(MockServiceError.unused)

    func accessMe() async throws -> LabAccess {
        throw MockServiceError.unused
    }

    func listSessions(limit _: Int, cursor _: String?, status _: String?, query _: String?) async throws -> PaginatedResponse<TrainerSessionDTO> {
        throw MockServiceError.unused
    }

    func createSession(request _: TrainerSessionCreateRequest, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw MockServiceError.unused
    }

    func getSession(simulationID: Int) async throws -> TrainerSessionDTO {
        getSessionCalls.append(simulationID)
        return try getSessionResult.get()
    }

    func retryInitialSimulation(simulationID: Int) async throws -> TrainerSessionDTO {
        retryInitialCalls.append(simulationID)
        return try retryInitialResult.get()
    }

    func getRuntimeState(simulationID: Int) async throws -> TrainerRuntimeStateOut {
        getRuntimeStateCalls.append(simulationID)
        return try getRuntimeStateResult.get()
    }

    func getControlPlaneDebug(simulationID _: Int) async throws -> ControlPlaneDebugOut {
        throw MockServiceError.unused
    }

    func runCommand(simulationID: Int, command: RunCommand, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        runCommandCalls.append((simulationID: simulationID, command: command))
        return try runCommandResult.get()
    }

    func triggerRunTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func triggerVitalsTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<EventEnvelope> {
        throw MockServiceError.unused
    }

    func getRunSummary(simulationID _: Int) async throws -> RunSummary {
        throw MockServiceError.unused
    }

    func adjustSimulation(simulationID _: Int, request _: SimulationAdjustRequest, idempotencyKey _: String) async throws -> SimulationAdjustAck {
        throw MockServiceError.unused
    }

    func steerPrompt(simulationID _: Int, request _: SteerPromptRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func injectInjuryEvent(simulationID _: Int, request _: InjuryEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func injectIllnessEvent(simulationID _: Int, request _: IllnessEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func createProblem(simulationID _: Int, request _: ProblemCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func createAssessmentFinding(simulationID _: Int, request _: AssessmentFindingCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func createDiagnosticResult(simulationID _: Int, request _: DiagnosticResultCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func createResourceState(simulationID _: Int, request _: ResourceStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func createDispositionState(simulationID _: Int, request _: DispositionStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func injectVitalEvent(simulationID _: Int, request _: VitalEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func injectInterventionEvent(simulationID _: Int, request: InterventionEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        injectInterventionCalls.append(request)
        return try injectInterventionResult.get()
    }

    func listPresets(limit _: Int, cursor _: String?) async throws -> PaginatedResponse<ScenarioInstruction> {
        throw MockServiceError.unused
    }

    func createPreset(request _: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction {
        throw MockServiceError.unused
    }

    func getPreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw MockServiceError.unused
    }

    func updatePreset(presetID _: Int, request _: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction {
        throw MockServiceError.unused
    }

    func deletePreset(presetID _: Int) async throws {
        throw MockServiceError.unused
    }

    func duplicatePreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw MockServiceError.unused
    }

    func sharePreset(presetID _: Int, request _: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission {
        throw MockServiceError.unused
    }

    func unsharePreset(presetID _: Int, request _: ScenarioInstructionUnshareRequest) async throws {
        throw MockServiceError.unused
    }

    func applyPreset(presetID _: Int, request _: ScenarioInstructionApplyRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func injuryDictionary() async throws -> InjuryDictionary {
        throw MockServiceError.unused
    }

    func interventionDictionary() async throws -> [InterventionGroup] {
        throw MockServiceError.unused
    }

    func listAccounts(query _: String, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<AccountListUser> {
        throw MockServiceError.unused
    }

    func updateProblemStatus(simulationID _: Int, problemID _: Int, request _: ProblemStatusUpdateRequest, idempotencyKey _: String) async throws -> ProblemStatusOut {
        throw MockServiceError.unused
    }

    func createNoteEvent(simulationID _: Int, request _: SimulationNoteCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
    }

    func createAnnotation(simulationID _: Int, request _: AnnotationCreateRequest, idempotencyKey _: String) async throws -> AnnotationOut {
        throw MockServiceError.unused
    }

    func listAnnotations(simulationID: Int) async throws -> [AnnotationOut] {
        listAnnotationsCalls.append(simulationID)
        return try listAnnotationsResult.get()
    }

    func updateScenarioBrief(simulationID _: Int, request _: ScenarioBriefUpdateRequest, idempotencyKey _: String) async throws -> ScenarioBriefOut {
        throw MockServiceError.unused
    }

    func replayPending(endpoint: String, method: String, body: Data?, idempotencyKey: String) async throws {
        replayPendingCalls.append(ReplayPendingCall(endpoint: endpoint, method: method, body: body, idempotencyKey: idempotencyKey))
        if let error = replayPendingErrorByEndpoint[endpoint] {
            throw error
        }
    }
}

private final class MockRealtimeClient: RealtimeClientProtocol, @unchecked Sendable {
    let events: AsyncStream<EventEnvelope>
    let transportStates: AsyncStream<RealtimeTransportState>

    private let eventContinuation: AsyncStream<EventEnvelope>.Continuation
    private let stateContinuation: AsyncStream<RealtimeTransportState>.Continuation

    init() {
        var eventCont: AsyncStream<EventEnvelope>.Continuation!
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
    }

    func connect(simulationID _: Int, cursor _: String?) async {
        stateContinuation.yield(.connecting)
        stateContinuation.yield(.connectedSSE)
    }

    func disconnect() {
        stateContinuation.yield(.disconnected)
        eventContinuation.finish()
        stateContinuation.finish()
    }

    func emit(event: EventEnvelope) {
        eventContinuation.yield(event)
    }

    func emit(transport: RealtimeTransportState) {
        stateContinuation.yield(transport)
    }
}

@MainActor
final class RunSessionStoreTests: XCTestCase {
    func testUnifiedTimelineDedupesDuplicateRuntimeEvents() async {
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore()
        )
        store.bind(session: makeSession(status: .seeded))
        store.startConsole()
        defer { store.stopConsole() }

        let event = EventEnvelope(
            eventID: "event-dup-1",
            eventType: "trainerlab.adjustment.applied",
            createdAt: Date(),
            correlationID: "corr-1",
            payload: ["target": .string("avpu")]
        )

        realtime.emit(event: event)
        realtime.emit(event: event)

        await waitUntil(timeout: 1.5) {
            store.state.clinicalTimelineEntries.count == 1
        }

        XCTAssertEqual(store.state.clinicalTimelineEntries.count, 1)
        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.title, "LOC Change")
        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.kind, .loc)
    }

    func testVitalEventsDoNotCreateClinicalTimelineEntries() async {
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore()
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        realtime.emit(event: EventEnvelope(
            eventID: "vital-1",
            eventType: "vital.created",
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "vital_type": .string("heart_rate"),
                "min_value": .number(80),
                "max_value": .number(140),
            ]
        ))

        await waitUntil(timeout: 1.5) {
            store.state.vitals.count == 1
        }

        XCTAssertTrue(store.state.clinicalTimelineEntries.isEmpty)
    }

    func testStopwatchTracksRunLifecycleTransitions() async throws {
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore()
        )
        store.bind(session: makeSession(status: .seeded))
        store.startConsole()
        defer { store.stopConsole() }

        realtime.emit(event: EventEnvelope(
            eventID: "run-1",
            eventType: "run.started",
            createdAt: Date(),
            correlationID: nil,
            payload: [:]
        ))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .running && store.state.stopwatchIsRunning
        }

        await waitUntil(timeout: 2.5) {
            store.state.stopwatchElapsedSeconds >= 1
        }
        let elapsedAfterStart = store.state.stopwatchElapsedSeconds
        XCTAssertGreaterThanOrEqual(elapsedAfterStart, 1)

        realtime.emit(event: EventEnvelope(
            eventID: "run-2",
            eventType: "run.paused",
            createdAt: Date(),
            correlationID: nil,
            payload: [:]
        ))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .paused && !store.state.stopwatchIsRunning
        }

        let pausedElapsed = store.state.stopwatchElapsedSeconds
        try await Task.sleep(nanoseconds: 1_300_000_000)
        XCTAssertEqual(store.state.stopwatchElapsedSeconds, pausedElapsed)

        realtime.emit(event: EventEnvelope(
            eventID: "run-3",
            eventType: "trainerlab.run.resumed",
            createdAt: Date(),
            correlationID: nil,
            payload: [:]
        ))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .running && store.state.stopwatchIsRunning
        }

        await waitUntil(timeout: 2.5) {
            store.state.stopwatchElapsedSeconds > pausedElapsed
        }
        XCTAssertGreaterThan(store.state.stopwatchElapsedSeconds, pausedElapsed)
    }

    func testPollingFallbackDisablesCommandChannelWithoutAutoPause() async throws {
        let realtime = MockRealtimeClient()
        let queue = InMemoryCommandQueueStore()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: queue
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.commandChannelAvailable
        }

        realtime.emit(transport: .polling)

        await waitUntil(timeout: 1.5) {
            !store.state.commandChannelAvailable && store.state.transportBanner.message == "Polling Fallback"
        }

        let pending = try await queue.pendingCount(simulationID: 420)
        XCTAssertEqual(pending, 0)
    }

    func testTrainerNotesAreAddedToClinicalTimelineImmediately() {
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: MockRealtimeClient(),
            commandQueue: InMemoryCommandQueueStore()
        )

        store.addTrainerNote("Patient became more agitated after intervention.")

        XCTAssertEqual(store.state.clinicalTimelineEntries.count, 1)
        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.title, "Trainer Note")
        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.kind, .note)
        XCTAssertEqual(
            store.state.clinicalTimelineEntries.first?.message,
            "Patient became more agitated after intervention."
        )
    }

    func testSimulationStateChangedFailureTransitionsSessionToFailed() async {
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore()
        )
        store.bind(session: makeSession(status: .running, runStartedAt: Date().addingTimeInterval(-12)))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.stopwatchIsRunning
        }

        realtime.emit(event: makeSimulationStateChangedEvent(
            payload: SimulationStateChangedPayload(
                status: "failed",
                retryable: true,
                terminalAt: Date(),
                simulationID: 420,
                terminalReasonCode: "trainerlab_initial_generation_enqueue_failed",
                terminalReasonText: "We could not start this simulation. Please try again."
            )
        ))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .failed &&
                store.state.terminalCard?.reasonText == "We could not start this simulation. Please try again." &&
                store.state.session?.retryable == true &&
                store.state.stopwatchIsRunning == false
        }

        XCTAssertEqual(store.state.session?.terminalReasonCode, "trainerlab_initial_generation_enqueue_failed")
        XCTAssertEqual(store.state.terminalCard?.status, .failed)
    }

    func testSimulationStateChangedIgnoresMismatchedSimulationID() async {
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore()
        )
        store.bind(session: makeSession(status: .running, runStartedAt: Date().addingTimeInterval(-6)))
        store.startConsole()
        defer { store.stopConsole() }

        realtime.emit(event: makeSimulationStateChangedEvent(
            payload: SimulationStateChangedPayload(
                status: "failed",
                retryable: true,
                terminalAt: Date(),
                simulationID: 999,
                terminalReasonCode: "trainerlab_initial_generation_enqueue_failed",
                terminalReasonText: "Should be ignored."
            )
        ))

        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(store.state.session?.status, .running)
        XCTAssertNil(store.state.terminalCard)
    }

    func testRetryInitialSimulationRebindsSessionAfterFailure() async {
        let service = MockTrainerLabService()
        service.retryInitialResult = .success(makeSession(status: .seeded))
        let store = RunSessionStore(
            service: service,
            realtimeClient: MockRealtimeClient(),
            commandQueue: InMemoryCommandQueueStore()
        )
        store.bind(session: makeSession(
            status: .failed,
            runCompletedAt: Date(),
            terminalReasonCode: "trainerlab_initial_generation_enqueue_failed",
            terminalReasonText: "We could not start this simulation. Please try again.",
            retryable: true
        ))

        XCTAssertEqual(store.state.terminalCard?.status, .failed)

        store.retryInitialSimulation()

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .seeded && store.state.terminalCard == nil
        }

        XCTAssertEqual(service.retryInitialCalls, [420])
        XCTAssertNil(store.state.conflictBanner)
    }

    func testRunAndInterventionMutationsAreBlockedWhileSeeding() async {
        let service = MockTrainerLabService()
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore()
        )
        store.bind(session: makeSession(status: .seeding))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.commandChannelAvailable
        }

        store.start()
        store.addIntervention(
            interventionType: "tourniquet",
            siteCode: "LEFT_ARM",
            targetProblemID: 99
        )

        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertTrue(service.runCommandCalls.isEmpty)
        XCTAssertTrue(service.injectInterventionCalls.isEmpty)
    }

    func testReplayPendingCommandsOnlyReplaysRowsForBoundSimulation() async throws {
        let service = MockTrainerLabService()
        let queue = InMemoryCommandQueueStore()
        let store = RunSessionStore(
            service: service,
            realtimeClient: MockRealtimeClient(),
            commandQueue: queue
        )
        store.bind(session: makeSession(status: .seeded))

        let matching = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420
        )
        let otherSimulation = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 421
        )
        let legacyMatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil
        )
        let legacyMismatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil
        )

        try await queue.enqueue(matching)
        try await queue.enqueue(otherSimulation)
        try await queue.enqueue(legacyMatch)
        try await queue.enqueue(legacyMismatch)

        await store.replayPendingCommands()

        XCTAssertEqual(
            service.replayPendingCalls.map(\.endpoint),
            [matching.endpoint, legacyMatch.endpoint]
        )
        let pendingCount = try await queue.pendingCount(simulationID: 420)
        let remainingEndpoints = try await queue.nextRetryBatch(limit: 10, now: .distantFuture, simulationID: 420)
            .map(\.endpoint)
        XCTAssertEqual(pendingCount, 0)
        XCTAssertEqual(remainingEndpoints, [legacyMismatch.endpoint])
    }

    func testReplayPendingCommandsTreatsTerminalHTTPFailuresAsNonRetryable() async throws {
        let service = MockTrainerLabService()
        let queue = InMemoryCommandQueueStore()
        let store = RunSessionStore(
            service: service,
            realtimeClient: MockRealtimeClient(),
            commandQueue: queue
        )
        store.bind(session: makeSession(status: .seeded))

        let envelope = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420
        )
        try await queue.enqueue(envelope)
        service.replayPendingErrorByEndpoint[envelope.endpoint] = APIClientError.http(
            statusCode: 404,
            detail: "Not ready",
            correlationID: nil
        )

        await store.replayPendingCommands()

        let pendingCount = try await queue.pendingCount(simulationID: 420)
        let retryBatch = try await queue.nextRetryBatch(limit: 10, now: .distantFuture, simulationID: 420)
        XCTAssertEqual(pendingCount, 0)
        XCTAssertTrue(retryBatch.isEmpty)
    }

    func testStartConsoleScopesPendingCountToBoundSimulation() async throws {
        let queue = InMemoryCommandQueueStore()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: MockRealtimeClient(),
            commandQueue: queue
        )

        var matching = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420
        )
        matching.nextRetryAt = .distantFuture

        var legacyMatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil
        )
        legacyMatch.nextRetryAt = .distantFuture

        var persistedMismatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 421
        )
        persistedMismatch.nextRetryAt = .distantFuture

        var legacyMismatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil
        )
        legacyMismatch.nextRetryAt = .distantFuture

        var terminalMatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/stop/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420
        )
        terminalMatch.retryCount = terminalMatch.maxRetries
        terminalMatch.nextRetryAt = .distantFuture

        try await queue.enqueue(matching)
        try await queue.enqueue(legacyMatch)
        try await queue.enqueue(persistedMismatch)
        try await queue.enqueue(legacyMismatch)
        try await queue.enqueue(terminalMatch)

        store.bind(session: makeSession(status: .seeded))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.pendingCommandCount == 2
        }

        XCTAssertEqual(store.state.pendingCommandCount, 2)
    }

    func testSessionSeededEventRefreshesBoundState() async throws {
        let service = MockTrainerLabService()
        service.getSessionResult = .success(makeSession(status: .seeded))
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "seeded"))
        service.listAnnotationsResult = .success([])

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore()
        )
        store.bind(session: makeSession(status: .seeding))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.commandChannelAvailable
        }
        let runtimeCallsBefore = service.getRuntimeStateCalls.count
        let annotationCallsBefore = service.listAnnotationsCalls.count

        realtime.emit(event: makeSessionSeededEvent(simulationID: 420))

        await waitUntil(timeout: 1.5) {
            service.getSessionCalls == [420]
                && service.getRuntimeStateCalls.count > runtimeCallsBefore
                && service.listAnnotationsCalls.count > annotationCallsBefore
                && store.state.session?.status == .seeded
        }
    }

    private func makeSession(
        status: TrainerSessionStatus,
        runStartedAt: Date? = nil,
        runCompletedAt: Date? = nil,
        terminalReasonCode: String? = nil,
        terminalReasonText: String? = nil,
        retryable: Bool? = nil
    ) -> TrainerSessionDTO {
        TrainerSessionDTO(
            simulationID: 420,
            status: status,
            scenarioSpec: [:],
            runtimeState: [:],
            initialDirectives: nil,
            tickIntervalSeconds: 15,
            runStartedAt: runStartedAt,
            runPausedAt: nil,
            runCompletedAt: runCompletedAt,
            lastAITickAt: nil,
            createdAt: Date(),
            modifiedAt: Date(),
            terminalReasonCode: terminalReasonCode,
            terminalReasonText: terminalReasonText,
            retryable: retryable
        )
    }

    private func makeSimulationStateChangedEvent(
        payload: SimulationStateChangedPayload
    ) -> EventEnvelope {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let terminalAt = payload.terminalAt ?? Date()
        var eventPayload: [String: JSONValue] = [
            "status": .string(payload.status),
            "terminal_at": .string(formatter.string(from: terminalAt)),
        ]

        if let retryable = payload.retryable {
            eventPayload["retryable"] = .bool(retryable)
        }
        if let simulationID = payload.simulationID {
            eventPayload["simulation_id"] = .number(Double(simulationID))
        }
        if let terminalReasonCode = payload.terminalReasonCode {
            eventPayload["terminal_reason_code"] = .string(terminalReasonCode)
        }
        if let terminalReasonText = payload.terminalReasonText {
            eventPayload["terminal_reason_text"] = .string(terminalReasonText)
        }

        return EventEnvelope(
            eventID: UUID().uuidString.lowercased(),
            eventType: "simulation.state_changed",
            createdAt: terminalAt,
            correlationID: nil,
            payload: eventPayload
        )
    }

    private func makeSessionSeededEvent(simulationID: Int?) -> EventEnvelope {
        var payload: [String: JSONValue] = [:]
        if let simulationID {
            payload["simulation_id"] = .number(Double(simulationID))
        }
        return EventEnvelope(
            eventID: UUID().uuidString.lowercased(),
            eventType: "session.seeded",
            createdAt: Date(),
            correlationID: nil,
            payload: payload
        )
    }

    private func makeRuntimeState(status: String) throws -> TrainerRuntimeStateOut {
        let json = """
        {
          "simulation_id": 420,
          "session_id": 420,
          "status": "\(status)",
          "state_revision": 1,
          "active_elapsed_seconds": 0,
          "tick_interval_seconds": 15,
          "next_tick_at": null,
          "scenario_brief": null,
          "current_snapshot": {
            "causes": [],
            "problems": [],
            "recommended_interventions": [],
            "interventions": [],
            "assessment_findings": [],
            "diagnostic_results": [],
            "resources": [],
            "disposition": null,
            "vitals": [],
            "pulses": [],
            "patient_status": {}
          },
          "ai_plan": null,
          "ai_rationale_notes": [],
          "pending_runtime_reasons": [],
          "pending_reasons": [],
          "currently_processing_reasons": [],
          "last_runtime_error": "",
          "last_ai_tick_at": null
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TrainerRuntimeStateOut.self, from: Data(json.utf8))
    }

    private func waitUntil(
        timeout: TimeInterval,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("Condition not met before timeout")
    }
}
