import Foundation
import Networking
import SharedModels
@testable import Auth
import XCTest

private enum MockError: Error, LocalizedError {
    case signInFailed
    case accessMeFailed

    var errorDescription: String? {
        switch self {
        case .signInFailed: return "Sign in failed."
        case .accessMeFailed: return "Access check failed."
        }
    }
}

private final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    var signInResult: Result<AuthTokens, Error> = .success(
        AuthTokens(accessToken: "a", refreshToken: "r", expiresIn: 3600, tokenType: "Bearer")
    )
    var signOutCalled = false
    var hasActiveTokensValue = false

    func signIn(email: String, password: String) async throws -> AuthTokens {
        try signInResult.get()
    }

    func signOut() { signOutCalled = true }

    func hasActiveTokens() -> Bool { hasActiveTokensValue }
}

private func makeLabAccess() -> LabAccess {
    let json = Data(#"{"lab_slug":"test-lab","access_level":"trainer"}"#.utf8)
    return try! JSONDecoder().decode(LabAccess.self, from: json)
}

private final class MockTrainerLabService: TrainerLabServiceProtocol, @unchecked Sendable {
    var accessMeResult: Result<LabAccess, Error> = .success(makeLabAccess())

    func accessMe() async throws -> LabAccess { try accessMeResult.get() }
    func listSessions(limit: Int, cursor: String?, status: String?, query: String?) async throws -> PaginatedResponse<TrainerSessionDTO> { throw MockError.accessMeFailed }
    func createSession(request: TrainerSessionCreateRequest, idempotencyKey: String) async throws -> TrainerSessionDTO { throw MockError.accessMeFailed }
    func getSession(simulationID: Int) async throws -> TrainerSessionDTO { throw MockError.accessMeFailed }
    func getRuntimeState(simulationID: Int) async throws -> TrainerRuntimeStateOut { throw MockError.accessMeFailed }
    func runCommand(simulationID: Int, command: RunCommand, idempotencyKey: String) async throws -> TrainerSessionDTO { throw MockError.accessMeFailed }
    func listEvents(simulationID: Int, cursor: String?, limit: Int) async throws -> PaginatedResponse<EventEnvelope> { throw MockError.accessMeFailed }
    func getRunSummary(simulationID: Int) async throws -> RunSummary { throw MockError.accessMeFailed }
    func adjustSimulation(simulationID: Int, request: SimulationAdjustRequest, idempotencyKey: String) async throws -> SimulationAdjustAck { throw MockError.accessMeFailed }
    func steerPrompt(simulationID: Int, request: SteerPromptRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func injectInjuryEvent(simulationID: Int, request: InjuryEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func injectIllnessEvent(simulationID: Int, request: IllnessEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func createProblem(simulationID: Int, request: ProblemCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func createAssessmentFinding(simulationID: Int, request: AssessmentFindingCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func createDiagnosticResult(simulationID: Int, request: DiagnosticResultCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func createResourceState(simulationID: Int, request: ResourceStateCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func createDispositionState(simulationID: Int, request: DispositionStateCreateRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func injectVitalEvent(simulationID: Int, request: VitalEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func injectInterventionEvent(simulationID: Int, request: InterventionEventRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func listPresets(limit: Int, cursor: String?) async throws -> PaginatedResponse<ScenarioInstruction> { throw MockError.accessMeFailed }
    func createPreset(request: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction { throw MockError.accessMeFailed }
    func getPreset(presetID: Int) async throws -> ScenarioInstruction { throw MockError.accessMeFailed }
    func updatePreset(presetID: Int, request: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction { throw MockError.accessMeFailed }
    func deletePreset(presetID: Int) async throws { throw MockError.accessMeFailed }
    func duplicatePreset(presetID: Int) async throws -> ScenarioInstruction { throw MockError.accessMeFailed }
    func sharePreset(presetID: Int, request: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission { throw MockError.accessMeFailed }
    func unsharePreset(presetID: Int, request: ScenarioInstructionUnshareRequest) async throws { throw MockError.accessMeFailed }
    func applyPreset(presetID: Int, request: ScenarioInstructionApplyRequest, idempotencyKey: String) async throws -> TrainerCommandAck { throw MockError.accessMeFailed }
    func injuryDictionary() async throws -> InjuryDictionary { throw MockError.accessMeFailed }
    func interventionDictionary() async throws -> [InterventionGroup] { throw MockError.accessMeFailed }
    func listAccounts(query: String, cursor: String?, limit: Int) async throws -> PaginatedResponse<AccountListUser> { throw MockError.accessMeFailed }
    func updateProblemStatus(simulationID: Int, problemID: Int, request: ProblemStatusUpdateRequest, idempotencyKey: String) async throws -> ProblemStatusOut { throw MockError.accessMeFailed }
    func createAnnotation(simulationID: Int, request: AnnotationCreateRequest, idempotencyKey: String) async throws -> AnnotationOut { throw MockError.accessMeFailed }
    func listAnnotations(simulationID: Int) async throws -> [AnnotationOut] { throw MockError.accessMeFailed }
    func updateScenarioBrief(simulationID: Int, request: ScenarioBriefUpdateRequest, idempotencyKey: String) async throws -> ScenarioBriefOut { throw MockError.accessMeFailed }
    func replayPending(endpoint: String, method: String, body: Data?, idempotencyKey: String) async throws {}
}

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testSignInEmptyEmailSetsError() async {
        let vm = AuthViewModel(authService: MockAuthService(), trainerService: MockTrainerLabService())
        vm.email = ""
        vm.password = "password"
        await vm.signIn()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isAuthenticated)
    }

    func testSignInEmptyPasswordSetsError() async {
        let vm = AuthViewModel(authService: MockAuthService(), trainerService: MockTrainerLabService())
        vm.email = "user@example.com"
        vm.password = ""
        await vm.signIn()
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isAuthenticated)
    }

    func testSignInSuccessSetsAuthenticated() async {
        let authService = MockAuthService()
        let trainerService = MockTrainerLabService()
        let vm = AuthViewModel(authService: authService, trainerService: trainerService)

        vm.email = "user@example.com"
        vm.password = "secret"
        await vm.signIn()

        XCTAssertTrue(vm.isAuthenticated)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func testSignInAuthFailureSetsError() async {
        let authService = MockAuthService()
        authService.signInResult = .failure(MockError.signInFailed)
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())

        vm.email = "user@example.com"
        vm.password = "wrong"
        await vm.signIn()

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.errorMessage, MockError.signInFailed.localizedDescription)
    }

    func testSignInTrainerAccessFailureSetsError() async {
        let authService = MockAuthService()
        let trainerService = MockTrainerLabService()
        trainerService.accessMeResult = .failure(MockError.accessMeFailed)
        let vm = AuthViewModel(authService: authService, trainerService: trainerService)

        vm.email = "user@example.com"
        vm.password = "secret"
        await vm.signIn()

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSignInClearsIsLoadingAfterCompletion() async {
        let vm = AuthViewModel(authService: MockAuthService(), trainerService: MockTrainerLabService())
        vm.email = "user@example.com"
        vm.password = "secret"
        await vm.signIn()
        XCTAssertFalse(vm.isLoading)
    }

    func testSignOutClearsAuthState() async {
        let authService = MockAuthService()
        authService.hasActiveTokensValue = true
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())
        // Manually drive to authenticated state
        vm.email = "user@example.com"
        vm.password = "secret"
        await vm.signIn()
        XCTAssertTrue(vm.isAuthenticated)

        vm.signOut()

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertTrue(vm.email.isEmpty)
        XCTAssertTrue(vm.password.isEmpty)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(authService.signOutCalled)
    }

    func testRestoreWithNoTokensStaysUnauthenticated() async {
        let authService = MockAuthService()
        authService.hasActiveTokensValue = false
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())

        await vm.restoreSessionIfAvailable()

        XCTAssertFalse(vm.isAuthenticated)
    }

    func testRestoreWithValidTokensSetsAuthenticated() async {
        let authService = MockAuthService()
        authService.hasActiveTokensValue = true
        let trainerService = MockTrainerLabService()
        let vm = AuthViewModel(authService: authService, trainerService: trainerService)

        await vm.restoreSessionIfAvailable()

        XCTAssertTrue(vm.isAuthenticated)
    }

    func testRestoreWithTokensButExpiredSessionSignsOut() async {
        let authService = MockAuthService()
        authService.hasActiveTokensValue = true
        let trainerService = MockTrainerLabService()
        trainerService.accessMeResult = .failure(MockError.accessMeFailed)
        let vm = AuthViewModel(authService: authService, trainerService: trainerService)

        await vm.restoreSessionIfAvailable()

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertTrue(authService.signOutCalled)
    }

    func testInitSetsAuthenticatedFromTokens() {
        let authService = MockAuthService()
        authService.hasActiveTokensValue = true
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())
        XCTAssertTrue(vm.isAuthenticated)
    }

    func testInitUnauthenticatedWhenNoTokens() {
        let authService = MockAuthService()
        authService.hasActiveTokensValue = false
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())
        XCTAssertFalse(vm.isAuthenticated)
    }
}
