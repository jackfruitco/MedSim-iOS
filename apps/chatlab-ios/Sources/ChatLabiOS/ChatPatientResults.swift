import Foundation
import SharedModels

public struct ChatPatientResult: Codable, Equatable, Sendable {
    public let rawRow: [String: JSONValue]

    init(rawRow: [String: JSONValue]) {
        self.rawRow = rawRow
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawRow = try container.decode([String: JSONValue].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawRow)
    }

    public var id: JSONValue? {
        rawRow["id"]
    }

    public var resultName: String? {
        rawRow.stringValue(forKey: "result_name")
    }

    public var panelName: String? {
        rawRow.nonEmptyString(forKey: "panel_name")
    }

    public var value: JSONValue? {
        rawRow["value"]
    }

    public var unit: String? {
        rawRow.nonEmptyString(forKey: "unit")
    }

    public var referenceRangeLow: JSONValue? {
        rawRow["reference_range_low"]
    }

    public var referenceRangeHigh: JSONValue? {
        rawRow["reference_range_high"]
    }

    public var flag: String? {
        rawRow.nonEmptyString(forKey: "flag")
    }

    public var attribute: String? {
        rawRow.nonEmptyString(forKey: "attribute")
    }

    public var type: String? {
        rawRow.nonEmptyString(forKey: "type")
    }

    var displayName: String {
        let trimmed = resultName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Result" : trimmed
    }

    var stableIdentifier: String {
        if let id {
            return ChatToolValueFormatter.render(id)
        }

        let panel = panelName ?? "standalone"
        return "\(panel)|\(displayName)|\(rawRow.count)"
    }
}

struct ChatPatientResultSection: Equatable {
    let panelName: String?
    var rows: [ChatPatientResult]
}

enum ChatPatientResultsPresentation {
    static func sections(from results: [ChatPatientResult]) -> [ChatPatientResultSection] {
        var sections: [ChatPatientResultSection] = []
        var panelIndexByName: [String: Int] = [:]

        for result in results {
            if let panelName = result.panelName {
                if let index = panelIndexByName[panelName] {
                    sections[index].rows.append(result)
                } else {
                    panelIndexByName[panelName] = sections.count
                    sections.append(ChatPatientResultSection(panelName: panelName, rows: [result]))
                }
            } else {
                sections.append(ChatPatientResultSection(panelName: nil, rows: [result]))
            }
        }

        return sections
    }
}

extension ChatToolState {
    var patientResults: [ChatPatientResult] {
        data.map(ChatPatientResult.init(rawRow:))
    }
}

private extension [String: JSONValue] {
    func stringValue(forKey key: String) -> String? {
        guard case let .string(text) = self[key] else {
            return nil
        }
        return text
    }

    func nonEmptyString(forKey key: String) -> String? {
        guard let text = stringValue(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            return nil
        }
        return text
    }
}
