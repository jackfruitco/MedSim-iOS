import Foundation
import Networking

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public var invitationToken = ""
    @Published public private(set) var isLoading = false
    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var pendingAppleSignup: PendingAppleSignup?

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

        beginLoading()
        defer { isLoading = false }

        do {
            _ = try await authService.signIn(email: email, password: password)
            try await finishAuthenticatedSession()
        } catch {
            handleAuthFailure(error)
        }
    }

    public func signInWithApple(_ credential: AppleSignInCredential) async {
        beginLoading()
        defer { isLoading = false }

        do {
            let result = try await authService.signInWithApple(
                credential: credential,
                invitationToken: normalizedInvitationToken()
            )
            switch result {
            case .authenticated:
                pendingAppleSignup = nil
                try await finishAuthenticatedSession()
            case let .profileCompletionRequired(pendingSignup):
                pendingAppleSignup = pendingSignup
                isAuthenticated = false
            }
        } catch {
            handleAuthFailure(error)
        }
    }

    public func completeAppleSignup(roleID: Int?, givenName: String, familyName: String) async {
        guard let pendingAppleSignup else {
            errorMessage = "Apple signup session is missing."
            return
        }
        guard let roleID else {
            errorMessage = "Role is required."
            return
        }
        guard !givenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            errorMessage = "First name and last name are required."
            return
        }

        beginLoading()
        defer { isLoading = false }

        do {
            _ = try await authService.completeAppleSignup(
                pendingSignup: pendingAppleSignup,
                roleID: roleID,
                givenName: givenName.trimmingCharacters(in: .whitespacesAndNewlines),
                familyName: familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            self.pendingAppleSignup = nil
            try await finishAuthenticatedSession()
        } catch {
            handleAuthFailure(error)
        }
    }

    public func cancelAppleSignup() {
        pendingAppleSignup = nil
        errorMessage = nil
    }

    public func setErrorMessage(_ message: String?) {
        errorMessage = message
    }

    public func signOut() async {
        await authService.signOut()
        isAuthenticated = false
        email = ""
        password = ""
        invitationToken = ""
        errorMessage = nil
        pendingAppleSignup = nil
    }

    public func restoreSessionIfAvailable() async {
        guard authService.hasActiveTokens() else {
            isAuthenticated = false
            return
        }

        do {
            try await finishAuthenticatedSession()
        } catch {
            await authService.signOut()
            isAuthenticated = false
        }
    }

    private func beginLoading() {
        isLoading = true
        errorMessage = nil
    }

    private func finishAuthenticatedSession() async throws {
        _ = try await trainerService.accessMe()
        isAuthenticated = true
        errorMessage = nil
        pendingAppleSignup = nil
    }

    private func handleAuthFailure(_ error: Error) {
        isAuthenticated = false
        errorMessage = error.localizedDescription
    }

    private func normalizedInvitationToken() -> String? {
        let trimmed = invitationToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
