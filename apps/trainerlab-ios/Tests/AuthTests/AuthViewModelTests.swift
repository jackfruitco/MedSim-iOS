@testable import Auth
import Foundation
import Networking
import SharedModels
import XCTest

private enum MockError: Error, LocalizedError {
    case signInFailed
    case appleSignInFailed
    case accessMeFailed

    var errorDescription: String? {
        switch self {
        case .signInFailed: "Sign in failed."
        case .appleSignInFailed: "Apple sign in failed."
        case .accessMeFailed: "Access check failed."
        }
    }
}

private final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    var signInResult: Result<AuthTokens, Error> = .success(
        AuthTokens(accessToken: "a", refreshToken: "r", expiresIn: 3600, tokenType: "Bearer")
    )
    var signInWithAppleResult: Result<AppleSignInResult, Error> = .success(
        .authenticated(
            AuthTokens(accessToken: "apple-a", refreshToken: "apple-r", expiresIn: 3600, tokenType: "Bearer")
        )
    )
    var completeAppleSignupResult: Result<AuthTokens, Error> = .success(
        AuthTokens(accessToken: "apple-a", refreshToken: "apple-r", expiresIn: 3600, tokenType: "Bearer")
    )
    var signOutCalled = false
    var hasActiveTokensValue = false

    func signIn(email _: String, password _: String) async throws -> AuthTokens {
        try signInResult.get()
    }

    func signInWithApple(
        credential _: AppleSignInCredential,
        invitationToken _: String?
    ) async throws -> AppleSignInResult {
        try signInWithAppleResult.get()
    }

    func completeAppleSignup(
        pendingSignup _: PendingAppleSignup,
        roleID _: Int,
        givenName _: String,
        familyName _: String
    ) async throws -> AuthTokens {
        try completeAppleSignupResult.get()
    }

    func signOut() async {
        signOutCalled = true
    }

    func hasActiveTokens() -> Bool {
        hasActiveTokensValue
    }
}

