import Foundation
import SharedModels

struct ChatPatientResult: Codable, Equatable, Sendable {
    let rawRow: [String: JSONValue]

    init(rawRow: [String: JSONValue]) {
        self.rawRow = rawRow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawRow = try container.decode([String: JSONValue].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawRow)
    }

    var id: JSONValue? { rawRow["id"] }
    var resultName: String? { rawRow.stringValue(forKey: "result_name") }
    var panelName: String? { rawRow.nonEmptyString(forKey: "panel_name") }
    var value: JSONValue? { rawRow["value"] }
    var unit: String? { rawRow.nonEmptyString(forKey: "unit") }
    var referenceRangeLow: JSONValue? { rawRow["reference_range_low"] }
    var referenceRangeHigh: JSONValue? { rawRow["reference_range_high"] }
    var flag: String? { rawRow.nonEmptyString(forKey: "flag") }
    var attribute: String? { rawRow.nonEmptyString(forKey: "attribute") }
    var type: String? { rawRow.nonEmptyString(forKey: "type") }

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

struct ChatPatientResultSection: Equatable, Sendable {
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

private extension Dictionary where Key == String, Value == JSONValue {
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
