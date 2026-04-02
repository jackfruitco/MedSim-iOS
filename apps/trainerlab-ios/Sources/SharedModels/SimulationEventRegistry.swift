import Foundation

public enum SimulationEventType {
    public static let messageItemCreated = "message.item.created"
    public static let messageDeliveryUpdated = "message.delivery.updated"

    public static let patientMetadataCreated = "patient.metadata.created"
    public static let patientResultsUpdated = "patient.results.updated"

    public static let feedbackItemCreated = "feedback.item.created"
    public static let feedbackGenerationFailed = "feedback.generation.failed"
    public static let feedbackGenerationUpdated = "feedback.generation.updated"

    public static let simulationStatusUpdated = "simulation.status.updated"
    public static let simulationBriefCreated = "simulation.brief.created"
    public static let simulationBriefUpdated = "simulation.brief.updated"
    public static let simulationSnapshotUpdated = "simulation.snapshot.updated"
    public static let simulationPlanUpdated = "simulation.plan.updated"
    public static let simulationPatchCompleted = "simulation.patch.completed"
    public static let simulationTickTriggered = "simulation.tick.triggered"
    public static let simulationSummaryUpdated = "simulation.summary.updated"
    public static let simulationRuntimeFailed = "simulation.runtime.failed"
    public static let simulationPresetUpdated = "simulation.preset.updated"
    public static let simulationCommandUpdated = "simulation.command.updated"
    public static let simulationAdjustmentUpdated = "simulation.adjustment.updated"
    public static let simulationNoteCreated = "simulation.note.created"
    public static let simulationAnnotationCreated = "simulation.annotation.created"

    public static let patientInjuryCreated = "patient.injury.created"
    public static let patientInjuryUpdated = "patient.injury.updated"
    public static let patientIllnessCreated = "patient.illness.created"
    public static let patientIllnessUpdated = "patient.illness.updated"
    public static let patientProblemCreated = "patient.problem.created"
    public static let patientProblemUpdated = "patient.problem.updated"
    public static let patientRecommendedInterventionCreated = "patient.recommendedintervention.created"
    public static let patientRecommendedInterventionUpdated = "patient.recommendedintervention.updated"
    public static let patientRecommendedInterventionRemoved = "patient.recommendedintervention.removed"
    public static let patientInterventionCreated = "patient.intervention.created"
    public static let patientInterventionUpdated = "patient.intervention.updated"
    public static let patientAssessmentFindingCreated = "patient.assessmentfinding.created"
    public static let patientAssessmentFindingUpdated = "patient.assessmentfinding.updated"
    public static let patientAssessmentFindingRemoved = "patient.assessmentfinding.removed"
    public static let patientDiagnosticResultCreated = "patient.diagnosticresult.created"
    public static let patientDiagnosticResultUpdated = "patient.diagnosticresult.updated"
    public static let patientResourceUpdated = "patient.resource.updated"
    public static let patientDispositionUpdated = "patient.disposition.updated"
    public static let patientRecommendationEvaluationCreated = "patient.recommendationevaluation.created"
    public static let patientVitalCreated = "patient.vital.created"
    public static let patientVitalUpdated = "patient.vital.updated"
    public static let patientPulseCreated = "patient.pulse.created"
    public static let patientPulseUpdated = "patient.pulse.updated"

    public static let guardStateUpdated = "guard.state.updated"
    public static let guardWarningUpdated = "guard.warning.updated"

    public static let connected = "connected"
    public static let disconnected = "disconnected"
    public static let initMessage = "init_message"
    public static let error = "error"
    public static let typing = "typing"
    public static let stoppedTyping = "stopped_typing"
    public static let simulationFeedbackContinueConversation = "simulation.feedback.continue_conversation"
    public static let simulationHotwashContinueConversation = "simulation.hotwash.continue_conversation"

    public static let allCanonicalDurable: [String] = [
        messageItemCreated,
        messageDeliveryUpdated,
        patientMetadataCreated,
        patientResultsUpdated,
        feedbackItemCreated,
        feedbackGenerationFailed,
        feedbackGenerationUpdated,
        simulationStatusUpdated,
        simulationBriefCreated,
        simulationBriefUpdated,
        simulationSnapshotUpdated,
        simulationPlanUpdated,
        simulationPatchCompleted,
        simulationTickTriggered,
        simulationSummaryUpdated,
        simulationRuntimeFailed,
        simulationPresetUpdated,
        simulationCommandUpdated,
        simulationAdjustmentUpdated,
        simulationNoteCreated,
        simulationAnnotationCreated,
        patientInjuryCreated,
        patientInjuryUpdated,
        patientIllnessCreated,
        patientIllnessUpdated,
        patientProblemCreated,
        patientProblemUpdated,
        patientRecommendedInterventionCreated,
        patientRecommendedInterventionUpdated,
        patientRecommendedInterventionRemoved,
        patientInterventionCreated,
        patientInterventionUpdated,
        patientAssessmentFindingCreated,
        patientAssessmentFindingUpdated,
        patientAssessmentFindingRemoved,
        patientDiagnosticResultCreated,
        patientDiagnosticResultUpdated,
        patientResourceUpdated,
        patientDispositionUpdated,
        patientRecommendationEvaluationCreated,
        patientVitalCreated,
        patientVitalUpdated,
        patientPulseCreated,
        patientPulseUpdated,
    ]

