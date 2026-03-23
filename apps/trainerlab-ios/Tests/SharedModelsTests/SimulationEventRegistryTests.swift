import SharedModels
import XCTest

final class SimulationEventRegistryTests: XCTestCase {
    func testCanonicalDurableEventTypesMatchBackendRegistry() {
        let expected = Set([
            "message.item.created",
            "message.delivery.updated",
            "patient.metadata.created",
            "patient.results.updated",
            "feedback.item.created",
            "feedback.generation.failed",
            "feedback.generation.updated",
            "simulation.status.updated",
            "simulation.brief.created",
            "simulation.brief.updated",
            "simulation.snapshot.updated",
            "simulation.plan.updated",
            "simulation.patch.completed",
            "simulation.tick.triggered",
            "simulation.summary.updated",
            "simulation.runtime.failed",
            "simulation.preset.updated",
            "simulation.command.updated",
            "simulation.adjustment.updated",
            "simulation.note.created",
            "simulation.annotation.created",
            "patient.injury.created",
            "patient.injury.updated",
            "patient.illness.created",
            "patient.illness.updated",
            "patient.problem.created",
            "patient.problem.updated",
            "patient.recommendedintervention.created",
            "patient.recommendedintervention.updated",
            "patient.recommendedintervention.removed",
            "patient.intervention.created",
            "patient.intervention.updated",
            "patient.assessmentfinding.created",
            "patient.assessmentfinding.updated",
            "patient.assessmentfinding.removed",
            "patient.diagnosticresult.created",
            "patient.diagnosticresult.updated",
            "patient.resource.updated",
            "patient.disposition.updated",
            "patient.recommendationevaluation.created",
            "patient.vital.created",
            "patient.vital.updated",
            "patient.pulse.created",
            "patient.pulse.updated",
        ])

        XCTAssertEqual(Set(SimulationEventType.allCanonicalDurable), expected)
        XCTAssertEqual(SimulationEventRegistry.knownCanonicalDurableEventTypes, expected)
        XCTAssertEqual(expected.count, 44)

        for eventType in expected {
            XCTAssertEqual(SimulationEventRegistry.canonicalize(eventType), eventType)
            XCTAssertTrue(SimulationEventRegistry.isKnown(eventType))
        }
    }

    func testTransientSocketEventTypesMatchBackendRegistry() {
        let expected = Set([
            "connected",
            "disconnected",
            "init_message",
            "error",
            "typing",
            "stopped_typing",
            "simulation.feedback.continue_conversation",
            "simulation.hotwash.continue_conversation",
        ])

        XCTAssertEqual(Set(SimulationEventType.transientSocketOnly), expected)
        XCTAssertEqual(SimulationEventRegistry.knownTransientEventTypes, expected)
        XCTAssertEqual(expected.count, 8)

        for eventType in expected {
            XCTAssertEqual(SimulationEventRegistry.canonicalize(eventType), eventType)
            XCTAssertTrue(SimulationEventRegistry.isTransientSocketEvent(eventType))
        }
    }

