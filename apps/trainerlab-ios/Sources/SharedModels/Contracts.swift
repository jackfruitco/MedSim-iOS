import Foundation

public struct PaginatedResponse<Item: Codable & Sendable>: Codable, Sendable {
    public let items: [Item]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(items: [Item], nextCursor: String?, hasMore: Bool) {
        self.items = items
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

public struct APIErrorPayload: Codable, Sendable {
    public let type: String
    public let title: String
    public let status: Int
    public let detail: String
    public let instance: String?
    public let correlationID: String?

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case status
        case detail
        case instance
        case correlationID = "correlation_id"
    }
}

public struct AuthTokens: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let tokenType: String

    public init(accessToken: String, refreshToken: String, expiresIn: Int, tokenType: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

public struct RefreshTokenResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int
    public let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

public struct LabAccess: Codable, Sendable {
    public let labSlug: String
    public let accessLevel: String

    enum CodingKeys: String, CodingKey {
        case labSlug = "lab_slug"
        case accessLevel = "access_level"
    }
}

public enum TrainerSessionStatus: String, Codable, Sendable, CaseIterable {
    case seeded
    case running
    case paused
    case completed
    case failed
}

public struct TrainerSessionDTO: Codable, Equatable, Identifiable, Sendable {
    public let simulationID: Int
    public let status: TrainerSessionStatus
    public let scenarioSpec: [String: JSONValue]
    public let runtimeState: [String: JSONValue]
    public let initialDirectives: String?
    public let tickIntervalSeconds: Int
    public let runStartedAt: Date?
    public let runPausedAt: Date?
    public let runCompletedAt: Date?
    public let lastAITickAt: Date?
    public let createdAt: Date
    public let modifiedAt: Date
    /// Populated when the simulation reaches a terminal state.
    public let terminalReasonCode: String?
    public let terminalReasonText: String?
    /// Non-nil when the terminal state can be retried.
    public let retryable: Bool?

    public var id: Int { simulationID }

    public init(
        simulationID: Int,
        status: TrainerSessionStatus,
        scenarioSpec: [String: JSONValue],
        runtimeState: [String: JSONValue],
        initialDirectives: String?,
        tickIntervalSeconds: Int,
        runStartedAt: Date?,
        runPausedAt: Date?,
        runCompletedAt: Date?,
        lastAITickAt: Date?,
        createdAt: Date,
        modifiedAt: Date,
        terminalReasonCode: String? = nil,
        terminalReasonText: String? = nil,
        retryable: Bool? = nil
    ) {
        self.simulationID = simulationID
        self.status = status
        self.scenarioSpec = scenarioSpec
        self.runtimeState = runtimeState
        self.initialDirectives = initialDirectives
        self.tickIntervalSeconds = tickIntervalSeconds
        self.runStartedAt = runStartedAt
        self.runPausedAt = runPausedAt
        self.runCompletedAt = runCompletedAt
        self.lastAITickAt = lastAITickAt
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.terminalReasonCode = terminalReasonCode
        self.terminalReasonText = terminalReasonText
        self.retryable = retryable
    }

    enum CodingKeys: String, CodingKey {
        case simulationID = "simulation_id"
        case status
        case scenarioSpec = "scenario_spec"
        case runtimeState = "runtime_state"
        case initialDirectives = "initial_directives"
        case tickIntervalSeconds = "tick_interval_seconds"
        case runStartedAt = "run_started_at"
        case runPausedAt = "run_paused_at"
        case runCompletedAt = "run_completed_at"
        case lastAITickAt = "last_ai_tick_at"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case terminalReasonCode = "terminal_reason_code"
        case terminalReasonText = "terminal_reason_text"
        case retryable
    }
}

public struct EventEnvelope: Codable, Equatable, Identifiable, Sendable {
    public let eventID: String
    public let eventType: String
    public let createdAt: Date
    public let correlationID: String?
    public let payload: [String: JSONValue]

    public var id: String { eventID }

    public init(
        eventID: String,
        eventType: String,
        createdAt: Date,
        correlationID: String?,
        payload: [String: JSONValue]
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.createdAt = createdAt
        self.correlationID = correlationID
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case eventType = "event_type"
        case createdAt = "created_at"
        case correlationID = "correlation_id"
        case payload
    }
}

public struct RunDebriefOutput: Codable, Sendable {
    public let narrativeSummary: String
    public let strengths: [String]
    public let misses: [String]
    public let deteriorationTimeline: [JSONValue]
    public let teachingPoints: [String]
    public let overallAssessment: String

    enum CodingKeys: String, CodingKey {
        case narrativeSummary = "narrative_summary"
        case strengths
        case misses
        case deteriorationTimeline = "deterioration_timeline"
        case teachingPoints = "teaching_points"
        case overallAssessment = "overall_assessment"
    }
}

public struct RunSummary: Codable, Sendable {
    public let simulationID: Int
    public let status: String
    public let runStartedAt: String?
    public let runCompletedAt: String?
    public let finalState: [String: JSONValue]
    public let eventTypeCounts: [String: Int]
    public let timelineHighlights: [SummaryTimelineEntry]
    public let commandLog: [SummaryCommandLog]
    public let aiRationaleNotes: [JSONValue]
    public let aiDebrief: RunDebriefOutput?

    public init(
        simulationID: Int,
        status: String,
        runStartedAt: String?,
        runCompletedAt: String?,
        finalState: [String: JSONValue],
        eventTypeCounts: [String: Int],
        timelineHighlights: [SummaryTimelineEntry],
        commandLog: [SummaryCommandLog],
        aiRationaleNotes: [JSONValue],
        aiDebrief: RunDebriefOutput? = nil
    ) {
        self.simulationID = simulationID
        self.status = status
        self.runStartedAt = runStartedAt
        self.runCompletedAt = runCompletedAt
        self.finalState = finalState
        self.eventTypeCounts = eventTypeCounts
        self.timelineHighlights = timelineHighlights
        self.commandLog = commandLog
        self.aiRationaleNotes = aiRationaleNotes
        self.aiDebrief = aiDebrief
    }

    enum CodingKeys: String, CodingKey {
        case simulationID = "simulation_id"
        case status
        case runStartedAt = "run_started_at"
        case runCompletedAt = "run_completed_at"
        case finalState = "final_state"
        case eventTypeCounts = "event_type_counts"
        case timelineHighlights = "timeline_highlights"
        case commandLog = "command_log"
        case aiRationaleNotes = "ai_rationale_notes"
        case aiDebrief = "ai_debrief"
    }
}

public struct SummaryTimelineEntry: Codable, Sendable {
    public let eventType: String
    public let createdAt: String
    public let payload: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case createdAt = "created_at"
        case payload
    }
}

public struct SummaryCommandLog: Codable, Sendable {
    public let id: String
    public let commandType: String
    public let status: String
    public let issuedAt: String
    public let payload: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case id
        case commandType = "command_type"
        case status
        case issuedAt = "issued_at"
        case payload
    }
}

