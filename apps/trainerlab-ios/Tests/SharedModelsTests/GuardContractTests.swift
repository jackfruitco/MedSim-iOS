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
            "guard_state": "active",
            "pause_reason": "none",
            "engine_runnable": true,
            "active_elapsed_seconds": 1500,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": "2026-03-28T12:00:00Z",
            "warnings": ["approaching_runtime_cap"],
            "denial_reason": null,
            "denial_message": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .active)
        XCTAssertEqual(gs.pauseReason, .none)
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
            "guard_state": "paused_inactivity",
            "pause_reason": "inactivity",
            "engine_runnable": false,
            "active_elapsed_seconds": 600,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "session_paused",
            "denial_message": "Session is paused due to inactivity."
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .pausedInactivity)
        XCTAssertEqual(gs.pauseReason, .inactivity)
        XCTAssertFalse(gs.engineRunnable)
        XCTAssertEqual(gs.denialReason, .sessionPaused)
        XCTAssertEqual(gs.denialMessage, "Session is paused due to inactivity.")
    }

    func testGuardStateDecodesPausedRuntimeCap() throws {
        let json = """
        {
            "guard_state": "paused_runtime_cap",
            "pause_reason": "runtime_cap",
            "engine_runnable": false,
            "active_elapsed_seconds": 1800,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "runtime_cap_reached",
            "denial_message": "Runtime limit has been exceeded."
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .pausedRuntimeCap)
        XCTAssertEqual(gs.pauseReason, .runtimeCap)
        XCTAssertFalse(gs.engineRunnable)
        XCTAssertEqual(gs.denialReason, .runtimeCapReached)
    }

    func testGuardStateDecodesEnded() throws {
        let json = """
        {
            "guard_state": "ended",
            "pause_reason": "wall_clock_expiry",
            "engine_runnable": false,
            "active_elapsed_seconds": 2700,
            "runtime_cap_seconds": null,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "wall_clock_expired",
            "denial_message": "Session time has expired."
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .ended)
        XCTAssertEqual(gs.pauseReason, .wallClockExpiry)
        XCTAssertNil(gs.runtimeCapSeconds)
        XCTAssertEqual(gs.denialReason, .wallClockExpired)
    }

    func testGuardStateDecodesLockedUsage() throws {
        let json = """
        {
            "guard_state": "locked_usage",
            "pause_reason": "usage_limit",
            "engine_runnable": false,
            "active_elapsed_seconds": 900,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "session_token_limit",
            "denial_message": "Session token limit reached."
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.guardState, .lockedUsage)
        XCTAssertEqual(gs.pauseReason, .usageLimit)
        XCTAssertFalse(gs.engineRunnable)
        XCTAssertEqual(gs.denialReason, .sessionTokenLimit)
        XCTAssertTrue(gs.isTerminalPause)
    }

    func testGuardStateDecodesIdleAndWarning() throws {
        // idle state — pre-inactivity, still engine-runnable
        let idleJson = """
        {
            "guard_state": "idle",
            "pause_reason": "none",
            "engine_runnable": true,
            "active_elapsed_seconds": 300,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": null,
            "denial_message": null
        }
        """
        let idle = try decoder.decode(SimulationGuardState.self, from: Data(idleJson.utf8))
        XCTAssertEqual(idle.guardState, .idle)
        XCTAssertTrue(idle.engineRunnable)
        XCTAssertFalse(idle.isPaused)

        // warning state — inactivity warning, still engine-runnable
        let warningJson = """
        {
            "guard_state": "warning",
            "pause_reason": "none",
            "engine_runnable": true,
            "active_elapsed_seconds": 300,
            "runtime_cap_seconds": 1800,
            "wall_clock_expires_at": null,
            "warnings": ["stale_heartbeat"],
            "denial_reason": null,
            "denial_message": null
        }
        """
        let warning = try decoder.decode(SimulationGuardState.self, from: Data(warningJson.utf8))
        XCTAssertEqual(warning.guardState, .warning)
        XCTAssertTrue(warning.engineRunnable)
        XCTAssertFalse(warning.isPaused)
    }

    // MARK: - Unknown Enum Fallbacks

    func testUnknownGuardStateFallsBackToUnknown() throws {
        let json = """
        {
            "guard_state": "future_state",
            "pause_reason": "none",
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
            "guard_state": "active",
            "pause_reason": "future_reason",
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
            "guard_state": "active",
            "pause_reason": "none",
            "engine_runnable": true,
            "active_elapsed_seconds": 0,
            "runtime_cap_seconds": null,
            "wall_clock_expires_at": null,
            "warnings": [],
            "denial_reason": "future_denial",
            "denial_message": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.denialReason, .unknown)
    }

    func testUnknownWarningFallsBackToUnknown() throws {
        let json = """
        {
            "guard_state": "active",
            "pause_reason": "none",
            "engine_runnable": true,
            "active_elapsed_seconds": 0,
            "runtime_cap_seconds": null,
            "wall_clock_expires_at": null,
            "warnings": ["future_warning"],
            "denial_reason": null,
            "denial_message": null
        }
        """
        let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
        XCTAssertEqual(gs.warnings, [.unknown])
    }

    // MARK: - All DenialReason values decode

    func testAllDenialReasonsDecodeCorrectly() throws {
        let reasons: [(String, DenialReason)] = [
            ("session_paused", .sessionPaused),
            ("runtime_cap_reached", .runtimeCapReached),
            ("session_token_limit", .sessionTokenLimit),
            ("user_token_limit", .userTokenLimit),
            ("account_token_limit", .accountTokenLimit),
            ("insufficient_token_budget", .insufficientTokenBudget),
            ("wall_clock_expired", .wallClockExpired),
            ("chat_send_locked", .chatSendLocked),
        ]
        for (raw, expected) in reasons {
            let json = """
            {
                "guard_state": "active",
                "pause_reason": "none",
                "engine_runnable": false,
                "active_elapsed_seconds": 0,
                "runtime_cap_seconds": null,
                "wall_clock_expires_at": null,
                "warnings": [],
                "denial_reason": "\(raw)",
                "denial_message": null
            }
            """
            let gs = try decoder.decode(SimulationGuardState.self, from: Data(json.utf8))
            XCTAssertEqual(gs.denialReason, expected, "Expected \(expected) for raw value \"\(raw)\"")
        }
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
        XCTAssertFalse(SimulationGuardState(guardState: .idle).isPaused)
        XCTAssertFalse(SimulationGuardState(guardState: .warning).isPaused)
        XCTAssertFalse(SimulationGuardState(guardState: .lockedUsage, engineRunnable: false).isPaused)
    }

    func testTerminalPause() {
        XCTAssertTrue(SimulationGuardState(guardState: .pausedRuntimeCap, engineRunnable: false).isTerminalPause)
        XCTAssertTrue(SimulationGuardState(guardState: .lockedUsage, engineRunnable: false).isTerminalPause)
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

        let locked = SimulationGuardState(guardState: .lockedUsage, engineRunnable: false)
        XCTAssertFalse(locked.isResumablePause)

        let ended = SimulationGuardState(guardState: .ended, engineRunnable: false)
        XCTAssertFalse(ended.isResumablePause)
    }

    func testShouldLockChatSending() {
        XCTAssertFalse(SimulationGuardState(guardState: .active).shouldLockChatSending)
        XCTAssertFalse(SimulationGuardState(guardState: .idle).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedInactivity, engineRunnable: false).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .pausedRuntimeCap, engineRunnable: false).shouldLockChatSending)
        XCTAssertTrue(SimulationGuardState(guardState: .lockedUsage, engineRunnable: false).shouldLockChatSending)
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
        XCTAssertNotNil(SimulationGuardState(guardState: .lockedUsage, engineRunnable: false).pauseMessage)
        XCTAssertNotNil(SimulationGuardState(guardState: .ended, engineRunnable: false).pauseMessage)
        XCTAssertNil(SimulationGuardState(guardState: .active).pauseMessage)
    }

    func testDenialMessagePrefersBackendText() {
        let withBackendMessage = SimulationGuardState(
            guardState: .pausedRuntimeCap,
            engineRunnable: false,
            denialReason: .runtimeCapReached,
            denialMessage: "Custom backend message"
        )
        XCTAssertEqual(withBackendMessage.userFacingDenialMessage, "Custom backend message")

        let withoutBackendMessage = SimulationGuardState(
            guardState: .pausedRuntimeCap,
            engineRunnable: false,
            denialReason: .runtimeCapReached
        )
        XCTAssertEqual(withoutBackendMessage.userFacingDenialMessage, "Runtime limit has been exceeded.")

        let token = SimulationGuardState(
            guardState: .lockedUsage,
            engineRunnable: false,
            denialReason: .sessionTokenLimit
        )
        XCTAssertEqual(token.userFacingDenialMessage, "Session token limit reached.")

        let none = SimulationGuardState(guardState: .active)
        XCTAssertNil(none.userFacingDenialMessage)
    }

    func testAllDenialReasonsHaveFallbackMessages() {
        let reasons: [DenialReason] = [
            .sessionPaused, .runtimeCapReached, .sessionTokenLimit,
            .userTokenLimit, .accountTokenLimit, .insufficientTokenBudget,
            .wallClockExpired, .chatSendLocked,
        ]
        for reason in reasons {
            let gs = SimulationGuardState(guardState: .active, engineRunnable: false, denialReason: reason)
            XCTAssertNotNil(gs.userFacingDenialMessage, "Missing fallback for \(reason)")
        }
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
