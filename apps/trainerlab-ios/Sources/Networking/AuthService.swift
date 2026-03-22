import Foundation
import Persistence
import SharedModels

public protocol AuthServiceProtocol: Sendable {
    func signIn(email: String, password: String) async throws -> AuthTokens
    func signInWithApple(
        credential: AppleSignInCredential,
        invitationToken: String?,
    ) async throws -> AppleSignInResult
    func completeAppleSignup(
        pendingSignup: PendingAppleSignup,
        roleID: Int,
        givenName: String,
        familyName: String,
    ) async throws -> AuthTokens
    func signOut() async
    func hasActiveTokens() -> Bool
}

public final class AuthService: AuthServiceProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let tokenProvider: AuthTokenProvider
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

    public func signInWithApple(
        credential: AppleSignInCredential,
        invitationToken: String?,
    ) async throws -> AppleSignInResult {
        let payload = AppleTokenRequest(
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode,
            givenName: credential.givenName,
            familyName: credential.familyName,
            invitationToken: invitationToken,
        )
        let endpoint = try Endpoint(
            path: "/api/v1/auth/apple/",
            method: .post,
            body: encoder.encode(payload),
            requiresAuth: false,
        )
        let response = try await apiClient.perform(endpoint)

        switch response.statusCode {
        case 200:
            let tokens = try decode(AuthTokens.self, from: response.data)
            tokenProvider.saveTokens(tokens)
            return .authenticated(tokens)
        case 409:
            let completion = try decode(AppleProfileCompletionEnvelope.self, from: response.data)
            return .profileCompletionRequired(
                PendingAppleSignup(
                    signupToken: completion.signupToken,
                    email: completion.email,
                    givenName: completion.givenName,
                    familyName: completion.familyName,
                    roles: completion.roles,
                ),
            )
        default:
            throw mapAuthError(from: response)
        }
    }

    public func completeAppleSignup(
        pendingSignup: PendingAppleSignup,
        roleID: Int,
        givenName: String,
        familyName: String,
    ) async throws -> AuthTokens {
        let payload = AppleCompleteSignupRequest(
            signupToken: pendingSignup.signupToken,
            roleID: roleID,
            givenName: givenName,
            familyName: familyName,
        )
        let endpoint = try Endpoint(
            path: "/api/v1/auth/apple/complete-signup/",
            method: .post,
            body: encoder.encode(payload),
            requiresAuth: false,
        )
        let response = try await apiClient.perform(endpoint)

        guard response.statusCode == 200 else {
            throw mapAuthError(from: response)
        }

        let tokens = try decode(AuthTokens.self, from: response.data)
        tokenProvider.saveTokens(tokens)
        return tokens
    }

    public func signOut() async {
        if let tokens = tokenProvider.loadTokens(),
           let payload = try? JSONEncoder().encode(["refresh_token": tokens.refreshToken])
        {
            let endpoint = Endpoint(
                path: "/api/v1/auth/logout/",
                method: .post,
                body: payload,
                requiresAuth: false,
            )
            _ = try? await apiClient.requestData(endpoint)
        }
        tokenProvider.clearTokens()
    }

    public func hasActiveTokens() -> Bool {
        tokenProvider.loadTokens() != nil
    }

    private func decode<T: Decodable>(_: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AuthServiceError.invalidAppleResponse
        }
    }

    private func mapAuthError(from response: HTTPResponseData) -> AuthServiceError {
        if let payload = try? decoder.decode(APIErrorPayload.self, from: response.data) {
            switch payload.type {
            case "invalid_apple_credential":
                return .invalidAppleCredential
            case "invitation_required":
                return .invitationRequired
            case "invitation_email_mismatch":
                return .invitationEmailMismatch
            case "account_conflict":
                return .accountConflict(payload.detail)
            default:
                return .api(
                    statusCode: response.statusCode,
                    detail: payload.detail,
                    correlationID: payload.correlationID,
                )
            }
        }

        let detail = String(data: response.data, encoding: .utf8) ?? "Request failed"
        return .api(statusCode: response.statusCode, detail: detail, correlationID: nil)
    }
}
