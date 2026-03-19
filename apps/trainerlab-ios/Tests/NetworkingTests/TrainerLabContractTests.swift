import Foundation
import Networking
import Persistence
import SQLite3
import SharedModels
import XCTest

private enum RecordingError: Error {
    case intercepted
}

private final class RecordingAPIClient: APIClientProtocol, @unchecked Sendable {
    private(set) var capturedEndpoints: [Endpoint] = []

    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        capturedEndpoints.append(endpoint)
        throw RecordingError.intercepted
    }

    func requestData(_ endpoint: Endpoint) async throws -> Data {
        capturedEndpoints.append(endpoint)
        throw RecordingError.intercepted
    }

    func baseURL() async -> URL {
        URL(string: "https://example.com")!
    }
}

final class TrainerLabContractTests: XCTestCase {
    func testTrainerRunDecodesWithoutLegacyID() throws {
        let json = """
        {
          "simulation_id": 420,
          "status": "seeded",
          "scenario_spec": {},
          "runtime_state": {},
          "initial_directives": null,
          "tick_interval_seconds": 15,
          "run_started_at": null,
          "run_paused_at": null,
          "run_completed_at": null,
          "last_ai_tick_at": null,
          "created_at": "2026-03-12T12:00:00Z",
          "modified_at": "2026-03-12T12:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let run = try decoder.decode(TrainerSessionDTO.self, from: Data(json.utf8))

        XCTAssertEqual(run.simulationID, 420)
        XCTAssertEqual(run.id, 420)
    }

    func testRunSummaryDecodesWithoutLegacySessionID() throws {
        let json = """
        {
          "simulation_id": 420,
          "status": "completed",
          "run_started_at": "2026-03-12T12:00:00Z",
          "run_completed_at": "2026-03-12T12:05:00Z",
          "final_state": {},
          "event_type_counts": {"run.started": 1},
          "timeline_highlights": [],
          "command_log": [],
          "ai_rationale_notes": []
        }
        """

        let decoder = JSONDecoder()
        let summary = try decoder.decode(RunSummary.self, from: Data(json.utf8))

        XCTAssertEqual(summary.simulationID, 420)
        XCTAssertEqual(summary.status, "completed")
    }

    func testScenarioInstructionApplyEncodesSimulationID() throws {
        let request = ScenarioInstructionApplyRequest(simulationID: 77)
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertEqual(object?["simulation_id"] as? Int, 77)
        XCTAssertNil(object?["session_id"])
    }

    func testTrainerLabServiceUsesSimulationFirstEndpoints() async throws {
        let api = RecordingAPIClient()
        let service = TrainerLabService(apiClient: api)

        do {
            _ = try await service.getSession(simulationID: 7)
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/trainerlab/simulations/7/")

        do {
            _ = try await service.runCommand(simulationID: 7, command: .start, idempotencyKey: "k1")
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(
            api.capturedEndpoints.last?.path,
            "/api/v1/trainerlab/simulations/7/run/start/"
        )

        do {
            _ = try await service.adjustSimulation(
                simulationID: 7,
                request: SimulationAdjustRequest(
                    target: "avpu",
                    direction: "set",
                    magnitude: nil,
                    injuryEventID: nil,
                    injuryRegion: nil,
                    avpuState: "alert",
                    interventionCode: nil,
                    note: nil
                ),
                idempotencyKey: "k2"
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(
            api.capturedEndpoints.last?.path,
            "/api/v1/trainerlab/simulations/7/adjust/"
        )

        do {
            _ = try await service.listEvents(simulationID: 7, cursor: nil, limit: 50)
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(
            api.capturedEndpoints.last?.path,
            "/api/v1/trainerlab/simulations/7/events/"
        )

        do {
            _ = try await service.updateProblemStatus(
                simulationID: 7,
                problemID: 3,
                request: ProblemStatusUpdateRequest(isTreated: true, isResolved: false),
                idempotencyKey: "k3"
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(
            api.capturedEndpoints.last?.path,
            "/api/v1/trainerlab/simulations/7/problems/3/"
        )
    }

    func testScenarioBriefDecodesArrayFields() throws {
        let json = """
        {
          "read_aloud_brief": "Move now.",
          "environment": "Urban",
          "location_overview": "Street",
          "threat_context": "Active threat",
          "evacuation_options": ["ground", "air"],
          "evacuation_time": "15 min",
          "special_considerations": ["night", "rain"]
        }
        """
        let brief = try JSONDecoder().decode(ScenarioBriefOut.self, from: Data(json.utf8))
        XCTAssertEqual(brief.evacuationOptions, ["ground", "air"])
        XCTAssertEqual(brief.specialConsiderations, ["night", "rain"])
    }

    func testAnnotationCreateRequestEncodesCurrentBackendKeys() throws {
        let request = AnnotationCreateRequest(
            observationText: "Applied tourniquet.",
            learningObjective: "hemorrhage_control",
            outcome: "correct",
            linkedEventID: 99,
            elapsedSecondsAt: 120
        )
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertEqual(object?["observation_text"] as? String, "Applied tourniquet.")
        XCTAssertEqual(object?["learning_objective"] as? String, "hemorrhage_control")
        XCTAssertEqual(object?["outcome"] as? String, "correct")
        XCTAssertEqual(object?["linked_event_id"] as? Int, 99)
        XCTAssertEqual(object?["elapsed_seconds_at"] as? Int, 120)
    }

    func testCommandQueueMigrationRewritesAndPurgesLegacyEndpoints() async throws {
        let dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("trainerlab-queue-migration-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        try seedLegacyQueueDatabase(at: dbURL)

        let store = try GRDBCommandQueueStore(fileURL: dbURL)
        let rows = try await store.nextRetryBatch(limit: 10, now: Date.distantFuture)
        let endpoints = Set(rows.map(\.endpoint))

        XCTAssertTrue(endpoints.contains("/api/v1/trainerlab/simulations/77/adjust/"))
        XCTAssertTrue(endpoints.contains("/api/v1/trainerlab/simulations/"))
        XCTAssertFalse(endpoints.contains("/api/v1/trainerlab/sessions/55/run/start/"))
        let pendingCount = try await store.pendingCount()
        XCTAssertEqual(pendingCount, 2)
    }

    private func seedLegacyQueueDatabase(at url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw NSError(domain: "TrainerLabContractTests", code: 1)
        }
        defer { sqlite3_close(db) }

        try execSQL(
            db,
            """
            CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY);
            CREATE TABLE pending_commands (
              local_id INTEGER PRIMARY KEY AUTOINCREMENT,
              idempotency_key TEXT NOT NULL UNIQUE,
              endpoint TEXT NOT NULL,
              method TEXT NOT NULL,
              body_base64 TEXT,
              body_hash TEXT NOT NULL,
              created_at TEXT NOT NULL,
              retry_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT,
              next_retry_at TEXT NOT NULL,
              ack_state TEXT NOT NULL
            );
            INSERT INTO grdb_migrations(identifier) VALUES ('create_pending_commands');
            """
        )

        try execSQL(
            db,
            """
            INSERT INTO pending_commands
              (idempotency_key, endpoint, method, body_base64, body_hash, created_at, retry_count, last_error, next_retry_at, ack_state)
            VALUES
              ('old-adjust', '/api/v1/simulations/77/adjust/', 'POST', NULL, 'h1', '2026-03-12T00:00:00Z', 0, NULL, '2026-03-12T00:00:00Z', 'pending'),
              ('old-session-run', '/api/v1/trainerlab/sessions/55/run/start/', 'POST', NULL, 'h2', '2026-03-12T00:00:00Z', 0, NULL, '2026-03-12T00:00:00Z', 'pending'),
              ('old-sessions-root', '/api/v1/trainerlab/sessions/', 'POST', NULL, 'h3', '2026-03-12T00:00:00Z', 0, NULL, '2026-03-12T00:00:00Z', 'pending');
            """
        )
    }

    private func execSQL(_ db: OpaquePointer, _ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown sqlite error"
            sqlite3_free(errorMessage)
            throw NSError(
                domain: "TrainerLabContractTests",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }
}
