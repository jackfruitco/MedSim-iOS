import AuthenticationServices
import Foundation
import Networking

enum AppleSignInCoordinatorError: Error, LocalizedError {
    case unsupportedCredential
    case missingIdentityToken
    case missingAuthorizationCode
    case invalidIdentityToken
    case invalidAuthorizationCode

    var errorDescription: String? {
        switch self {
        case .unsupportedCredential:
            "Apple sign-in returned an unsupported credential."
        case .missingIdentityToken, .invalidIdentityToken:
            "Apple sign-in did not provide a valid identity token."
        case .missingAuthorizationCode, .invalidAuthorizationCode:
            "Apple sign-in did not provide a valid authorization code."
        }
    }
}

struct AppleSignInCoordinator {
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func credential(from result: Result<ASAuthorization, Error>) throws -> AppleSignInCredential {
        let authorization = try result.get()
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInCoordinatorError.unsupportedCredential
        }
        guard let identityTokenData = credential.identityToken else {
            throw AppleSignInCoordinatorError.missingIdentityToken
        }
        guard let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AppleSignInCoordinatorError.invalidIdentityToken
        }
        guard let authorizationCodeData = credential.authorizationCode else {
            throw AppleSignInCoordinatorError.missingAuthorizationCode
        }
        guard let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            throw AppleSignInCoordinatorError.invalidAuthorizationCode
        }

        return AppleSignInCredential(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName,
            email: credential.email
        )
    }
}
