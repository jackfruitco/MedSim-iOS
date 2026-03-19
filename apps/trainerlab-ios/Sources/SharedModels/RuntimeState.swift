import Foundation

public enum RealtimeTransportState: Equatable, Sendable {
    case disconnected
    case connecting
    case connectedSSE
    case polling
    case reconnecting(Int)
}

public enum TransportBannerStyle: String, Equatable, Sendable {
    case healthy
    case warning
    case error
}

public struct TransportBanner: Equatable, Sendable {
    public var style: TransportBannerStyle
    public var message: String
    public var visible: Bool

    public init(style: TransportBannerStyle, message: String, visible: Bool) {
        self.style = style
        self.message = message
        self.visible = visible
    }
}

public enum VitalTrendDirection: String, Codable, Equatable, Sendable {
    case up
    case down
    case flat
}

public enum InjuryZoneSide: String, Codable, Equatable, Sendable {
    case front
    case back
}

public enum InjuryDisplayStatus: String, Codable, Equatable, Sendable {
    case pending
    case active
    case inactive
}

public typealias CauseAnnotation = InjuryAnnotation

public struct InjuryAnnotation: Identifiable, Equatable, Sendable {
    public let id: String
    public let causeID: Int?
    public let locationCode: String
    public let side: InjuryZoneSide
    public let x: Double
    public let y: Double
    public let category: String?
    public let kind: String
    public let code: String?
    public let title: String
    public let displayName: String?
    public let summary: String
    public let severity: String?
    public var status: InjuryDisplayStatus
    public var source: String?
    public var supersedesEventID: String?
    public var hiddenAfter: Date?
    public var updatedAt: Date

    public init(
        id: String,
        causeID: Int? = nil,
        locationCode: String,
        side: InjuryZoneSide,
        x: Double,
        y: Double,
        category: String? = nil,
        kind: String,
        code: String? = nil,
        title: String? = nil,
        displayName: String? = nil,
        summary: String,
        severity: String? = nil,
        status: InjuryDisplayStatus,
        source: String? = nil,
        supersedesEventID: String? = nil,
        hiddenAfter: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.causeID = causeID
        self.locationCode = locationCode
        self.side = side
        self.x = x
        self.y = y
        self.category = category
        self.kind = kind
        self.code = code
        self.title = title ?? summary
        self.displayName = displayName
        self.summary = summary
        self.severity = severity
        self.status = status
        self.source = source
        self.supersedesEventID = supersedesEventID
        self.hiddenAfter = hiddenAfter
        self.updatedAt = updatedAt
    }

    public var label: String {
        if let displayName, !displayName.isEmpty { return displayName }
        if !title.isEmpty { return title }
        return summary
    }

    public var isTreated: Bool {
        status == .inactive
    }
}

// MARK: - Intervention Annotation

public struct InterventionAnnotation: Identifiable, Equatable, Sendable {
    public let id: String
    public let interventionID: Int?
    public let interventionType: String
    public let title: String
    public let siteCode: String
    public let siteLabel: String?
    public let targetProblemID: Int?
    public let targetCauseID: Int?
    public let targetCauseKind: String?
    public let validationStatus: String?
    public let adjudicationReason: String?
    public let warnings: [String]
    public let contraindications: [String]
    public let side: InjuryZoneSide
    public let x: Double
    public let y: Double
    public let effectiveness: String
    public let status: String
    public var updatedAt: Date

    public init(
        id: String,
        interventionID: Int? = nil,
        interventionType: String,
        title: String? = nil,
        siteCode: String,
        siteLabel: String? = nil,
        targetProblemID: Int? = nil,
        targetCauseID: Int? = nil,
        targetCauseKind: String? = nil,
        validationStatus: String? = nil,
        adjudicationReason: String? = nil,
        warnings: [String] = [],
        contraindications: [String] = [],
        side: InjuryZoneSide,
        x: Double,
        y: Double,
        effectiveness: String,
        status: String,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.interventionID = interventionID
        self.interventionType = interventionType
        self.title = title ?? interventionType.replacingOccurrences(of: "_", with: " ").capitalized
        self.siteCode = siteCode
        self.siteLabel = siteLabel
        self.targetProblemID = targetProblemID
        self.targetCauseID = targetCauseID
        self.targetCauseKind = targetCauseKind
        self.validationStatus = validationStatus
        self.adjudicationReason = adjudicationReason
        self.warnings = warnings
        self.contraindications = contraindications
        self.side = side
        self.x = x
        self.y = y
        self.effectiveness = effectiveness
        self.status = status
        self.updatedAt = updatedAt
    }
}

// MARK: - Problem Annotation

public struct ProblemAnnotation: Identifiable, Equatable, Sendable {
    public let id: String
    public let problemID: Int?
    public let title: String
    public let displayName: String?
    public let description: String?
    public let isAnatomic: Bool
    public let locationCode: String?
    public let side: InjuryZoneSide?
    public let x: Double?
    public let y: Double?
    public let status: ProblemLifecycleState
    public let previousStatus: ProblemLifecycleState?
    public let severity: String?
    public let causeID: Int?
    public let causeKind: String?
    public let recommendedInterventionIDs: [Int]
    public let adjudicationReason: String?
    public var updatedAt: Date

