import Foundation
import SharedModels

public enum FeedbackCategory: String, Codable, CaseIterable, Sendable {
    case bugReport = "bug_report"
    case uxIssue = "ux_issue"
    case simulationContent = "simulation_content"
    case featureRequest = "feature_request"
    case other

    public var title: String {
        switch self {
        case .bugReport:
            "Bug Report"
        case .uxIssue:
            "UX Issue"
        case .simulationContent:
            "Simulation Content"
        case .featureRequest:
            "Feature Request"
        case .other:
            "Other"
        }
    }

    public var description: String {
        switch self {
        case .bugReport:
            "Something in the app is broken or behaving unexpectedly."
        case .uxIssue:
            "The experience is confusing, awkward, or hard to use."
        case .simulationContent:
            "The simulation scenario, realism, or content needs improvement."
        case .featureRequest:
            "There’s a capability you’d like to add."
        case .other:
            "General feedback that doesn’t fit the other categories."
        }
    }
}

public struct FeedbackCategoryDTO: Codable, Equatable, Sendable {
    public let value: FeedbackCategory
    public let label: String

    public init(value: FeedbackCategory, label: String? = nil) {
        self.value = value
        self.label = label ?? value.title
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case label
        case category
        case name
    }

    public init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let rawValue = try? singleValue.decode(String.self),
           let category = FeedbackCategory(rawValue: rawValue)
        {
            value = category
            label = category.title
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue =
            try container.decodeIfPresent(String.self, forKey: .value)
                ?? container.decodeIfPresent(String.self, forKey: .category)
                ?? ""
        guard let category = FeedbackCategory(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                forKey: .value,
                in: container,
                debugDescription: "Unsupported feedback category: \(rawValue)",
            )
        }
        value = category
        label =
            try container.decodeIfPresent(String.self, forKey: .label)
                ?? container.decodeIfPresent(String.self, forKey: .name)
                ?? category.title
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(label, forKey: .label)
    }
}

public struct FeedbackCreateRequest: Codable, Equatable, Sendable {
    public let category: FeedbackCategory
    public let title: String?
    public let body: String
    public let simulationID: Int?
    public let conversationID: Int?
    public let rating: Int?
    public let allowFollowUp: Bool?
    public let context: [String: JSONValue]?

    public init(
        category: FeedbackCategory,
        title: String? = nil,
        body: String,
        simulationID: Int? = nil,
        conversationID: Int? = nil,
        rating: Int? = nil,
        allowFollowUp: Bool? = nil,
        context: [String: JSONValue]? = nil,
    ) {
        self.category = category
        self.title = title
        self.body = body
        self.simulationID = simulationID
        self.conversationID = conversationID
        self.rating = rating
        self.allowFollowUp = allowFollowUp
        self.context = context
    }

    enum CodingKeys: String, CodingKey {
        case category
        case title
        case body
        case simulationID = "simulation_id"
        case conversationID = "conversation_id"
        case rating
        case allowFollowUp = "allow_follow_up"
        case context
    }
}

public struct FeedbackResponse: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let category: FeedbackCategory
    public let title: String?
    public let body: String
    public let simulationID: Int?
    public let conversationID: Int?
    public let rating: Int?
    public let allowFollowUp: Bool?
    public let context: [String: JSONValue]?
    public let createdAt: Date?

    public init(
        id: Int,
        category: FeedbackCategory,
        title: String?,
        body: String,
        simulationID: Int?,
        conversationID: Int?,
        rating: Int?,
        allowFollowUp: Bool?,
        context: [String: JSONValue]?,
        createdAt: Date?,
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.body = body
        self.simulationID = simulationID
        self.conversationID = conversationID
        self.rating = rating
        self.allowFollowUp = allowFollowUp
        self.context = context
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case title
        case body
        case simulationID = "simulation_id"
        case conversationID = "conversation_id"
        case rating
        case allowFollowUp = "allow_follow_up"
        case context
        case createdAt = "created_at"
    }
}