public struct TrainerCommandAck: Codable, Sendable {
    public let commandID: String
    public let status: String

    public init(commandID: String, status: String) {
        self.commandID = commandID
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case commandID = "command_id"
        case status
    }
}

public struct SimulationAdjustRequest: Codable, Sendable {
    public let target: String
    public let direction: String?
    public let magnitude: Int?
    public let injuryEventID: Int?
    public let injuryRegion: String?
    public let avpuState: String?
    public let interventionCode: String?
    public let note: String?
    public let metadata: [String: JSONValue]

    public init(
        target: String,
        direction: String?,
        magnitude: Int?,
        injuryEventID: Int?,
        injuryRegion: String?,
        avpuState: String?,
        interventionCode: String?,
        note: String?,
        metadata: [String: JSONValue] = [:]
    ) {
        self.target = target
        self.direction = direction
        self.magnitude = magnitude
        self.injuryEventID = injuryEventID
        self.injuryRegion = injuryRegion
        self.avpuState = avpuState
        self.interventionCode = interventionCode
        self.note = note
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case target
        case direction
        case magnitude
        case injuryEventID = "injury_event_id"
        case injuryRegion = "injury_region"
        case avpuState = "avpu_state"
        case interventionCode = "intervention_code"
        case note
        case metadata
    }
}

public struct SimulationAdjustAck: Codable, Sendable {
    public let commandID: String
    public let status: String
    public let simulationID: Int

    public init(commandID: String, status: String, simulationID: Int) {
        self.commandID = commandID
        self.status = status
        self.simulationID = simulationID
    }

    enum CodingKeys: String, CodingKey {
        case commandID = "command_id"
        case status
        case simulationID = "simulation_id"
    }
}

public struct ScenarioInstructionPermission: Codable, Sendable {
    public let userID: Int
    public let canRead: Bool
    public let canEdit: Bool
    public let canDelete: Bool
    public let canShare: Bool
    public let canDuplicate: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case canRead = "can_read"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
        case canShare = "can_share"
        case canDuplicate = "can_duplicate"
    }
}

public struct ScenarioInstruction: Codable, Identifiable, Sendable {
    public let id: Int
    public let ownerID: Int
    public let title: String
    public let description: String
    public let instructionText: String
    public let injuries: [String]
    public let severity: String
    public let metadata: [String: JSONValue]
    public let isActive: Bool
    public let permissions: [ScenarioInstructionPermission]
    public let createdAt: Date
    public let modifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case title
        case description
        case instructionText = "instruction_text"
        case injuries
        case severity
        case metadata
        case isActive = "is_active"
        case permissions
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
    }
}

public struct ScenarioInstructionCreateRequest: Codable, Sendable {
    public let title: String
    public let description: String
    public let instructionText: String
    public let injuries: [String]
    public let severity: String
    public let metadata: [String: JSONValue]

    public init(
        title: String,
        description: String,
        instructionText: String,
        injuries: [String],
        severity: String,
        metadata: [String: JSONValue] = [:]
    ) {
        self.title = title
        self.description = description
        self.instructionText = instructionText
        self.injuries = injuries
        self.severity = severity
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case instructionText = "instruction_text"
        case injuries
        case severity
        case metadata
    }
}

public struct ScenarioInstructionUpdateRequest: Codable, Sendable {
    public let title: String?
    public let description: String?
    public let instructionText: String?
    public let injuries: [String]?
    public let severity: String?
    public let metadata: [String: JSONValue]?
    public let isActive: Bool?

    public init(
        title: String? = nil,
        description: String? = nil,
        instructionText: String? = nil,
        injuries: [String]? = nil,
        severity: String? = nil,
        metadata: [String: JSONValue]? = nil,
        isActive: Bool? = nil
    ) {
        self.title = title
        self.description = description
        self.instructionText = instructionText
        self.injuries = injuries
        self.severity = severity
        self.metadata = metadata
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case instructionText = "instruction_text"
        case injuries
        case severity
        case metadata
        case isActive = "is_active"
    }
}

public struct ScenarioInstructionShareRequest: Codable, Sendable {
    public let userID: Int
    public let canRead: Bool
    public let canEdit: Bool
    public let canDelete: Bool
    public let canShare: Bool
    public let canDuplicate: Bool

    public init(
        userID: Int,
        canRead: Bool = true,
        canEdit: Bool = false,
        canDelete: Bool = false,
        canShare: Bool = false,
        canDuplicate: Bool = true
    ) {
        self.userID = userID
        self.canRead = canRead
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.canShare = canShare
        self.canDuplicate = canDuplicate
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case canRead = "can_read"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
        case canShare = "can_share"
        case canDuplicate = "can_duplicate"
    }
}

public struct ScenarioInstructionUnshareRequest: Codable, Sendable {
    public let userID: Int

    public init(userID: Int) {
        self.userID = userID
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}

public struct ScenarioInstructionApplyRequest: Codable, Sendable {
    public let simulationID: Int

    public init(simulationID: Int) {
        self.simulationID = simulationID
    }

    enum CodingKeys: String, CodingKey {
        case simulationID = "simulation_id"
    }
}

public struct DictionaryItem: Codable, Identifiable, Sendable {
    public let code: String
    public let label: String