    public static let transientSocketOnly: [String] = [
        connected,
        disconnected,
        initMessage,
        error,
        typing,
        stoppedTyping,
        simulationFeedbackContinueConversation,
        simulationHotwashContinueConversation,
        guardStateUpdated,
        guardWarningUpdated,
    ]
}

public enum SimulationEventDomain: String, Sendable {
    case message
    case feedback
    case simulation
    case patient
    case transient
    case unknown
}

public enum SimulationEventPresentationTarget: String, CaseIterable, Sendable {
    case trainerClinicalTimeline = "trainer.clinical_timeline"
    case trainerInfoPanel = "trainer.info_panel"
    case trainerOperationalLog = "trainer.operational_log"
    case trainerRunSummary = "trainer.run_summary"
    case chatMessageTimeline = "chat.message_timeline"
    case chatToolsPane = "chat.tools_pane"
    case chatActivity = "chat.activity"
    case chatStatusBanner = "chat.status_banner"
    case chatTypingIndicator = "chat.typing_indicator"
    case explicitNoOp = "explicit.no_op"
}

public struct SimulationEventAuditEntry: Equatable, Sendable {
    public let canonicalEventType: String
    public let legacyAliases: [String]
    public let hydrationTargets: [String]
    public let refreshTargets: [String]
    public let presentationTargets: [SimulationEventPresentationTarget]

    public init(
        canonicalEventType: String,
        legacyAliases: [String],
        hydrationTargets: [String],
        refreshTargets: [String],
        presentationTargets: [SimulationEventPresentationTarget],
    ) {
        self.canonicalEventType = canonicalEventType
        self.legacyAliases = legacyAliases
        self.hydrationTargets = hydrationTargets
        self.refreshTargets = refreshTargets
        self.presentationTargets = presentationTargets
    }
}

public enum SimulationLifecycleSemantic: String, Sendable {
    case seeding
    case seeded
    case started
    case paused
    case resumed
    case completed
    case failed
    case updated
}

public struct SimulationStatusUpdatedPayload: Codable, Equatable, Sendable {
    public let status: String?
    public let phase: String?
    public let fromStatus: String?
    public let toStatus: String?
    public let retryable: Bool?
    public let terminalAt: Date?
    public let simulationID: Int?
    public let sessionID: Int?
    public let scenarioSpec: [String: JSONValue]?
    public let stateRevision: Int?
    public let callID: String?
    public let retryCount: Int?
    public let terminalReasonCode: String?
    public let terminalReasonText: String?
    public let reasonCode: String?
    public let reasonText: String?
    public let action: String?

    public init(
        status: String? = nil,
        phase: String? = nil,
        fromStatus: String? = nil,
        toStatus: String? = nil,
        retryable: Bool? = nil,
        terminalAt: Date? = nil,
        simulationID: Int? = nil,
        sessionID: Int? = nil,
        scenarioSpec: [String: JSONValue]? = nil,
        stateRevision: Int? = nil,
        callID: String? = nil,
        retryCount: Int? = nil,
        terminalReasonCode: String? = nil,
        terminalReasonText: String? = nil,
        reasonCode: String? = nil,
        reasonText: String? = nil,
        action: String? = nil,
    ) {
        self.status = status
        self.phase = phase
        self.fromStatus = fromStatus
        self.toStatus = toStatus
        self.retryable = retryable
        self.terminalAt = terminalAt
        self.simulationID = simulationID
        self.sessionID = sessionID
        self.scenarioSpec = scenarioSpec
        self.stateRevision = stateRevision
        self.callID = callID
        self.retryCount = retryCount
        self.terminalReasonCode = terminalReasonCode
        self.terminalReasonText = terminalReasonText
        self.reasonCode = reasonCode
        self.reasonText = reasonText
        self.action = action
    }

    enum CodingKeys: String, CodingKey {
        case status
        case phase
        case fromStatus = "from"
        case toStatus = "to"
        case retryable
        case terminalAt = "terminal_at"
        case simulationID = "simulation_id"
        case sessionID = "session_id"
        case scenarioSpec = "scenario_spec"
        case stateRevision = "state_revision"
        case callID = "call_id"
        case retryCount = "retry_count"
        case terminalReasonCode = "terminal_reason_code"
        case terminalReasonText = "terminal_reason_text"
        case reasonCode = "reason_code"
        case reasonText = "reason_text"
        case action
    }