private func makeLabAccess() -> LabAccess {
    let json = Data(#"{"lab_slug":"test-lab","access_level":"trainer"}"#.utf8)
    do {
        return try JSONDecoder().decode(LabAccess.self, from: json)
    } catch {
        fatalError("Failed to decode mock LabAccess: \(error)")
    }
}

private final class MockTrainerLabService: TrainerLabServiceProtocol, @unchecked Sendable {
    var accessMeResult: Result<LabAccess, Error> = .success(makeLabAccess())

    func accessMe() async throws -> LabAccess {
        try accessMeResult.get()
    }

    func listSessions(limit _: Int, cursor _: String?, status _: String?, query _: String?) async throws -> PaginatedResponse<TrainerSessionDTO> {
        throw MockError.accessMeFailed
    }

    func createSession(request _: TrainerSessionCreateRequest, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw MockError.accessMeFailed
    }

    func getSession(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw MockError.accessMeFailed
    }

    func retryInitialSimulation(simulationID _: Int) async throws -> TrainerSessionDTO {
        throw MockError.accessMeFailed
    }

    func getRuntimeState(simulationID _: Int) async throws -> TrainerRuntimeStateOut {
        throw MockError.accessMeFailed
    }

    func getControlPlaneDebug(simulationID _: Int) async throws -> ControlPlaneDebugOut {
        throw MockError.accessMeFailed
    }

    func runCommand(simulationID _: Int, command _: RunCommand, idempotencyKey _: String) async throws -> TrainerSessionDTO {
        throw MockError.accessMeFailed
    }

    func triggerRunTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func triggerVitalsTick(simulationID _: Int, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func listEvents(simulationID _: Int, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<EventEnvelope> {
        throw MockError.accessMeFailed
    }

    func getRunSummary(simulationID _: Int) async throws -> RunSummary {
        throw MockError.accessMeFailed
    }

    func adjustSimulation(simulationID _: Int, request _: SimulationAdjustRequest, idempotencyKey _: String) async throws -> SimulationAdjustAck {
        throw MockError.accessMeFailed
    }

    func steerPrompt(simulationID _: Int, request _: SteerPromptRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func injectInjuryEvent(simulationID _: Int, request _: InjuryEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func injectIllnessEvent(simulationID _: Int, request _: IllnessEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func createProblem(simulationID _: Int, request _: ProblemCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func createAssessmentFinding(simulationID _: Int, request _: AssessmentFindingCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func createDiagnosticResult(simulationID _: Int, request _: DiagnosticResultCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func createResourceState(simulationID _: Int, request _: ResourceStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func createDispositionState(simulationID _: Int, request _: DispositionStateCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func injectVitalEvent(simulationID _: Int, request _: VitalEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func injectInterventionEvent(simulationID _: Int, request _: InterventionEventRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func listPresets(limit _: Int, cursor _: String?) async throws -> PaginatedResponse<ScenarioInstruction> {
        throw MockError.accessMeFailed
    }

    func createPreset(request _: ScenarioInstructionCreateRequest) async throws -> ScenarioInstruction {
        throw MockError.accessMeFailed
    }

    func getPreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw MockError.accessMeFailed
    }

    func updatePreset(presetID _: Int, request _: ScenarioInstructionUpdateRequest) async throws -> ScenarioInstruction {
        throw MockError.accessMeFailed
    }

    func deletePreset(presetID _: Int) async throws {
        throw MockError.accessMeFailed
    }

    func duplicatePreset(presetID _: Int) async throws -> ScenarioInstruction {
        throw MockError.accessMeFailed
    }

    func sharePreset(presetID _: Int, request _: ScenarioInstructionShareRequest) async throws -> ScenarioInstructionPermission {
        throw MockError.accessMeFailed
    }

    func unsharePreset(presetID _: Int, request _: ScenarioInstructionUnshareRequest) async throws {
        throw MockError.accessMeFailed
    }

    func applyPreset(presetID _: Int, request _: ScenarioInstructionApplyRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func injuryDictionary() async throws -> InjuryDictionary {
        throw MockError.accessMeFailed
    }

    func interventionDictionary() async throws -> [InterventionGroup] {
        throw MockError.accessMeFailed
    }

    func listAccounts(query _: String, cursor _: String?, limit _: Int) async throws -> PaginatedResponse<AccountListUser> {
        throw MockError.accessMeFailed
    }

    func updateProblemStatus(simulationID _: Int, problemID _: Int, request _: ProblemStatusUpdateRequest, idempotencyKey _: String) async throws -> ProblemStatusOut {
        throw MockError.accessMeFailed
    }

    func createNoteEvent(simulationID _: Int, request _: SimulationNoteCreateRequest, idempotencyKey _: String) async throws -> TrainerCommandAck {
        throw MockError.accessMeFailed
    }

    func createAnnotation(simulationID _: Int, request _: AnnotationCreateRequest, idempotencyKey _: String) async throws -> AnnotationOut {
        throw MockError.accessMeFailed
    }

    func listAnnotations(simulationID _: Int) async throws -> [AnnotationOut] {
        throw MockError.accessMeFailed
    }

    func updateScenarioBrief(simulationID _: Int, request _: ScenarioBriefUpdateRequest, idempotencyKey _: String) async throws -> ScenarioBriefOut {
        throw MockError.accessMeFailed
    }

    func replayPending(endpoint _: String, method _: String, body _: Data?, idempotencyKey _: String) async throws {}
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

    func testAppleSignInSuccessSetsAuthenticated() async {
        let vm = AuthViewModel(authService: MockAuthService(), trainerService: MockTrainerLabService())

        await vm.signInWithApple(
            AppleSignInCredential(identityToken: "token", authorizationCode: "code")
        )

        XCTAssertTrue(vm.isAuthenticated)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNil(vm.pendingAppleSignup)
        XCTAssertFalse(vm.isLoading)
    }

    func testAppleSignInProfileCompletionSetsPendingSignup() async {
        let authService = MockAuthService()
        authService.signInWithAppleResult = .success(
            .profileCompletionRequired(
                PendingAppleSignup(
                    signupToken: "signup-token",
                    email: "new@example.com",
                    givenName: "New",
                    familyName: "User",
                    roles: [AppleRoleOption(id: 1, title: "Instructor")]
                )
            )
        )
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())

        await vm.signInWithApple(
            AppleSignInCredential(identityToken: "token", authorizationCode: "code")
        )

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.pendingAppleSignup?.signupToken, "signup-token")
    }

    func testAppleSignInFailureSetsError() async {
        let authService = MockAuthService()
        authService.signInWithAppleResult = .failure(MockError.appleSignInFailed)
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())

        await vm.signInWithApple(
            AppleSignInCredential(identityToken: "token", authorizationCode: "code")
        )

        XCTAssertFalse(vm.isAuthenticated)
        XCTAssertEqual(vm.errorMessage, MockError.appleSignInFailed.localizedDescription)
    }

    func testCompleteAppleSignupSuccessSetsAuthenticated() async {
        let authService = MockAuthService()
        authService.signInWithAppleResult = .success(
            .profileCompletionRequired(
                PendingAppleSignup(
                    signupToken: "signup-token",
                    email: "new@example.com",
                    givenName: "New",
                    familyName: "User",
                    roles: [AppleRoleOption(id: 1, title: "Instructor")]
                )
            )
        )
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())

        await vm.signInWithApple(
            AppleSignInCredential(identityToken: "token", authorizationCode: "code")
        )
        await vm.completeAppleSignup(roleID: 1, givenName: "New", familyName: "User")

        XCTAssertTrue(vm.isAuthenticated)
        XCTAssertNil(vm.pendingAppleSignup)
        XCTAssertNil(vm.errorMessage)
    }

    func testCompleteAppleSignupWithoutRoleSetsError() async {
        let authService = MockAuthService()
        authService.signInWithAppleResult = .success(
            .profileCompletionRequired(
                PendingAppleSignup(
                    signupToken: "signup-token",
                    email: "new@example.com",
                    givenName: "New",
                    familyName: "User",
                    roles: [AppleRoleOption(id: 1, title: "Instructor")]
                )
            )
        )
        let vm = AuthViewModel(authService: authService, trainerService: MockTrainerLabService())

        await vm.signInWithApple(
            AppleSignInCredential(identityToken: "token", authorizationCode: "code")
        )
        await vm.completeAppleSignup(roleID: nil, givenName: "New", familyName: "User")

        XCTAssertEqual(vm.errorMessage, "Role is required.")
        XCTAssertFalse(vm.isAuthenticated)
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

        await vm.signOut()

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
