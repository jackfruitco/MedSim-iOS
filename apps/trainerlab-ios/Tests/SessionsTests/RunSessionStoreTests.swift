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

private final class MockTrainerLabService: TrainerLabServiceProtocol, @unchecked Sendable {
    func accessMe() async throws -> LabAccess {
        throw MockServiceError.unused
    }

    func listSessions(limit _: Int, cursor _: String?, status _: String?, query _: String?) async throws -> PaginatedResponse<TrainerSessionDTO> {
        throw MockServiceError.unused
    }

    func createSession(request _: TrainerSessionCreateRequest, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw MockServiceError.unused
    }

    func getSession(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw MockServiceError.unused
    }

    func getRuntimeState(simulationID _: Int) async throws -> TrainerRuntimeStateOut {
        throw MockServiceError.unused
    }

    func getControlPlaneDebug(simulationID _: Int) async throws -> ControlPlaneDebugOut {
        throw MockServiceError.unused
    }

    func runCommand(simulationID _: Int, command _: RunCommand, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw MockServiceError.unused
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

    func injectInterventionEvent(simulationID _: Int, request _: InterventionEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockServiceError.unused
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

    func listAnnotations(simulationID _: Int) async throws -> [AnnotationOut] {
        throw MockServiceError.unused
    }

    func updateScenarioBrief(simulationID _: Int, request _: ScenarioBriefUpdateRequest, idempotencyKey _: String) async throws -> ScenarioBriefOut {
        throw MockServiceError.unused
    }

    func replayPending(endpoint _: String, method _: String, body _: Data?, idempotencyKey _: String) async throws {}
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
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .seeded))
        store.startConsole()
        defer { store.stopConsole() }

        let event = EventEnvelope(
            eventID: "event-dup-1",
            eventType: "trainerlab.adjustment.applied",
            createdAt: Date(),
            correlationID: "corr-1",
            payload: ["target": .string("avpu")],
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
            commandQueue: InMemoryCommandQueueStore(),
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
            ],
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
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .seeded))
        store.startConsole()
        defer { store.stopConsole() }

        realtime.emit(event: EventEnvelope(
            eventID: "run-1",
            eventType: "run.started",
            createdAt: Date(),
            correlationID: nil,
            payload: [:],
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
            payload: [:],
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
            payload: [:],
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
            commandQueue: queue,
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

        let pending = try await queue.pendingCount()
        XCTAssertEqual(pending, 0)
    }

    func testTrainerNotesAreAddedToClinicalTimelineImmediately() {
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: MockRealtimeClient(),
            commandQueue: InMemoryCommandQueueStore(),
        )

        store.addTrainerNote("Patient became more agitated after intervention.")

        XCTAssertEqual(store.state.clinicalTimelineEntries.count, 1)
        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.title, "Trainer Note")
        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.kind, .note)
        XCTAssertEqual(
            store.state.clinicalTimelineEntries.first?.message,
            "Patient became more agitated after intervention.",
        )
    }

    private func makeSession(status: TrainerSessionStatus) -> TrainerSessionDTO {
        TrainerSessionDTO(
            simulationID: 420,
            status: status,
            scenarioSpec: [:],
            runtimeState: [:],
            initialDirectives: nil,
            tickIntervalSeconds: 15,
            runStartedAt: nil,
            runPausedAt: nil,
            runCompletedAt: nil,
            lastAITickAt: nil,
            createdAt: Date(),
            modifiedAt: Date(),
        )
    }

    private func waitUntil(
        timeout: TimeInterval,
        condition: @escaping @MainActor () -> Bool,
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
