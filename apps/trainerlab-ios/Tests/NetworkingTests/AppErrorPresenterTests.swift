import Foundation
@testable import Networking
import SharedModels
import XCTest

private struct UnknownTestError: Error {}

final class AppErrorPresenterTests: XCTestCase {
    func testInvalidURLMapsToUserSafeMessage() {
        let error = AppErrorPresenter.present(APIClientError.invalidURL)

        XCTAssertEqual(error?.title, "Request Error")
        XCTAssertEqual(error?.message, "The app generated an invalid request.")
        XCTAssertNil(error?.statusCode)
        XCTAssertNil(error?.correlationID)
    }

    func testAuthorizationErrorsMapToSessionExpired() {
        let unauthorized = AppErrorPresenter.present(APIClientError.unauthorized)
        let missingRefresh = AppErrorPresenter.present(APIClientError.missingRefreshToken)
        let httpUnauthorized = AppErrorPresenter.present(
            APIClientError.http(statusCode: 401, detail: "expired", correlationID: "corr-401"),
        )

        XCTAssertEqual(unauthorized?.title, "Session Expired")
        XCTAssertEqual(unauthorized?.message, "Your session expired. Please sign in again.")
        XCTAssertEqual(unauthorized?.recoveryActionLabel, "Sign In Again")

        XCTAssertEqual(missingRefresh?.title, "Session Expired")
        XCTAssertEqual(missingRefresh?.message, "Your session is incomplete. Please sign in again.")
        XCTAssertEqual(missingRefresh?.recoveryActionLabel, "Sign In Again")

        XCTAssertEqual(httpUnauthorized?.title, "Session Expired")
        XCTAssertEqual(httpUnauthorized?.message, "Your session expired. Please sign in again.")
        XCTAssertEqual(httpUnauthorized?.recoveryActionLabel, "Sign In Again")
        XCTAssertEqual(httpUnauthorized?.correlationID, "corr-401")
    }

    func testHTTPSafeDetailIsShownForActionable4xx() {
        let error = APIClientError.http(
            statusCode: 409,
            detail: "That simulation is already running.",
            correlationID: "corr-123",
        )

        let presentable = AppErrorPresenter.present(error)

        XCTAssertEqual(presentable?.title, "Conflict")
        XCTAssertEqual(presentable?.message, "That simulation is already running.")
        XCTAssertEqual(presentable?.statusCode, 409)
        XCTAssertEqual(presentable?.correlationID, "corr-123")
    }

    func testHTTPUnsafeDetailFallsBackToStatusMessage() {
        let error = APIClientError.http(
            statusCode: 422,
            detail: "Traceback: serializer exploded",
            correlationID: "corr-unsafe",
        )

        let presentable = AppErrorPresenter.present(error)

        XCTAssertEqual(presentable?.title, "Invalid Request")
        XCTAssertEqual(presentable?.message, "The submitted data was invalid.")
        XCTAssertEqual(presentable?.statusCode, 422)
        XCTAssertEqual(presentable?.correlationID, "corr-unsafe")
        XCTAssertTrue(presentable?.debugMessage?.contains("backend_detail=Traceback: serializer exploded") == true)
    }

    func testHTTPStatusFallbacksCoverExpectedMappings() {
        let expectations: [(Int, String)] = [
            (400, "The request was invalid."),
            (403, "You don’t have permission to do that."),
            (404, "That item could not be found."),
            (409, "That change conflicts with the current state."),
            (422, "The submitted data was invalid."),
            (429, "Too many requests. Please try again shortly."),
            (503, "Something went wrong on the server."),
        ]

        for (statusCode, message) in expectations {
            let error = APIClientError.http(statusCode: statusCode, detail: "", correlationID: nil)
            XCTAssertEqual(AppErrorPresenter.present(error)?.message, message, "status \(statusCode)")
        }
    }

    func testServerErrorsNeverExposeRawDetail() {
        let error = APIClientError.http(
            statusCode: 503,
            detail: "Service temporarily unavailable. Please retry job 91827.",
            correlationID: "server-corr",
        )

        let presentable = AppErrorPresenter.present(error)

        XCTAssertEqual(presentable?.title, "Server Error")
        XCTAssertEqual(presentable?.message, "Something went wrong on the server.")
        XCTAssertEqual(presentable?.correlationID, "server-corr")
        XCTAssertTrue(presentable?.debugMessage?.contains("job 91827") == true)
    }

    func testURLErrorMappings() {
        XCTAssertEqual(
            AppErrorPresenter.present(URLError(.notConnectedToInternet))?.message,
            "No internet connection.",
        )
        XCTAssertEqual(
            AppErrorPresenter.present(URLError(.timedOut))?.message,
            "The request timed out.",
        )
        XCTAssertNil(AppErrorPresenter.present(URLError(.cancelled)))
    }

    func testCancellationErrorIsSilent() {
        XCTAssertNil(AppErrorPresenter.present(CancellationError()))
    }

    func testUnknownErrorFallsBackToGenericMessage() {
        let presentable = AppErrorPresenter.present(UnknownTestError())

        XCTAssertEqual(presentable?.title, "Something Went Wrong")
        XCTAssertEqual(presentable?.message, "Something went wrong.")
        XCTAssertNotNil(presentable?.debugMessage)
    }

    func testGuardDeniedErrorUsesSignalTitleAndMessage() {
        let signal = GuardSignal(
            code: "runtime_cap_exceeded",
            severity: "error",
            title: "Session Ended",
            message: "Your session has exceeded the allowed runtime.",
            resumable: false,
            terminal: true,
            expiresInSeconds: nil,
            metadata: nil,
        )
        let error = APIClientError.guardDenied(
            statusCode: 403,
            detail: "The runtime cap has been exceeded.",
            correlationID: "corr-guard",
            signal: signal,
        )

        let presentable = AppErrorPresenter.present(error)

        XCTAssertEqual(presentable?.title, "Session Ended")
        XCTAssertEqual(presentable?.message, "Your session has exceeded the allowed runtime.")
        XCTAssertEqual(presentable?.statusCode, 403)
        XCTAssertEqual(presentable?.correlationID, "corr-guard")
        XCTAssertNil(presentable?.recoveryActionLabel)
    }

    func testGuardDeniedResumableHasResumeActionLabel() {
        let signal = GuardSignal(
            code: "paused_inactivity",
            severity: "warning",
            title: "Session Paused",
            message: "Your session was paused due to inactivity.",
            resumable: true,
            terminal: false,
            expiresInSeconds: nil,
            metadata: nil,
        )
        let error = APIClientError.guardDenied(
            statusCode: 403,
            detail: "Paused due to inactivity.",
            correlationID: nil,
            signal: signal,
        )

        let presentable = AppErrorPresenter.present(error)

        XCTAssertEqual(presentable?.recoveryActionLabel, "Resume")
    }

    func testGuardDeniedWithNoTitleFallsBackToNotice() {
        let signal = GuardSignal(
            code: "unknown_code",
            severity: "error",
            title: nil,
            message: "Something blocked this request.",
            resumable: nil,
            terminal: nil,
            expiresInSeconds: nil,
            metadata: nil,
        )
        let error = APIClientError.guardDenied(
            statusCode: 403,
            detail: "blocked",
            correlationID: nil,
            signal: signal,
        )

        let presentable = AppErrorPresenter.present(error)

        XCTAssertEqual(presentable?.title, "Notice")
    }
}