    func testAliasMapMatchesBackendRegistry() {
        let expected: [String: String] = [
            "chat.message_created": "message.item.created",
            "message_status_update": "message.delivery.updated",
            "metadata.created": "patient.metadata.created",
            "simulation.metadata.results_created": "patient.results.updated",
            "feedback.created": "feedback.item.created",
            "simulation.feedback_created": "feedback.item.created",
            "simulation.hotwash.created": "feedback.item.created",
            "feedback.failed": "feedback.generation.failed",
            "feedback.retrying": "feedback.generation.updated",
            "simulation.state_changed": "simulation.status.updated",
            "simulation.ended": "simulation.status.updated",
            "run.started": "simulation.status.updated",
            "run.paused": "simulation.status.updated",
            "run.resumed": "simulation.status.updated",
            "run.stopped": "simulation.status.updated",
            "session.seeded": "simulation.status.updated",
            "session.failed": "simulation.status.updated",
            "session.seeding": "simulation.status.updated",
            "trainerlab.scenario_brief.created": "simulation.brief.created",
            "trainerlab.scenario_brief.updated": "simulation.brief.updated",
            "state.updated": "simulation.snapshot.updated",
            "ai.intent.updated": "simulation.plan.updated",
            "trainerlab.control_plane.patch_evaluated": "simulation.patch.completed",
            "simulation.patch_evaluation.completed": "simulation.patch.completed",
            "trainerlab.tick.triggered": "simulation.tick.triggered",
            "summary.ready": "simulation.summary.updated",
            "summary.updated": "simulation.summary.updated",
            "simulation.summary.ready": "simulation.summary.updated",
            "runtime.failed": "simulation.runtime.failed",
            "preset.applied": "simulation.preset.updated",
            "command.accepted": "simulation.command.updated",
            "adjustment.accepted": "simulation.adjustment.updated",
            "adjustment.applied": "simulation.adjustment.updated",
            "trainerlab.adjustment.accepted": "simulation.adjustment.updated",
            "trainerlab.adjustment.applied": "simulation.adjustment.updated",
            "note.created": "simulation.note.created",
            "trainerlab.annotation.created": "simulation.annotation.created",
            "injury.created": "patient.injury.created",
            "injury.updated": "patient.injury.updated",
            "illness.created": "patient.illness.created",
            "illness.updated": "patient.illness.updated",
            "problem.created": "patient.problem.created",
            "problem.updated": "patient.problem.updated",
            "problem.resolved": "patient.problem.updated",
            "recommended_intervention.created": "patient.recommendedintervention.created",
            "patient.recommended_intervention.created": "patient.recommendedintervention.created",
            "recommended_intervention.updated": "patient.recommendedintervention.updated",
            "patient.recommended_intervention.updated": "patient.recommendedintervention.updated",
            "recommended_intervention.removed": "patient.recommendedintervention.removed",
            "patient.recommended_intervention.removed": "patient.recommendedintervention.removed",
            "intervention.created": "patient.intervention.created",
            "intervention.updated": "patient.intervention.updated",
            "trainerlab.intervention.assessed": "patient.intervention.updated",
            "trainerlab.assessment_finding.created": "patient.assessmentfinding.created",
            "patient.assessment_finding.created": "patient.assessmentfinding.created",
            "trainerlab.assessment_finding.updated": "patient.assessmentfinding.updated",
            "patient.assessment_finding.updated": "patient.assessmentfinding.updated",
            "trainerlab.assessment_finding.removed": "patient.assessmentfinding.removed",
            "patient.assessment_finding.removed": "patient.assessmentfinding.removed",
            "trainerlab.diagnostic_result.created": "patient.diagnosticresult.created",
            "patient.diagnostic_result.created": "patient.diagnosticresult.created",
            "trainerlab.diagnostic_result.updated": "patient.diagnosticresult.updated",
            "patient.diagnostic_result.updated": "patient.diagnosticresult.updated",
            "trainerlab.resource.updated": "patient.resource.updated",
            "trainerlab.disposition.updated": "patient.disposition.updated",
            "trainerlab.recommendation_evaluation.created": "patient.recommendationevaluation.created",
            "patient.recommendation_evaluation.created": "patient.recommendationevaluation.created",
            "trainerlab.vital.created": "patient.vital.created",
            "trainerlab.vital.updated": "patient.vital.updated",
            "trainerlab.pulse.created": "patient.pulse.created",
            "trainerlab.pulse.updated": "patient.pulse.updated",
        ]

        XCTAssertEqual(SimulationEventRegistry.aliasToCanonicalMap, expected)

        for (alias, canonical) in expected {
            XCTAssertEqual(SimulationEventRegistry.canonicalize(alias), canonical)
        }
    }

    func testUnknownEventFallbackLowercasesButStaysUnknown() {
        XCTAssertEqual(
            SimulationEventRegistry.canonicalize("SIMULATION.SOMETHING.NEW"),
            "simulation.something.new",
        )
        XCTAssertFalse(SimulationEventRegistry.isKnown("SIMULATION.SOMETHING.NEW"))
    }

