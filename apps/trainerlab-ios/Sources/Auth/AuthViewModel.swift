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
    @Published public private(set) var errorMessage: String?

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

    public func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await authService.signIn(email: email, password: password)
            try await sessionBootstrapper.bootstrapSession()
            isAuthenticated = true
        } catch {
            await authService.signOut()
            await sessionBootstrapper.clearSession()
            isAuthenticated = false
            errorMessage = error.localizedDescription
        }
    }

    public func signOut() async {
        await authService.signOut()
        await sessionBootstrapper.clearSession()
        isAuthenticated = false
        email = ""
        password = ""
        errorMessage = nil
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