    public var id: String { code }

    public init(code: String, label: String) {
        self.code = code
        self.label = label
    }
}

public struct InjuryDictionary: Codable, Sendable {
    public let categories: [DictionaryItem]
    public let regions: [DictionaryItem]
    public let kinds: [DictionaryItem]
}

public struct InterventionSite: Codable, Identifiable, Sendable {
    public let code: String
    public let label: String

    public var id: String { code }

    public init(code: String, label: String) {
        self.code = code
        self.label = label
    }
}

public struct InterventionGroup: Codable, Identifiable, Sendable {
    public let interventionType: String
    public let label: String
    public let sites: [InterventionSite]

    public var id: String { interventionType }

    public init(interventionType: String, label: String, sites: [InterventionSite]) {
        self.interventionType = interventionType
        self.label = label
        self.sites = sites
    }

    enum CodingKeys: String, CodingKey {
        case interventionType = "code"
        case label
        case sites
    }
}

public enum InterventionStatus: String, Codable, Sendable, CaseIterable {
    case applied
    case adjusted
    case reassessed
    case removed
}

public enum InterventionEffectiveness: String, Codable, Sendable, CaseIterable {
    case unknown
    case effective
    case partiallyEffective = "partially_effective"
    case ineffective
}

public struct ScenarioBriefOut: Codable, Sendable {
    public let readAloudBrief: String
    public let environment: String
    public let locationOverview: String?
    public let threatContext: String?
    public let evacuationOptions: [String]
    public let evacuationTime: String?
    public let specialConsiderations: [String]

    public init(
        readAloudBrief: String,
        environment: String,
        locationOverview: String? = nil,
        threatContext: String? = nil,
        evacuationOptions: [String] = [],
        evacuationTime: String? = nil,
        specialConsiderations: [String] = []
    ) {
        self.readAloudBrief = readAloudBrief
        self.environment = environment
        self.locationOverview = locationOverview
        self.threatContext = threatContext
        self.evacuationOptions = evacuationOptions
        self.evacuationTime = evacuationTime
        self.specialConsiderations = specialConsiderations
    }

    enum CodingKeys: String, CodingKey {
        case readAloudBrief = "read_aloud_brief"
        case environment
        case locationOverview = "location_overview"
        case threatContext = "threat_context"
        case evacuationOptions = "evacuation_options"
        case evacuationTime = "evacuation_time"
        case specialConsiderations = "special_considerations"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        readAloudBrief = try container.decodeIfPresent(String.self, forKey: .readAloudBrief) ?? ""
        environment = try container.decodeIfPresent(String.self, forKey: .environment) ?? ""
        locationOverview = try container.decodeIfPresent(String.self, forKey: .locationOverview)
        threatContext = try container.decodeIfPresent(String.self, forKey: .threatContext)
        evacuationOptions = try container.decodeStringArrayOrSingle(forKey: .evacuationOptions)
        evacuationTime = try container.decodeIfPresent(String.self, forKey: .evacuationTime)
        specialConsiderations = try container.decodeStringArrayOrSingle(forKey: .specialConsiderations)
    }
}

private extension KeyedDecodingContainer where K == ScenarioBriefOut.CodingKeys {
    func decodeStringArrayOrSingle(forKey key: K) throws -> [String] {
        if let values = try decodeIfPresent([String].self, forKey: key) {
            return values
        }
        if let single = try decodeIfPresent(String.self, forKey: key), !single.isEmpty {
            return [single]
        }
        return []
    }
}

public struct RuntimePatientStatus: Codable, Sendable {
    public let avpu: String?
    public let respiratoryDistress: Bool
    public let hemodynamicInstability: Bool
    public let impendingPneumothorax: Bool
    public let tensionPneumothorax: Bool
    public let narrative: String
    public let teachingFlags: [String]

    public init(
        avpu: String? = nil,
        respiratoryDistress: Bool = false,
        hemodynamicInstability: Bool = false,
        impendingPneumothorax: Bool = false,
        tensionPneumothorax: Bool = false,
        narrative: String = "",
        teachingFlags: [String] = []
    ) {
        self.avpu = avpu
        self.respiratoryDistress = respiratoryDistress
        self.hemodynamicInstability = hemodynamicInstability
        self.impendingPneumothorax = impendingPneumothorax
        self.tensionPneumothorax = tensionPneumothorax
        self.narrative = narrative
        self.teachingFlags = teachingFlags
    }

    enum CodingKeys: String, CodingKey {
        case avpu
        case respiratoryDistress = "respiratory_distress"
        case hemodynamicInstability = "hemodynamic_instability"
        case impendingPneumothorax = "impending_pneumothorax"
        case tensionPneumothorax = "tension_pneumothorax"
        case narrative
        case teachingFlags = "teaching_flags"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        avpu = try container.decodeIfPresent(String.self, forKey: .avpu)
        respiratoryDistress = try container.decodeIfPresent(Bool.self, forKey: .respiratoryDistress) ?? false
        hemodynamicInstability = try container.decodeIfPresent(Bool.self, forKey: .hemodynamicInstability) ?? false
        impendingPneumothorax = try container.decodeIfPresent(Bool.self, forKey: .impendingPneumothorax) ?? false
        tensionPneumothorax = try container.decodeIfPresent(Bool.self, forKey: .tensionPneumothorax) ?? false
        narrative = try container.decodeIfPresent(String.self, forKey: .narrative) ?? ""
        teachingFlags = try container.decodeIfPresent([String].self, forKey: .teachingFlags) ?? []
    }
}

public enum ProblemLifecycleState: String, Codable, Sendable, CaseIterable {
    case active
    case treated
    case controlled
    case resolved
}

public struct RuntimeCauseState: Codable, Sendable {
    public let causeID: Int?
    public let domainEventID: Int?
    public let kind: String?
    public let code: String?
    public let title: String?
    public let displayName: String?
    public let label: String?
    public let description: String?
    public let severity: String?
    public let marchCategory: String?
    public let anatomicalLocation: String?
    public let laterality: String?
    public let injuryLocation: String?
    public let injuryKind: String?
    public let status: String?
    public let source: String?
    public let timestamp: String?
    public let metadata: [String: JSONValue]?

