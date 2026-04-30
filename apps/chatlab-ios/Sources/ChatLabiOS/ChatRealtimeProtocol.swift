import Foundation
import SharedModels

public enum ChatRealtimeEventType {
    public static let sessionHello = "session.hello"
    public static let sessionResume = "session.resume"
    public static let typingStarted = "typing.started"
    public static let typingStopped = "typing.stopped"
    public static let ping = "ping"

    public static let sessionReady = "session.ready"
    public static let sessionResumed = "session.resumed"
    public static let sessionResyncRequired = "session.resync_required"
    public static let error = "error"
    public static let pong = "pong"

    public static let durableEventTypes: Set<String> = [
        SimulationEventType.messageItemCreated,
        SimulationEventType.messageDeliveryUpdated,
        SimulationEventType.patientMetadataCreated,
        SimulationEventType.patientResultsUpdated,
        SimulationEventType.feedbackItemCreated,
        SimulationEventType.feedbackGenerationFailed,
        SimulationEventType.feedbackGenerationUpdated,
        SimulationEventType.simulationStatusUpdated,
        SimulationEventType.simulationBriefCreated,
        SimulationEventType.simulationBriefUpdated,
        SimulationEventType.simulationSnapshotUpdated,
        SimulationEventType.simulationPlanUpdated,
        SimulationEventType.simulationPatchCompleted,
        SimulationEventType.simulationTickTriggered,
        SimulationEventType.simulationSummaryUpdated,
        SimulationEventType.simulationRuntimeFailed,
        SimulationEventType.simulationPresetUpdated,
        SimulationEventType.simulationCommandUpdated,
        SimulationEventType.simulationAdjustmentUpdated,
        SimulationEventType.simulationNoteCreated,
        SimulationEventType.simulationAnnotationCreated,
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
        SimulationEventType.guardStateUpdated,
        SimulationEventType.guardWarningUpdated,
    ]

    public static let transientEventTypes: Set<String> = [
        sessionReady,
        sessionResumed,
        sessionResyncRequired,
        error,
        pong,
        typingStarted,
        typingStopped,
    ]

    public static let lifecycleEventTypes: Set<String> = [
        sessionReady,
        sessionResumed,
        sessionResyncRequired,
        error,
        pong,
    ]
}

public func isDurableEventType(_ eventType: String) -> Bool {
    ChatRealtimeEventType.durableEventTypes.contains(eventType)
}

public func isTransientEventType(_ eventType: String) -> Bool {
    ChatRealtimeEventType.transientEventTypes.contains(eventType)
}

public func isLifecycleEventType(_ eventType: String) -> Bool {
    ChatRealtimeEventType.lifecycleEventTypes.contains(eventType)
}

public struct ChatRealtimeOutboundMessage: Encodable, Sendable, Equatable {
    public let eventType: String
    public let correlationID: String?
    public let payload: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case correlationID = "correlation_id"
        case payload
    }
}

public struct ChatRealtimeSessionPayload: Codable, Sendable, Equatable {
    public let simulationID: Int
    public let lastEventID: String?
    public let replayCount: Int?
    public let patientDisplayName: String?
    public let patientInitials: String?
    public let status: String?

    enum CodingKeys: String, CodingKey {
        case simulationID = "simulation_id"
        case lastEventID = "last_event_id"
        case replayCount = "replay_count"
        case patientDisplayName = "patient_display_name"
        case patientInitials = "patient_initials"
        case status
    }
}

public struct ChatRealtimeResyncPayload: Codable, Sendable, Equatable {
    public let simulationID: Int?
    public let lastEventID: String?
    public let reason: String

    enum CodingKeys: String, CodingKey {
        case simulationID = "simulation_id"
        case lastEventID = "last_event_id"
        case reason
    }
}

public struct ChatRealtimeErrorPayload: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public let details: [String: JSONValue]?
}

public struct ChatRealtimeTypingPayload: Codable, Sendable, Equatable {
    public let conversationID: Int?
    public let user: String?
    public let displayInitials: String?

    // Enriched identity fields from backend (optional; absent on older payloads)
    public let actorType: String?
    public let senderId: Int?
    public let actorUserId: Int?
    public let actorUserUuid: String?

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case user
        case displayInitials = "display_initials"
        case actorType = "actor_type"
        case senderId = "sender_id"
        case actorUserId = "actor_user_id"
        case actorUserUuid = "actor_user_uuid"
    }

    /// Stable key for store identity: prefers UUID > actorUserId > senderId > user email.
    public var identityKey: String {
        actorUserUuid
            ?? actorUserId.map(String.init)
            ?? senderId.map(String.init)
            ?? user
            ?? "unknown"
    }

    /// Treats a missing actor_type as "user" for backward compatibility.
    public var normalizedActorType: String {
        actorType ?? "user"
    }

    /// Returns true when the payload belongs to the currently authenticated user.
    /// System/simulated-patient payloads (actor_type == "system") always return false.
    public func isFromCurrentUser(
        currentUserId: Int?,
        currentUserUuid: String?,
        currentUserEmail: String?
    ) -> Bool {
        guard normalizedActorType == "user" else {
            return false
        }

        if let actorUserId, let currentUserId, actorUserId == currentUserId {
            return true
        }

        if let senderId, let currentUserId, senderId == currentUserId {
            return true
        }

        if let actorUserUuid, let currentUserUuid,
           actorUserUuid.lowercased() == currentUserUuid.lowercased()
        {
            return true
        }

        if let user, let currentUserEmail,
           user.lowercased() == currentUserEmail.lowercased()
        {
            return true
        }

        return false
    }
}

public struct ChatRealtimePingPayload: Codable, Sendable, Equatable {
    public let clientTimestamp: String?
    public let clientNonce: String?

    enum CodingKeys: String, CodingKey {
        case clientTimestamp = "client_timestamp"
        case clientNonce = "client_nonce"
    }
}

public extension ChatEventEnvelope {
    func sessionPayload() throws -> ChatRealtimeSessionPayload {
        try decodePayload(ChatRealtimeSessionPayload.self)
    }

    func resyncPayload() throws -> ChatRealtimeResyncPayload {
        try decodePayload(ChatRealtimeResyncPayload.self)
    }

    func errorPayload() throws -> ChatRealtimeErrorPayload {
        try decodePayload(ChatRealtimeErrorPayload.self)
    }

    func typingPayload() throws -> ChatRealtimeTypingPayload {
        try decodePayload(ChatRealtimeTypingPayload.self)
    }

    func pingPayload() throws -> ChatRealtimePingPayload {
        try decodePayload(ChatRealtimePingPayload.self)
    }
}