    public var normalizedStatus: String? {
        Self.normalizedStateToken(toStatus) ?? Self.normalizedStateToken(status) ?? Self.normalizedStateToken(phase)
    }

    public var normalizedFromStatus: String? {
        Self.normalizedStateToken(fromStatus)
    }

    public var effectiveReasonCode: String? {
        Self.normalizedOptionalString(terminalReasonCode) ?? Self.normalizedOptionalString(reasonCode)
    }

    public var effectiveReasonText: String? {
        Self.normalizedOptionalString(terminalReasonText) ?? Self.normalizedOptionalString(reasonText)
    }

    public func trainerSessionStatus(previousStatus: TrainerSessionStatus? = nil) -> TrainerSessionStatus? {
        if let mapped = Self.mapTrainerStatus(normalizedStatus) {
            return mapped
        }
        if let mapped = Self.mapTrainerStatus(normalizedFromStatus) {
            return mapped
        }
        return previousStatus
    }

    public func lifecycleSemantic(previousStatus: TrainerSessionStatus? = nil) -> SimulationLifecycleSemantic {
        let nextStatus = trainerSessionStatus(previousStatus: previousStatus)
        switch nextStatus {
        case .seeding:
            return .seeding
        case .seeded:
            return .seeded
        case .running:
            if normalizedFromStatus == TrainerSessionStatus.paused.rawValue || previousStatus == .paused {
                return .resumed
            }
            return .started
        case .paused:
            return .paused
        case .completed:
            return .completed
        case .failed:
            return .failed
        case nil:
            return .updated
        }
    }

    public static func decode(from payload: [String: JSONValue]) throws -> SimulationStatusUpdatedPayload {
        try payload.decodedPayload(as: SimulationStatusUpdatedPayload.self)
    }

    private static func normalizedStateToken(_ value: String?) -> String? {
        normalizedOptionalString(value)?.lowercased()
    }

    private static func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func mapTrainerStatus(_ value: String?) -> TrainerSessionStatus? {
        switch value {
        case "seeding":
            .seeding
        case "seeded", "ready":
            .seeded
        case "running", "started", "resumed":
            .running
        case "paused":
            .paused
        case "completed", "stopped", "ended":
            .completed
        case "failed":
            .failed
        default:
            nil
        }
    }
}

public enum SimulationEventRegistry {
    private typealias AuditDescriptor = (
        hydrationTargets: [String],
        refreshTargets: [String],
        presentationTargets: [SimulationEventPresentationTarget],
    )