    public var primaryLabel: String {
        displayName ?? title ?? label ?? description ?? code ?? kind ?? "Cause"
    }

    enum CodingKeys: String, CodingKey {
        case causeID = "cause_id"
        case domainEventID = "domain_event_id"
        case kind
        case code
        case title
        case displayName = "display_name"
        case label
        case description
        case severity
        case marchCategory = "march_category"
        case anatomicalLocation = "anatomical_location"
        case laterality
        case injuryLocation = "injury_location"
        case injuryKind = "injury_kind"
        case status
        case source
        case timestamp
        case metadata
    }
}

public struct RuntimeProblemState: Codable, Sendable {
    public let problemID: Int?
    public let kind: String?
    public let code: String?
    public let title: String?
    public let displayName: String?
    public let description: String?
    public let severity: String?
    public let marchCategory: String?
    public let anatomicalLocation: String?
    public let laterality: String?
    public let status: ProblemLifecycleState?
    public let previousStatus: ProblemLifecycleState?
    public let treatedAt: Date?
    public let controlledAt: Date?
    public let resolvedAt: Date?
    public let causeID: Int?
    public let causeKind: String?
    public let parentProblemID: Int?
    public let triggeringInterventionID: Int?
    public let adjudicationReason: String?
    public let adjudicationRuleID: String?
    public let recommendedInterventionIDs: [Int]
    public let metadata: [String: JSONValue]?

    public var primaryLabel: String {
        displayName ?? title ?? description ?? code ?? kind ?? "Problem"
    }

    enum CodingKeys: String, CodingKey {
        case problemID = "problem_id"
        case kind
        case code
        case title
        case displayName = "display_name"
        case description
        case severity
        case marchCategory = "march_category"
        case anatomicalLocation = "anatomical_location"
        case laterality
        case status
        case previousStatus = "previous_status"
        case treatedAt = "treated_at"
        case controlledAt = "controlled_at"
        case resolvedAt = "resolved_at"
        case causeID = "cause_id"
        case causeKind = "cause_kind"
        case parentProblemID = "parent_problem_id"
        case triggeringInterventionID = "triggering_intervention_id"
        case adjudicationReason = "adjudication_reason"
        case adjudicationRuleID = "adjudication_rule_id"
        case recommendedInterventionIDs = "recommended_interventions"
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        problemID = try container.decodeIfPresent(Int.self, forKey: .problemID)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
        marchCategory = try container.decodeIfPresent(String.self, forKey: .marchCategory)
        anatomicalLocation = try container.decodeIfPresent(String.self, forKey: .anatomicalLocation)
        laterality = try container.decodeIfPresent(String.self, forKey: .laterality)
        status = try container.decodeIfPresent(ProblemLifecycleState.self, forKey: .status)
        previousStatus = try container.decodeIfPresent(ProblemLifecycleState.self, forKey: .previousStatus)
        treatedAt = try container.decodeIfPresent(Date.self, forKey: .treatedAt)
        controlledAt = try container.decodeIfPresent(Date.self, forKey: .controlledAt)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
        causeID = try container.decodeIfPresent(Int.self, forKey: .causeID)
        causeKind = try container.decodeIfPresent(String.self, forKey: .causeKind)
        parentProblemID = try container.decodeIfPresent(Int.self, forKey: .parentProblemID)
        triggeringInterventionID = try container.decodeIfPresent(Int.self, forKey: .triggeringInterventionID)
        adjudicationReason = try container.decodeIfPresent(String.self, forKey: .adjudicationReason)
        adjudicationRuleID = try container.decodeIfPresent(String.self, forKey: .adjudicationRuleID)
        if let ids = try? container.decode([Int].self, forKey: .recommendedInterventionIDs) {
            recommendedInterventionIDs = ids
        } else {
            let nested = try container.decodeIfPresent([RuntimeRecommendedInterventionState].self, forKey: .recommendedInterventionIDs) ?? []
            recommendedInterventionIDs = nested.compactMap(\.recommendationID)
        }
        metadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
    }
}

public struct RuntimeRecommendedInterventionState: Codable, Sendable {
    public let recommendationID: Int?
    public let kind: String?
    public let code: String?
    public let title: String?
    public let targetProblemID: Int?
    public let targetCauseID: Int?
    public let targetCauseKind: String?
    public let recommendationSource: String?
    public let validationStatus: String?
    public let normalizedKind: String?
    public let normalizedCode: String?
    public let rationale: String?
    public let priority: String?
    public let siteCode: String?
    public let siteLabel: String?
    public let warnings: [String]
    public let contraindications: [String]
    public let metadata: [String: JSONValue]?

    public var primaryLabel: String {
        title ?? code ?? kind ?? "Recommendation"
    }

    enum CodingKeys: String, CodingKey {
        case recommendationID = "recommendation_id"
        case kind
        case code
        case title
        case targetProblemID = "target_problem_id"
        case targetCauseID = "target_cause_id"
        case targetCauseKind = "target_cause_kind"
        case recommendationSource = "recommendation_source"
        case validationStatus = "validation_status"
        case normalizedKind = "normalized_kind"
        case normalizedCode = "normalized_code"
        case rationale
        case priority
        case siteCode = "site_code"
        case siteLabel = "site_label"
        case warnings
        case contraindications
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recommendationID = try container.decodeIfPresent(Int.self, forKey: .recommendationID)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        targetProblemID = try container.decodeIfPresent(Int.self, forKey: .targetProblemID)
        targetCauseID = try container.decodeIfPresent(Int.self, forKey: .targetCauseID)
        targetCauseKind = try container.decodeIfPresent(String.self, forKey: .targetCauseKind)
        recommendationSource = try container.decodeIfPresent(String.self, forKey: .recommendationSource)
        validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)
        normalizedKind = try container.decodeIfPresent(String.self, forKey: .normalizedKind)
        normalizedCode = try container.decodeIfPresent(String.self, forKey: .normalizedCode)
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        siteCode = try container.decodeIfPresent(String.self, forKey: .siteCode)
        siteLabel = try container.decodeIfPresent(String.self, forKey: .siteLabel)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        contraindications = try container.decodeIfPresent([String].self, forKey: .contraindications) ?? []
        metadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
    }
}

