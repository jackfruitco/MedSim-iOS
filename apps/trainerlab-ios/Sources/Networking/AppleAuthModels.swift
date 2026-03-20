import Foundation
import SharedModels

public struct AppleSignInCredential: Equatable, Sendable {
    public let identityToken: String
    public let authorizationCode: String
    public let givenName: String?
    public let familyName: String?
    public let email: String?

    public init(
        identityToken: String,
        authorizationCode: String,
        givenName: String? = nil,
        familyName: String? = nil,
        email: String? = nil
    ) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.givenName = givenName
        self.familyName = familyName
        self.email = email
    }
}

public struct AppleRoleOption: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let title: String

    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}

public struct PendingAppleSignup: Codable, Equatable, Identifiable, Sendable {
    public let signupToken: String
    public let email: String
    public let givenName: String
    public let familyName: String
    public let roles: [AppleRoleOption]

    public var id: String {
        signupToken
    }

    public init(
        signupToken: String,
        email: String,
        givenName: String,
        familyName: String,
        roles: [AppleRoleOption]
    ) {
        self.signupToken = signupToken
        self.email = email
        self.givenName = givenName
        self.familyName = familyName
        self.roles = roles
    }

    enum CodingKeys: String, CodingKey {
        case signupToken = "signup_token"
        case email
        case givenName = "given_name"
        case familyName = "family_name"
        case roles
    }
}

public enum AppleSignInResult: Equatable, Sendable {
    case authenticated(AuthTokens)
    case profileCompletionRequired(PendingAppleSignup)
}

public enum AuthServiceError: Error, Equatable, LocalizedError {
    case invalidAppleCredential
    case invitationRequired
    case invitationEmailMismatch
    case accountConflict(String)
    case invalidAppleResponse
    case api(statusCode: Int, detail: String, correlationID: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            "Apple sign-in could not be verified. Please try again."
        case .invitationRequired:
            "A valid invitation token is required to create a new account with Apple."
        case .invitationEmailMismatch:
            "This invitation token belongs to a different email address."
        case let .accountConflict(detail):
            detail
        case .invalidAppleResponse:
            "The server returned an unexpected Apple sign-in response."
        case let .api(_, detail, _):
            detail
        }
    }
}

struct AppleTokenRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let givenName: String?
    let familyName: String?
    let invitationToken: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case authorizationCode = "authorization_code"
        case givenName = "given_name"
        case familyName = "family_name"
        case invitationToken = "invitation_token"
    }
}

struct AppleProfileCompletionEnvelope: Codable {
    let type: String
    let title: String
    let status: Int
    let detail: String
    let signupToken: String
    let email: String
    let givenName: String
    let familyName: String
    let roles: [AppleRoleOption]

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case status
        case detail
        case signupToken = "signup_token"
        case email
        case givenName = "given_name"
        case familyName = "family_name"
        case roles
    }
}

struct AppleCompleteSignupRequest: Codable {
    let signupToken: String
    let roleID: Int
    let givenName: String
    let familyName: String

    enum CodingKeys: String, CodingKey {
        case signupToken = "signup_token"
        case roleID = "role_id"
        case givenName = "given_name"
        case familyName = "family_name"
    }
}
