import Foundation
import Networking
import Persistence
import SharedModels
import SQLite3
import XCTest

private enum RecordingError: Error {
    case intercepted
}

private final class RecordingAPIClient: APIClientProtocol, @unchecked Sendable {
    private(set) var capturedEndpoints: [Endpoint] = []
    var responseDataByPath: [String: Data] = [:]

    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as _: T.Type) async throws -> T {
        capturedEndpoints.append(endpoint)
        if let data = responseDataByPath[endpoint.path] {
            return try makeContractDecoder().decode(T.self, from: data)
        }
        throw RecordingError.intercepted
    }

    func requestData(_ endpoint: Endpoint) async throws -> Data {
        capturedEndpoints.append(endpoint)
        if let data = responseDataByPath[endpoint.path] {
            return data
        }
        throw RecordingError.intercepted
    }

    func baseURL() async -> URL {
        URL(string: "https://example.com")!
    }
}

private final class RecordingTokenProvider: AuthTokenProvider, @unchecked Sendable {
    var tokens: AuthTokens?
    var cleared = false

    func loadTokens() -> AuthTokens? {
        tokens
    }

    func saveTokens(_ tokens: AuthTokens) {
        self.tokens = tokens
    }

    func clearTokens() {
        cleared = true
        tokens = nil
    }
}