public struct RuntimeInterventionState: Codable, Sendable {
    public let interventionID: Int?
    public let domainEventID: Int?
    public let kind: String?
    public let code: String?
    public let title: String?
    public let siteCode: String?
    public let siteLabel: String?
    public let targetProblemID: Int?
    public let targetCauseID: Int?
    public let targetCauseKind: String?
    public let effectiveness: String?
    public let status: String?
    public let validationStatus: String?
    public let adjudicationReason: String?
    public let warnings: [String]
    public let contraindications: [String]
    public let notes: String?
    public let performedByRole: String?
    public let source: String?
    public let timestamp: String?
    public let metadata: [String: JSONValue]?

    public var primaryCode: String {
        code ?? kind ?? "intervention"
    }

    enum CodingKeys: String, CodingKey {
        case interventionID = "intervention_id"
        case domainEventID = "domain_event_id"
        case kind
        case code
        case title
        case siteCode = "site_code"
        case siteLabel = "site_label"
        case targetProblemID = "target_problem_id"
        case targetCauseID = "target_cause_id"
        case targetCauseKind = "target_cause_kind"
        case effectiveness
        case status
        case validationStatus = "validation_status"
        case adjudicationReason = "adjudication_reason"
        case warnings
        case contraindications
        case notes
        case performedByRole = "performed_by_role"
        case source
        case timestamp
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        interventionID = try container.decodeIfPresent(Int.self, forKey: .interventionID)
        domainEventID = try container.decodeIfPresent(Int.self, forKey: .domainEventID)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        siteCode = try container.decodeIfPresent(String.self, forKey: .siteCode)
        siteLabel = try container.decodeIfPresent(String.self, forKey: .siteLabel)
        targetProblemID = try container.decodeIfPresent(Int.self, forKey: .targetProblemID)
        targetCauseID = try container.decodeIfPresent(Int.self, forKey: .targetCauseID)
        targetCauseKind = try container.decodeIfPresent(String.self, forKey: .targetCauseKind)
        effectiveness = try container.decodeIfPresent(String.self, forKey: .effectiveness)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        validationStatus = try container.decodeIfPresent(String.self, forKey: .validationStatus)
        adjudicationReason = try container.decodeIfPresent(String.self, forKey: .adjudicationReason)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        contraindications = try container.decodeIfPresent([String].self, forKey: .contraindications) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        performedByRole = try container.decodeIfPresent(String.self, forKey: .performedByRole)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        metadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
    }
}

public struct RuntimeAssessmentFindingState: Codable, Sendable {
    public let findingID: Int?
    public let kind: String?
    public let code: String?
    public let title: String?
    public let description: String?
    public let status: String?
    public let metadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case findingID = "finding_id"
        case kind
        case code
        case title
        case description
        case status
        case metadata
    }
}

public struct RuntimeDiagnosticResultState: Codable, Sendable {
    public let resultID: Int?
    public let kind: String?
    public let code: String?
    public let title: String?
    public let description: String?
    public let status: String?
    public let metadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case resultID = "result_id"
        case kind
        case code
        case title
        case description
        case status
        case metadata
    }
}

public struct RuntimeResourceState: Codable, Sendable {
    public let resourceID: Int?
    public let kind: String?
    public let code: String?
    public let title: String?
    public let description: String?
    public let status: String?
    public let metadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case resourceID = "resource_id"
        case kind
        case code
        case title
        case description
        case status
        case metadata
    }
}

public struct RuntimeDispositionState: Codable, Sendable {
    public let code: String?
    public let title: String?
    public let status: String?
    public let metadata: [String: JSONValue]?
}

public struct RuntimeVitalState: Codable, Sendable {
    public let domainEventID: Int?
    public let vitalType: String
    public let minValue: Int
    public let maxValue: Int
    public let lockValue: Bool
    public let minValueDiastolic: Int?
    public let maxValueDiastolic: Int?
    public let trend: String
    public let source: String?
    public let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case domainEventID = "domain_event_id"
        case vitalType = "vital_type"
        case minValue = "min_value"
        case maxValue = "max_value"
        case lockValue = "lock_value"
        case minValueDiastolic = "min_value_diastolic"
        case maxValueDiastolic = "max_value_diastolic"
        case trend
        case source
        case timestamp
    }
}

public struct RuntimePulseState: Codable, Sendable {
    public let domainEventID: Int?
    public let location: String?
    public let present: Bool?
    public let quality: String?
    public let colorNormal: Bool?
    public let colorDescription: String?
    public let conditionNormal: Bool?
    public let conditionDescription: String?
    public let temperatureNormal: Bool?
    public let temperatureDescription: String?
    public let source: String?
    public let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case domainEventID = "domain_event_id"
        case location
        case present
        case quality
        case colorNormal = "color_normal"
        case colorDescription = "color_description"
        case conditionNormal = "condition_normal"
        case conditionDescription = "condition_description"
        case temperatureNormal = "temperature_normal"
        case temperatureDescription = "temperature_description"
        case source
        case timestamp
    }
}

public struct TrainerRuntimeSnapshot: Codable, Sendable {
    public let causes: [RuntimeCauseState]
    public let problems: [RuntimeProblemState]
    public let recommendedInterventions: [RuntimeRecommendedInterventionState]
    public let interventions: [RuntimeInterventionState]
    public let assessmentFindings: [RuntimeAssessmentFindingState]
    public let diagnosticResults: [RuntimeDiagnosticResultState]
    public let resources: [RuntimeResourceState]
    public let disposition: RuntimeDispositionState?
    public let vitals: [RuntimeVitalState]
    public let pulses: [RuntimePulseState]
    public let patientStatus: RuntimePatientStatus

