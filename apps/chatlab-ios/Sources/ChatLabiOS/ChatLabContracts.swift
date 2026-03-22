import Foundation
import SharedModels

public enum SimulationTerminalState: String, Codable, Sendable, CaseIterable {
    case inProgress = "in_progress"
    case completed
    case timedOut = "timed_out"
    case failed
    case canceled
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = (try? container.decode(String.self)) ?? ""
        self = Self(rawValue: value) ?? .unknown
    }
}

public struct ChatSimulation: Codable, Identifiable, Sendable, Equatable {
    public let id: Int
    public let userID: Int
    public let startTimestamp: Date
    public let endTimestamp: Date?
    public let timeLimitSeconds: Int?
    public let diagnosis: String?
    public let chiefComplaint: String?
    public let patientDisplayName: String
    public let patientInitials: String
    public let status: SimulationTerminalState
    public let terminalReasonCode: String
    public let terminalReasonText: String
    public let terminalAt: Date?
    public let retryable: Bool?

    public init(
        id: Int,
        userID: Int,
        startTimestamp: Date,
        endTimestamp: Date?,
        timeLimitSeconds: Int?,
        diagnosis: String?,
        chiefComplaint: String?,
        patientDisplayName: String,
        patientInitials: String,
        status: SimulationTerminalState,
        terminalReasonCode: String,
        terminalReasonText: String,
        terminalAt: Date?,
        retryable: Bool?,
    ) {
        self.id = id
        self.userID = userID
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.timeLimitSeconds = timeLimitSeconds
        self.diagnosis = diagnosis
        self.chiefComplaint = chiefComplaint
        self.patientDisplayName = patientDisplayName
        self.patientInitials = patientInitials
        self.status = status
        self.terminalReasonCode = terminalReasonCode
        self.terminalReasonText = terminalReasonText
        self.terminalAt = terminalAt
        self.retryable = retryable
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case startTimestamp = "start_timestamp"
        case endTimestamp = "end_timestamp"
        case timeLimitSeconds = "time_limit_seconds"
        case diagnosis
        case chiefComplaint = "chief_complaint"
        case patientDisplayName = "patient_display_name"
        case patientInitials = "patient_initials"
        case status
        case terminalReasonCode = "terminal_reason_code"
        case terminalReasonText = "terminal_reason_text"
        case terminalAt = "terminal_at"
        case retryable
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userID = try container.decode(Int.self, forKey: .userID)
        startTimestamp = try container.decode(Date.self, forKey: .startTimestamp)
        endTimestamp = try container.decodeIfPresent(Date.self, forKey: .endTimestamp)
        timeLimitSeconds = try container.decodeIfPresent(Int.self, forKey: .timeLimitSeconds)
        diagnosis = try container.decodeIfPresent(String.self, forKey: .diagnosis)
        chiefComplaint = try container.decodeIfPresent(String.self, forKey: .chiefComplaint)
        patientDisplayName = try container.decode(String.self, forKey: .patientDisplayName)
        patientInitials = try container.decode(String.self, forKey: .patientInitials)
        status = try container.decode(SimulationTerminalState.self, forKey: .status)
        terminalReasonCode = try container.decodeIfPresent(String.self, forKey: .terminalReasonCode) ?? ""
        terminalReasonText = try container.decodeIfPresent(String.self, forKey: .terminalReasonText) ?? ""
        terminalAt = try container.decodeIfPresent(Date.self, forKey: .terminalAt)
        retryable = try container.decodeIfPresent(Bool.self, forKey: .retryable)
    }
}

public struct ChatConversation: Codable, Identifiable, Sendable, Equatable {
    public let id: Int
    public let uuid: String
    public let simulationID: Int
    public let conversationType: String
    public let conversationTypeDisplay: String
    public let icon: String
    public let displayName: String
    public let displayInitials: String
    public let isLocked: Bool
    public let createdAt: Date

