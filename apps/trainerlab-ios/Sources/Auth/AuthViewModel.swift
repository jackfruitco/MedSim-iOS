import Foundation
import Networking

private struct LegacyLabAccessBootstrapper: AuthSessionBootstrapper {
    let trainerService: TrainerLabServiceProtocol

    func bootstrapSession() async throws {
        _ = try await trainerService.accessMe()
    }

    func clearSession() async {}
}

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public private(set) var isLoading = false
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var presentableError: PresentableAppError?

    private let authService: AuthServiceProtocol
    private let sessionBootstrapper: AuthSessionBootstrapper

    public init(authService: AuthServiceProtocol, sessionBootstrapper: AuthSessionBootstrapper) {
        self.authService = authService
        self.sessionBootstrapper = sessionBootstrapper
        isAuthenticated = authService.hasActiveTokens()
    }

    public convenience init(authService: AuthServiceProtocol, trainerService: TrainerLabServiceProtocol) {
        self.init(
            authService: authService,
            sessionBootstrapper: LegacyLabAccessBootstrapper(trainerService: trainerService),
        )
    }

    public var errorMessage: String? {
        presentableError?.message
    }

    public func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            presentableError = PresentableAppError(
                title: "Sign In Required",
                message: "Email and password are required.",
            )
            return
        }

        isLoading = true
        presentableError = nil
        defer { isLoading = false }

        do {
            _ = try await authService.signIn(email: email, password: password)
            try await sessionBootstrapper.bootstrapSession()
            isAuthenticated = true
        } catch {
            await authService.signOut()
            await sessionBootstrapper.clearSession()
            isAuthenticated = false
            presentableError = AppErrorPresenter.present(error)
        }
    }

    public func signOut() async {
        await authService.signOut()
        await sessionBootstrapper.clearSession()
        isAuthenticated = false
        email = ""
        password = ""
        presentableError = nil
    }

    public func handleAuthorizationFailure(_ error: PresentableAppError?) async {
        await authService.signOut()
        await sessionBootstrapper.clearSession()
        isAuthenticated = false
        password = ""
        presentableError = error
    }

    public func restoreSessionIfAvailable() async {
        guard authService.hasActiveTokens() else {
            isAuthenticated = false
            return
        }

        do {
            try await sessionBootstrapper.bootstrapSession()
            isAuthenticated = true
        } catch {
            await authService.signOut()
            await sessionBootstrapper.clearSession()
            isAuthenticated = false
        }
    }
}