    enum CodingKeys: String, CodingKey {
        case causes
        case problems
        case recommendedInterventions = "recommended_interventions"
        case interventions
        case assessmentFindings = "assessment_findings"
        case diagnosticResults = "diagnostic_results"
        case resources
        case disposition
        case vitals
        case pulses
        case patientStatus = "patient_status"
    }

    public init(
        causes: [RuntimeCauseState] = [],
        problems: [RuntimeProblemState] = [],
        recommendedInterventions: [RuntimeRecommendedInterventionState] = [],
        interventions: [RuntimeInterventionState] = [],
        assessmentFindings: [RuntimeAssessmentFindingState] = [],
        diagnosticResults: [RuntimeDiagnosticResultState] = [],
        resources: [RuntimeResourceState] = [],
        disposition: RuntimeDispositionState? = nil,
        vitals: [RuntimeVitalState] = [],
        pulses: [RuntimePulseState] = [],
        patientStatus: RuntimePatientStatus = .init()
    ) {
        self.causes = causes
        self.problems = problems
        self.recommendedInterventions = recommendedInterventions
        self.interventions = interventions
        self.assessmentFindings = assessmentFindings
        self.diagnosticResults = diagnosticResults
        self.resources = resources
        self.disposition = disposition
        self.vitals = vitals
        self.pulses = pulses
        self.patientStatus = patientStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        causes = try container.decodeIfPresent([RuntimeCauseState].self, forKey: .causes) ?? []
        problems = try container.decodeIfPresent([RuntimeProblemState].self, forKey: .problems) ?? []
        recommendedInterventions = try container.decodeIfPresent([RuntimeRecommendedInterventionState].self, forKey: .recommendedInterventions) ?? []
        interventions = try container.decodeIfPresent([RuntimeInterventionState].self, forKey: .interventions) ?? []
        assessmentFindings = try container.decodeIfPresent([RuntimeAssessmentFindingState].self, forKey: .assessmentFindings) ?? []
        diagnosticResults = try container.decodeIfPresent([RuntimeDiagnosticResultState].self, forKey: .diagnosticResults) ?? []
        resources = try container.decodeIfPresent([RuntimeResourceState].self, forKey: .resources) ?? []
        disposition = try container.decodeIfPresent(RuntimeDispositionState.self, forKey: .disposition)
        vitals = try container.decodeIfPresent([RuntimeVitalState].self, forKey: .vitals) ?? []
        pulses = try container.decodeIfPresent([RuntimePulseState].self, forKey: .pulses) ?? []
        patientStatus = try container.decodeIfPresent(RuntimePatientStatus.self, forKey: .patientStatus) ?? .init()
    }
}

public struct RuntimeInstructorIntent: Codable, Sendable {
    public let summary: String
    public let rationale: String
    public let trigger: String
    public let etaSeconds: Int?
    public let confidence: Double
    public let upcomingChanges: [String]
    public let monitoringFocus: [String]

    enum CodingKeys: String, CodingKey {
        case summary
        case rationale
        case trigger
        case etaSeconds = "eta_seconds"
        case confidence
        case upcomingChanges = "upcoming_changes"
        case monitoringFocus = "monitoring_focus"
    }
}

public struct TrainerRuntimeStateOut: Codable, Sendable {
    public let simulationID: Int
    public let sessionID: Int
    public let status: String
    public let stateRevision: Int
    public let activeElapsedSeconds: Int
    public let scenarioBrief: ScenarioBriefOut?
    public let currentSnapshot: TrainerRuntimeSnapshot
    public let aiPlan: RuntimeInstructorIntent?
    public let aiRationaleNotes: [String]
    public let pendingReasons: [JSONValue]
    public let lastAITickAt: Date?

    enum CodingKeys: String, CodingKey {
        case simulationID = "simulation_id"
        case sessionID = "session_id"
        case status
        case stateRevision = "state_revision"
        case activeElapsedSeconds = "active_elapsed_seconds"
        case scenarioBrief = "scenario_brief"
        case currentSnapshot = "current_snapshot"
        case aiPlan = "ai_plan"
        case aiRationaleNotes = "ai_rationale_notes"
        case pendingReasons = "pending_reasons"
        case lastAITickAt = "last_ai_tick_at"
    }
}

public struct TrainerSessionCreateRequest: Codable, Sendable {
    public let scenarioSpec: [String: JSONValue]
    public let directives: String?
    public let modifiers: [String]

    public init(scenarioSpec: [String: JSONValue], directives: String?, modifiers: [String]) {
        self.scenarioSpec = scenarioSpec
        self.directives = directives
        self.modifiers = modifiers
    }

    enum CodingKeys: String, CodingKey {
        case scenarioSpec = "scenario_spec"
        case directives
        case modifiers
    }
}

public struct SteerPromptRequest: Codable, Sendable {
    public let prompt: String

    public init(prompt: String) {
        self.prompt = prompt
    }
}

public struct InjuryEventRequest: Codable, Sendable {
    public let injuryLocation: String
    public let injuryKind: String
    public let injuryDescription: String
    public let description: String
    public let metadata: [String: JSONValue]?
    public let supersedesEventID: Int?

    public init(
        injuryLocation: String,
        injuryKind: String,
        injuryDescription: String,
        description: String = "",
        metadata: [String: JSONValue]? = nil,
        supersedesEventID: Int? = nil
    ) {
        self.injuryLocation = injuryLocation
        self.injuryKind = injuryKind
        self.injuryDescription = injuryDescription
        self.description = description
        self.metadata = metadata
        self.supersedesEventID = supersedesEventID
    }

    enum CodingKeys: String, CodingKey {
        case injuryLocation = "injury_location"
        case injuryKind = "injury_kind"
        case injuryDescription = "injury_description"
        case description
        case metadata
        case supersedesEventID = "supersedes_event_id"
    }
}

public struct IllnessEventRequest: Codable, Sendable {
    public let name: String
    public let description: String
    public let anatomicalLocation: String
    public let laterality: String
    public let metadata: [String: JSONValue]?
    public let supersedesEventID: Int?