    public static let aliasToCanonicalMap: [String: String] = [
        "chat.message_created": SimulationEventType.messageItemCreated,
        "message_status_update": SimulationEventType.messageDeliveryUpdated,
        "metadata.created": SimulationEventType.patientMetadataCreated,
        "simulation.metadata.results_created": SimulationEventType.patientResultsUpdated,
        "feedback.created": SimulationEventType.feedbackItemCreated,
        "simulation.feedback_created": SimulationEventType.feedbackItemCreated,
        "simulation.hotwash.created": SimulationEventType.feedbackItemCreated,
        "feedback.failed": SimulationEventType.feedbackGenerationFailed,
        "feedback.retrying": SimulationEventType.feedbackGenerationUpdated,
        "simulation.state_changed": SimulationEventType.simulationStatusUpdated,
        "simulation.ended": SimulationEventType.simulationStatusUpdated,
        "run.started": SimulationEventType.simulationStatusUpdated,
        "run.paused": SimulationEventType.simulationStatusUpdated,
        "run.resumed": SimulationEventType.simulationStatusUpdated,
        "run.stopped": SimulationEventType.simulationStatusUpdated,
        "session.seeded": SimulationEventType.simulationStatusUpdated,
        "session.failed": SimulationEventType.simulationStatusUpdated,
        "session.seeding": SimulationEventType.simulationStatusUpdated,
        "trainerlab.scenario_brief.created": SimulationEventType.simulationBriefCreated,
        "trainerlab.scenario_brief.updated": SimulationEventType.simulationBriefUpdated,
        "state.updated": SimulationEventType.simulationSnapshotUpdated,
        "ai.intent.updated": SimulationEventType.simulationPlanUpdated,
        "trainerlab.control_plane.patch_evaluated": SimulationEventType.simulationPatchCompleted,
        "simulation.patch_evaluation.completed": SimulationEventType.simulationPatchCompleted,
        "trainerlab.tick.triggered": SimulationEventType.simulationTickTriggered,
        "summary.ready": SimulationEventType.simulationSummaryUpdated,
        "summary.updated": SimulationEventType.simulationSummaryUpdated,
        "simulation.summary.ready": SimulationEventType.simulationSummaryUpdated,
        "runtime.failed": SimulationEventType.simulationRuntimeFailed,
        "preset.applied": SimulationEventType.simulationPresetUpdated,
        "command.accepted": SimulationEventType.simulationCommandUpdated,
        "adjustment.accepted": SimulationEventType.simulationAdjustmentUpdated,
        "adjustment.applied": SimulationEventType.simulationAdjustmentUpdated,
        "trainerlab.adjustment.accepted": SimulationEventType.simulationAdjustmentUpdated,
        "trainerlab.adjustment.applied": SimulationEventType.simulationAdjustmentUpdated,
        "note.created": SimulationEventType.simulationNoteCreated,
        "trainerlab.annotation.created": SimulationEventType.simulationAnnotationCreated,
        "injury.created": SimulationEventType.patientInjuryCreated,
        "injury.updated": SimulationEventType.patientInjuryUpdated,
        "illness.created": SimulationEventType.patientIllnessCreated,
        "illness.updated": SimulationEventType.patientIllnessUpdated,
        "problem.created": SimulationEventType.patientProblemCreated,
        "problem.updated": SimulationEventType.patientProblemUpdated,
        "problem.resolved": SimulationEventType.patientProblemUpdated,
        "recommended_intervention.created": SimulationEventType.patientRecommendedInterventionCreated,
        "patient.recommended_intervention.created": SimulationEventType.patientRecommendedInterventionCreated,
        "recommended_intervention.updated": SimulationEventType.patientRecommendedInterventionUpdated,
        "patient.recommended_intervention.updated": SimulationEventType.patientRecommendedInterventionUpdated,
        "recommended_intervention.removed": SimulationEventType.patientRecommendedInterventionRemoved,
        "patient.recommended_intervention.removed": SimulationEventType.patientRecommendedInterventionRemoved,
        "intervention.created": SimulationEventType.patientInterventionCreated,
        "intervention.updated": SimulationEventType.patientInterventionUpdated,
        "trainerlab.intervention.assessed": SimulationEventType.patientInterventionUpdated,
        "trainerlab.assessment_finding.created": SimulationEventType.patientAssessmentFindingCreated,
        "patient.assessment_finding.created": SimulationEventType.patientAssessmentFindingCreated,
        "trainerlab.assessment_finding.updated": SimulationEventType.patientAssessmentFindingUpdated,
        "patient.assessment_finding.updated": SimulationEventType.patientAssessmentFindingUpdated,
        "trainerlab.assessment_finding.removed": SimulationEventType.patientAssessmentFindingRemoved,
        "patient.assessment_finding.removed": SimulationEventType.patientAssessmentFindingRemoved,
        "trainerlab.diagnostic_result.created": SimulationEventType.patientDiagnosticResultCreated,
        "patient.diagnostic_result.created": SimulationEventType.patientDiagnosticResultCreated,
        "trainerlab.diagnostic_result.updated": SimulationEventType.patientDiagnosticResultUpdated,
        "patient.diagnostic_result.updated": SimulationEventType.patientDiagnosticResultUpdated,
        "trainerlab.resource.updated": SimulationEventType.patientResourceUpdated,
        "trainerlab.disposition.updated": SimulationEventType.patientDispositionUpdated,
        "trainerlab.recommendation_evaluation.created": SimulationEventType.patientRecommendationEvaluationCreated,
        "patient.recommendation_evaluation.created": SimulationEventType.patientRecommendationEvaluationCreated,
        "trainerlab.vital.created": SimulationEventType.patientVitalCreated,
        "trainerlab.vital.updated": SimulationEventType.patientVitalUpdated,
        "trainerlab.pulse.created": SimulationEventType.patientPulseCreated,
        "trainerlab.pulse.updated": SimulationEventType.patientPulseUpdated,
    ]

    public static let knownCanonicalDurableEventTypes = Set(SimulationEventType.allCanonicalDurable)
    public static let knownTransientEventTypes = Set(SimulationEventType.transientSocketOnly)
    public static let knownCanonicalEventTypes = knownCanonicalDurableEventTypes.union(knownTransientEventTypes)

