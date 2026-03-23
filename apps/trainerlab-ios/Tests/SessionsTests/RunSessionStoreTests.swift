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
    var getRuntimeStateResultsQueue: [Result<TrainerRuntimeStateOut, Error>] = []
    var getRuntimeStateResult: Result<TrainerRuntimeStateOut, Error> = .failure(MockServiceError.unused)
    var listEventsCalls: [(simulationID: Int, cursor: String?, limit: Int)] = []
    var listEventsResultsQueue: [Result<PaginatedResponse<EventEnvelope>, Error>] = []
    var listEventsResult: Result<PaginatedResponse<EventEnvelope>, Error> = .failure(MockServiceError.unused)
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
        if !getRuntimeStateResultsQueue.isEmpty {
            return try getRuntimeStateResultsQueue.removeFirst().get()
        }
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

    func listEvents(simulationID: Int, cursor: String?, limit: Int) async throws -> PaginatedResponse<EventEnvelope> {
        listEventsCalls.append((simulationID: simulationID, cursor: cursor, limit: limit))
        if !listEventsResultsQueue.isEmpty {
            return try listEventsResultsQueue.removeFirst().get()
        }
        return try listEventsResult.get()
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
    private(set) var connectCalls: [(simulationID: Int, cursor: String?)] = []

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

    func connect(simulationID: Int, cursor: String?) async {
        connectCalls.append((simulationID: simulationID, cursor: cursor))
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
            eventType: SimulationEventType.simulationAdjustmentUpdated,
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

    func testVitalEventsTriggerAuthoritativeRefreshAndTimelineEntries() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResultsQueue = try [
            .success(makeRuntimeState(status: "running")),
            .success(makeRuntimeState(
                status: "running",
                vitals: [[
                    "vital_type": "heart_rate",
                    "min_value": 80,
                    "max_value": 140,
                ]],
            )),
        ]
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            service.getRuntimeStateCalls.count == 1
        }

        realtime.emit(event: EventEnvelope(
            eventID: "vital-1",
            eventType: SimulationEventType.patientVitalCreated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "vital_type": .string("heart_rate"),
                "min_value": .number(80),
                "max_value": .number(140),
            ],
        ))

        await waitUntil(timeout: 2.0) {
            service.getRuntimeStateCalls.count == 2
                && store.state.vitals.count == 1
                && store.state.clinicalTimelineEntries.first?.kind == .vitals
        }

        XCTAssertEqual(store.state.vitals.first?.key, "heart_rate")
        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.title, "Vital Update")
    }

    func testBootstrapLoadsAuthoritativeRuntimeStateAndHistoricalTimeline() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResult = try .success(makeRuntimeState(
            status: "seeded",
            stateRevision: 4,
            scenarioBrief: [
                "read_aloud_brief": "Patrol medic called to blast injury.",
                "environment": "Night operation",
            ],
            causes: [[
                "cause_id": 11,
                "kind": "injury",
                "title": "Blast Injury",
                "description": "Open wound to the left arm",
                "injury_location": "LEFT_ARM",
            ]],
            problems: [[
                "problem_id": 21,
                "title": "Hemorrhagic Shock",
                "status": "active",
                "cause_id": 11,
                "anatomical_location": "LEFT_ARM",
            ]],
            vitals: [[
                "vital_type": "heart_rate",
                "min_value": 120,
                "max_value": 140,
            ]],
            pulses: [[
                "location": "radial_left",
                "present": false,
                "quality": "weak",
            ]],
            assessmentFindings: [[
                "title": "Absent breath sounds",
                "status": "present",
            ]],
            diagnosticResults: [[
                "title": "Ultrasound pending",
                "status": "queued",
            ]],
            resources: [[
                "title": "Whole blood available",
                "status": "ready",
            ]],
            disposition: [
                "title": "Urgent evacuation",
                "status": "requested",
            ],
            patientStatus: [
                "avpu": "verbal",
                "narrative": "Increasing respiratory distress.",
                "respiratory_distress": true,
            ],
            aiPlan: [
                "summary": "Escalate respiratory distress",
                "upcoming_changes": ["Decrease SpO2"],
            ],
        ))
        service.listEventsResult = .success(PaginatedResponse(
            items: [
                makeStatusUpdatedEvent(
                    eventID: "seed-1",
                    status: "seeded",
                    stateRevision: 4,
                    createdAt: Date(timeIntervalSince1970: 10),
                ),
                makeStatusUpdatedEvent(
                    eventID: "run-1",
                    status: "running",
                    to: "running",
                    createdAt: Date(timeIntervalSince1970: 20),
                ),
            ],
            nextCursor: nil,
            hasMore: false,
        ))
        service.listAnnotationsResult = .success([])

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .seeded))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 2.0) {
            store.runtimeState?.stateRevision == 4
                && store.state.clinicalTimelineEntries.count == 2
                && realtime.connectCalls.first?.cursor == "run-1"
        }

        XCTAssertEqual(store.state.vitals.first?.key, "heart_rate")
        XCTAssertEqual(store.state.pulseAnnotations.first?.location, "radial_left")
        XCTAssertEqual(store.state.causeAnnotations.first?.causeID, 11)
        XCTAssertEqual(store.state.problemAnnotations.first?.problemID, 21)
        XCTAssertEqual(store.scenarioBrief?.readAloudBrief, "Patrol medic called to blast injury.")
        XCTAssertEqual(store.patientStatus.narrative, "Increasing respiratory distress.")
        XCTAssertEqual(store.runtimeState?.aiPlan?.summary, "Escalate respiratory distress")
        XCTAssertEqual(store.state.clinicalTimelineEntries.map(\.title), ["Run Started", "Scenario Ready"])
        XCTAssertEqual(
            store.state.timeline.map(\.eventType),
            [SimulationEventType.simulationStatusUpdated, SimulationEventType.simulationStatusUpdated],
        )
    }

    func testBindSeedsHydratedSectionsFromSessionRuntimeStateAliases() {
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: MockRealtimeClient(),
            commandQueue: InMemoryCommandQueueStore(),
        )

        store.bind(session: makeSession(
            status: .seeded,
            runtimeState: makeAliasedSessionRuntimeSeed(),
        ))

        XCTAssertEqual(store.scenarioBrief?.readAloudBrief, "Patrol medic called to blast injury.")
        XCTAssertEqual(store.patientStatus.narrative, "Increasing respiratory distress.")
        XCTAssertEqual(store.aiInstructorIntent?.summary, "Escalate respiratory distress")
        XCTAssertEqual(store.hydratedCauses.first?.causeID, 11)
        XCTAssertEqual(store.state.problemAnnotations.first?.problemID, 21)
        XCTAssertEqual(store.state.vitals.first?.key, "heart_rate")
        XCTAssertEqual(store.state.pulseAnnotations.first?.location, "radial_left")
        XCTAssertEqual(store.state.interventionAnnotations.first?.siteCode, "LEFT_ARM")
    }

    func testRefreshSessionSeedsHydratedSectionsFromReturnedRuntimeSeed() async {
        let service = MockTrainerLabService()
        service.getSessionResult = .success(makeSession(
            status: .running,
            runtimeState: makeAliasedSessionRuntimeSeed(),
        ))
        let store = RunSessionStore(
            service: service,
            realtimeClient: MockRealtimeClient(),
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))

        await store.refreshSession()

        XCTAssertEqual(service.getSessionCalls, [420])
        XCTAssertEqual(store.scenarioBrief?.readAloudBrief, "Patrol medic called to blast injury.")
        XCTAssertEqual(store.patientStatus.narrative, "Increasing respiratory distress.")
        XCTAssertEqual(store.aiInstructorIntent?.summary, "Escalate respiratory distress")
        XCTAssertEqual(store.hydratedCauses.first?.causeID, 11)
        XCTAssertEqual(store.state.problemAnnotations.first?.problemID, 21)
    }

    func testStateUpdatedAuthoritativelyReplacesVitals() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResultsQueue = try [
            .success(makeRuntimeState(
                status: "running",
                stateRevision: 1,
                vitals: [[
                    "vital_type": "heart_rate",
                    "min_value": 80,
                    "max_value": 100,
                ]],
            )),
            .success(makeRuntimeState(
                status: "running",
                stateRevision: 2,
                vitals: [[
                    "vital_type": "heart_rate",
                    "min_value": 120,
                    "max_value": 150,
                ]],
            )),
        ]

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.vitals.first?.minValue == 80
        }

        realtime.emit(event: EventEnvelope(
            eventID: "state-2",
            eventType: SimulationEventType.simulationSnapshotUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: [:],
        ))

        await waitUntil(timeout: 2.0) {
            service.getRuntimeStateCalls.count == 2
                && store.state.vitals.first?.minValue == 120
                && store.state.vitals.first?.maxValue == 150
        }

        XCTAssertEqual(store.state.vitals.count, 1)
    }

    func testSparseRuntimeRefreshPreservesHydratedSectionsWhenPayloadOmitsThem() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResultsQueue = try [
            .success(makeRuntimeState(
                status: "running",
                stateRevision: 1,
                scenarioBrief: [
                    "read_aloud_brief": "Patrol medic called to blast injury.",
                ],
                causes: [[
                    "cause_id": 11,
                    "kind": "injury",
                    "title": "Blast Injury",
                    "description": "Open wound to the left arm",
                    "injury_location": "LEFT_ARM",
                ]],
                problems: [[
                    "problem_id": 21,
                    "title": "Hemorrhagic Shock",
                    "status": "active",
                    "cause_id": 11,
                    "anatomical_location": "LEFT_ARM",
                ]],
                vitals: [[
                    "vital_type": "heart_rate",
                    "min_value": 90,
                    "max_value": 110,
                ]],
                pulses: [[
                    "location": "radial_left",
                    "present": false,
                    "quality": "weak",
                ]],
                interventions: [[
                    "intervention_id": 31,
                    "kind": "tourniquet",
                    "title": "Tourniquet",
                    "site_code": "LEFT_ARM",
                    "target_problem_id": 21,
                ]],
                patientStatus: [
                    "narrative": "Increasing respiratory distress.",
                ],
                aiPlan: [
                    "summary": "Escalate respiratory distress",
                ],
            )),
            .success(try decodeRuntimeStatePayload([
                "simulation_id": 420,
                "session_id": 420,
                "status": "running",
                "state_revision": 2,
                "active_elapsed_seconds": 0,
                "tick_interval_seconds": 15,
                "current_snapshot": [
                    "vitals": [[
                        "vital_type": "heart_rate",
                        "min_value": 120,
                        "max_value": 150,
                    ]],
                ],
                "pending_runtime_reasons": [],
                "pending_reasons": [],
                "currently_processing_reasons": [],
                "last_runtime_error": "",
            ])),
        ]

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.hydratedCauses.first?.causeID == 11 &&
                store.state.vitals.first?.minValue == 90
        }

        realtime.emit(event: EventEnvelope(
            eventID: "state-2",
            eventType: "state.updated",
            createdAt: Date(),
            correlationID: nil,
            payload: [:],
        ))

        await waitUntil(timeout: 2.0) {
            service.getRuntimeStateCalls.count == 2 &&
                store.state.vitals.first?.minValue == 120 &&
                store.state.vitals.first?.maxValue == 150
        }

        XCTAssertEqual(store.scenarioBrief?.readAloudBrief, "Patrol medic called to blast injury.")
        XCTAssertEqual(store.patientStatus.narrative, "Increasing respiratory distress.")
        XCTAssertEqual(store.aiInstructorIntent?.summary, "Escalate respiratory distress")
        XCTAssertEqual(store.hydratedCauses.first?.causeID, 11)
        XCTAssertEqual(store.state.problemAnnotations.first?.problemID, 21)
        XCTAssertEqual(store.state.interventionAnnotations.first?.siteCode, "LEFT_ARM")
        XCTAssertEqual(store.state.pulseAnnotations.first?.location, "radial_left")
    }

    func testExplicitEmptyRuntimeCollectionsClearHydratedState() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResultsQueue = try [
            .success(makeRuntimeState(
                status: "running",
                stateRevision: 1,
                causes: [[
                    "cause_id": 11,
                    "kind": "injury",
                    "title": "Blast Injury",
                    "description": "Open wound to the left arm",
                    "injury_location": "LEFT_ARM",
                ]],
                problems: [[
                    "problem_id": 21,
                    "title": "Hemorrhagic Shock",
                    "status": "active",
                    "cause_id": 11,
                    "anatomical_location": "LEFT_ARM",
                ]],
                vitals: [[
                    "vital_type": "heart_rate",
                    "min_value": 90,
                    "max_value": 110,
                ]],
                pulses: [[
                    "location": "radial_left",
                    "present": false,
                    "quality": "weak",
                ]],
                interventions: [[
                    "intervention_id": 31,
                    "kind": "tourniquet",
                    "title": "Tourniquet",
                    "site_code": "LEFT_ARM",
                    "target_problem_id": 21,
                ]],
            )),
            .success(try decodeRuntimeStatePayload([
                "simulation_id": 420,
                "session_id": 420,
                "status": "running",
                "state_revision": 2,
                "active_elapsed_seconds": 0,
                "tick_interval_seconds": 15,
                "current_snapshot": [
                    "causes": [],
                    "problems": [],
                    "recommended_interventions": [],
                    "interventions": [],
                    "assessment_findings": [],
                    "diagnostic_results": [],
                    "resources": [],
                    "disposition": NSNull(),
                    "vitals": [],
                    "pulses": [],
                    "patient_status": [:],
                ],
                "pending_runtime_reasons": [],
                "pending_reasons": [],
                "currently_processing_reasons": [],
                "last_runtime_error": "",
            ])),
        ]

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.hydratedCauses.count == 1 &&
                store.state.problemAnnotations.count == 1 &&
                store.state.interventionAnnotations.count == 1 &&
                store.state.pulseAnnotations.count == 1 &&
                store.state.vitals.count == 1
        }

        realtime.emit(event: EventEnvelope(
            eventID: "state-clear",
            eventType: "state.updated",
            createdAt: Date(),
            correlationID: nil,
            payload: [:],
        ))

        await waitUntil(timeout: 2.0) {
            service.getRuntimeStateCalls.count == 2 &&
                store.hydratedCauses.isEmpty &&
                store.state.problemAnnotations.isEmpty &&
                store.state.interventionAnnotations.isEmpty &&
                store.state.pulseAnnotations.isEmpty &&
                store.state.vitals.isEmpty
        }
    }

    func testAIIntentUpdatedTriggersAuthoritativeRefresh() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResultsQueue = try [
            .success(makeRuntimeState(status: "running")),
            .success(makeRuntimeState(
                status: "running",
                aiPlan: [
                    "summary": "Reassess airway",
                    "rationale": "SpO2 is falling",
                ],
            )),
        ]

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            service.getRuntimeStateCalls.count == 1
        }

        realtime.emit(event: EventEnvelope(
            eventID: "ai-1",
            eventType: SimulationEventType.simulationPlanUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: ["summary": .string("Reassess airway")],
        ))

        await waitUntil(timeout: 2.0) {
            service.getRuntimeStateCalls.count == 2
                && store.runtimeState?.aiPlan?.summary == "Reassess airway"
        }

        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.title, "AI Instructor")
    }

    func testBurstRuntimeEventsCoalesceToSingleRefresh() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResultsQueue = try [
            .success(makeRuntimeState(status: "running")),
            .success(makeRuntimeState(status: "running", stateRevision: 2)),
        ]

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            service.getRuntimeStateCalls.count == 1
        }

        realtime.emit(event: EventEnvelope(eventID: "e1", eventType: SimulationEventType.simulationSnapshotUpdated, createdAt: Date(), correlationID: nil, payload: [:]))
        realtime.emit(event: EventEnvelope(eventID: "e2", eventType: SimulationEventType.simulationPlanUpdated, createdAt: Date(), correlationID: nil, payload: [:]))
        realtime.emit(event: EventEnvelope(eventID: "e3", eventType: SimulationEventType.patientRecommendedInterventionUpdated, createdAt: Date(), correlationID: nil, payload: [:]))

        await waitUntil(timeout: 2.0) {
            service.getRuntimeStateCalls.count == 2
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(service.getRuntimeStateCalls.count, 2)
    }

    func testHistoryAndLiveTimelineDedupesAndSortsStably() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "running"))
        service.listEventsResult = .success(PaginatedResponse(
            items: [
                makeStatusUpdatedEvent(
                    eventID: "seed-1",
                    status: "seeded",
                    stateRevision: 1,
                    createdAt: Date(timeIntervalSince1970: 10),
                ),
                makeStatusUpdatedEvent(
                    eventID: "run-1",
                    status: "running",
                    to: "running",
                    createdAt: Date(timeIntervalSince1970: 20),
                ),
            ],
            nextCursor: nil,
            hasMore: false,
        ))

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 2.0) {
            store.state.timeline.count == 2
        }

        realtime.emit(event: makeStatusUpdatedEvent(
            eventID: "run-1",
            status: "running",
            to: "running",
            createdAt: Date(timeIntervalSince1970: 20),
        ))
        realtime.emit(event: makeStatusUpdatedEvent(
            eventID: "run-2",
            status: "paused",
            from: "running",
            to: "paused",
            createdAt: Date(timeIntervalSince1970: 30),
        ))

        await waitUntil(timeout: 2.0) {
            store.state.timeline.map(\.eventID) == ["seed-1", "run-1", "run-2"]
                && store.state.clinicalTimelineEntries.map(\.title) == ["Run Paused", "Run Started", "Scenario Ready"]
        }

        XCTAssertEqual(
            store.state.timeline.map(\.eventType),
            [
                SimulationEventType.simulationStatusUpdated,
                SimulationEventType.simulationStatusUpdated,
                SimulationEventType.simulationStatusUpdated,
            ],
        )
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
            eventType: SimulationEventType.simulationStatusUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: ["status": .string("running"), "to": .string("running")],
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
            eventType: SimulationEventType.simulationStatusUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: ["status": .string("paused"), "from": .string("running"), "to": .string("paused")],
        ))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .paused && !store.state.stopwatchIsRunning
        }

        let pausedElapsed = store.state.stopwatchElapsedSeconds
        try await Task.sleep(nanoseconds: 1_300_000_000)
        XCTAssertEqual(store.state.stopwatchElapsedSeconds, pausedElapsed)

        realtime.emit(event: EventEnvelope(
            eventID: "run-3",
            eventType: SimulationEventType.simulationStatusUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: ["status": .string("running"), "from": .string("paused"), "to": .string("running")],
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

        let pending = try await queue.pendingCount(simulationID: 420)
        XCTAssertEqual(pending, 0)
    }

    func testSimulationStateChangedFailureTransitionsSessionToFailed() async {
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running, runStartedAt: Date().addingTimeInterval(-12)))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.stopwatchIsRunning
        }

        realtime.emit(event: makeStatusUpdatedEvent(
            status: "failed",
            reasonCode: "trainerlab_initial_generation_enqueue_failed",
            reasonText: "We could not start this simulation. Please try again.",
            retryable: true,
            terminalAt: Date(),
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
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running, runStartedAt: Date().addingTimeInterval(-6)))
        store.startConsole()
        defer { store.stopConsole() }

        realtime.emit(event: makeStatusUpdatedEvent(
            simulationID: 999,
            status: "failed",
            reasonCode: "trainerlab_initial_generation_enqueue_failed",
            reasonText: "Should be ignored.",
            retryable: true,
            terminalAt: Date(),
        ))

        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(store.state.session?.status, .running)
        XCTAssertNil(store.state.terminalCard)
    }

    func testSessionFailedEventTransitionsSeedingSessionToFailed() async {
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .seeding))
        store.startConsole()
        defer { store.stopConsole() }

        realtime.emit(event: makeStatusUpdatedEvent(
            status: "failed",
            reasonCode: "trainerlab_initial_generation_failed",
            reasonText: "Initial scenario generation failed.",
            retryable: true,
        ))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .failed &&
                store.state.session?.terminalReasonCode == "trainerlab_initial_generation_failed" &&
                store.state.session?.terminalReasonText == "Initial scenario generation failed." &&
                store.state.session?.retryable == true &&
                store.state.terminalCard?.status == .failed
        }
    }

    func testSessionSeedingEventClearsTerminalFailureState() async {
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: MockTrainerLabService(),
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(
            status: .failed,
            terminalReasonCode: "trainerlab_initial_generation_failed",
            terminalReasonText: "Initial scenario generation failed.",
            retryable: true,
        ))
        store.startConsole()
        defer { store.stopConsole() }

        realtime.emit(event: makeStatusUpdatedEvent(
            status: "seeding",
            stateRevision: 2,
            scenarioSpec: ["diagnosis": .string("Tension pneumothorax")],
            retryCount: 1,
        ))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .seeding &&
                store.state.session?.terminalReasonCode == nil &&
                store.state.session?.retryable == nil &&
                store.state.terminalCard == nil &&
                store.state.session?.scenarioSpec["diagnosis"] == .string("Tension pneumothorax")
        }
    }

    func testRetryInitialSimulationRebindsSeedingSessionThenCompletesAfterSeededEvent() async throws {
        let service = MockTrainerLabService()
        service.retryInitialResult = .success(makeSession(status: .seeding))
        service.getSessionResult = .success(makeSession(status: .seeded))
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "seeded", stateRevision: 2))
        service.listAnnotationsResult = .success([])
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(
            status: .failed,
            runCompletedAt: Date(),
            terminalReasonCode: "trainerlab_initial_generation_enqueue_failed",
            terminalReasonText: "We could not start this simulation. Please try again.",
            retryable: true,
        ))
        store.startConsole()
        defer { store.stopConsole() }

        XCTAssertEqual(store.state.terminalCard?.status, .failed)
        let runtimeCallsBefore = service.getRuntimeStateCalls.count
        let annotationCallsBefore = service.listAnnotationsCalls.count

        store.retryInitialSimulation()

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .seeding &&
                store.state.terminalCard == nil &&
                service.retryInitialCalls == [420]
        }

        realtime.emit(event: makeStatusUpdatedEvent(
            status: "seeded",
            stateRevision: 2,
            scenarioSpec: ["diagnosis": .string("Tension pneumothorax")],
        ))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .seeded &&
                service.getSessionCalls == [420] &&
                service.getRuntimeStateCalls.count > runtimeCallsBefore &&
                service.listAnnotationsCalls.count > annotationCallsBefore
        }

        XCTAssertNil(store.state.conflictBanner)
    }

    func testRunAndInterventionMutationsAreBlockedWhileSeeding() async {
        let service = MockTrainerLabService()
        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
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
            targetProblemID: 99,
        )

        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertTrue(service.runCommandCalls.isEmpty)
        XCTAssertTrue(service.injectInterventionCalls.isEmpty)
    }

    func testAddInterventionAllowsMissingTargetProblem() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "running"))
        service.listEventsResult = .success(PaginatedResponse(items: [], nextCursor: nil, hasMore: false))
        service.listAnnotationsResult = .success([])
        service.injectInterventionResult = .success(TrainerCommandAck(commandID: "cmd-1", status: "accepted"))

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.commandChannelAvailable
        }

        store.addIntervention(
            interventionType: "tourniquet",
            siteCode: "LEFT_ARM",
            targetProblemID: nil,
            notes: "Applied prophylactically",
        )

        await waitUntil(timeout: 1.5) {
            service.injectInterventionCalls.count == 1
        }

        XCTAssertNil(service.injectInterventionCalls.first?.targetProblemID)
        XCTAssertNil(store.state.conflictBanner)
        XCTAssertEqual(store.state.clinicalTimelineEntries.first?.kind, .intervention)
    }

    func testReplayPendingCommandsOnlyReplaysRowsForBoundSimulation() async throws {
        let service = MockTrainerLabService()
        let queue = InMemoryCommandQueueStore()
        let store = RunSessionStore(
            service: service,
            realtimeClient: MockRealtimeClient(),
            commandQueue: queue,
        )
        store.bind(session: makeSession(status: .seeded))

        let matching = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420,
        )
        let otherSimulation = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 421,
        )
        let legacyMatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil,
        )
        let legacyMismatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil,
        )

        try await queue.enqueue(matching)
        try await queue.enqueue(otherSimulation)
        try await queue.enqueue(legacyMatch)
        try await queue.enqueue(legacyMismatch)

        await store.replayPendingCommands()

        XCTAssertEqual(
            service.replayPendingCalls.map(\.endpoint),
            [matching.endpoint, legacyMatch.endpoint],
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
            commandQueue: queue,
        )
        store.bind(session: makeSession(status: .seeded))

        let envelope = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420,
        )
        try await queue.enqueue(envelope)
        service.replayPendingErrorByEndpoint[envelope.endpoint] = APIClientError.http(
            statusCode: 404,
            detail: "Not ready",
            correlationID: nil,
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
            commandQueue: queue,
        )

        var matching = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420,
        )
        matching.nextRetryAt = .distantFuture

        var legacyMatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil,
        )
        legacyMatch.nextRetryAt = .distantFuture

        var persistedMismatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 421,
        )
        persistedMismatch.nextRetryAt = .distantFuture

        var legacyMismatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil,
        )
        legacyMismatch.nextRetryAt = .distantFuture

        var terminalMatch = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/stop/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420,
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
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "seeded", stateRevision: 2))
        service.listAnnotationsResult = .success([])

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .seeding))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.state.commandChannelAvailable
        }
        let runtimeCallsBefore = service.getRuntimeStateCalls.count
        let annotationCallsBefore = service.listAnnotationsCalls.count

        realtime.emit(event: makeStatusUpdatedEvent(
            status: "seeded",
            stateRevision: 2,
            scenarioSpec: ["diagnosis": .string("Tension pneumothorax")],
        ))

        await waitUntil(timeout: 1.5) {
            service.getSessionCalls == [420]
                && service.getRuntimeStateCalls.count > runtimeCallsBefore
                && service.listAnnotationsCalls.count > annotationCallsBefore
                && store.state.session?.status == .seeded
        }
    }

    func testLivePatientEventsHydrateClinicalStateAcrossFamilies() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "running"))

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running, runStartedAt: Date()))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            service.getRuntimeStateCalls.count == 1
        }

        realtime.emit(event: EventEnvelope(
            eventID: "injury-1",
            eventType: SimulationEventType.patientInjuryCreated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "cause_id": .number(501),
                "domain_event_id": .number(501),
                "title": .string("Gunshot wound"),
                "description": .string("Penetrating injury to the left arm"),
                "anatomical_location": .string("LEFT_ARM"),
                "kind": .string("injury"),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "problem-1",
            eventType: SimulationEventType.patientProblemUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "problem_id": .number(601),
                "title": .string("External hemorrhage"),
                "status": .string("active"),
                "cause_id": .number(501),
                "anatomical_location": .string("LEFT_ARM"),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "recommendation-1",
            eventType: SimulationEventType.patientRecommendedInterventionCreated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "recommendation_id": .number(701),
                "title": .string("Apply tourniquet"),
                "target_problem_id": .number(601),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "intervention-1",
            eventType: SimulationEventType.patientInterventionCreated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "domain_event_id": .number(801),
                "intervention_id": .number(801),
                "intervention_type": .string("tourniquet"),
                "title": .string("Tourniquet"),
                "site_code": .string("LEFT_ARM"),
                "target_problem_id": .number(601),
                "status": .string("applied"),
                "effectiveness": .string("effective"),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "pulse-1",
            eventType: SimulationEventType.patientPulseUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "domain_event_id": .number(901),
                "location": .string("radial_left"),
                "present": .bool(false),
                "quality": .string("weak"),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "finding-1",
            eventType: SimulationEventType.patientAssessmentFindingCreated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "finding_id": .number(1001),
                "title": .string("Absent breath sounds"),
                "status": .string("present"),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "diagnostic-1",
            eventType: SimulationEventType.patientDiagnosticResultCreated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "diagnostic_id": .number(1101),
                "title": .string("Ultrasound pending"),
                "status": .string("queued"),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "resource-1",
            eventType: SimulationEventType.patientResourceUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "resource_id": .number(1201),
                "title": .string("Whole blood available"),
                "status": .string("ready"),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "disposition-1",
            eventType: SimulationEventType.patientDispositionUpdated,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "disposition_id": .number(1301),
                "status": .string("requested"),
                "destination": .string("Role 2"),
                "transport_mode": .string("ground"),
            ],
        ))
        realtime.emit(event: EventEnvelope(
            eventID: "recommendation-2",
            eventType: SimulationEventType.patientRecommendedInterventionRemoved,
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "recommendation_id": .number(701),
                "target_problem_id": .number(601),
            ],
        ))

        await waitUntil(timeout: 2.0) {
            store.state.causeAnnotations.first?.causeID == 501
                && store.state.problemAnnotations.first?.problemID == 601
                && store.state.interventionAnnotations.first?.interventionID == 801
                && store.state.pulseAnnotations.first?.location == "radial_left"
                && store.assessmentFindings.first?.findingID == 1001
                && store.diagnosticResults.first?.resultID == 1101
                && store.resources.first?.resourceID == 1201
                && store.disposition?.dispositionID == 1301
                && store.state.recommendedInterventions.isEmpty
        }
    }

    func testUnknownEventsNormalizeSafelyWithoutTriggeringRefresh() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "running"))

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .running, runStartedAt: Date()))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            service.getRuntimeStateCalls.count == 1
        }

        realtime.emit(event: EventEnvelope(
            eventID: "unknown-1",
            eventType: "SIMULATION.BRAND_NEW_EVENT",
            createdAt: Date(),
            correlationID: nil,
            payload: [:],
        ))

        await waitUntil(timeout: 1.5) {
            store.state.timeline.last?.eventID == "unknown-1"
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(service.getRuntimeStateCalls.count, 1)
        XCTAssertEqual(store.state.timeline.last?.eventType, "simulation.brand_new_event")
    }

    func testDuplicateSessionSeededEventsRemainSafe() async throws {
        let service = MockTrainerLabService()
        service.getSessionResult = .success(makeSession(status: .seeded))
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "seeded", stateRevision: 2))
        service.listAnnotationsResult = .success([])

        let realtime = MockRealtimeClient()
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(status: .seeding))
        store.startConsole()
        defer { store.stopConsole() }

        realtime.emit(event: makeStatusUpdatedEvent(status: "seeded", stateRevision: 2))
        realtime.emit(event: makeStatusUpdatedEvent(status: "seeded", stateRevision: 2))

        await waitUntil(timeout: 1.5) {
            store.state.session?.status == .seeded &&
                !service.getSessionCalls.isEmpty
        }

        XCTAssertTrue(service.getSessionCalls.allSatisfy { $0 == 420 })
        XCTAssertNil(store.state.terminalCard)
    }

    func testStaleSessionSeedingEventDoesNotRegressSeededSession() async throws {
        let service = MockTrainerLabService()
        service.getRuntimeStateResult = try .success(makeRuntimeState(status: "seeded", stateRevision: 3))

        let realtime = MockRealtimeClient()
        let existingScenarioSpec: [String: JSONValue] = ["diagnosis": .string("Existing scenario")]
        let store = RunSessionStore(
            service: service,
            realtimeClient: realtime,
            commandQueue: InMemoryCommandQueueStore(),
        )
        store.bind(session: makeSession(
            status: .seeded,
            scenarioSpec: existingScenarioSpec,
        ))
        store.startConsole()
        defer { store.stopConsole() }

        await waitUntil(timeout: 1.5) {
            store.runtimeState?.stateRevision == 3
        }

        realtime.emit(event: makeStatusUpdatedEvent(
            status: "seeding",
            stateRevision: 2,
            scenarioSpec: ["diagnosis": .string("Stale scenario")],
        ))

        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(store.state.session?.status, .seeded)
        XCTAssertEqual(store.state.session?.scenarioSpec, existingScenarioSpec)
    }

    private func makeSession(
        status: TrainerSessionStatus,
        scenarioSpec: [String: JSONValue] = [:],
        runtimeState: [String: JSONValue] = [:],
        runStartedAt: Date? = nil,
        runCompletedAt: Date? = nil,
        terminalReasonCode: String? = nil,
        terminalReasonText: String? = nil,
        retryable: Bool? = nil,
        modifiedAt: Date = Date(),
    ) -> TrainerSessionDTO {
        TrainerSessionDTO(
            simulationID: 420,
            status: status,
            scenarioSpec: scenarioSpec,
            runtimeState: runtimeState,
            initialDirectives: nil,
            tickIntervalSeconds: 15,
            runStartedAt: runStartedAt,
            runPausedAt: nil,
            runCompletedAt: runCompletedAt,
            lastAITickAt: nil,
            createdAt: Date(),
            modifiedAt: modifiedAt,
            terminalReasonCode: terminalReasonCode,
            terminalReasonText: terminalReasonText,
            retryable: retryable,
        )
    }

    private func makeStatusUpdatedEvent(
        eventID: String = UUID().uuidString.lowercased(),
        simulationID: Int? = 420,
        status: String,
        from fromStatus: String? = nil,
        to toStatus: String? = nil,
        stateRevision: Int? = nil,
        scenarioSpec: [String: JSONValue]? = nil,
        callID: String? = nil,
        retryCount: Int? = nil,
        reasonCode: String? = nil,
        reasonText: String? = nil,
        retryable: Bool? = nil,
        createdAt: Date = Date(),
        terminalAt: Date? = nil,
    ) -> EventEnvelope {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var payload: [String: JSONValue] = [
            "status": .string(status),
        ]
        if let simulationID {
            payload["simulation_id"] = .number(Double(simulationID))
        }
        if let fromStatus {
            payload["from"] = .string(fromStatus)
        }
        if let toStatus {
            payload["to"] = .string(toStatus)
        }
        if let stateRevision {
            payload["state_revision"] = .number(Double(stateRevision))
        }
        if let scenarioSpec {
            payload["scenario_spec"] = .object(scenarioSpec)
        }
        if let callID {
            payload["call_id"] = .string(callID)
        }
        if let retryCount {
            payload["retry_count"] = .number(Double(retryCount))
        }
        if let reasonCode {
            payload["reason_code"] = .string(reasonCode)
            payload["terminal_reason_code"] = .string(reasonCode)
        }
        if let reasonText {
            payload["reason_text"] = .string(reasonText)
            payload["terminal_reason_text"] = .string(reasonText)
        }
        if let retryable {
            payload["retryable"] = .bool(retryable)
        }
        if let terminalAt {
            payload["terminal_at"] = .string(formatter.string(from: terminalAt))
        }

        return EventEnvelope(
            eventID: eventID,
            eventType: SimulationEventType.simulationStatusUpdated,
            createdAt: createdAt,
            correlationID: nil,
            payload: payload,
        )
    }

    private func makeRuntimeState(
        status: String,
        stateRevision: Int = 1,
        scenarioBrief: [String: Any]? = nil,
        causes: [[String: Any]] = [],
        problems: [[String: Any]] = [],
        vitals: [[String: Any]] = [],
        pulses: [[String: Any]] = [],
        recommendedInterventions: [[String: Any]] = [],
        interventions: [[String: Any]] = [],
        assessmentFindings: [[String: Any]] = [],
        diagnosticResults: [[String: Any]] = [],
        resources: [[String: Any]] = [],
        disposition: [String: Any]? = nil,
        patientStatus: [String: Any] = [:],
        aiPlan: [String: Any]? = nil,
    ) throws -> TrainerRuntimeStateOut {
        let payload: [String: Any] = [
            "simulation_id": 420,
            "session_id": 420,
            "status": status,
            "state_revision": stateRevision,
            "active_elapsed_seconds": 0,
            "tick_interval_seconds": 15,
            "next_tick_at": NSNull(),
            "scenario_brief": scenarioBrief ?? NSNull(),
            "current_snapshot": [
                "causes": causes,
                "problems": problems,
                "recommended_interventions": recommendedInterventions,
                "interventions": interventions,
                "assessment_findings": assessmentFindings,
                "diagnostic_results": diagnosticResults,
                "resources": resources,
                "disposition": disposition ?? (NSNull() as Any),
                "vitals": vitals,
                "pulses": pulses,
                "patient_status": patientStatus,
            ],
            "ai_plan": aiPlan ?? NSNull(),
            "ai_rationale_notes": [],
            "pending_runtime_reasons": [],
            "pending_reasons": [],
            "currently_processing_reasons": [],
            "last_runtime_error": "",
            "last_ai_tick_at": NSNull(),
        ]

        return try decodeRuntimeStatePayload(payload)
    }

    private func decodeRuntimeStatePayload(_ payload: [String: Any]) throws -> TrainerRuntimeStateOut {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TrainerRuntimeStateOut.self, from: data)
    }

    private func makeAliasedSessionRuntimeSeed() -> [String: JSONValue] {
        [
            "scenario_brief": .object([
                "read_aloud_brief": .string("Patrol medic called to blast injury."),
                "environment": .string("Night operation"),
            ]),
            "injuries": .array([
                .object([
                    "cause_id": .number(11),
                    "kind": .string("injury"),
                    "title": .string("Blast Injury"),
                    "description": .string("Open wound to the left arm"),
                    "injury_location": .string("LEFT_ARM"),
                ]),
            ]),
            "conditions": .array([
                .object([
                    "problem_id": .number(21),
                    "title": .string("Hemorrhagic Shock"),
                    "status": .string("active"),
                    "cause_id": .number(11),
                    "anatomical_location": .string("LEFT_ARM"),
                ]),
            ]),
            "interventions": .array([
                .object([
                    "intervention_id": .number(31),
                    "kind": .string("tourniquet"),
                    "title": .string("Tourniquet"),
                    "site_code": .string("LEFT_ARM"),
                    "target_problem_id": .number(21),
                ]),
            ]),
            "pulses": .array([
                .object([
                    "location": .string("radial_left"),
                    "present": .bool(false),
                    "quality": .string("weak"),
                ]),
            ]),
            "vitals": .array([
                .object([
                    "vital_type": .string("heart_rate"),
                    "min_value": .number(120),
                    "max_value": .number(140),
                ]),
            ]),
            "patient_status": .object([
                "avpu": .string("verbal"),
                "narrative": .string("Increasing respiratory distress."),
                "respiratory_distress": .bool(true),
            ]),
            "ai_instructor": .object([
                "summary": .string("Escalate respiratory distress"),
                "upcoming_changes": .array([.string("Decrease SpO2")]),
            ]),
        ]
    }

    private func makeLifecycleEvent(
        eventID: String,
        eventType: String,
        createdAt: Date,
    ) -> EventEnvelope {
        EventEnvelope(
            eventID: eventID,
            eventType: eventType,
            createdAt: createdAt,
            correlationID: nil,
            payload: [:],
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
