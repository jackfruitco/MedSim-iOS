@testable import RunConsole
import XCTest

@MainActor
final class VoiceActionCaptureTests: XCTestCase {
    func testCancelIsIdempotentAndClearsDraftCapture() {
        let capture = VoiceActionCapture()
        capture.cancel()
        capture.cancel()
        XCTAssertFalse(capture.isRecording)
        XCTAssertFalse(capture.isStarting)
        XCTAssertEqual(capture.transcript, "")
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
