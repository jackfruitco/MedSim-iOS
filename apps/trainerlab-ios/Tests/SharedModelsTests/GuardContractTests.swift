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
            "runtime_minutes_used": 25,
            "runtime_cap_minutes": 30,
            "warnings": ["APPROACHING_RUNTIME_CAP"],
            "can_resume": true,
            "denial_reason": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .active)
        XCTAssertNil(gs.pauseReason)
        XCTAssertEqual(gs.runtimeMinutesUsed, 25)
        XCTAssertEqual(gs.runtimeCapMinutes, 30)
        XCTAssertEqual(gs.warnings, [.approachingRuntimeCap])
        XCTAssertTrue(gs.canResume)
        XCTAssertNil(gs.denialReason)
    }

    func testGuardStateDecodesPausedInactivity() throws {
        let json = """
        {
            "guard_state": "PAUSED_INACTIVITY",
            "pause_reason": "INACTIVITY",
            "runtime_minutes_used": 10,
            "runtime_cap_minutes": 30,
            "warnings": [],
            "can_resume": true,
            "denial_reason": "INACTIVITY_PAUSED"
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .pausedInactivity)
        XCTAssertEqual(gs.pauseReason, .inactivity)
        XCTAssertTrue(gs.canResume)
        XCTAssertEqual(gs.denialReason, .inactivityPaused)
    }

    func testGuardStateDecodesPausedRuntimeCap() throws {
        let json = """
        {
            "guard_state": "PAUSED_RUNTIME_CAP",
            "pause_reason": "RUNTIME_CAP",
            "runtime_minutes_used": 30,
            "runtime_cap_minutes": 30,
            "warnings": [],
            "can_resume": false,
            "denial_reason": "RUNTIME_CAP_EXCEEDED"
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .pausedRuntimeCap)
        XCTAssertEqual(gs.pauseReason, .runtimeCap)
        XCTAssertFalse(gs.canResume)
        XCTAssertEqual(gs.denialReason, .runtimeCapExceeded)
    }

    func testGuardStateDecodesEnded() throws {
        let json = """
        {
            "guard_state": "ENDED",
            "pause_reason": "WALL_CLOCK_EXPIRY",
            "runtime_minutes_used": 45,
            "runtime_cap_minutes": null,
            "warnings": [],
            "can_resume": false,
            "denial_reason": "SESSION_ENDED"
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .ended)
        XCTAssertEqual(gs.pauseReason, .wallClockExpiry)
        XCTAssertNil(gs.runtimeCapMinutes)
        XCTAssertEqual(gs.denialReason, .sessionEnded)
    }

    // MARK: - Unknown Enum Fallbacks

    func testUnknownGuardStateFallsBackToUnknown() throws {
        let json = """
        {
            "guard_state": "FUTURE_STATE",
            "pause_reason": null,
            "runtime_minutes_used": 0,
            "runtime_cap_minutes": null,
            "warnings": [],
            "can_resume": false,
            "denial_reason": null
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
            "runtime_minutes_used": 0,
            "runtime_cap_minutes": null,
            "warnings": [],
            "can_resume": false,
            "denial_reason": null
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
            "runtime_minutes_used": 0,
            "runtime_cap_minutes": null,
            "warnings": [],
            "can_resume": false,
            "denial_reason": "FUTURE_DENIAL"
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
            "runtime_minutes_used": 0,
            "runtime_cap_minutes": null,
            "warnings": ["FUTURE_WARNING"],
            "can_resume": false,
            "denial_reason": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.warnings, [.unknown])
    }

    // MARK: - Computed Properties

    func testIsEngineRunnableWhenActive() {
        let gs = SimulationGuardState(guardState: .active)
        XCTAssertTrue(gs.isEngineRunnable)
    }

    func testIsNotEngineRunnableWhenPaused() {
        let gs = SimulationGuardState(guardState: .pausedInactivity)
        XCTAssertFalse(gs.isEngineRunnable)
    }

    func testIsPausedForAllPauseStates() {
        XCTAssertTrue(SimulationGuardState(guardState: .pausedInactivity).isPaused)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedRuntimeCap).isPaused)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedManual).isPaused)
        XCTAssertFalse(SimulationGuardState(guardState: .active).isPaused)
        XCTAssertFalse(SimulationGuardState(guardState: .ended).isPaused)
    }

    func testTerminalPause() {
        XCTAssertTrue(SimulationGuardState(guardState: .pausedRuntimeCap).isTerminalPause)
        XCTAssertTrue(SimulationGuardState(guardState: .ended).isTerminalPause)
        XCTAssertFalse(SimulationGuardState(guardState: .pausedInactivity).isTerminalPause)
        XCTAssertFalse(SimulationGuardState(guardState: .pausedManual).isTerminalPause)
    }

    func testResumablePause() {
        let inactivity = SimulationGuardState(guardState: .pausedInactivity, canResume: true)
        XCTAssertTrue(inactivity.isResumablePause)

        let manual = SimulationGuardState(guardState: .pausedManual, canResume: true)
        XCTAssertTrue(manual.isResumablePause)

        let runtimeCap = SimulationGuardState(guardState: .pausedRuntimeCap, canResume: false)
        XCTAssertFalse(runtimeCap.isResumablePause)

        let runtimeCapWithResume = SimulationGuardState(guardState: .pausedRuntimeCap, canResume: true)
        XCTAssertFalse(runtimeCapWithResume.isResumablePause)
    }

    func testShouldLockChatSending() {
        XCTAssertFalse(SimulationGuardState(guardState: .active).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedInactivity).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedRuntimeCap).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .ended).shouldLockChatSending)
    }

    func testRemainingMinutes() {
        let withCap = SimulationGuardState(guardState: .active, runtimeMinutesUsed: 20, runtimeCapMinutes: 30)
        XCTAssertEqual(withCap.remainingMinutes, 10)

        let atCap = SimulationGuardState(guardState: .active, runtimeMinutesUsed: 30, runtimeCapMinutes: 30)
        XCTAssertEqual(atCap.remainingMinutes, 0)

        let overCap = SimulationGuardState(guardState: .active, runtimeMinutesUsed: 35, runtimeCapMinutes: 30)
        XCTAssertEqual(overCap.remainingMinutes, 0)

        let noCap = SimulationGuardState(guardState: .active, runtimeMinutesUsed: 20)
        XCTAssertNil(noCap.remainingMinutes)
    }

    func testWarningMessage() {
        let approaching = SimulationGuardState(
            guardState: .active,
            runtimeMinutesUsed: 25,
            runtimeCapMinutes: 30,
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
        XCTAssertNotNil(SimulationGuardState(guardState: .pausedInactivity).pauseMessage)
        XCTAssertNotNil(SimulationGuardState(guardState: .pausedRuntimeCap).pauseMessage)
        XCTAssertNotNil(SimulationGuardState(guardState: .pausedManual).pauseMessage)
        XCTAssertNotNil(SimulationGuardState(guardState: .ended).pauseMessage)
        XCTAssertNil(SimulationGuardState(guardState: .active).pauseMessage)
    }

    func testDenialMessage() {
        let runtime = SimulationGuardState(guardState: .pausedRuntimeCap, denialReason: .runtimeCapExceeded)
        XCTAssertNotNil(runtime.denialMessage)

        let token = SimulationGuardState(guardState: .pausedRuntimeCap, denialReason: .tokenLimitExceeded)
        XCTAssertNotNil(token.denialMessage)

        let none = SimulationGuardState(guardState: .active)
        XCTAssertNil(none.denialMessage)
    }

    // MARK: - Heartbeat Response

    func testHeartbeatResponseDecodes() throws {
        let json = """
        {"success": true}
        """
        let response = try decoder.decode(HeartbeatResponse.self, from: Data(json.utf8))
        XCTAssertTrue(response.success)
    }
}
