@testable import AppShell
import Networking
import XCTest

private actor AuthorizationFailureRecorder {
    private(set) var errors: [APIClientError] = []

    func record(_ error: APIClientError) {
        errors.append(error)
    }
}

final class AuthorizationFailureRelayTests: XCTestCase {
    func testNotifyBuffersHTTP401UntilHandlerIsInstalled() async {
        let relay = AuthorizationFailureRelay()
        let recorder = AuthorizationFailureRecorder()
        let error = APIClientError.http(
            statusCode: 401,
            detail: "expired",
            correlationID: "corr-401",
        )

        await relay.notify(error)
        await relay.install { error in
            await recorder.record(error)
        }

        let recorded = await recorder.errors
        XCTAssertEqual(recorded, [error])
        XCTAssertTrue(recorded.first?.isAuthorizationFailure == true)
    }
}
