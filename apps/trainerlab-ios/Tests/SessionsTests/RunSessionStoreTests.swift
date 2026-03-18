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
    func accessMe() async throws -> LabAccess { throw MockServiceError.unused }
    func listSessions(limit: Int, cursor: String?, status: String?, query: String?) async throws -> PaginatedResponse<TrainerSessionDTO> { throw MockServiceError.unused }
    func createSession(request: TrainerSessionCreateRequest, idempotencyKey: String) async throws -> TrainerSessionDTO { throw MockServiceError.unused }
    func getSession(simulationID: Int) async throws -> TrainerSessionDTO { throw MockServiceError.unused }
    func getRuntimeState(simulationID: Int) async throws -> TrainerRuntimeStateOut { throw MockServiceError.unused }
    func runCommand(simulationID: Int, command: RunCommand, idempotencyKey: String) async throws -> TrainerSessionDTO { throw MockServiceError.unused }
    func listEvents(simulationID: Int, cursor: String?, limit: Int) async throws -> PaginatedResponse<EventEnvelope> { throw MockServiceError.unused }
    func getRunSummary(simulationID: Int) async throws -> RunSummary { throw MockServiceError.unused }
    func adjustSimulation(simulationID: Int, request: SimulationAdjustRequest, idempotencyKey: String) async throws -> SimulationAdjustAck { throw MockServiceError.unused }
    func steerPrompt(simulationID: Int, request: SteerPromptRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func injectInjuryEvent(simulationID: Int, request: InjuryEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func injectIllnessEvent(simulationID: Int, request: IllnessEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func createProblem(simulationID: Int, request: ProblemCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func createAssessmentFinding(simulationID: Int, request: AssessmentFindingCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func createDiagnosticResult(simulationID: Int, request: DiagnosticResultCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func createResourceState(simulationID: Int, request: ResourceStateCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func createDispositionState(simulationID: Int, request: DispositionStateCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func injectVitalEvent(simulationID: Int, request: VitalEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func injectInterventionEvent(simulationID: Int, request: InterventionEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func listPresets(limit: Int, cursor: String?) async throws -> PaginatedResponse<ScenarioInstruction> { throw MockServiceError.unused }
    func createPreset(request: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction { throw MockServiceError.unused }
    func getPreset(presetID: Int) async throws -> ScenarioInstruction { throw MockServiceError.unused }
    func updatePreset(presetID: Int, request: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction { throw MockServiceError.unused }
    func deletePreset(presetID: Int) async throws { throw MockServiceError.unused }
    func duplicatePreset(presetID: Int) async throws -> ScenarioInstruction { throw MockServiceError.unused }
    func sharePreset(presetID: Int, request: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission { throw MockServiceError.unused }
    func unsharePreset(presetID: Int, request: ScenarioInstructionUnshareRequest) async throws { throw MockServiceError.unused }
    func applyPreset(presetID: Int, request: ScenarioInstructionApplyRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockServiceError.unused }
    func injuryDictionary() async throws -> InjuryDictionary { throw MockServiceError.unused }
    func interventionDictionary() async throws -> [InterventionGroup] { throw MockServiceError.unused }
    func listAccounts(query: String, cursor: String?, limit: Int) async throws -> PaginatedResponse<AccountListUser> { throw MockServiceError.unused }
    func updateProblemStatus(simulationID: Int, problemID: Int, request: ProblemStatusUpdateRequest, idempotencyKey: String) async throws -> ProblemStatusOut { throw MockServiceError.unused }
    func createAnnotation(simulationID: Int, request: AnnotationCreateRequest, idempotencyKey: String) async throws -> AnnotationOut { throw MockServiceError.unused }
    func listAnnotations(simulationID: Int) async throws -> [AnnotationOut] { throw MockServiceError.unused }
    func updateScenarioBrief(simulationID: Int, request: ScenarioBriefUpdateRequest, idempotencyKey: String) async throws -> ScenarioBriefOut { throw MockServiceError.unused }
    func replayPending(endpoint: String, method: String, body: Data?, idempotencyKey: String) async throws {}
}

private final class MockRealtimeClient: RealtimeClientProtocol, @unchecked Sendable {
    let events: AsyncStream<EventEnvelope>
    let transportStates: AsyncStream<RealtimeTransportState>

    private let eventContinuation: AsyncStream<EventEnvelope>.Continuation
    private let stateContinuation: AsyncStream<RealtimeTransportState>.Continuation

    init() {
        var eventCont: AsyncStream<EventEnvelope>.Continuation!
        self.events = AsyncStream { continuation in
            eventCont = continuation
        }
        self.eventContinuation = eventCont

        var stateCont: AsyncStream<RealtimeTransportState>.Continuation!
        self.transportStates = AsyncStream { continuation in
            stateCont = continuation
            continuation.yield(.disconnected)
        }
        self.stateContinuation = stateCont
    }

    func connect(simulationID: Int, cursor: String?) async {
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
    func testUnifiedTimelineDedupesDuplicateRuntimeEvents() async throws {
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

    func testVitalEventsDoNotCreateClinicalTimelineEntries() async throws {
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

        let pending = try await queue.pendingCount()
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
            modifiedAt: Date()
        )
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