    public init(
        id: Int,
        uuid: String,
        simulationID: Int,
        conversationType: String,
        conversationTypeDisplay: String,
        icon: String,
        displayName: String,
        displayInitials: String,
        isLocked: Bool,
        createdAt: Date,
    ) {
        self.id = id
        self.uuid = uuid
        self.simulationID = simulationID
        self.conversationType = conversationType
        self.conversationTypeDisplay = conversationTypeDisplay
        self.icon = icon
        self.displayName = displayName
        self.displayInitials = displayInitials
        self.isLocked = isLocked
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case simulationID = "simulation_id"
        case conversationType = "conversation_type"
        case conversationTypeDisplay = "conversation_type_display"
        case icon
        case displayName = "display_name"
        case displayInitials = "display_initials"
        case isLocked = "is_locked"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        uuid = try container.decode(String.self, forKey: .uuid)
        simulationID = try container.decode(Int.self, forKey: .simulationID)
        conversationType = try container.decode(String.self, forKey: .conversationType)
        conversationTypeDisplay = try container.decode(String.self, forKey: .conversationTypeDisplay)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        displayInitials = try container.decodeIfPresent(String.self, forKey: .displayInitials) ?? ""
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

public enum DeliveryStatus: String, Codable, Sendable {
    case sending
    case sent
    case delivered
    case failed
}

public struct ChatMessageMedia: Codable, Identifiable, Sendable, Equatable {
    public let id: Int
    public let uuid: String
    public let originalURL: String
    public let thumbnailURL: String
    public let url: String
    public let mimeType: String
    public let description: String

    public init(
        id: Int,
        uuid: String,
        originalURL: String,
        thumbnailURL: String,
        url: String,
        mimeType: String,
        description: String,
    ) {
        self.id = id
        self.uuid = uuid
        self.originalURL = originalURL
        self.thumbnailURL = thumbnailURL
        self.url = url
        self.mimeType = mimeType
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case originalURL = "original_url"
        case thumbnailURL = "thumbnail_url"
        case url
        case mimeType = "mime_type"
        case description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        uuid = try container.decode(String.self, forKey: .uuid)
        originalURL = try container.decode(String.self, forKey: .originalURL)
        thumbnailURL = try container.decode(String.self, forKey: .thumbnailURL)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? thumbnailURL
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}

public struct ChatMessage: Codable, Identifiable, Sendable, Equatable {
    public let id: Int
    public let simulationID: Int
    public let conversationID: Int?
    public let conversationType: String?
    public let senderID: Int
    public let content: String?
    public let role: String
    public let messageType: String
    public let timestamp: Date
    public let isFromAI: Bool
    public let displayName: String
    public let deliveryStatus: DeliveryStatus
    public let deliveryErrorCode: String
    public let deliveryErrorText: String
    public let deliveryRetryable: Bool
    public let deliveryRetryCount: Int
    public let isRead: Bool
    public let mediaList: [ChatMessageMedia]

    public init(
        id: Int,
        simulationID: Int,
        conversationID: Int?,
        conversationType: String?,
        senderID: Int,
        content: String?,
        role: String,
        messageType: String,
        timestamp: Date,
        isFromAI: Bool,
        displayName: String,
        deliveryStatus: DeliveryStatus,
        deliveryErrorCode: String,
        deliveryErrorText: String,
        deliveryRetryable: Bool,
        deliveryRetryCount: Int,
        isRead: Bool,
        mediaList: [ChatMessageMedia],
    ) {
        self.id = id
        self.simulationID = simulationID
        self.conversationID = conversationID
        self.conversationType = conversationType
        self.senderID = senderID
        self.content = content
        self.role = role
        self.messageType = messageType
        self.timestamp = timestamp
        self.isFromAI = isFromAI
        self.displayName = displayName
        self.deliveryStatus = deliveryStatus
        self.deliveryErrorCode = deliveryErrorCode
        self.deliveryErrorText = deliveryErrorText
        self.deliveryRetryable = deliveryRetryable
        self.deliveryRetryCount = deliveryRetryCount
        self.isRead = isRead
        self.mediaList = mediaList
    }

    enum CodingKeys: String, CodingKey {
        case id
        case simulationID = "simulation_id"
        case conversationID = "conversation_id"
        case conversationType = "conversation_type"
        case senderID = "sender_id"
        case content
        case role
        case messageType = "message_type"
        case timestamp
        case isFromAI = "is_from_ai"
        case displayName = "display_name"
        case deliveryStatus = "delivery_status"
        case deliveryErrorCode = "delivery_error_code"
        case deliveryErrorText = "delivery_error_text"
        case deliveryRetryable = "delivery_retryable"
        case deliveryRetryCount = "delivery_retry_count"
        case isRead = "is_read"
        case mediaList = "media_list"
    }

    enum CompatibilityCodingKeys: String, CodingKey {
        case mediaListCompatibility = "mediaList"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        simulationID = try container.decode(Int.self, forKey: .simulationID)
        conversationID = try container.decodeIfPresent(Int.self, forKey: .conversationID)
        conversationType = try container.decodeIfPresent(String.self, forKey: .conversationType)
        senderID = try container.decode(Int.self, forKey: .senderID)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        role = try container.decode(String.self, forKey: .role)
        messageType = try container.decodeIfPresent(String.self, forKey: .messageType) ?? "text"
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isFromAI = try container.decode(Bool.self, forKey: .isFromAI)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        deliveryStatus = try container.decodeIfPresent(DeliveryStatus.self, forKey: .deliveryStatus) ?? .sent
        deliveryErrorCode = try container.decodeIfPresent(String.self, forKey: .deliveryErrorCode) ?? ""
        deliveryErrorText = try container.decodeIfPresent(String.self, forKey: .deliveryErrorText) ?? ""
        deliveryRetryable = try container.decodeIfPresent(Bool.self, forKey: .deliveryRetryable) ?? true
        deliveryRetryCount = try container.decodeIfPresent(Int.self, forKey: .deliveryRetryCount) ?? 0
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        if let primaryMedia = try container.decodeIfPresent([ChatMessageMedia].self, forKey: .mediaList) {
            mediaList = primaryMedia
        } else {
            let compatibilityContainer = try decoder.container(keyedBy: CompatibilityCodingKeys.self)
            mediaList = try compatibilityContainer.decodeIfPresent([ChatMessageMedia].self, forKey: .mediaListCompatibility) ?? []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(simulationID, forKey: .simulationID)
        try container.encodeIfPresent(conversationID, forKey: .conversationID)
        try container.encodeIfPresent(conversationType, forKey: .conversationType)
        try container.encode(senderID, forKey: .senderID)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encode(role, forKey: .role)
        try container.encode(messageType, forKey: .messageType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isFromAI, forKey: .isFromAI)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(deliveryStatus, forKey: .deliveryStatus)
        try container.encode(deliveryErrorCode, forKey: .deliveryErrorCode)
        try container.encode(deliveryErrorText, forKey: .deliveryErrorText)
        try container.encode(deliveryRetryable, forKey: .deliveryRetryable)
        try container.encode(deliveryRetryCount, forKey: .deliveryRetryCount)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(mediaList, forKey: .mediaList)
    }
}

public struct ChatToolState: Codable, Sendable, Equatable {
    public let name: String
    public let displayName: String
    public let data: [[String: JSONValue]]
    public let isGeneric: Bool
    public let checksum: String

    public init(
        name: String,
        displayName: String,
        data: [[String: JSONValue]],
        isGeneric: Bool,
        checksum: String,
    ) {
        self.name = name
        self.displayName = displayName
        self.data = data
        self.isGeneric = isGeneric
        self.checksum = checksum
    }

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case data
        case isGeneric = "is_generic"
        case checksum
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decode(String.self, forKey: .displayName)
        data = try container.decodeIfPresent([[String: JSONValue]].self, forKey: .data) ?? []
        isGeneric = try container.decodeIfPresent(Bool.self, forKey: .isGeneric) ?? false
        checksum = try container.decode(String.self, forKey: .checksum)
    }
}

public struct ChatToolListResponse: Codable, Sendable {
    public let items: [ChatToolState]
}

public struct ChatTypingEvent: Codable, Sendable, Equatable {
    public let user: String
    public let displayName: String?
    public let displayInitials: String?
    public let conversationID: Int?

    public init(user: String, displayName: String?, displayInitials: String?, conversationID: Int?) {
        self.user = user
        self.displayName = displayName
        self.displayInitials = displayInitials
        self.conversationID = conversationID
    }

    enum CodingKeys: String, CodingKey {
        case user
        case displayName = "display_name"
        case displayInitials = "display_initials"
        case conversationID = "conversation_id"
    }
}

public struct ChatEventEnvelope: Codable, Equatable, Identifiable, Sendable {
    public let eventID: String
    public let eventType: String
    public let createdAt: Date
    public let correlationID: String?
    public let payload: [String: JSONValue]

    public var id: String {
        eventID
    }

    public init(
        eventID: String,
        eventType: String,
        createdAt: Date,
        correlationID: String?,
        payload: [String: JSONValue],
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

public extension ChatEventEnvelope {
    func decodePayload<T: Decodable>(_ type: T.Type) throws -> T {
        try payload.decodedPayload(as: type)
    }

    func canonicalized() -> ChatEventEnvelope {
        let canonicalEventType = SimulationEventRegistry.canonicalize(eventType)
        let normalizedPayload = SimulationEventRegistry.normalizedPayload(for: eventType, payload: payload)
        guard canonicalEventType != eventType || normalizedPayload != payload else { return self }
        return ChatEventEnvelope(
            eventID: eventID,
            eventType: canonicalEventType,
            createdAt: createdAt,
            correlationID: correlationID,
            payload: normalizedPayload,
        )
    }
}

public enum ChatRealtimeConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case catchingUp
}

public struct ChatConversationListResponse: Codable, Sendable {
    public let items: [ChatConversation]
}

public struct ChatCreateConversationRequest: Codable, Sendable {
    public let conversationType: String

    public init(conversationType: String) {
        self.conversationType = conversationType
    }

    enum CodingKeys: String, CodingKey {
        case conversationType = "conversation_type"
    }
}

public struct ChatCreateMessageRequest: Codable, Sendable {
    public let content: String
    public let messageType: String
    public let conversationID: Int?

    public init(content: String, messageType: String = "text", conversationID: Int?) {
        self.content = content
        self.messageType = messageType
        self.conversationID = conversationID
    }

    enum CodingKeys: String, CodingKey {
        case content
        case messageType = "message_type"
        case conversationID = "conversation_id"
    }
}

public struct ChatQuickCreateRequest: Codable, Sendable {
    public let modifiers: [String]

    public init(modifiers: [String]) {
        self.modifiers = modifiers
    }
}

public struct ChatSignOrdersRequest: Codable, Sendable {
    public let submittedOrders: [String]

    public init(submittedOrders: [String]) {
        self.submittedOrders = submittedOrders
    }

    enum CodingKeys: String, CodingKey {
        case submittedOrders = "submitted_orders"
    }
}

public struct ChatSignOrdersResponse: Codable, Sendable {
    public let status: String
    public let orders: [String]
}

public struct ChatSubmitLabOrdersRequest: Codable, Sendable {
    public let orders: [String]

    public init(orders: [String]) {
        self.orders = orders
    }
}

public struct ChatLabOrdersResponse: Codable, Sendable, Equatable {
    public let status: String
    public let callID: String?
    public let orders: [String]

    public init(status: String, callID: String?, orders: [String]) {
        self.status = status
        self.callID = callID
        self.orders = orders
    }

    enum CodingKeys: String, CodingKey {
        case status
        case callID = "call_id"
        case orders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "accepted"
        callID = try container.decodeIfPresent(String.self, forKey: .callID)
        orders = try container.decodeIfPresent([String].self, forKey: .orders) ?? []
    }
}

public struct ModifierGroup: Codable, Sendable, Equatable {
    public let group: String
    public let description: String
    public let modifiers: [ModifierOption]
}

public struct ModifierOption: Codable, Sendable, Equatable {
    public let key: String
    public let description: String
}
