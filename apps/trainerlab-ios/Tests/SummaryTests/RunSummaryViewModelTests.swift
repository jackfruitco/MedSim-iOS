import Foundation
import Networking
import Persistence
import SharedModels
@testable import Summary
import XCTest

private enum SummaryMockError: Error {
    case unused
}

private final class MockSummaryService: TrainerLabServiceProtocol, @unchecked Sendable {
    var getRunSummaryCalls: [Int] = []
    var getRunSummaryResult: Result<RunSummary, Error> = .failure(SummaryMockError.unused)
    var getRunSummaryResults: [Result<RunSummary, Error>] = []
    var replayKeys: [String] = []
    var replayBodies: [Data?] = []
    var replayError: Error?
    var firstSummaryContinuation: CheckedContinuation<RunSummary, Error>?
    var suspendFirstSummary = false

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

    func getRuntimeState(simulationID _: Int) async throws -> TrainerRestViewModelDTO {
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
        if suspendFirstSummary, getRunSummaryCalls.count == 1 {
            return try await withCheckedThrowingContinuation { firstSummaryContinuation = $0 }
        }
        if !getRunSummaryResults.isEmpty {
            return try getRunSummaryResults.removeFirst().get()
        }
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

    func replayPending(endpoint _: String, method _: String, body: Data?, idempotencyKey: String) async throws {
        replayKeys.append(idempotencyKey)
        replayBodies.append(body)
        if let replayError {
            throw replayError
        }
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        throw SummaryMockError.unused
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        throw SummaryMockError.unused
    }
}

@MainActor
final class RunSummaryViewModelTests: XCTestCase {
    func testObservationStopsAtBoundAndPreservesAvailableSummary() async {
        let service = MockSummaryService()
        service.getRunSummaryResult = .success(makeSummary())
        let viewModel = RunSummaryViewModel(service: service, simulationID: 420)
        await viewModel.loadUntilReady(maxAttempts: 3, delayNanoseconds: 0)
        XCTAssertEqual(service.getRunSummaryCalls.count, 3)
        XCTAssertNotNil(viewModel.summary)
        XCTAssertFalse(viewModel.isWaitingForDebrief)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testObservationFollowsNotReadyThroughCompletedDebrief() async throws {
        let debrief = try JSONDecoder().decode(RunDebriefOutput.self, from: Data(#"{"narrative_summary":"Completed", "strengths":[], "misses":[], "deterioration_timeline":[], "teaching_points":[], "overall_assessment":"Reviewed"}"#.utf8))
        let service = MockSummaryService()
        service.getRunSummaryResults = [
            .failure(APIClientError.http(statusCode: 404, detail: "Not ready", correlationID: nil)),
            .success(makeSummary()),
            .success(makeSummary(debrief: debrief)),
        ]
        let viewModel = RunSummaryViewModel(service: service, simulationID: 420)
        await viewModel.loadUntilReady(maxAttempts: 5, delayNanoseconds: 0)
        XCTAssertEqual(service.getRunSummaryCalls.count, 3)
        XCTAssertEqual(viewModel.summary?.aiDebrief?.narrativeSummary, "Completed")
        XCTAssertNil(viewModel.notReadyMessage)
        XCTAssertFalse(viewModel.isWaitingForDebrief)
    }

    func testCancelledObservationDoesNotFetch() async {
        let service = MockSummaryService()
        let viewModel = RunSummaryViewModel(service: service, simulationID: 420)
        let task = Task { await viewModel.loadUntilReady() }
        task.cancel()
        await task.value
        XCTAssertTrue(service.getRunSummaryCalls.isEmpty)
        XCTAssertFalse(viewModel.isWaitingForDebrief)
    }

    private func makeSummary(debrief: RunDebriefOutput? = nil, status: String? = nil) -> RunSummary {
        RunSummary(
            simulationID: 420, status: "completed", runStartedAt: nil, runCompletedAt: nil,
            finalState: [:], eventTypeCounts: [:], timelineHighlights: [], commandLog: [],
            aiRationaleNotes: [], aiDebrief: debrief,
            evidenceRevision: "evidence-1", debriefStatus: status,
        )
    }

    func testExplicitFailureStopsPolling() async {
        let service = MockSummaryService()
        service.getRunSummaryResult = .success(makeSummary(status: "failed"))
        let model = RunSummaryViewModel(service: service, simulationID: 420)
        await model.loadUntilReady(maxAttempts: 5, delayNanoseconds: 0)
        XCTAssertEqual(service.getRunSummaryCalls.count, 1)
        XCTAssertFalse(model.isWaitingForDebrief)
    }

    func testOldResponseCannotReplaceNewerSummary() async {
        let service = MockSummaryService()
        service.suspendFirstSummary = true
        service.getRunSummaryResult = .success(makeSummary(status: "ready"))
        let model = RunSummaryViewModel(service: service, simulationID: 420)
        let oldLoad = Task { await model.load() }
        while service.firstSummaryContinuation == nil {
            await Task.yield()
        }
        await model.load()
        service.firstSummaryContinuation?.resume(returning: makeSummary(status: "generating"))
        await oldLoad.value
        XCTAssertEqual(model.summary?.debriefStatus, "ready")
    }

    func testPersistedCorrectionReplaysWithOriginalKeyAndBody() async throws {
        let service = MockSummaryService()
        service.getRunSummaryResult = .success(makeSummary(status: "generating"))
        let queue = InMemoryCommandQueueStore()
        let body = try JSONEncoder().encode(DebriefReviewRequest(evidenceRevision: "evidence-1", correction: "Learner reassessed"))
        let envelope = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/summary/review/", method: "POST", body: body,
            simulationID: 420, accountUUID: "account-1",
        )
        try await queue.enqueue(envelope)
        let restored = RunSummaryViewModel(service: service, simulationID: 420, commandQueue: queue, accountUUID: "account-1")
        await restored.loadUntilReady(maxAttempts: 1, delayNanoseconds: 0)
        XCTAssertEqual(service.replayKeys, [envelope.idempotencyKey])
        XCTAssertEqual(service.replayBodies.first, body)
        XCTAssertFalse(restored.hasQueuedReview)
    }

    func testRejectedCorrectionIsPreservedForEditing() async {
        let service = MockSummaryService()
        service.getRunSummaryResult = .success(makeSummary(status: "ready"))
        service.replayError = APIClientError.http(statusCode: 409, detail: "Evidence changed", correlationID: nil)
        let model = RunSummaryViewModel(service: service, simulationID: 420)
        await model.load()
        await model.submitReview(correction: "Learner reassessed")
        XCTAssertEqual(model.rejectedCorrection, "Learner reassessed")
        XCTAssertNotNil(model.reviewError)
        XCTAssertFalse(model.hasQueuedReview)
    }

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
