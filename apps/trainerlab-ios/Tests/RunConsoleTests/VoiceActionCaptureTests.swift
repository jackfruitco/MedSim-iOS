@testable import RunConsole
import XCTest

@MainActor
final class VoiceActionCaptureTests: XCTestCase {
    func testCancellationDuringAuthorizationIgnoresLatePermissionResult() async {
        var permission: CheckedContinuation<Bool, Never>?
        let capture = VoiceActionCapture(authorizeSpeech: {
            await withCheckedContinuation { permission = $0 }
        })
        let startTask = Task { await capture.start() }
        while permission == nil {
            await Task.yield()
        }
        XCTAssertTrue(capture.isStarting)
        capture.cancel()
        capture.cancel()
        permission?.resume(returning: false)
        await startTask.value
        XCTAssertFalse(capture.isRecording)
        XCTAssertFalse(capture.isStarting)
        XCTAssertEqual(capture.transcript, "")
        XCTAssertNil(capture.errorMessage)
    }

    func testPermissionDenialDoesNotStartRecording() async {
        let capture = VoiceActionCapture(authorizeSpeech: { false })
        await capture.start()
        XCTAssertFalse(capture.isRecording)
        XCTAssertFalse(capture.isStarting)
        XCTAssertNotNil(capture.errorMessage)
    }

    #if !os(iOS)
        func testUnavailableCaptureOffersManualFallback() async {
            let capture = VoiceActionCapture()
            await capture.start()
            XCTAssertFalse(capture.isRecording)
            XCTAssertFalse(capture.isStarting)
            XCTAssertNotNil(capture.errorMessage)
        }
    #endif
}
