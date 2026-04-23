import Networking
@testable import Sessions
import SharedModels
import XCTest

private enum StubError: Error { case sentinel }

private final class StubTrainerLabService: TrainerLabServiceProtocol, @unchecked Sendable {
    var listSessionsResult: Result<PaginatedResponse<TrainerSessionDTO>, Error> = .success(
        PaginatedResponse(items: [], nextCursor: nil, hasMore: false),
    )
    var listSessionsCallCount = 0

    func listSessions(limit _: Int, cursor _: String?, status _: String?, query _: String?) async throws -> PaginatedResponse<TrainerSessionDTO> {
        listSessionsCallCount += 1
        return try listSessionsResult.get()
    }

    func accessMe() async throws -> LabAccess {
        throw StubError.sentinel
    }

    func createSession(request _: TrainerSessionCreateRequest, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw StubError.sentinel
    }

    func getSession(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw StubError.sentinel
    }

    func retryInitialSimulation(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw StubError.sentinel
    }

    func getRuntimeState(simulationID _: Int) async throws -> TrainerRestViewModelDTO {
        throw StubError.sentinel
    }

    func getControlPlaneDebug(simulationID _: Int) async throws -> ControlPlaneDebugOut {
        throw StubError.sentinel
    }

    func runCommand(simulationID _: Int, command _: RunCommand, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw StubError.sentinel
    }

    func triggerRunTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func triggerVitalsTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<EventEnvelope> {
        throw StubError.sentinel
    }

    func getRunSummary(simulationID _: Int) async throws -> RunSummary {
        throw StubError.sentinel
    }

    func adjustSimulation(simulationID _: Int, request _: SimulationAdjustRequest, idempotencyKey _: String) async throws -> SimulationAdjustAck {
        throw StubError.sentinel
    }

    func steerPrompt(simulationID _: Int, request _: SteerPromptRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func injectInjuryEvent(simulationID _: Int, request _: InjuryEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func injectIllnessEvent(simulationID _: Int, request _: IllnessEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func createProblem(simulationID _: Int, request _: ProblemCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func createAssessmentFinding(simulationID _: Int, request _: AssessmentFindingCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func createDiagnosticResult(simulationID _: Int, request _: DiagnosticResultCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func createResourceState(simulationID _: Int, request _: ResourceStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func createDispositionState(simulationID _: Int, request _: DispositionStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func injectVitalEvent(simulationID _: Int, request _: VitalEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func injectInterventionEvent(simulationID _: Int, request _: InterventionEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func listPresets(limit _: Int, cursor _: String?) async throws -> PaginatedResponse<ScenarioInstruction> {
        throw StubError.sentinel
    }

    func createPreset(request _: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction {
        throw StubError.sentinel
    }

    func getPreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw StubError.sentinel
    }

    func updatePreset(presetID _: Int, request _: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction {
        throw StubError.sentinel
    }

    func deletePreset(presetID _: Int) async throws {
        throw StubError.sentinel
    }

    func duplicatePreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw StubError.sentinel
    }

    func sharePreset(presetID _: Int, request _: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission {
        throw StubError.sentinel
    }

    func unsharePreset(presetID _: Int, request _: ScenarioInstructionUnshareRequest) async throws {
        throw StubError.sentinel
    }

    func applyPreset(presetID _: Int, request _: ScenarioInstructionApplyRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func injuryDictionary() async throws -> InjuryDictionary {
        throw StubError.sentinel
    }

    func interventionDictionary() async throws -> [InterventionGroup] {
        throw StubError.sentinel
    }

    func listAccounts(query _: String, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<AccountListUser> {
        throw StubError.sentinel
    }

    func updateProblemStatus(simulationID _: Int, problemID _: Int, request _: ProblemStatusUpdateRequest, idempotencyKey _: String) async throws -> ProblemStatusOut {
        throw StubError.sentinel
    }

    func createNoteEvent(simulationID _: Int, request _: SimulationNoteCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw StubError.sentinel
    }

    func createAnnotation(simulationID _: Int, request _: AnnotationCreateRequest, idempotencyKey _: String) async throws -> AnnotationOut {
        throw StubError.sentinel
    }

    func listAnnotations(simulationID _: Int) async throws -> [AnnotationOut] {
        throw StubError.sentinel
    }

    func updateScenarioBrief(simulationID _: Int, request _: ScenarioBriefUpdateRequest, idempotencyKey _: String) async throws -> ScenarioBriefOut {
        throw StubError.sentinel
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        throw StubError.sentinel
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        throw StubError.sentinel
    }

    func replayPending(endpoint _: String, method _: String, body _: Data?, idempotencyKey _: String) async throws {
        throw StubError.sentinel
    }
}

@MainActor
final class SessionHubViewModelTests: XCTestCase {
    func testLoadSessions_populatesSessions() async {
        let service = StubTrainerLabService()
        let session = makeSession()
        service.listSessionsResult = .success(PaginatedResponse(items: [session], nextCursor: nil, hasMore: false))
        let vm = SessionHubViewModel(service: service)

        await vm.loadSessions()

        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.sessions.first?.simulationID, session.simulationID)
        XCTAssertEqual(service.listSessionsCallCount, 1)
    }

    func testLoadSessions_replacesStaleData() async {
        let service = StubTrainerLabService()
        let old = makeSession(simulationID: 1)
        let new = makeSession(simulationID: 2)

        service.listSessionsResult = .success(PaginatedResponse(items: [old], nextCursor: nil, hasMore: false))
        let vm = SessionHubViewModel(service: service)
        await vm.loadSessions()
        XCTAssertEqual(vm.sessions.first?.simulationID, 1)

        service.listSessionsResult = .success(PaginatedResponse(items: [new], nextCursor: nil, hasMore: false))
        await vm.loadSessions()

        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.sessions.first?.simulationID, 2)
    }

    func testLoadSessions_isLoadingFalseAfterSuccess() async {
        let service = StubTrainerLabService()
        service.listSessionsResult = .success(PaginatedResponse(items: [], nextCursor: nil, hasMore: false))
        let vm = SessionHubViewModel(service: service)

        await vm.loadSessions()

        XCTAssertFalse(vm.isLoading)
    }

    func testLoadSessions_setsErrorOnFailure() async {
        let service = StubTrainerLabService()
        service.listSessionsResult = .failure(NSError(domain: "test", code: 42))
        let vm = SessionHubViewModel(service: service)

        await vm.loadSessions()

        XCTAssertNotNil(vm.presentableError)
        XCTAssertFalse(vm.isLoading)
    }

    func testLoadSessions_clearsErrorBeforeRetry() async {
        let service = StubTrainerLabService()
        service.listSessionsResult = .failure(NSError(domain: "test", code: 1))
        let vm = SessionHubViewModel(service: service)
        await vm.loadSessions()
        XCTAssertNotNil(vm.presentableError)

        service.listSessionsResult = .success(PaginatedResponse(items: [], nextCursor: nil, hasMore: false))
        await vm.loadSessions()

        XCTAssertNil(vm.presentableError)
    }
}

private func makeSession(simulationID: Int = 99) -> TrainerSessionDTO {
    TrainerSessionDTO(
        simulationID: simulationID,
        status: .seeded,
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
        terminalReasonCode: nil,
        terminalReasonText: nil,
        retryable: nil,
    )
}
