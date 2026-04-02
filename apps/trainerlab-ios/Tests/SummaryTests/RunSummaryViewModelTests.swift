import Foundation
import Networking
import SharedModels
@testable import Summary
import XCTest

private enum SummaryMockError: Error {
    case unused
}

private final class MockSummaryService: TrainerLabServiceProtocol, @unchecked Sendable {
    var getRunSummaryCalls: [Int] = []
    var getRunSummaryResult: Result<RunSummary, Error> = .failure(SummaryMockError.unused)

    func accessMe() async throws -> LabAccess {
        throw SummaryMockError.unused
    }

    func listSessions(limit _: Int, cursor _: String?, status _: String?, query _: String?) async throws -> PaginatedResponse<TrainerSessionDTO> {
        throw SummaryMockError.unused
    }

    func createSession(request _: TrainerSessionCreateRequest, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw SummaryMockError.unused
    }

    func getSession(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw SummaryMockError.unused
    }

    func retryInitialSimulation(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw SummaryMockError.unused
    }

    func getRuntimeState(simulationID _: Int) async throws -> TrainerRuntimeStateOut {
        throw SummaryMockError.unused
    }

    func getControlPlaneDebug(simulationID _: Int) async throws -> ControlPlaneDebugOut {
        throw SummaryMockError.unused
    }

    func runCommand(simulationID _: Int, command _: RunCommand, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw SummaryMockError.unused
    }

    func triggerRunTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func triggerVitalsTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<EventEnvelope> {
        throw SummaryMockError.unused
    }

    func getRunSummary(simulationID: Int) async throws -> RunSummary {
        getRunSummaryCalls.append(simulationID)
        return try getRunSummaryResult.get()
    }

    func adjustSimulation(simulationID _: Int, request _: SimulationAdjustRequest, idempotencyKey _: String) async throws -> SimulationAdjustAck {
        throw SummaryMockError.unused
    }

    func steerPrompt(simulationID _: Int, request _: SteerPromptRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func injectInjuryEvent(simulationID _: Int, request _: InjuryEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func injectIllnessEvent(simulationID _: Int, request _: IllnessEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func createProblem(simulationID _: Int, request _: ProblemCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func createAssessmentFinding(simulationID _: Int, request _: AssessmentFindingCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func createDiagnosticResult(simulationID _: Int, request _: DiagnosticResultCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func createResourceState(simulationID _: Int, request _: ResourceStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func createDispositionState(simulationID _: Int, request _: DispositionStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func injectVitalEvent(simulationID _: Int, request _: VitalEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func injectInterventionEvent(simulationID _: Int, request _: InterventionEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func listPresets(limit _: Int, cursor _: String?) async throws -> PaginatedResponse<ScenarioInstruction> {
        throw SummaryMockError.unused
    }

    func createPreset(request _: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction {
        throw SummaryMockError.unused
    }

    func getPreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw SummaryMockError.unused
    }

    func updatePreset(presetID _: Int, request _: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction {
        throw SummaryMockError.unused
    }

    func deletePreset(presetID _: Int) async throws {
        throw SummaryMockError.unused
    }

    func duplicatePreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw SummaryMockError.unused
    }

    func sharePreset(presetID _: Int, request _: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission {
        throw SummaryMockError.unused
    }

    func unsharePreset(presetID _: Int, request _: ScenarioInstructionUnshareRequest) async throws {
        throw SummaryMockError.unused
    }

    func applyPreset(presetID _: Int, request _: ScenarioInstructionApplyRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func injuryDictionary() async throws -> InjuryDictionary {
        throw SummaryMockError.unused
    }

    func interventionDictionary() async throws -> [InterventionGroup] {
        throw SummaryMockError.unused
    }

    func listAccounts(query _: String, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<AccountListUser> {
        throw SummaryMockError.unused
    }

    func updateProblemStatus(simulationID _: Int, problemID _: Int, request _: ProblemStatusUpdateRequest, idempotencyKey _: String) async throws -> ProblemStatusOut {
        throw SummaryMockError.unused
    }

    func createNoteEvent(simulationID _: Int, request _: SimulationNoteCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw SummaryMockError.unused
    }

    func createAnnotation(simulationID _: Int, request _: AnnotationCreateRequest, idempotencyKey _: String) async throws -> AnnotationOut {
        throw SummaryMockError.unused
    }

    func listAnnotations(simulationID _: Int) async throws -> [AnnotationOut] {
        throw SummaryMockError.unused
    }

    func updateScenarioBrief(simulationID _: Int, request _: ScenarioBriefUpdateRequest, idempotencyKey _: String) async throws -> ScenarioBriefOut {
        throw SummaryMockError.unused
    }

    func replayPending(endpoint _: String, method _: String, body _: Data?, idempotencyKey _: String) async throws {
        throw SummaryMockError.unused
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO { throw SummaryMockError.unused }
    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO { throw SummaryMockError.unused }
}

@MainActor
final class RunSummaryViewModelTests: XCTestCase {
    func testLoadMaps404ToNotReadyState() async {
        let service = MockSummaryService()
        service.getRunSummaryResult = .failure(APIClientError.http(statusCode: 404, detail: "Not ready", correlationID: nil))
        let viewModel = RunSummaryViewModel(service: service, simulationID: 420)

        await viewModel.load()

        XCTAssertEqual(service.getRunSummaryCalls, [420])
        XCTAssertEqual(viewModel.notReadyMessage, RunSummaryViewModel.notReadyCopy)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.summary)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadKeepsNon404FailuresFatal() async {
        let service = MockSummaryService()
        service.getRunSummaryResult = .failure(APIClientError.http(statusCode: 500, detail: "Boom", correlationID: nil))
        let viewModel = RunSummaryViewModel(service: service, simulationID: 420)

        await viewModel.load()

        XCTAssertEqual(service.getRunSummaryCalls, [420])
        XCTAssertNil(viewModel.notReadyMessage)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.summary)
        XCTAssertFalse(viewModel.isLoading)
    }
}
