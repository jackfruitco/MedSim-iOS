import Foundation
import SharedModels
import XCTest

final class GuardContractTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()

    // MARK: - Full Decode

    func testGuardStateDecodesAllFields() throws {
        let json = """
        {
            "guard_state": "ACTIVE",
            "pause_reason": null,
            "engine_runnable": true,
            "active_elapsed_seconds": 1500,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": "2026-03-28T12:00:00Z",
            "warnings": ["APPROACHING_RUNTIME_CAP"],
            "denial_reason": null,
            "denial_message": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .active)
        XCTAssertNil(gs.pauseReason)
        XCTAssertTrue(gs.engineRunnable)
        XCTAssertEqual(gs.activeElapsedSeconds, 1500)
        XCTAssertEqual(gs.runtimeCapSeconds, 1800)
        XCTAssertEqual(gs.wallClockExpiresAt, "2026-03-28T12:00:00Z")
        XCTAssertEqual(gs.warnings, [.approachingRuntimeCap])
        XCTAssertNil(gs.denialReason)
        XCTAssertNil(gs.denialMessage)
    }

    func testGuardStateDecodesPausedInactivity() throws {
        let json = """
        {
            "guard_state": "PAUSED_INACTIVITY",
            "pause_reason": "INACTIVITY",
            "engine_runnable": false,
            "active_elapsed_seconds": 600,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "INACTIVITY_PAUSED",
            "denial_message": "Session is paused due to inactivity."
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .pausedInactivity)
        XCTAssertEqual(gs.pauseReason, .inactivity)
        XCTAssertFalse(gs.engineRunnable)
        XCTAssertEqual(gs.denialReason, .inactivityPaused)
        XCTAssertEqual(gs.denialMessage, "Session is paused due to inactivity.")
    }

    func testGuardStateDecodesPausedRuntimeCap() throws {
        let json = """
        {
            "guard_state": "PAUSED_RUNTIME_CAP",
            "pause_reason": "RUNTIME_CAP",
            "engine_runnable": false,
            "active_elapsed_seconds": 1800,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "RUNTIME_CAP_EXCEEDED",
            "denial_message": "Runtime limit has been exceeded."
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .pausedRuntimeCap)
        XCTAssertEqual(gs.pauseReason, .runtimeCap)
        XCTAssertFalse(gs.engineRunnable)
        XCTAssertEqual(gs.denialReason, .runtimeCapExceeded)
    }

    func testGuardStateDecodesEnded() throws {
        let json = """
        {
            "guard_state": "ENDED",
            "pause_reason": "WALL_CLOCK_EXPIRY",
            "engine_runnable": false,
            "active_elapsed_seconds": 2700,
            "runtime_cap_seconds": null,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "SESSION_ENDED",
            "denial_message": "This session has ended."
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .ended)
        XCTAssertEqual(gs.pauseReason, .wallClockExpiry)
        XCTAssertNil(gs.runtimeCapSeconds)
        XCTAssertEqual(gs.denialReason, .sessionEnded)
    }

    // MARK: - Unknown Enum Fallbacks

    func testUnknownGuardStateFallsBackToUnknown() throws {
        let json = """
        {
            "guard_state": "FUTURE_STATE",
            "pause_reason": null,
            "engine_runnable": false,
            "active_elapsed_seconds": 0,
            "runtime_cap_seconds": null,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": null,
            "denial_message": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .unknown)
    }

    func testUnknownPauseReasonFallsBackToUnknown() throws {
        let json = """
        {
            "guard_state": "ACTIVE",
            "pause_reason": "FUTURE_REASON",
            "engine_runnable": true,
            "active_elapsed_seconds": 0,
            "runtime_cap_seconds": null,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": null,
            "denial_message": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.pauseReason, .unknown)
    }

    func testUnknownDenialReasonFallsBackToUnknown() throws {
        let json = """
        {
            "guard_state": "ACTIVE",
            "pause_reason": null,
            "engine_runnable": true,
            "active_elapsed_seconds": 0,
            "runtime_cap_seconds": null,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "FUTURE_DENIAL",
            "denial_message": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.denialReason, .unknown)
    }

    func testUnknownWarningFallsBackToUnknown() throws {
        let json = """
        {
            "guard_state": "ACTIVE",
            "pause_reason": null,
            "engine_runnable": true,
            "active_elapsed_seconds": 0,
            "runtime_cap_seconds": null,
            "wall_clock_expires_at": null,
            "warnings": ["FUTURE_WARNING"],
            "denial_reason": null,
            "denial_message": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.warnings, [.unknown])
    }

    // MARK: - Computed Properties

    func testIsEngineRunnableUsesBackendFlag() {
        let runnable = SimulationGuardState(guardState: .active, engineRunnable: true)
        XCTAssertTrue(runnable.isEngineRunnable)

        let notRunnable = SimulationGuardState(guardState: .active, engineRunnable: false)
        XCTAssertFalse(notRunnable.isEngineRunnable)
    }

    func testIsNotEngineRunnableWhenPaused() {
        let gs = SimulationGuardState(guardState: .pausedInactivity, engineRunnable: false)
        XCTAssertFalse(gs.isEngineRunnable)
    }

    func testIsPausedForAllPauseStates() {
        XCTAssertTrue(SimulationGuardState(guardState: .pausedInactivity, engineRunnable: false).isPaused)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedRuntimeCap, engineRunnable: false).isPaused)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedManual, engineRunnable: false).isPaused)
        XCTAssertFalse(SimulationGuardState(guardState: .active).isPaused)
        XCTAssertFalse(SimulationGuardState(guardState: .ended, engineRunnable: false).isPaused)
    }

    func testTerminalPause() {
        XCTAssertTrue(SimulationGuardState(guardState: .pausedRuntimeCap, engineRunnable: false).isTerminalPause)
        XCTAssertTrue(SimulationGuardState(guardState: .ended, engineRunnable: false).isTerminalPause)
        XCTAssertFalse(SimulationGuardState(guardState: .pausedInactivity, engineRunnable: false).isTerminalPause)
        XCTAssertFalse(SimulationGuardState(guardState: .pausedManual, engineRunnable: false).isTerminalPause)
    }

    func testResumablePause() {
        let inactivity = SimulationGuardState(guardState: .pausedInactivity, engineRunnable: false)
        XCTAssertTrue(inactivity.isResumablePause)

        let manual = SimulationGuardState(guardState: .pausedManual, engineRunnable: false)
        XCTAssertTrue(manual.isResumablePause)

        let runtimeCap = SimulationGuardState(guardState: .pausedRuntimeCap, engineRunnable: false)
        XCTAssertFalse(runtimeCap.isResumablePause)

        let ended = SimulationGuardState(guardState: .ended, engineRunnable: false)
        XCTAssertFalse(ended.isResumablePause)
    }

    func testShouldLockChatSending() {
        XCTAssertFalse(SimulationGuardState(guardState: .active).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedInactivity, engineRunnable: false).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedRuntimeCap, engineRunnable: false).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .ended, engineRunnable: false).shouldLockChatSending)
    }

    func testRemainingMinutes() {
        let withCap = SimulationGuardState(guardState: .active, activeElapsedSeconds: 1200, runtimeCapSeconds: 1800)
        XCTAssertEqual(withCap.remainingMinutes, 10)

        let atCap = SimulationGuardState(guardState: .active, activeElapsedSeconds: 1800, runtimeCapSeconds: 1800)
        XCTAssertEqual(atCap.remainingMinutes, 0)

        let overCap = SimulationGuardState(guardState: .active, activeElapsedSeconds: 2100, runtimeCapSeconds: 1800)
        XCTAssertEqual(overCap.remainingMinutes, 0)

        let noCap = SimulationGuardState(guardState: .active, activeElapsedSeconds: 1200)
        XCTAssertNil(noCap.remainingMinutes)

        // Partial minute truncates down
        let partial = SimulationGuardState(guardState: .active, activeElapsedSeconds: 1500, runtimeCapSeconds: 1800)
        XCTAssertEqual(partial.remainingMinutes, 5)
    }

    func testWarningMessage() {
        let approaching = SimulationGuardState(
            guardState: .active,
            activeElapsedSeconds: 1500,
            runtimeCapSeconds: 1800,
            warnings: [.approachingRuntimeCap],
        )
        XCTAssertNotNil(approaching.warningMessage)
        XCTAssertTrue(approaching.warningMessage?.contains("5 min") == true)

        let stale = SimulationGuardState(guardState: .active, warnings: [.staleHeartbeat])
        XCTAssertEqual(stale.warningMessage, "Connection may be stale")

        let noWarnings = SimulationGuardState(guardState: .active)
        XCTAssertNil(noWarnings.warningMessage)
    }

    func testPauseMessage() {
        XCTAssertNotNil(SimulationGuardState(guardState: .pausedInactivity, engineRunnable: false).pauseMessage)
        XCTAssertNotNil(SimulationGuardState(guardState: .pausedRuntimeCap, engineRunnable: false).pauseMessage)
        XCTAssertNotNil(SimulationGuardState(guardState: .pausedManual, engineRunnable: false).pauseMessage)
        XCTAssertNotNil(SimulationGuardState(guardState: .ended, engineRunnable: false).pauseMessage)
        XCTAssertNil(SimulationGuardState(guardState: .active).pauseMessage)
    }

    func testDenialMessagePrefersBackendText() {
        let withBackendMessage = SimulationGuardState(
            guardState: .pausedRuntimeCap,
            engineRunnable: false,
            denialReason: .runtimeCapExceeded,
            denialMessage: "Custom backend message"
        )
        XCTAssertEqual(withBackendMessage.userFacingDenialMessage, "Custom backend message")

        let withoutBackendMessage = SimulationGuardState(
            guardState: .pausedRuntimeCap,
            engineRunnable: false,
            denialReason: .runtimeCapExceeded
        )
        XCTAssertEqual(withoutBackendMessage.userFacingDenialMessage, "Runtime limit has been exceeded.")

        let token = SimulationGuardState(
            guardState: .pausedRuntimeCap,
            engineRunnable: false,
            denialReason: .tokenLimitExceeded
        )
        XCTAssertNotNil(token.userFacingDenialMessage)

        let none = SimulationGuardState(guardState: .active)
        XCTAssertNil(none.userFacingDenialMessage)
    }

    // MARK: - Heartbeat Request

    func testHeartbeatRequestEncodes() throws {
        let request = HeartbeatRequest(clientVisibility: "foreground")
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["client_visibility"] as? String, "foreground")
    }

    func testHeartbeatRequestDefaultsToUnknown() {
        let request = HeartbeatRequest()
        XCTAssertEqual(request.clientVisibility, "unknown")
    }
}