    public init(
        name: String,
        description: String,
        anatomicalLocation: String = "",
        laterality: String = "",
        metadata: [String: JSONValue]? = nil,
        supersedesEventID: Int? = nil
    ) {
        self.name = name
        self.description = description
        self.anatomicalLocation = anatomicalLocation
        self.laterality = laterality
        self.metadata = metadata
        self.supersedesEventID = supersedesEventID
    }

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case anatomicalLocation = "anatomical_location"
        case laterality
        case metadata
        case supersedesEventID = "supersedes_event_id"
    }
}

public struct InterventionEventRequest: Codable, Sendable {
    public let interventionType: String
    public let siteCode: String
    public let targetProblemID: Int?
    public let status: InterventionStatus
    public let effectiveness: InterventionEffectiveness
    public let notes: String
    public let details: [String: JSONValue]?
    public let performedByRole: String
    public let supersedesEventID: Int?

    public init(
        interventionType: String,
        siteCode: String,
        targetProblemID: Int? = nil,
        status: InterventionStatus = .applied,
        effectiveness: InterventionEffectiveness = .unknown,
        notes: String = "",
        details: [String: JSONValue]? = nil,
        performedByRole: String = "instructor",
        supersedesEventID: Int? = nil
    ) {
        self.interventionType = interventionType
        self.siteCode = siteCode
        self.targetProblemID = targetProblemID
        self.status = status
        self.effectiveness = effectiveness
        self.notes = notes
        self.details = details
        self.performedByRole = performedByRole
        self.supersedesEventID = supersedesEventID
    }

    enum CodingKeys: String, CodingKey {
        case interventionType = "intervention_type"
        case siteCode = "site_code"
        case targetProblemID = "target_problem_id"
        case status
        case effectiveness
        case notes
        case details
        case performedByRole = "performed_by_role"
        case supersedesEventID = "supersedes_event_id"
    }
}

public struct VitalEventRequest: Codable, Sendable {
    public let vitalType: String
    public let minValue: Int
    public let maxValue: Int
    public let lockValue: Bool
    public let minValueDiastolic: Int?
    public let maxValueDiastolic: Int?
    public let supersedesEventID: Int?

    public init(
        vitalType: String,
        minValue: Int,
        maxValue: Int,
        lockValue: Bool,
        minValueDiastolic: Int?,
        maxValueDiastolic: Int?,
        supersedesEventID: Int?
    ) {
        self.vitalType = vitalType
        self.minValue = minValue
        self.maxValue = maxValue
        self.lockValue = lockValue
        self.minValueDiastolic = minValueDiastolic
        self.maxValueDiastolic = maxValueDiastolic
        self.supersedesEventID = supersedesEventID
    }

    enum CodingKeys: String, CodingKey {
        case vitalType = "vital_type"
        case minValue = "min_value"
        case maxValue = "max_value"
        case lockValue = "lock_value"
        case minValueDiastolic = "min_value_diastolic"
        case maxValueDiastolic = "max_value_diastolic"
        case supersedesEventID = "supersedes_event_id"
    }
}

public struct AccountListUser: Codable, Identifiable, Sendable {
    public let id: Int
    public let email: String
    public let fullName: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
    }
}

public enum AVPUState: String, CaseIterable, Codable, Sendable {
    case alert
    case verbal
    case pain
    case unalert

    public var colorToken: String {
        switch self {
        case .alert:
            return "avpu.green"
        case .verbal:
            return "avpu.amber"
        case .pain:
            return "avpu.red"
        case .unalert:
            return "avpu.black"
        }
    }
}

// MARK: - Problem State Updates

public struct ProblemStatusUpdateRequest: Codable, Sendable {
    public let isTreated: Bool?
    public let isResolved: Bool?

    public init(isTreated: Bool? = nil, isResolved: Bool? = nil) {
        self.isTreated = isTreated
        self.isResolved = isResolved
    }

    enum CodingKeys: String, CodingKey {
        case isTreated = "is_treated"
        case isResolved = "is_resolved"
    }
}

public struct ProblemStatusOut: Codable, Sendable {
    public let problemID: Int
    public let isTreated: Bool
    public let isControlled: Bool
    public let isResolved: Bool
    public let status: ProblemLifecycleState
    public let label: String

    enum CodingKeys: String, CodingKey {
        case problemID = "problem_id"
        case isTreated = "is_treated"
        case isControlled = "is_controlled"
        case isResolved = "is_resolved"
        case status
        case label
    }
}

// MARK: - Additional TrainerLab Create Requests

public struct ProblemCreateRequest: Codable, Sendable {
    public let causeKind: String
    public let causeID: Int
    public let parentProblemID: Int?
    public let kind: String
    public let code: String?
    public let title: String
    public let displayName: String
    public let description: String
    public let marchCategory: String
    public let severity: String
    public let anatomicalLocation: String
    public let laterality: String
    public let status: ProblemLifecycleState
    public let metadata: [String: JSONValue]?
    public let supersedesEventID: Int?

    public init(
        causeKind: String,
        causeID: Int,
        parentProblemID: Int? = nil,
        kind: String,
        code: String? = nil,
        title: String,
        displayName: String = "",
        description: String = "",
        marchCategory: String,
        severity: String = "moderate",
        anatomicalLocation: String = "",
        laterality: String = "",
        status: ProblemLifecycleState = .active,
        metadata: [String: JSONValue]? = nil,
        supersedesEventID: Int? = nil
    ) {
        self.causeKind = causeKind
        self.causeID = causeID
        self.parentProblemID = parentProblemID
        self.kind = kind
        self.code = code
        self.title = title
        self.displayName = displayName
        self.description = description
        self.marchCategory = marchCategory
        self.severity = severity
        self.anatomicalLocation = anatomicalLocation
        self.laterality = laterality
        self.status = status
        self.metadata = metadata
        self.supersedesEventID = supersedesEventID
    }

    enum CodingKeys: String, CodingKey {
        case causeKind = "cause_kind"
        case causeID = "cause_id"
        case parentProblemID = "parent_problem_id"
        case kind
        case code
        case title
        case displayName = "display_name"
        case description
        case marchCategory = "march_category"
        case severity
        case anatomicalLocation = "anatomical_location"
        case laterality
        case status
        case metadata
        case supersedesEventID = "supersedes_event_id"
    }
}