    public init(
        id: String,
        problemID: Int? = nil,
        title: String,
        displayName: String? = nil,
        description: String? = nil,
        isAnatomic: Bool,
        locationCode: String? = nil,
        side: InjuryZoneSide? = nil,
        x: Double? = nil,
        y: Double? = nil,
        status: ProblemLifecycleState,
        previousStatus: ProblemLifecycleState? = nil,
        severity: String? = nil,
        causeID: Int? = nil,
        causeKind: String? = nil,
        recommendedInterventionIDs: [Int] = [],
        adjudicationReason: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.problemID = problemID
        self.title = title
        self.displayName = displayName
        self.description = description
        self.isAnatomic = isAnatomic
        self.locationCode = locationCode
        self.side = side
        self.x = x
        self.y = y
        self.status = status
        self.previousStatus = previousStatus
        self.severity = severity
        self.causeID = causeID
        self.causeKind = causeKind
        self.recommendedInterventionIDs = recommendedInterventionIDs
        self.adjudicationReason = adjudicationReason
        self.updatedAt = updatedAt
    }

    public var label: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return title
    }

    /// Compatibility shim while the UI migrates away from legacy condition-control language.
    public var controlState: String {
        switch status {
        case .active:
            "uncontrolled"
        case .treated:
            "treated"
        case .controlled:
            "controlled"
        case .resolved:
            "resolved"
        }
    }

    public var isUncontrolled: Bool {
        status == .active
    }

    public var isHistorical: Bool {
        status == .resolved
    }
}

public struct RecommendedInterventionItem: Identifiable, Equatable, Sendable {
    public let recommendationID: Int
    public let title: String
    public let code: String?
    public let kind: String?
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

    public var id: Int {
        recommendationID
    }

    public init(
        recommendationID: Int,
        title: String,
        code: String? = nil,
        kind: String? = nil,
        targetProblemID: Int? = nil,
        targetCauseID: Int? = nil,
        targetCauseKind: String? = nil,
        recommendationSource: String? = nil,
        validationStatus: String? = nil,
        normalizedKind: String? = nil,
        normalizedCode: String? = nil,
        rationale: String? = nil,
        priority: String? = nil,
        siteCode: String? = nil,
        siteLabel: String? = nil,
        warnings: [String] = [],
        contraindications: [String] = []
    ) {
        self.recommendationID = recommendationID
        self.title = title
        self.code = code
        self.kind = kind
        self.targetProblemID = targetProblemID
        self.targetCauseID = targetCauseID
        self.targetCauseKind = targetCauseKind
        self.recommendationSource = recommendationSource
        self.validationStatus = validationStatus
        self.normalizedKind = normalizedKind
        self.normalizedCode = normalizedCode
        self.rationale = rationale
        self.priority = priority
        self.siteCode = siteCode
        self.siteLabel = siteLabel
        self.warnings = warnings
        self.contraindications = contraindications
    }
}

// MARK: - Pulse Annotation

public struct PulseAnnotation: Identifiable, Equatable, Sendable {
    public let id: String
    public let location: String
    public let side: InjuryZoneSide
    public let x: Double
    public let y: Double
    public let present: Bool
    public let quality: String
    public let colorNormal: Bool
    public let colorDescription: String
    public let conditionNormal: Bool
    public let conditionDescription: String
    public let temperatureNormal: Bool
    public let temperatureDescription: String
    public var updatedAt: Date

    public init(
        id: String,
        location: String,
        side: InjuryZoneSide,
        x: Double,
        y: Double,
        present: Bool,
        quality: String,
        colorNormal: Bool = true,
        colorDescription: String = "pink",
        conditionNormal: Bool = true,
        conditionDescription: String = "dry",
        temperatureNormal: Bool = true,
        temperatureDescription: String = "warm",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.location = location
        self.side = side
        self.x = x
        self.y = y
        self.present = present
        self.quality = quality
        self.colorNormal = colorNormal
        self.colorDescription = colorDescription
        self.conditionNormal = conditionNormal
        self.conditionDescription = conditionDescription
        self.temperatureNormal = temperatureNormal
        self.temperatureDescription = temperatureDescription
        self.updatedAt = updatedAt
    }

