import Foundation
import Networking

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public private(set) var isLoading = false
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var errorMessage: String?

    private let authService: AuthServiceProtocol
    private let trainerService: TrainerLabServiceProtocol

    public init(authService: AuthServiceProtocol, trainerService: TrainerLabServiceProtocol) {
        self.authService = authService
        self.trainerService = trainerService
        isAuthenticated = authService.hasActiveTokens()
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
            _ = try await trainerService.accessMe()
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            errorMessage = error.localizedDescription
        }
    }

    public func signOut() {
        authService.signOut()
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
            _ = try await trainerService.accessMe()
            isAuthenticated = true
        } catch {
            authService.signOut()
            isAuthenticated = false
        }
    }
}