final class TrainerLabContractTests: XCTestCase {
    func testTrainerRunDecodesWithoutLegacyID() throws {
        let json = """
        {
          "simulation_id": 420,
          "status": "seeding",
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
        XCTAssertEqual(run.status, .seeding)
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

    func testSimulationStateChangedEnvelopeDecodesExactFailurePayload() throws {
        let json = """
        {
          "event_id": "cfb87f10-d622-42af-9eff-1267e51607d6",
          "event_type": "simulation.state_changed",
          "created_at": "2026-03-20T13:54:34.990952+00:00",
          "correlation_id": "",
          "payload": {
            "status": "failed",
            "retryable": true,
            "terminal_at": "2026-03-20T13:54:34.986942+00:00",
            "simulation_id": 1,
            "terminal_reason_code": "trainerlab_initial_generation_enqueue_failed",
            "terminal_reason_text": "We could not start this simulation. Please try again."
          },
          "status": "delivered",
          "delivery_attempts": 0,
          "last_error": null,
          "idempotency_key": "simulation.state_changed:b5cd7d71-7e95-44ef-9ccd-9d3e5e1f3cb2"
        }
        """

        let event = try makeContractDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
        let payload = try event.decodePayload(SimulationStateChangedPayload.self)

        XCTAssertEqual(event.eventType, "simulation.state_changed")
        XCTAssertEqual(payload.status, "failed")
        XCTAssertEqual(payload.retryable, true)
        XCTAssertEqual(payload.simulationID, 1)
        XCTAssertEqual(payload.terminalReasonCode, "trainerlab_initial_generation_enqueue_failed")
        XCTAssertEqual(payload.terminalReasonText, "We could not start this simulation. Please try again.")
    }

    func testSessionSeedingEnvelopeDecodesLifecyclePayload() throws {
        let json = """
        {
          "event_id": "seed-1",
          "event_type": "session.seeding",
          "created_at": "2026-03-20T13:54:34.990952+00:00",
          "correlation_id": "",
          "payload": {
            "status": "seeding",
            "scenario_spec": {
              "diagnosis": "Tension pneumothorax",
              "modifiers": ["night-ops"]
            },
            "state_revision": 3,
            "retry_count": 1,
            "simulation_id": 7,
            "extra_field": "ignored"
          }
        }
        """

        let event = try makeContractDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
        let payload = try event.decodePayload(SessionSeedingPayload.self)

        XCTAssertEqual(event.eventType, "session.seeding")
        XCTAssertEqual(payload.status, "seeding")
        XCTAssertEqual(payload.stateRevision, 3)
        XCTAssertEqual(payload.retryCount, 1)
        XCTAssertEqual(payload.simulationID, 7)
        XCTAssertEqual(payload.scenarioSpec["diagnosis"], .string("Tension pneumothorax"))
        XCTAssertEqual(payload.scenarioSpec["modifiers"], .array([.string("night-ops")]))
    }

    func testSessionSeededEnvelopeDecodesLifecyclePayloadWithOptionalCallID() throws {
        let json = """
        {
          "event_id": "seed-2",
          "event_type": "session.seeded",
          "created_at": "2026-03-20T13:55:34.990952+00:00",
          "correlation_id": "",
          "payload": {
            "status": "seeded",
            "scenario_spec": {
              "diagnosis": "Tension pneumothorax"
            },
            "state_revision": 4,
            "call_id": "call-123",
            "simulation_id": 7
          }
        }
        """

        let event = try makeContractDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
        let payload = try event.decodePayload(SessionSeededPayload.self)

        XCTAssertEqual(event.eventType, "session.seeded")
        XCTAssertEqual(payload.status, "seeded")
        XCTAssertEqual(payload.stateRevision, 4)
        XCTAssertEqual(payload.callID, "call-123")
        XCTAssertEqual(payload.simulationID, 7)
        XCTAssertEqual(payload.scenarioSpec["diagnosis"], .string("Tension pneumothorax"))
    }

    func testSessionFailedEnvelopeDecodesLifecyclePayload() throws {
        let json = """
        {
          "event_id": "seed-3",
          "event_type": "session.failed",
          "created_at": "2026-03-20T13:56:34.990952+00:00",
          "correlation_id": "",
          "payload": {
            "status": "failed",
            "reason_code": "trainerlab_initial_generation_failed",
            "reason_text": "The initial scenario could not be generated.",
            "retryable": false,
            "simulation_id": 7
          }
        }
        """

        let event = try makeContractDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
        let payload = try event.decodePayload(SessionFailedPayload.self)

        XCTAssertEqual(event.eventType, "session.failed")
        XCTAssertEqual(payload.status, "failed")
        XCTAssertEqual(payload.reasonCode, "trainerlab_initial_generation_failed")
        XCTAssertEqual(payload.reasonText, "The initial scenario could not be generated.")
        XCTAssertEqual(payload.retryable, false)
        XCTAssertEqual(payload.simulationID, 7)
    }

    func testScenarioInstructionApplyEncodesSimulationID() throws {
        let request = ScenarioInstructionApplyRequest(simulationID: 77)
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertEqual(object?["simulation_id"] as? Int, 77)
        XCTAssertNil(object?["session_id"])
    }

    func testInterventionDictionaryDecodesInterventionTypeKey() throws {
        let json = """
        {
          "intervention_type": "tourniquet",
          "label": "Tourniquet",
          "sites": []
        }
        """

        let group = try JSONDecoder().decode(InterventionGroup.self, from: Data(json.utf8))
        XCTAssertEqual(group.interventionType, "tourniquet")
    }

    func testIllnessEventRequestEncodesCurrentBackendKeys() throws {
        let request = IllnessEventRequest(name: "sepsis", description: "Fever and hypotension")
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        XCTAssertEqual(object?["illness_name"] as? String, "sepsis")
        XCTAssertEqual(object?["illness_description"] as? String, "Fever and hypotension")
        XCTAssertNil(object?["name"])
        XCTAssertNil(object?["description"])
    }

    func testInterventionEventRequestOmitsNilTargetProblemID() throws {
        let request = InterventionEventRequest(
            interventionType: "tourniquet",
            siteCode: "LEFT_ARM",
            targetProblemID: nil,
        )
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        XCTAssertEqual(object?["intervention_type"] as? String, "tourniquet")
        XCTAssertEqual(object?["site_code"] as? String, "LEFT_ARM")
        XCTAssertNil(object?["target_problem_id"])
    }

    func testInterventionEventRequestEncodesCurrentBackendKeys() throws {
        let request = InterventionEventRequest(
            interventionType: "tourniquet",
            siteCode: "left_arm",
            targetProblemID: 19,
            status: .applied,
            effectiveness: .effective,
            notes: "Applied high and tight",
        )
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let details = object?["details"] as? [String: Any]

        XCTAssertEqual(object?["target_problem_id"] as? Int, 19)
        XCTAssertEqual(object?["initiated_by_type"] as? String, "instructor")
        XCTAssertNil(object?["performed_by_role"])
        XCTAssertNil(object?["body"])
        XCTAssertEqual(details?["kind"] as? String, "tourniquet")
        XCTAssertEqual(details?["application_mode"] as? String, "hasty")
    }

    func testInterventionEventRequestEncodesExplicitTourniquetApplicationMode() throws {
        let request = InterventionEventRequest(
            interventionType: "tourniquet",
            siteCode: "left_arm",
            targetProblemID: 19,
            tourniquetApplicationMode: .deliberate,
        )
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let details = object?["details"] as? [String: Any]

        XCTAssertEqual(object?["intervention_type"] as? String, "tourniquet")
        XCTAssertEqual(details?["kind"] as? String, "tourniquet")
        XCTAssertEqual(details?["version"] as? Double, 1)
        XCTAssertEqual(details?["application_mode"] as? String, "deliberate")
    }

    func testSimulationNoteCreateRequestEncodesCurrentBackendKeys() throws {
        let request = SimulationNoteCreateRequest(
            content: "Observe airway",
            sendToAI: true,
            performedByRole: "instructor",
        )
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        XCTAssertEqual(object?["content"] as? String, "Observe airway")
        XCTAssertEqual(object?["send_to_ai"] as? Bool, true)
        XCTAssertEqual(object?["performed_by_role"] as? String, "instructor")
    }

    func testAuthServiceLogoutPostsRefreshTokenAndClearsLocalTokens() async {
        let api = RecordingAPIClient()
        let tokenProvider = RecordingTokenProvider()
        tokenProvider.tokens = AuthTokens(accessToken: "a", refreshToken: "r", expiresIn: 3600, tokenType: "Bearer")
        let service = AuthService(apiClient: api, tokenProvider: tokenProvider)

        await service.signOut()

        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/auth/logout/")
        XCTAssertEqual(api.capturedEndpoints.last?.method, .post)
        XCTAssertEqual(api.capturedEndpoints.last?.requiresAuth, false)
        XCTAssertEqual(
            try? decodeJSONBody(api.capturedEndpoints.last?.body)?["refresh_token"] as? String,
            "r",
        )
        XCTAssertTrue(tokenProvider.cleared)
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
            "/api/v1/trainerlab/simulations/7/run/start/",
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
                    note: nil,
                ),
                idempotencyKey: "k2",
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(
            api.capturedEndpoints.last?.path,
            "/api/v1/trainerlab/simulations/7/adjust/",
        )

        do {
            _ = try await service.listEvents(simulationID: 7, cursor: nil, limit: 50)
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(
            api.capturedEndpoints.last?.path,
            "/api/v1/trainerlab/simulations/7/events/",
        )

        do {
            _ = try await service.updateProblemStatus(
                simulationID: 7,
                problemID: 3,
                request: ProblemStatusUpdateRequest(isTreated: true, isResolved: false),
                idempotencyKey: "k3",
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(
            api.capturedEndpoints.last?.path,
            "/api/v1/trainerlab/simulations/7/problems/3/",
        )

        do {
            _ = try await service.getControlPlaneDebug(simulationID: 7)
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/trainerlab/simulations/7/control-plane/")

        do {
            _ = try await service.triggerRunTick(simulationID: 7, idempotencyKey: "k4")
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/trainerlab/simulations/7/run/tick/")

        do {
            _ = try await service.triggerVitalsTick(simulationID: 7, idempotencyKey: "k5")
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/trainerlab/simulations/7/run/tick/vitals/")

        do {
            _ = try await service.createNoteEvent(
                simulationID: 7,
                request: SimulationNoteCreateRequest(content: "Observe airway"),
                idempotencyKey: "k6",
            )
            XCTFail("Expected intercepted error")
        } catch {
            XCTAssertTrue(error is RecordingError)
        }
        XCTAssertEqual(api.capturedEndpoints.last?.path, "/api/v1/trainerlab/simulations/7/events/notes/")
        XCTAssertEqual(
            try decodeJSONBody(api.capturedEndpoints.last?.body)?["content"] as? String,
            "Observe airway",
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

    func testRetryInitialSimulationUsesTrainerLabRetryEndpointThenReloadsCurrentTrainerSession() async throws {
        let api = RecordingAPIClient()
        api.responseDataByPath["/api/v1/trainerlab/simulations/7/retry-initial/"] = Data()
        api.responseDataByPath["/api/v1/trainerlab/simulations/7/"] = Data(
            """
            {
              "simulation_id": 7,
              "status": "seeding",
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
            """.utf8,
        )
        let service = TrainerLabService(apiClient: api)

        let session = try await service.retryInitialSimulation(simulationID: 7)

        XCTAssertEqual(session.simulationID, 7)
        XCTAssertEqual(session.status, .seeding)
        XCTAssertEqual(api.capturedEndpoints.map(\.path), [
            "/api/v1/trainerlab/simulations/7/retry-initial/",
            "/api/v1/trainerlab/simulations/7/",
        ])
    }

    func testTrainerRuntimeStateDecodesRuntimeAdditions() throws {
        let json = """
        {
          "simulation_id": 420,
          "session_id": 420,
          "status": "running",
          "state_revision": 12,
          "active_elapsed_seconds": 90,
          "tick_interval_seconds": 30,
          "next_tick_at": "2026-03-12T12:01:30Z",
          "scenario_brief": null,
          "current_snapshot": {
            "causes": [],
            "problems": [],
            "vitals": [],
            "annotations": [],
            "assessment_findings": [],
            "diagnostic_results": [],
            "resources": [],
            "disposition": null,
            "recommended_interventions": []
          },
          "ai_plan": {
            "summary": "Monitor airway",
            "rationale": "",
            "trigger": "",
            "eta_seconds": null,
            "confidence": 0.5,
            "upcoming_changes": [],
            "monitoring_focus": []
          },
          "ai_rationale_notes": ["watching trend"],
          "pending_runtime_reasons": [{"kind": "trend"}],
          "pending_reasons": [{"kind": "manual"}],
          "currently_processing_reasons": [{"kind": "tick"}],
          "last_runtime_error": "none",
          "last_ai_tick_at": "2026-03-12T12:01:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(TrainerRuntimeStateOut.self, from: Data(json.utf8))

        XCTAssertEqual(state.tickIntervalSeconds, 30)
        XCTAssertEqual(state.aiPlan?.summary, "Monitor airway")
        XCTAssertEqual(state.pendingRuntimeReasons.count, 1)
        XCTAssertEqual(state.currentlyProcessingReasons.count, 1)
        XCTAssertEqual(state.lastRuntimeError, "none")
        XCTAssertNotNil(state.nextTickAt)
        XCTAssertNotNil(state.lastAITickAt)
    }

    func testTrainerRuntimeStateDecodesVitalWithoutLockValue() throws {
        let json = """
        {
          "simulation_id": 420,
          "status": "running",
          "current_snapshot": {
            "causes": [],
            "problems": [],
            "recommended_interventions": [],
            "interventions": [],
            "assessment_findings": [],
            "diagnostic_results": [],
            "resources": [],
            "disposition": null,
            "vitals": [
              {
                "vital_type": "heart_rate",
                "min_value": 80,
                "max_value": 120
              }
            ],
            "pulses": [],
            "patient_status": {}
          }
        }
        """

        let state = try makeContractDecoder().decode(TrainerRuntimeStateOut.self, from: Data(json.utf8))

        XCTAssertEqual(state.currentSnapshot.vitals.first?.vitalType, "heart_rate")
        XCTAssertNil(state.currentSnapshot.vitals.first?.lockValue)
    }

    func testTrainerRuntimeStateDecodesSparseAIPlan() throws {
        let json = """
        {
          "simulation_id": 420,
          "status": "running",
          "current_snapshot": {
            "causes": [],
            "problems": [],
            "recommended_interventions": [],
            "interventions": [],
            "assessment_findings": [],
            "diagnostic_results": [],
            "resources": [],
            "disposition": null,
            "vitals": [],
            "pulses": [],
            "patient_status": {}
          },
          "ai_plan": {
            "summary": "Watch SpO2"
          }
        }
        """

        let state = try makeContractDecoder().decode(TrainerRuntimeStateOut.self, from: Data(json.utf8))

        XCTAssertEqual(state.aiPlan?.summary, "Watch SpO2")
        XCTAssertEqual(state.aiPlan?.rationale, "")
        XCTAssertEqual(state.aiPlan?.monitoringFocus, [])
    }

    func testTrainerRuntimeStateDecodesAliasedHydrationKeysWithoutWipingPresence() throws {
        let json = """
        {
          "simulation_id": 420,
          "status": "running",
          "scenario_brief": {
            "read_aloud_brief": "Patient found after blast exposure."
          },
          "current_snapshot": {
            "injuries": [
              {
                "cause_id": 11,
                "kind": "injury",
                "title": "Blast Injury",
                "description": "Open wound to the left arm",
                "injury_location": "LEFT_ARM"
              }
            ],
            "conditions": [
              {
                "problem_id": 21,
                "title": "Hemorrhagic Shock",
                "status": "active",
                "cause_id": 11,
                "anatomical_location": "LEFT_ARM"
              }
            ],
            "interventions": [],
            "pulses": [],
            "vitals": [],
            "patient_status": {
              "narrative": "Bleeding remains uncontrolled."
            }
          },
          "ai_instructor": {
            "summary": "Control hemorrhage first"
          }
        }
        """

        let state = try makeContractDecoder().decode(TrainerRuntimeStateOut.self, from: Data(json.utf8))

        XCTAssertEqual(state.scenarioBrief?.readAloudBrief, "Patient found after blast exposure.")
        XCTAssertEqual(state.currentSnapshot.causes.first?.causeID, 11)
        XCTAssertEqual(state.currentSnapshot.problems.first?.problemID, 21)
        XCTAssertEqual(state.currentSnapshot.patientStatus.narrative, "Bleeding remains uncontrolled.")
        XCTAssertEqual(state.aiPlan?.summary, "Control hemorrhage first")
        XCTAssertEqual(state.presence.scenarioBrief, true)
        XCTAssertEqual(state.presence.aiPlan, true)
        XCTAssertEqual(state.presence.aiRationaleNotes, false)
        XCTAssertEqual(state.currentSnapshot.presence.causes, true)
        XCTAssertEqual(state.currentSnapshot.presence.problems, true)
        XCTAssertEqual(state.currentSnapshot.presence.interventions, true)
        XCTAssertEqual(state.currentSnapshot.presence.vitals, true)
        XCTAssertEqual(state.currentSnapshot.presence.patientStatus, true)
        XCTAssertEqual(state.currentSnapshot.presence.recommendedInterventions, false)
    }

    func testRecommendedInterventionRemovedEnvelopeDecodesWithoutStrictPayloadSchema() throws {
        let json = """
        {
          "event_id": "rec-removed-1",
          "event_type": "recommended_intervention.removed",
          "created_at": "2026-03-20T13:56:34.990952+00:00",
          "payload": {
            "recommendation_id": 91,
            "target_problem_id": 12
          }
        }
        """

        let event = try makeContractDecoder().decode(EventEnvelope.self, from: Data(json.utf8))

        XCTAssertEqual(event.eventType, "recommended_intervention.removed")
        XCTAssertEqual(event.payload["recommendation_id"], .number(91))
    }

    func testControlPlaneDebugDecodesCurrentBackendShape() throws {
        let json = """
        {
          "execution_plan": ["assess", "stabilize"],
          "current_step_index": 1,
          "queued_reasons": [{"reason": "manual"}],
          "currently_processing_reasons": [{"reason": "tick"}],
          "last_processed_reasons": [{"reason": "done"}],
          "last_failed_step": "",
          "last_failed_error": "",
          "last_patch_evaluation_summary": {"accepted": 1},
          "last_rejected_or_normalized_summary": {"normalized": true},
          "status_flags": {"paused": false}
        }
        """

        let debug = try JSONDecoder().decode(ControlPlaneDebugOut.self, from: Data(json.utf8))

        XCTAssertEqual(debug.executionPlan, ["assess", "stabilize"])
        XCTAssertEqual(debug.currentStepIndex, 1)
        XCTAssertEqual(debug.queuedReasons.count, 1)
        XCTAssertEqual(debug.lastPatchEvaluationSummary["accepted"], .number(1))
        XCTAssertEqual(debug.statusFlags["paused"], .bool(false))
    }

    func testAnnotationEnumsMatchBackendContract() {
        XCTAssertEqual(
            AnnotationLearningObjective.allCases.map(\.rawValue),
            [
                "assessment",
                "hemorrhage_control",
                "airway",
                "breathing",
                "circulation",
                "hypothermia",
                "communication",
                "triage",
                "intervention",
                "other",
            ],
        )
        XCTAssertEqual(
            AnnotationOutcome.allCases.map(\.rawValue),
            [
                "correct",
                "incorrect",
                "missed",
                "improvised",
                "pending",
            ],
        )
    }

    func testAnnotationCreateRequestEncodesCurrentBackendKeys() throws {
        let request = AnnotationCreateRequest(
            observationText: "Applied tourniquet.",
            learningObjective: .hemorrhageControl,
            outcome: .correct,
            linkedEventID: 99,
            elapsedSecondsAt: 120,
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
        let rows = try await store.nextRetryBatch(limit: 10, now: Date.distantFuture, simulationID: nil)
        let endpoints = Set(rows.map(\.endpoint))

        XCTAssertTrue(endpoints.contains("/api/v1/trainerlab/simulations/77/adjust/"))
        XCTAssertTrue(endpoints.contains("/api/v1/trainerlab/simulations/"))
        XCTAssertFalse(endpoints.contains("/api/v1/trainerlab/sessions/55/run/start/"))
        let pendingCount = try await store.pendingCount(simulationID: nil)
        XCTAssertEqual(pendingCount, 2)
    }

    func testCommandQueuePendingCountScopesToActiveRowsForSimulation() async throws {
        let dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("trainerlab-queue-pending-count-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let store = try GRDBCommandQueueStore(fileURL: dbURL)

        try await store.enqueue(CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420,
        ))
        try await store.enqueue(CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil,
        ))
        try await store.enqueue(CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/run/start/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 421,
        ))
        try await store.enqueue(CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/421/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil,
        ))
        try await store.enqueue(CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/events/notes/",
            method: HTTPMethod.post.rawValue,
            body: nil,
        ))

        let terminal = CommandEnvelopeBuilder.make(
            endpoint: "/api/v1/trainerlab/simulations/420/run/stop/",
            method: HTTPMethod.post.rawValue,
            body: Data(),
            simulationID: 420,
        )
        try await store.enqueue(terminal)
        try await store.markTerminalFailure(idempotencyKey: terminal.idempotencyKey, error: "terminal")

        let currentSimulationCount = try await store.pendingCount(simulationID: 420)
        let otherSimulationCount = try await store.pendingCount(simulationID: 421)
        let globalCount = try await store.pendingCount(simulationID: nil)

        XCTAssertEqual(currentSimulationCount, 2)
        XCTAssertEqual(otherSimulationCount, 2)
        XCTAssertEqual(globalCount, 5)
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
            """,
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
            """,
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
                userInfo: [NSLocalizedDescriptionKey: message],
            )
        }
    }

    private func decodeJSONBody(_ data: Data?) throws -> [String: Any]? {
        guard let data else { return nil }
        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }
}

private func makeContractDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let date = parseISO8601(value) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
    }
    return decoder
}

private func parseISO8601(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) {
        return date
    }

    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: value)
}
