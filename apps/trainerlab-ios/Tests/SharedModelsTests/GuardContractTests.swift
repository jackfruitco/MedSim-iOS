import Foundation
import SharedModels
import XCTest

final class GuardContractTests: XCTestCase {
    // MARK: - GuardSignal

    func testGuardSignalDecodesAllFields() throws {
        let json = """
        {
          "code": "approaching_runtime_cap",
          "severity": "warning",
          "title": "Approaching Time Limit",
          "message": "This simulation will end in 5 minutes.",
          "resumable": true,
          "terminal": false,
          "expires_in_seconds": 300,
          "metadata": {"cap_seconds": 3600}
        }
        """
        let signal = try decode(GuardSignal.self, from: json)

        XCTAssertEqual(signal.code, "approaching_runtime_cap")
        XCTAssertEqual(signal.severity, "warning")
        XCTAssertEqual(signal.title, "Approaching Time Limit")
        XCTAssertEqual(signal.message, "This simulation will end in 5 minutes.")
        XCTAssertEqual(signal.resumable, true)
        XCTAssertEqual(signal.terminal, false)
        XCTAssertEqual(signal.expiresInSeconds, 300)
        XCTAssertNotNil(signal.metadata)
    }

    func testGuardSignalDecodesWithOptionalFieldsMissing() throws {
        let json = """
        {
          "code": "runtime_cap_exceeded",
          "severity": "error",
          "message": "The simulation has exceeded its runtime limit."
        }
        """
        let signal = try decode(GuardSignal.self, from: json)

        XCTAssertEqual(signal.code, "runtime_cap_exceeded")
        XCTAssertNil(signal.title)
        XCTAssertNil(signal.resumable)
        XCTAssertNil(signal.terminal)
        XCTAssertNil(signal.expiresInSeconds)
        XCTAssertNil(signal.metadata)
    }

    func testGuardSignalConvenienceDefaults() throws {
        let json = """
        {"code": "x", "severity": "info", "message": "msg"}
        """
        let signal = try decode(GuardSignal.self, from: json)

        XCTAssertFalse(signal.isTerminal)
        XCTAssertFalse(signal.isResumable)
        XCTAssertEqual(signal.displayTitle, "Notice")
    }

    func testGuardSignalConvenienceWithValues() throws {
        let json = """
        {
          "code": "x",
          "severity": "error",
          "title": "Blocked",
          "message": "msg",
          "terminal": true,
          "resumable": false
        }
        """
        let signal = try decode(GuardSignal.self, from: json)

        XCTAssertTrue(signal.isTerminal)
        XCTAssertFalse(signal.isResumable)
        XCTAssertEqual(signal.displayTitle, "Blocked")
    }

    // MARK: - GuardStateDTO

    func testGuardStateDTODecodesAllFields() throws {
        let json = """
        {
          "guard_state": "active",
          "guard_reason": "normal",
          "engine_runnable": true,
          "active_elapsed_seconds": 120,
          "runtime_cap_seconds": 3600,
          "wall_clock_expires_at": "2026-04-02T12:00:00Z",
          "warnings": [
            {
              "code": "approaching_runtime_cap",
              "severity": "warning",
              "message": "Approaching limit."
            }
          ],
          "denial": null
        }
        """
        let dto = try decode(GuardStateDTO.self, from: json)

        XCTAssertEqual(dto.guardState, "active")
        XCTAssertEqual(dto.guardReason, "normal")
        XCTAssertTrue(dto.engineRunnable)
        XCTAssertEqual(dto.activeElapsedSeconds, 120)
        XCTAssertEqual(dto.runtimeCapSeconds, 3600)
        XCTAssertEqual(dto.wallClockExpiresAt, "2026-04-02T12:00:00Z")
        XCTAssertEqual(dto.warnings.count, 1)
        XCTAssertNil(dto.denial)
        XCTAssertFalse(dto.isEngineBlocked)
        XCTAssertNil(dto.primaryDenial)
    }

    func testGuardStateDTOWithDenialAndBlockedEngine() throws {
        let json = """
        {
          "guard_state": "denied",
          "guard_reason": "runtime_cap_exceeded",
          "engine_runnable": false,
          "active_elapsed_seconds": 3601,
          "warnings": [],
          "denial": {
            "code": "runtime_cap_exceeded",
            "severity": "error",
            "title": "Session Ended",
            "message": "The runtime cap was reached.",
            "terminal": true
          }
        }
        """
        let dto = try decode(GuardStateDTO.self, from: json)

        XCTAssertFalse(dto.engineRunnable)
        XCTAssertTrue(dto.isEngineBlocked)
        XCTAssertNotNil(dto.denial)
        XCTAssertTrue(dto.denial!.isTerminal)
        XCTAssertEqual(dto.primaryDenial?.code, "runtime_cap_exceeded")
    }

    func testGuardStateDTOWithMissingOptionalFields() throws {
        let json = """
        {
          "guard_state": "active",
          "guard_reason": "normal",
          "engine_runnable": true,
          "active_elapsed_seconds": 0,
          "warnings": []
        }
        """
        let dto = try decode(GuardStateDTO.self, from: json)

        XCTAssertNil(dto.runtimeCapSeconds)
        XCTAssertNil(dto.wallClockExpiresAt)
        XCTAssertNil(dto.denial)
    }

    // MARK: - GuardDeniedPayload

    func testGuardDeniedPayloadDecodes() throws {
        let json = """
        {
          "type": "guard_denied",
          "title": "Access Denied",
          "status": 403,
          "detail": "The runtime cap has been exceeded.",
          "guard_denial": {
            "code": "runtime_cap_exceeded",
            "severity": "error",
            "message": "Your session has exceeded the allowed runtime.",
            "terminal": true
          }
        }
        """
        let payload = try decode(GuardDeniedPayload.self, from: json)

        XCTAssertEqual(payload.type, "guard_denied")
        XCTAssertEqual(payload.title, "Access Denied")
        XCTAssertEqual(payload.status, 403)
        XCTAssertEqual(payload.detail, "The runtime cap has been exceeded.")
        XCTAssertEqual(payload.guardDenial.code, "runtime_cap_exceeded")
        XCTAssertTrue(payload.guardDenial.isTerminal)
    }

    // MARK: - Unknown values decode gracefully (strings, not enums)

    func testUnknownGuardStateDecodesAsString() throws {
        let json = """
        {
          "guard_state": "future_unknown_state",
          "guard_reason": "future_unknown_reason",
          "engine_runnable": true,
          "active_elapsed_seconds": 0,
          "warnings": []
        }
        """
        let dto = try decode(GuardStateDTO.self, from: json)

        XCTAssertEqual(dto.guardState, "future_unknown_state")
        XCTAssertEqual(dto.guardReason, "future_unknown_reason")
    }

    func testUnknownGuardSignalCodeDecodesAsString() throws {
        let json = """
        {
          "code": "future_unknown_code",
          "severity": "future_severity",
          "message": "msg"
        }
        """
        let signal = try decode(GuardSignal.self, from: json)

        XCTAssertEqual(signal.code, "future_unknown_code")
        XCTAssertEqual(signal.severity, "future_severity")
    }
}

private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}