    func testLifecycleAliasesEnrichPayloadDuringCanonicalization() {
        let legacyPaused = EventEnvelope(
            eventID: "pause-1",
            eventType: "run.paused",
            createdAt: Date(),
            correlationID: nil,
            payload: [:],
        ).canonicalized()

        XCTAssertEqual(legacyPaused.eventType, SimulationEventType.simulationStatusUpdated)
        XCTAssertEqual(legacyPaused.payload["status"], .string("paused"))
        XCTAssertEqual(legacyPaused.payload["from"], .string("running"))
        XCTAssertEqual(legacyPaused.payload["to"], .string("paused"))
    }

    func testDisplayTitleUsesCanonicalLifecycleSemantics() throws {
        let pausedPayload = try SimulationStatusUpdatedPayload.decode(from: [
            "status": .string("running"),
            "from": .string("paused"),
            "to": .string("running"),
        ])

        XCTAssertEqual(
            SimulationEventRegistry.lifecycleDisplay(for: pausedPayload, previousStatus: .paused).title,
            "Run Resumed",
        )
        XCTAssertEqual(
            SimulationEventRegistry.displayTitle(
                for: SimulationEventType.patientRecommendedInterventionRemoved,
            ),
            "Recommendation",
        )
    }

    func testAuditEntriesCoverEveryKnownEventAndDeclarePresentationTargets() {
        let auditEntries = SimulationEventRegistry.auditEntries
        let expectedEventTypes = Set(
            SimulationEventType.allCanonicalDurable + SimulationEventType.transientSocketOnly,
        )

        XCTAssertEqual(auditEntries.count, expectedEventTypes.count)
        XCTAssertEqual(Set(auditEntries.map(\.canonicalEventType)), expectedEventTypes)
        XCTAssertTrue(auditEntries.allSatisfy { !$0.presentationTargets.isEmpty })
    }

    func testAuditEntriesCaptureRepresentativePresentationPolicies() {
        let lifecycle = SimulationEventRegistry.auditEntry(for: SimulationEventType.simulationStatusUpdated)
        XCTAssertEqual(
            lifecycle?.presentationTargets,
            [.trainerClinicalTimeline, .trainerOperationalLog, .trainerRunSummary, .chatStatusBanner, .chatActivity],
        )
        XCTAssertEqual(
            lifecycle?.refreshTargets,
            ["trainer.seeded.rehydrate", "trainer.runtime.refresh"],
        )

        let assessmentFinding = SimulationEventRegistry.auditEntry(for: SimulationEventType.patientAssessmentFindingCreated)
        XCTAssertEqual(
            assessmentFinding?.hydrationTargets,
            ["trainer.assessment_findings"],
        )
        XCTAssertEqual(
            assessmentFinding?.presentationTargets,
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        )

        let feedbackFailure = SimulationEventRegistry.auditEntry(for: "feedback.failed")
        XCTAssertEqual(feedbackFailure?.canonicalEventType, SimulationEventType.feedbackGenerationFailed)
        XCTAssertEqual(feedbackFailure?.presentationTargets, [.chatStatusBanner, .chatActivity])

        let patientResults = SimulationEventRegistry.auditEntry(for: SimulationEventType.patientResultsUpdated)
        XCTAssertEqual(
            patientResults?.presentationTargets,
            [.trainerOperationalLog, .trainerRunSummary, .chatToolsPane, .chatActivity],
        )

        let typing = SimulationEventRegistry.auditEntry(for: SimulationEventType.typing)
        XCTAssertEqual(typing?.presentationTargets, [.chatTypingIndicator])

        let connected = SimulationEventRegistry.auditEntry(for: SimulationEventType.connected)
        XCTAssertEqual(connected?.presentationTargets, [.explicitNoOp])
    }

    func testDisplayMessageUsesRepresentativeCanonicalMessages() {
        XCTAssertEqual(
            SimulationEventRegistry.displayMessage(
                for: SimulationEventType.patientResultsUpdated,
            ),
            "Patient results refreshed.",
        )
        XCTAssertEqual(
            SimulationEventRegistry.displayMessage(
                for: SimulationEventType.feedbackGenerationFailed,
                payload: ["error_text": .string("Feedback pipeline timed out")],
            ),
            "Feedback pipeline timed out",
        )
    }
}
