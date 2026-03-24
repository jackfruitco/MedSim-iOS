import Foundation

public struct PresentableAppError: Equatable, Sendable {
    public let title: String
    public let message: String
    public let debugMessage: String?
    public let correlationID: String?
    public let statusCode: Int?
    public let recoveryActionLabel: String?

    public init(
        title: String,
        message: String,
        debugMessage: String? = nil,
        correlationID: String? = nil,
        statusCode: Int? = nil,
        recoveryActionLabel: String? = nil,
    ) {
        self.title = title
        self.message = message
        self.debugMessage = debugMessage
        self.correlationID = correlationID
        self.statusCode = statusCode
        self.recoveryActionLabel = recoveryActionLabel
    }

    public var debugDetailsText: String {
        var lines: [String] = []
        if let statusCode {
            lines.append("Status: \(statusCode)")
        }
        if let correlationID, !correlationID.isEmpty {
            lines.append("Correlation ID: \(correlationID)")
        }
        if let debugMessage, !debugMessage.isEmpty {
            lines.append("Debug: \(debugMessage)")
        }
        return lines.joined(separator: "\n")
    }
}

public enum AppErrorPresenter {
    public static func present(_ error: Error) -> PresentableAppError? {
        if error is CancellationError {
            return nil
        }

        if let urlError = error as? URLError {
            return present(urlError)
        }

        if let apiError = error as? APIClientError {
            return present(apiError)
        }

        let debugMessage = String(reflecting: error)
        return PresentableAppError(
            title: "Something Went Wrong",
            message: "Something went wrong.",
            debugMessage: debugMessage,
            recoveryActionLabel: "Retry",
        )
    }

    public static func message(for error: Error) -> String? {
        present(error)?.message
    }

    private static func present(_ error: URLError) -> PresentableAppError? {
        switch error.code {
        case .cancelled:
            nil
        case .notConnectedToInternet:
            PresentableAppError(
                title: "No Internet Connection",
                message: "No internet connection.",
                debugMessage: String(reflecting: error),
                recoveryActionLabel: "Retry",
            )
        case .timedOut:
            PresentableAppError(
                title: "Request Timed Out",
                message: "The request timed out.",
                debugMessage: String(reflecting: error),
                recoveryActionLabel: "Retry",
            )
        default:
            PresentableAppError(
                title: "Connection Problem",
                message: "We couldn’t connect to the server.",
                debugMessage: String(reflecting: error),
                recoveryActionLabel: "Retry",
            )
        }
    }

    private static func present(_ error: APIClientError) -> PresentableAppError {
        let message = error.errorDescription ?? "Something went wrong."
        let debugMessage = buildDebugMessage(for: error)

        switch error {
        case .unauthorized, .missingRefreshToken:
            return PresentableAppError(
                title: "Session Expired",
                message: message,
                debugMessage: debugMessage,
                correlationID: error.correlationID,
                statusCode: error.statusCode,
                recoveryActionLabel: "Sign In Again",
            )
        case let .http(statusCode, _, _):
            return PresentableAppError(
                title: title(forHTTPStatus: statusCode),
                message: message,
                debugMessage: debugMessage,
                correlationID: error.correlationID,
                statusCode: statusCode,
                recoveryActionLabel: recoveryActionLabel(forHTTPStatus: statusCode),
            )
        case .invalidURL:
            return PresentableAppError(
                title: "Request Error",
                message: message,
                debugMessage: debugMessage,
            )
        case .invalidResponse, .decoding:
            return PresentableAppError(
                title: "Something Went Wrong",
                message: message,
                debugMessage: debugMessage,
            )
        }
    }

    private static func buildDebugMessage(for error: APIClientError) -> String {
        var parts = [String(reflecting: error)]
        if let backendDetail = error.backendDetail, !backendDetail.isEmpty {
            parts.append("backend_detail=\(backendDetail)")
        }
        return parts.joined(separator: " | ")
    }

    private static func title(forHTTPStatus statusCode: Int) -> String {
        switch statusCode {
        case 400, 422:
            "Invalid Request"
        case 401:
            "Session Expired"
        case 403:
            "Permission Denied"
        case 404:
            "Not Found"
        case 409:
            "Conflict"
        case 429:
            "Too Many Requests"
        case 500...:
            "Server Error"
        default:
            "Something Went Wrong"
        }
    }

    private static func recoveryActionLabel(forHTTPStatus statusCode: Int) -> String? {
        switch statusCode {
        case 401:
            "Sign In Again"
        case 429:
            "Try Again"
        case 500...:
            "Retry"
        default:
            nil
        }
    }
}