public struct AssessmentFindingCreateRequest: Codable, Sendable {
    public let findingKind: String
    public let title: String
    public let description: String
    public let status: String
    public let severity: String
    public let targetProblemID: Int?
    public let anatomicalLocation: String
    public let laterality: String
    public let metadata: [String: JSONValue]?
    public let supersedesEventID: Int?

    enum CodingKeys: String, CodingKey {
        case findingKind = "finding_kind"
        case title
        case description
        case status
        case severity
        case targetProblemID = "target_problem_id"
        case anatomicalLocation = "anatomical_location"
        case laterality
        case metadata
        case supersedesEventID = "supersedes_event_id"
    }
}

public struct DiagnosticResultCreateRequest: Codable, Sendable {
    public let diagnosticKind: String
    public let title: String
    public let description: String
    public let status: String
    public let valueText: String
    public let targetProblemID: Int?
    public let metadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case diagnosticKind = "diagnostic_kind"
        case title
        case description
        case status
        case valueText = "value_text"
        case targetProblemID = "target_problem_id"
        case metadata
    }
}

public struct ResourceStateCreateRequest: Codable, Sendable {
    public let kind: String
    public let code: String?
    public let title: String
    public let displayName: String
    public let status: String
    public let quantityAvailable: Int
    public let quantityUnit: String
    public let description: String
    public let metadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case kind
        case code
        case title
        case displayName = "display_name"
        case status
        case quantityAvailable = "quantity_available"
        case quantityUnit = "quantity_unit"
        case description
        case metadata
    }
}

public struct DispositionStateCreateRequest: Codable, Sendable {
    public let status: String
    public let transportMode: String
    public let destination: String
    public let notes: String
    public let etaSeconds: Int?
    public let metadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case status
        case transportMode = "transport_mode"
        case destination
        case notes
        case etaSeconds = "eta_seconds"
        case metadata
    }
}

// MARK: - Annotations

public struct AnnotationCreateRequest: Codable, Sendable {
    public let learningObjective: String
    public let observationText: String
    public let outcome: String
    public let linkedEventID: Int?
    public let elapsedSecondsAt: Int?

    public init(
        observationText: String,
        learningObjective: String = "other",
        outcome: String = "pending",
        linkedEventID: Int? = nil,
        elapsedSecondsAt: Int? = nil
    ) {
        self.learningObjective = learningObjective
        self.observationText = observationText
        self.outcome = outcome
        self.linkedEventID = linkedEventID
        self.elapsedSecondsAt = elapsedSecondsAt
    }

    enum CodingKeys: String, CodingKey {
        case learningObjective = "learning_objective"
        case observationText = "observation_text"
        case outcome
        case linkedEventID = "linked_event_id"
        case elapsedSecondsAt = "elapsed_seconds_at"
    }
}

public struct AnnotationOut: Codable, Identifiable, Sendable {
    public let id: Int
    public let sessionID: Int
    public let simulationID: Int
    public let createdByID: Int?
    public let learningObjective: String
    public let learningObjectiveLabel: String
    public let observationText: String
    public let outcome: String
    public let outcomeLabel: String
    public let linkedEventID: Int?
    public let elapsedSecondsAt: Int?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case simulationID = "simulation_id"
        case createdByID = "created_by_id"
        case learningObjective = "learning_objective"
        case learningObjectiveLabel = "learning_objective_label"
        case observationText = "observation_text"
        case outcome
        case outcomeLabel = "outcome_label"
        case linkedEventID = "linked_event_id"
        case elapsedSecondsAt = "elapsed_seconds_at"
        case createdAt = "created_at"
    }
}

// MARK: - Scenario Brief Update

public struct ScenarioBriefUpdateRequest: Codable, Sendable {
    public let readAloudBrief: String?
    public let environment: String?
    public let locationOverview: String?
    public let threatContext: String?
    public let evacuationOptions: [String]?
    public let evacuationTime: String?
    public let specialConsiderations: [String]?

    public init(
        readAloudBrief: String? = nil,
        environment: String? = nil,
        locationOverview: String? = nil,
        threatContext: String? = nil,
        evacuationOptions: [String]? = nil,
        evacuationTime: String? = nil,
        specialConsiderations: [String]? = nil
    ) {
        self.readAloudBrief = readAloudBrief
        self.environment = environment
        self.locationOverview = locationOverview
        self.threatContext = threatContext
        self.evacuationOptions = evacuationOptions
        self.evacuationTime = evacuationTime
        self.specialConsiderations = specialConsiderations
    }

    enum CodingKeys: String, CodingKey {
        case readAloudBrief = "read_aloud_brief"
        case environment
        case locationOverview = "location_overview"
        case threatContext = "threat_context"
        case evacuationOptions = "evacuation_options"
        case evacuationTime = "evacuation_time"
        case specialConsiderations = "special_considerations"
    }
}

// MARK: - Pulse Assessment

public enum PulseLocation: String, Codable, Sendable, CaseIterable {
    case carotidLeft = "carotid_left"
    case carotidRight = "carotid_right"
    case radialLeft = "radial_left"
    case radialRight = "radial_right"
    case femoralLeft = "femoral_left"
    case femoralRight = "femoral_right"
    case pedalLeft = "pedal_left"
    case pedalRight = "pedal_right"

    public var label: String {
        switch self {
        case .carotidLeft: return "Carotid (Left)"
        case .carotidRight: return "Carotid (Right)"
        case .radialLeft: return "Radial (Left)"
        case .radialRight: return "Radial (Right)"
        case .femoralLeft: return "Femoral (Left)"
        case .femoralRight: return "Femoral (Right)"
        case .pedalLeft: return "Pedal (Left)"
        case .pedalRight: return "Pedal (Right)"
        }
    }
}

public enum PulseQuality: String, Codable, Sendable, CaseIterable {
    case strong
    case bounding
    case weak
    case absent
    case thready
}
