import Foundation

public struct DebriefClaim: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let text: String
    public let evidenceIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id, category, text
        case evidenceIDs = "evidence_ids"
    }
}

public struct DebriefEvidence: Codable, Identifiable, Sendable {
    public let id: String
    public let kind: String
    public let eventType: String
    public let createdAt: String
    public let facts: [String: JSONValue]

    public var detail: String {
        facts.keys.sorted().compactMap { key in
            guard !key.hasSuffix("_id"), key != "domain_event_type" else { return nil }
            guard let value = facts[key] else { return nil }
            let text: String
            switch value {
            case let .string(string): text = string
            case let .number(number): text = number.formatted()
            case let .bool(flag): text = flag ? "Yes" : "No"
            default: return nil
            }
            return "\(key.replacingOccurrences(of: "_", with: " ").capitalized): \(text)"
        }.joined(separator: "\n")
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, facts
        case eventType = "event_type"
        case createdAt = "created_at"
    }
}

public struct DebriefReviewRequest: Codable, Sendable {
    public let evidenceRevision: String
    public let correction: String?
    public let claimID: String?

    public init(evidenceRevision: String, correction: String? = nil, claimID: String? = nil) {
        self.evidenceRevision = evidenceRevision
        self.correction = correction
        self.claimID = claimID
    }

    enum CodingKeys: String, CodingKey {
        case evidenceRevision = "evidence_revision"
        case correction
        case claimID = "claim_id"
    }
}