    private static let auditDescriptorMap: [String: AuditDescriptor] = [
        SimulationEventType.messageItemCreated: (
            ["chat.messages"],
            ["chat.tools.refresh"],
            [.chatMessageTimeline],
        ),
        SimulationEventType.messageDeliveryUpdated: (
            ["chat.message_delivery"],
            [],
            [.chatMessageTimeline],
        ),
        SimulationEventType.patientMetadataCreated: (
            ["trainer.runtime.state", "chat.tools"],
            ["trainer.runtime.refresh", "chat.tools.refresh"],
            [.trainerOperationalLog, .trainerRunSummary, .chatToolsPane, .chatActivity],
        ),
        SimulationEventType.patientResultsUpdated: (
            ["trainer.runtime.state", "chat.tools"],
            ["trainer.runtime.refresh", "chat.tools.refresh"],
            [.trainerOperationalLog, .trainerRunSummary, .chatToolsPane, .chatActivity],
        ),
        SimulationEventType.feedbackItemCreated: (
            ["chat.feedback.state"],
            ["chat.tools.refresh"],
            [.chatToolsPane, .chatActivity],
        ),
        SimulationEventType.feedbackGenerationFailed: (
            ["chat.feedback.state"],
            [],
            [.chatStatusBanner, .chatActivity],
        ),
        SimulationEventType.feedbackGenerationUpdated: (
            ["chat.feedback.state"],
            ["chat.tools.refresh"],
            [.chatToolsPane, .chatActivity],
        ),
        SimulationEventType.simulationStatusUpdated: (
            ["trainer.session.lifecycle", "chat.simulation.status"],
            ["trainer.seeded.rehydrate", "trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerOperationalLog, .trainerRunSummary, .chatStatusBanner, .chatActivity],
        ),
        SimulationEventType.simulationBriefCreated: (
            ["trainer.scenario_brief"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationBriefUpdated: (
            ["trainer.scenario_brief"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationSnapshotUpdated: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationPlanUpdated: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationPatchCompleted: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationTickTriggered: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationSummaryUpdated: (
            ["trainer.runtime.state"],
            [],
            [.trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationRuntimeFailed: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationPresetUpdated: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationCommandUpdated: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationAdjustmentUpdated: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationNoteCreated: (
            ["trainer.runtime.state"],
            [],
            [.trainerClinicalTimeline, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.simulationAnnotationCreated: (
            ["trainer.annotations"],
            [],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientInjuryCreated: (
            ["trainer.cause_annotations"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientInjuryUpdated: (
            ["trainer.cause_annotations"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientIllnessCreated: (
            ["trainer.cause_annotations"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientIllnessUpdated: (
            ["trainer.cause_annotations"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientProblemCreated: (
            ["trainer.problem_annotations"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientProblemUpdated: (
            ["trainer.problem_annotations"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientRecommendedInterventionCreated: (
            ["trainer.recommended_interventions"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientRecommendedInterventionUpdated: (
            ["trainer.recommended_interventions"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientRecommendedInterventionRemoved: (
            ["trainer.recommended_interventions"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientInterventionCreated: (
            ["trainer.intervention_annotations"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientInterventionUpdated: (
            ["trainer.intervention_annotations"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientAssessmentFindingCreated: (
            ["trainer.assessment_findings"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientAssessmentFindingUpdated: (
            ["trainer.assessment_findings"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientAssessmentFindingRemoved: (
            ["trainer.assessment_findings"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientDiagnosticResultCreated: (
            ["trainer.diagnostic_results"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientDiagnosticResultUpdated: (
            ["trainer.diagnostic_results"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientResourceUpdated: (
            ["trainer.resources"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientDispositionUpdated: (
            ["trainer.disposition"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientRecommendationEvaluationCreated: (
            ["trainer.runtime.state"],
            ["trainer.runtime.refresh"],
            [.trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientVitalCreated: (
            ["trainer.vitals"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientVitalUpdated: (
            ["trainer.vitals"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientPulseCreated: (
            ["trainer.pulses"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.patientPulseUpdated: (
            ["trainer.pulses"],
            ["trainer.runtime.refresh"],
            [.trainerClinicalTimeline, .trainerInfoPanel, .trainerOperationalLog, .trainerRunSummary],
        ),
        SimulationEventType.connected: (
            ["none"],
            [],
            [.explicitNoOp],
        ),
        SimulationEventType.disconnected: (
            ["none"],
            [],
            [.explicitNoOp],
        ),
        SimulationEventType.initMessage: (
            ["none"],
            [],
            [.explicitNoOp],
        ),
        SimulationEventType.error: (
            ["none"],
            [],
            [.explicitNoOp],
        ),
        SimulationEventType.typing: (
            ["chat.typing"],
            [],
            [.chatTypingIndicator],
        ),
        SimulationEventType.stoppedTyping: (
            ["chat.typing"],
            [],
            [.chatTypingIndicator],
        ),
        SimulationEventType.simulationFeedbackContinueConversation: (
            ["none"],
            [],
            [.explicitNoOp],
        ),
        SimulationEventType.simulationHotwashContinueConversation: (
            ["none"],
            [],
            [.explicitNoOp],
        ),
        SimulationEventType.guardStateUpdated: (
            ["none"],
            [],
            [.explicitNoOp],
        ),
        SimulationEventType.guardWarningUpdated: (
            ["none"],
            [],
            [.explicitNoOp],
        ),
    ]

    public static let runtimeRefreshTriggerEventTypes: Set<String> = [
        SimulationEventType.simulationStatusUpdated,
        SimulationEventType.simulationBriefCreated,
        SimulationEventType.simulationBriefUpdated,
        SimulationEventType.simulationSnapshotUpdated,
        SimulationEventType.simulationPlanUpdated,
        SimulationEventType.simulationPatchCompleted,
        SimulationEventType.simulationTickTriggered,
        SimulationEventType.simulationRuntimeFailed,
        SimulationEventType.simulationPresetUpdated,
        SimulationEventType.simulationCommandUpdated,
        SimulationEventType.simulationAdjustmentUpdated,
        SimulationEventType.patientMetadataCreated,
        SimulationEventType.patientResultsUpdated,
        SimulationEventType.patientInjuryCreated,
        SimulationEventType.patientInjuryUpdated,
        SimulationEventType.patientIllnessCreated,
        SimulationEventType.patientIllnessUpdated,
        SimulationEventType.patientProblemCreated,
        SimulationEventType.patientProblemUpdated,
        SimulationEventType.patientRecommendedInterventionCreated,
        SimulationEventType.patientRecommendedInterventionUpdated,
        SimulationEventType.patientRecommendedInterventionRemoved,
        SimulationEventType.patientInterventionCreated,
        SimulationEventType.patientInterventionUpdated,
        SimulationEventType.patientAssessmentFindingCreated,
        SimulationEventType.patientAssessmentFindingUpdated,
        SimulationEventType.patientAssessmentFindingRemoved,
        SimulationEventType.patientDiagnosticResultCreated,
        SimulationEventType.patientDiagnosticResultUpdated,
        SimulationEventType.patientResourceUpdated,
        SimulationEventType.patientDispositionUpdated,
        SimulationEventType.patientRecommendationEvaluationCreated,
        SimulationEventType.patientVitalCreated,
        SimulationEventType.patientVitalUpdated,
        SimulationEventType.patientPulseCreated,
        SimulationEventType.patientPulseUpdated,
    ]

    public static let toolRefreshTriggerEventTypes: Set<String> = [
        SimulationEventType.feedbackItemCreated,
        SimulationEventType.feedbackGenerationUpdated,
        SimulationEventType.feedbackGenerationFailed,
        SimulationEventType.patientMetadataCreated,
        SimulationEventType.patientResultsUpdated,
    ]

    public static func normalize(_ rawEventType: String) -> String {
        rawEventType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    public static func canonicalize(_ rawEventType: String) -> String {
        let normalized = normalize(rawEventType)
        if let canonical = aliasToCanonicalMap[normalized] {
            return canonical
        }
        return normalized
    }

    public static func normalizedPayload(
        for rawEventType: String,
        payload: [String: JSONValue],
    ) -> [String: JSONValue] {
        let normalized = normalize(rawEventType)
        var normalizedPayload = payload

        func ensureString(_ key: String, value: String) {
            if normalizedPayload[key] == nil {
                normalizedPayload[key] = .string(value)
            }
        }

        switch normalized {
        case "session.seeding":
            ensureString("status", value: "seeding")
            ensureString("phase", value: "seeding")
        case "session.seeded":
            ensureString("status", value: "seeded")
            ensureString("phase", value: "seeded")
        case "session.failed":
            ensureString("status", value: "failed")
        case "run.started":
            ensureString("status", value: "running")
            ensureString("to", value: "running")
        case "run.paused":
            ensureString("status", value: "paused")
            ensureString("from", value: "running")
            ensureString("to", value: "paused")
        case "run.resumed":
            ensureString("status", value: "running")
            ensureString("from", value: "paused")
            ensureString("to", value: "running")
        case "run.stopped", "simulation.ended":
            ensureString("status", value: "completed")
            ensureString("to", value: "completed")
        default:
            break
        }

        return normalizedPayload
    }

    public static func canonicalEventType(for rawEventType: String) -> String? {
        let canonical = canonicalize(rawEventType)
        return knownCanonicalEventTypes.contains(canonical) ? canonical : nil
    }

    public static func isKnown(_ rawEventType: String) -> Bool {
        canonicalEventType(for: rawEventType) != nil
    }

    public static func isLifecycleEvent(_ rawEventType: String) -> Bool {
        canonicalize(rawEventType) == SimulationEventType.simulationStatusUpdated
    }

    public static func isRuntimeRefreshTrigger(_ rawEventType: String) -> Bool {
        runtimeRefreshTriggerEventTypes.contains(canonicalize(rawEventType))
    }

    public static func isToolRefreshTrigger(_ rawEventType: String) -> Bool {
        toolRefreshTriggerEventTypes.contains(canonicalize(rawEventType))
    }

    public static func isTransientSocketEvent(_ rawEventType: String) -> Bool {
        knownTransientEventTypes.contains(canonicalize(rawEventType))
    }

    public static func domain(for rawEventType: String) -> SimulationEventDomain {
        let canonical = canonicalize(rawEventType)
        if knownTransientEventTypes.contains(canonical) {
            return .transient
        }
        if canonical.hasPrefix("message.") {
            return .message
        }
        if canonical.hasPrefix("feedback.") {
            return .feedback
        }
        if canonical.hasPrefix("simulation.") {
            return .simulation
        }
        if canonical.hasPrefix("patient.") {
            return .patient
        }
        return .unknown
    }

    public static func isPatientDomainEvent(_ rawEventType: String) -> Bool {
        domain(for: rawEventType) == .patient
    }

    public static func isSimulationDomainEvent(_ rawEventType: String) -> Bool {
        domain(for: rawEventType) == .simulation
    }

    public static func isMessageDomainEvent(_ rawEventType: String) -> Bool {
        domain(for: rawEventType) == .message
    }

    public static func isFeedbackDomainEvent(_ rawEventType: String) -> Bool {
        domain(for: rawEventType) == .feedback
    }

    public static var auditEntries: [SimulationEventAuditEntry] {
        (SimulationEventType.allCanonicalDurable + SimulationEventType.transientSocketOnly)
            .compactMap { auditEntry(for: $0) }
    }

    public static func auditEntry(for rawEventType: String) -> SimulationEventAuditEntry? {
        let canonical = canonicalize(rawEventType)
        guard let descriptor = auditDescriptorMap[canonical] else { return nil }
        let legacyAliases = aliasToCanonicalMap
            .compactMap { alias, mappedCanonical in
                mappedCanonical == canonical ? alias : nil
            }
            .sorted()
        return SimulationEventAuditEntry(
            canonicalEventType: canonical,
            legacyAliases: legacyAliases,
            hydrationTargets: descriptor.hydrationTargets,
            refreshTargets: descriptor.refreshTargets,
            presentationTargets: descriptor.presentationTargets,
        )
    }

    public static func presentationTargets(for rawEventType: String) -> [SimulationEventPresentationTarget] {
        auditEntry(for: rawEventType)?.presentationTargets ?? []
    }

    public static func shouldPresentInTrainerOperationalLog(_ rawEventType: String) -> Bool {
        presentationTargets(for: rawEventType).contains(.trainerOperationalLog)
    }

    public static func shouldPresentInChatActivity(_ rawEventType: String) -> Bool {
        presentationTargets(for: rawEventType).contains(.chatActivity)
    }

    public static func shouldPresentInChatStatusBanner(_ rawEventType: String) -> Bool {
        presentationTargets(for: rawEventType).contains(.chatStatusBanner)
    }

    public static func lifecycleDisplay(
        for payload: SimulationStatusUpdatedPayload,
        previousStatus: TrainerSessionStatus? = nil,
    ) -> (title: String, message: String) {
        switch payload.lifecycleSemantic(previousStatus: previousStatus) {
        case .seeding:
            return ("Scenario Seeding", "Initial scenario generation is in progress.")
        case .seeded:
            return ("Scenario Ready", "Scenario is ready to run.")
        case .started:
            return ("Run Started", "Simulation active.")
        case .paused:
            return ("Run Paused", "Simulation paused.")
        case .resumed:
            return ("Run Resumed", "Simulation resumed.")
        case .completed:
            return ("Run Stopped", "Simulation completed.")
        case .failed:
            let message = payload.effectiveReasonText ?? "Simulation failed."
            return ("Scenario Failed", message)
        case .updated:
            return ("Lifecycle Update", "Simulation lifecycle updated.")
        }
    }

    public static func displayTitle(
        for rawEventType: String,
        payload: [String: JSONValue] = [:],
        previousStatus: TrainerSessionStatus? = nil,
    ) -> String {
        let canonical = canonicalize(rawEventType)
        switch canonical {
        case SimulationEventType.simulationStatusUpdated:
            if let decoded = try? SimulationStatusUpdatedPayload.decode(from: payload) {
                return lifecycleDisplay(for: decoded, previousStatus: previousStatus).title
            }
            return "Lifecycle Update"
        case SimulationEventType.simulationBriefCreated, SimulationEventType.simulationBriefUpdated:
            return "Scenario Brief"
        case SimulationEventType.simulationSnapshotUpdated:
            return "Runtime State Updated"
        case SimulationEventType.simulationPlanUpdated:
            return "AI Instructor"
        case SimulationEventType.simulationPatchCompleted:
            return "Patch Completed"
        case SimulationEventType.simulationTickTriggered:
            return "Simulation Tick"
        case SimulationEventType.simulationSummaryUpdated:
            return "Summary Updated"
        case SimulationEventType.simulationRuntimeFailed:
            return "Runtime Failed"
        case SimulationEventType.simulationPresetUpdated:
            return "Preset Updated"
        case SimulationEventType.simulationCommandUpdated:
            return "Command Updated"
        case SimulationEventType.simulationAdjustmentUpdated:
            if payload["target"] == .string("avpu") {
                return "LOC Change"
            }
            return "Adjustment"
        case SimulationEventType.simulationNoteCreated:
            return "Trainer Note"
        case SimulationEventType.simulationAnnotationCreated:
            return "Debrief Annotation"
        case SimulationEventType.patientInjuryCreated, SimulationEventType.patientInjuryUpdated:
            return "Injury"
        case SimulationEventType.patientIllnessCreated, SimulationEventType.patientIllnessUpdated:
            return "Illness"
        case SimulationEventType.patientProblemCreated, SimulationEventType.patientProblemUpdated:
            return "Problem"
        case SimulationEventType.patientRecommendedInterventionCreated,
             SimulationEventType.patientRecommendedInterventionUpdated,
             SimulationEventType.patientRecommendedInterventionRemoved:
            return "Recommendation"
        case SimulationEventType.patientInterventionCreated, SimulationEventType.patientInterventionUpdated:
            return "Intervention"
        case SimulationEventType.patientAssessmentFindingCreated,
             SimulationEventType.patientAssessmentFindingUpdated,
             SimulationEventType.patientAssessmentFindingRemoved:
            return "Assessment Finding"
        case SimulationEventType.patientDiagnosticResultCreated, SimulationEventType.patientDiagnosticResultUpdated:
            return "Diagnostic Result"
        case SimulationEventType.patientResourceUpdated:
            return "Resource Update"
        case SimulationEventType.patientDispositionUpdated:
            return "Disposition"
        case SimulationEventType.patientRecommendationEvaluationCreated:
            return "Recommendation Evaluation"
        case SimulationEventType.patientVitalCreated, SimulationEventType.patientVitalUpdated:
            return "Vital Update"
        case SimulationEventType.patientPulseCreated, SimulationEventType.patientPulseUpdated:
            return "Pulse Update"
        default:
            return humanizedLabel(canonical)
        }
    }

    public static func displayMessage(
        for rawEventType: String,
        payload: [String: JSONValue] = [:],
        previousStatus: TrainerSessionStatus? = nil,
    ) -> String {
        let canonical = canonicalize(rawEventType)
        switch canonical {
        case SimulationEventType.simulationStatusUpdated:
            if let decoded = try? SimulationStatusUpdatedPayload.decode(from: payload) {
                return lifecycleDisplay(for: decoded, previousStatus: previousStatus).message
            }
            return "Simulation lifecycle updated."
        case SimulationEventType.feedbackGenerationFailed:
            return payloadString(payload, keys: ["error_text", "reason_text", "terminal_reason_text"])
                ?? "Feedback generation failed."
        case SimulationEventType.feedbackGenerationUpdated:
            return "Feedback generation updated."
        case SimulationEventType.feedbackItemCreated:
            return payloadPrimaryText(payload) ?? "Simulation feedback available."
        case SimulationEventType.patientMetadataCreated:
            return "Patient metadata refreshed."
        case SimulationEventType.patientResultsUpdated:
            return "Patient results refreshed."
        case SimulationEventType.messageItemCreated:
            return payloadString(payload, keys: ["content"]) ?? "New message received."
        case SimulationEventType.messageDeliveryUpdated:
            if let status = payloadString(payload, keys: ["status"]) {
                return "Message marked \(humanizedLabel(status).lowercased())."
            }
            return "Message delivery updated."
        default:
            return payloadPrimaryText(payload) ?? "\(displayTitle(for: canonical, payload: payload, previousStatus: previousStatus)) received."
        }
    }

    public static func humanizedLabel(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }

    private static func payloadPrimaryText(_ payload: [String: JSONValue]) -> String? {
        payloadString(payload, keys: [
            "summary",
            "title",
            "content",
            "description",
            "error_text",
            "reason_text",
            "terminal_reason_text",
            "trigger",
            "status",
        ])
    }

    private static func payloadString(_ payload: [String: JSONValue], keys: [String]) -> String? {
        for key in keys {
            guard case let .string(value)? = payload[key] else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}

public extension [String: JSONValue] {
    func decodedPayload<T: Decodable>(as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: mapValues(\.rawValue))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = PayloadDateDecoding.parseISO8601(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return try decoder.decode(type, from: data)
    }
}

public extension EventEnvelope {
    func canonicalized() -> EventEnvelope {
        let canonicalEventType = SimulationEventRegistry.canonicalize(eventType)
        let normalizedPayload = SimulationEventRegistry.normalizedPayload(for: eventType, payload: payload)
        guard canonicalEventType != eventType || normalizedPayload != payload else { return self }
        return EventEnvelope(
            eventID: eventID,
            eventType: canonicalEventType,
            createdAt: createdAt,
            correlationID: correlationID,
            payload: normalizedPayload,
        )
    }
}

public extension SummaryTimelineEntry {
    var canonicalEventType: String {
        SimulationEventRegistry.canonicalize(eventType)
    }
}

private enum PayloadDateDecoding {
    static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: value)
    }
}