    public var locationLabel: String {
        PulseLocation(rawValue: location)?.label ?? location.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

public enum ClinicalTimelineKind: String, Codable, Equatable, Sendable {
    case lifecycle
    case cause
    case injury
    case illness
    case problem
    case recommendation
    case intervention
    case loc
    case note
    case vitals
}

public struct ClinicalTimelineEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let dedupeKey: String
    public let kind: ClinicalTimelineKind
    public let title: String
    public let message: String
    public let createdAt: Date
    /// Extra data for rich rendering. Common keys:
    /// "intervention_type", "site_code", "effectiveness", "status", "superseded_by"
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        dedupeKey: String,
        kind: ClinicalTimelineKind,
        title: String,
        message: String,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.dedupeKey = dedupeKey
        self.kind = kind
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

public struct TerminalCard: Equatable, Sendable {
    public let status: TrainerSessionStatus
    public let reasonText: String?
    public let completedAt: Date?

    public init(status: TrainerSessionStatus, reasonText: String?, completedAt: Date?) {
        self.status = status
        self.reasonText = reasonText
        self.completedAt = completedAt
    }
}

public struct VitalStatusSnapshot: Identifiable, Equatable, Sendable {
    public let key: String
    public let minValue: Int
    public let maxValue: Int
    public let minValueDiastolic: Int?
    public let maxValueDiastolic: Int?
    public let lockValue: Bool
    public var previousValue: Int?
    public var previousDiastolicValue: Int?
    public var currentValue: Int
    public var currentDiastolicValue: Int?
    public var trend: VitalTrendDirection
    public var changeToken: Int
    public var lastUpdatedAt: Date

    public var id: String {
        key
    }

    public init(
        key: String,
        minValue: Int,
        maxValue: Int,
        minValueDiastolic: Int? = nil,
        maxValueDiastolic: Int? = nil,
        lockValue: Bool = false,
        previousValue: Int? = nil,
        previousDiastolicValue: Int? = nil,
        currentValue: Int,
        currentDiastolicValue: Int? = nil,
        trend: VitalTrendDirection = .flat,
        changeToken: Int = 0,
        lastUpdatedAt: Date = Date()
    ) {
        self.key = key
        self.minValue = minValue
        self.maxValue = maxValue
        self.minValueDiastolic = minValueDiastolic
        self.maxValueDiastolic = maxValueDiastolic
        self.lockValue = lockValue
        self.previousValue = previousValue
        self.previousDiastolicValue = previousDiastolicValue
        self.currentValue = currentValue
        self.currentDiastolicValue = currentDiastolicValue
        self.trend = trend
        self.changeToken = changeToken
        self.lastUpdatedAt = lastUpdatedAt
    }
}

public struct RunSessionState: Equatable, Sendable {
    public var session: TrainerSessionDTO?
    public var transportState: RealtimeTransportState
    public var timeline: [EventEnvelope]
    public var clinicalTimelineEntries: [ClinicalTimelineEntry]
    public var vitals: [VitalStatusSnapshot]
    public var causeAnnotations: [CauseAnnotation]
    public var interventionAnnotations: [InterventionAnnotation]
    public var problemAnnotations: [ProblemAnnotation]
    public var recommendedInterventions: [RecommendedInterventionItem]
    public var pulseAnnotations: [PulseAnnotation]
    public var stopwatchElapsedSeconds: Int
    public var stopwatchIsRunning: Bool
    public var stopwatchRunningSince: Date?
    public var eventCursor: String?
    public var pendingCommandCount: Int
    public var commandChannelAvailable: Bool
    public var transportBanner: TransportBanner
    public var conflictBanner: String?
    public var terminalCard: TerminalCard?

    public init(
        session: TrainerSessionDTO? = nil,
        transportState: RealtimeTransportState = .disconnected,
        timeline: [EventEnvelope] = [],
        clinicalTimelineEntries: [ClinicalTimelineEntry] = [],
        vitals: [VitalStatusSnapshot] = [],
        causeAnnotations: [CauseAnnotation] = [],
        interventionAnnotations: [InterventionAnnotation] = [],
        problemAnnotations: [ProblemAnnotation] = [],
        recommendedInterventions: [RecommendedInterventionItem] = [],
        pulseAnnotations: [PulseAnnotation] = [],
        stopwatchElapsedSeconds: Int = 0,
        stopwatchIsRunning: Bool = false,
        stopwatchRunningSince: Date? = nil,
        eventCursor: String? = nil,
        pendingCommandCount: Int = 0,
        commandChannelAvailable: Bool = false,
        transportBanner: TransportBanner = TransportBanner(
            style: .error,
            message: "Disconnected",
            visible: true
        ),
        conflictBanner: String? = nil,
        terminalCard: TerminalCard? = nil
    ) {
        self.session = session
        self.transportState = transportState
        self.timeline = timeline
        self.clinicalTimelineEntries = clinicalTimelineEntries
        self.vitals = vitals
        self.causeAnnotations = causeAnnotations
        self.interventionAnnotations = interventionAnnotations
        self.problemAnnotations = problemAnnotations
        self.recommendedInterventions = recommendedInterventions
        self.pulseAnnotations = pulseAnnotations
        self.stopwatchElapsedSeconds = stopwatchElapsedSeconds
        self.stopwatchIsRunning = stopwatchIsRunning
        self.stopwatchRunningSince = stopwatchRunningSince
        self.eventCursor = eventCursor
        self.pendingCommandCount = pendingCommandCount
        self.commandChannelAvailable = commandChannelAvailable
        self.transportBanner = transportBanner
        self.conflictBanner = conflictBanner
        self.terminalCard = terminalCard
    }

    public var injuryAnnotations: [CauseAnnotation] {
        get { causeAnnotations }
        set { causeAnnotations = newValue }
    }
}
