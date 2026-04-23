import Foundation

public struct TrainerLabHubEvent: Decodable, Equatable, Identifiable, Sendable {
    public let eventID: String
    public let eventType: String?
    public let createdAt: Date?
    public let simulationID: Int
    public let status: TrainerSessionStatus?
    public let from: TrainerSessionStatus?
    public let to: TrainerSessionStatus?
    public let updatedAt: Date?
    public let retryable: Bool?
    public let terminalReasonCode: String?
    public let terminalReasonText: String?
    public let patientName: String?
    public let chiefComplaint: String?
    public let diagnosis: String?
    public let labSlug: String?
    public let stateRevision: Int?

    public var id: String {
        eventID
    }

    public init(
        eventID: String,
        eventType: String? = nil,
        createdAt: Date? = nil,
        simulationID: Int,
        status: TrainerSessionStatus? = nil,
        from: TrainerSessionStatus? = nil,
        to: TrainerSessionStatus? = nil,
        updatedAt: Date? = nil,
        retryable: Bool? = nil,
        terminalReasonCode: String? = nil,
        terminalReasonText: String? = nil,
        patientName: String? = nil,
        chiefComplaint: String? = nil,
        diagnosis: String? = nil,
        labSlug: String? = nil,
        stateRevision: Int? = nil,
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.createdAt = createdAt
        self.simulationID = simulationID
        self.status = status
        self.from = from
        self.to = to
        self.updatedAt = updatedAt
        self.retryable = retryable
        self.terminalReasonCode = terminalReasonCode
        self.terminalReasonText = terminalReasonText
        self.patientName = patientName
        self.chiefComplaint = chiefComplaint
        self.diagnosis = diagnosis
        self.labSlug = labSlug
        self.stateRevision = stateRevision
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let payload = try container.decodeIfPresent([String: JSONValue].self, forKey: "payload")

        guard let eventID = Self.stringValue(
            keys: ["event_id", "eventID", "cursor", "id"],
            container: container,
            payload: payload,
        ) else {
            throw DecodingError.keyNotFound(
                DynamicCodingKey("event_id"),
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing hub event cursor"),
            )
        }

        guard let simulationID = Self.intValue(
            keys: ["simulation_id", "simulationID", "session_id", "sessionID"],
            container: container,
            payload: payload,
        ) else {
            throw DecodingError.keyNotFound(
                DynamicCodingKey("simulation_id"),
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing hub event simulation ID"),
            )
        }

        self.eventID = eventID
        eventType = Self.stringValue(keys: ["event_type", "eventType", "type"], container: container, payload: payload)
        createdAt = Self.dateValue(keys: ["created_at", "createdAt"], container: container, payload: payload)
        self.simulationID = simulationID
        status = Self.statusValue(keys: ["status", "phase"], container: container, payload: payload)
        from = Self.statusValue(keys: ["from", "from_status", "fromStatus"], container: container, payload: payload)
        to = Self.statusValue(keys: ["to", "to_status", "toStatus"], container: container, payload: payload)
        updatedAt = Self.dateValue(
            keys: ["updated_at", "updatedAt", "modified_at", "modifiedAt", "created_at", "createdAt"],
            container: container,
            payload: payload,
        )
        retryable = Self.boolValue(keys: ["retryable"], container: container, payload: payload)
        terminalReasonCode = Self.stringValue(
            keys: ["terminal_reason_code", "terminalReasonCode", "reason_code", "reasonCode"],
            container: container,
            payload: payload,
        )
        terminalReasonText = Self.stringValue(
            keys: ["terminal_reason_text", "terminalReasonText", "reason_text", "reasonText"],
            container: container,
            payload: payload,
        )
        patientName = Self.stringValue(keys: ["patient_name", "patientName"], container: container, payload: payload)
        chiefComplaint = Self.stringValue(keys: ["chief_complaint", "chiefComplaint"], container: container, payload: payload)
        diagnosis = Self.stringValue(keys: ["diagnosis"], container: container, payload: payload)
        labSlug = Self.stringValue(keys: ["lab_slug", "labSlug"], container: container, payload: payload)
        stateRevision = Self.intValue(keys: ["state_revision", "stateRevision"], container: container, payload: payload)
    }

    public var effectiveStatus: TrainerSessionStatus? {
        to ?? status ?? from
    }

    private static func statusValue(
        keys: [String],
        container: KeyedDecodingContainer<DynamicCodingKey>,
        payload: [String: JSONValue]?,
    ) -> TrainerSessionStatus? {
        guard let value = stringValue(keys: keys, container: container, payload: payload)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !value.isEmpty
        else {
            return nil
        }
        return TrainerSessionStatus(rawValue: value)
    }

    private static func stringValue(
        keys: [String],
        container: KeyedDecodingContainer<DynamicCodingKey>,
        payload: [String: JSONValue]?,
    ) -> String? {
        for key in keys {
            if let value = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKey(key)) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
            if case let .string(value)? = payload?[key] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func intValue(
        keys: [String],
        container: KeyedDecodingContainer<DynamicCodingKey>,
        payload: [String: JSONValue]?,
    ) -> Int? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try? container.decodeIfPresent(Int.self, forKey: codingKey) {
                return value
            }
            if let value = try? container.decodeIfPresent(Double.self, forKey: codingKey) {
                return Int(value)
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: codingKey), let int = Int(value) {
                return int
            }
            switch payload?[key] {
            case let .number(value):
                return Int(value)
            case let .string(value):
                if let int = Int(value) {
                    return int
                }
            default:
                continue
            }
        }
        return nil
    }

    private static func boolValue(
        keys: [String],
        container: KeyedDecodingContainer<DynamicCodingKey>,
        payload: [String: JSONValue]?,
    ) -> Bool? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try? container.decodeIfPresent(Bool.self, forKey: codingKey) {
                return value
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: codingKey) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "1", "yes":
                    return true
                case "false", "0", "no":
                    return false
                default:
                    break
                }
            }
            switch payload?[key] {
            case let .bool(value):
                return value
            case let .string(value):
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "1", "yes":
                    return true
                case "false", "0", "no":
                    return false
                default:
                    break
                }
            default:
                continue
            }
        }
        return nil
    }

    private static func dateValue(
        keys: [String],
        container: KeyedDecodingContainer<DynamicCodingKey>,
        payload: [String: JSONValue]?,
    ) -> Date? {
        for key in keys {
            let codingKey = DynamicCodingKey(key)
            if let value = try? container.decodeIfPresent(Date.self, forKey: codingKey) {
                return value
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: codingKey),
               let date = parseISO8601(value)
            {
                return date
            }
            if case let .string(value)? = payload?[key], let date = parseISO8601(value) {
                return date
            }
        }
        return nil
    }

    private nonisolated static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where K == DynamicCodingKey {
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        try decodeIfPresent(type, forKey: DynamicCodingKey(key))
    }
}
