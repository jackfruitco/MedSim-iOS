import Foundation
import Persistence
import SharedModels

public protocol AuthServiceProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> AuthTokens
    func signOut()
    func hasActiveTokens() -> Bool
}

public final class AuthService: AuthServiceProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let tokenProvider: AuthTokenProvider

    public init(apiClient: APIClientProtocol, tokenProvider: AuthTokenProvider) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    public func signIn(email: String, password: String) async throws -> AuthTokens {
        let payload = try JSONEncoder().encode(["email": email, "password": password])
        let endpoint = Endpoint(
            path: "/api/v1/auth/token/",
            method: .post,
            body: payload,
            requiresAuth: false,
        )
        let tokens: AuthTokens = try await apiClient.request(endpoint, as: AuthTokens.self)
        tokenProvider.saveTokens(tokens)
        return tokens
    }

    public func signOut() {
        tokenProvider.clearTokens()
    }

    public func hasActiveTokens() -> Bool {
        tokenProvider.loadTokens() != nil
    }
}
