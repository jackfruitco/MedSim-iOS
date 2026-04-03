#if canImport(Foundation)
    import Foundation
#endif
#if canImport(UIKit)
    import UIKit
#endif
import SharedModels
import SwiftUI

enum ChatLabTheme {
    #if canImport(UIKit)
        static let systemBackground = Color(uiColor: .systemBackground)
    #else
        static let systemBackground = Color.white
    #endif
}

enum ChatLabSurfaceMode: Equatable {
    case narrowPhone
    case phone
    case pad

    static func resolve(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Self {
        if horizontalSizeClass == .regular || width >= 820 {
            return .pad
        }
        if width <= 390 {
            return .narrowPhone
        }
        return .phone
    }
}

enum ChatRunLayoutMode: Equatable {
    case compactMessenger
    case widePhoneMessenger
    case padWorkspace

    static func resolve(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Self {
        if horizontalSizeClass == .regular || width >= 820 {
            return .padWorkspace
        }
        if width <= 430 {
            return .compactMessenger
        }
        return .widePhoneMessenger
    }
}

enum ChatRunChromeMode: Equatable {
    case standard
    case keyboardCollapsed

    static func resolve(isKeyboardPresented: Bool) -> Self {
        isKeyboardPresented ? .keyboardCollapsed : .standard
    }
}

enum ChatToolsSection: String, CaseIterable {
    case activity
    case patientHistory
    case patientResults
    case simulationFeedback
    case simulationMetadata
    case requestLabs

    var title: String {
        switch self {
        case .activity:
            "Activity"
        case .patientHistory:
            "Patient History"
        case .patientResults:
            "Patient Results"
        case .simulationFeedback:
            "Simulation Feedback"
        case .simulationMetadata:
            "Simulation Metadata"
        case .requestLabs:
            "Request Labs"
        }
    }

    func defaultExpanded(for mode: ChatRunLayoutMode) -> Bool {
        switch mode {
        case .padWorkspace:
            true
        case .widePhoneMessenger:
            self == .activity || self == .patientResults || self == .requestLabs
        case .compactMessenger:
            self == .requestLabs
        }
    }
}

enum ChatBubbleFooterLayout {
    struct Context {
        let content: String
        let metadataText: String
        let bubbleWidth: CGFloat
        let hasMedia: Bool
        let hasError: Bool
        let hasRetryAction: Bool
    }

    static func prefersInline(in context: Context) -> Bool {
        guard context.hasMedia == false, context.hasError == false, context.hasRetryAction == false else {
            return false
        }

        let trimmedContent = context.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMetadata = context.metadataText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty, !trimmedMetadata.isEmpty else {
            return false
        }

        let horizontalInsets: CGFloat = 24
        let usableWidth = max(context.bubbleWidth - horizontalInsets, 160)
        let approximateCharacterWidth: CGFloat = 7.2
        let lineCapacity = max(Int(usableWidth / approximateCharacterWidth), 12)
        let metadataLength = trimmedMetadata.count + 2

        let finalParagraph = trimmedContent
            .split(separator: "\n", omittingEmptySubsequences: false)
            .last
            .map(String.init) ?? trimmedContent
        let lastLineLength = renderedLastLineLength(for: finalParagraph, lineCapacity: lineCapacity)

        return lastLineLength + metadataLength <= lineCapacity
    }

    private static func renderedLastLineLength(for text: String, lineCapacity: Int) -> Int {
        guard text.count > lineCapacity else {
            return text.count
        }

        let wrappedLineLength = text.count % lineCapacity
        return wrappedLineLength == 0 ? lineCapacity : wrappedLineLength
    }
}

enum ChatToolValueFormatter {
    static func render(_ value: JSONValue) -> String {
        switch value {
        case let .string(text):
            return text
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case let .bool(flag):
            return flag ? "Yes" : "No"
        case let .array(values):
            return values.map(render).joined(separator: ", ")
        case let .object(dict):
            return dict
                .sorted { $0.key < $1.key }
                .map { "\(friendlyLabel(for: $0.key)): \(render($0.value))" }
                .joined(separator: "\n")
        case .null:
            return "-"
        }
    }

    static func friendlyLabel(for key: String) -> String {
        let normalized = key.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return "Unknown"
        }

        return normalized
            .split(separator: " ")
            .map { token in
                let lowercased = token.lowercased()
                switch lowercased {
                case "ai":
                    return "AI"
                case "id":
                    return "ID"
                case "hr":
                    return "HR"
                case "bp":
                    return "BP"
                case "rr":
                    return "RR"
                case "spo2":
                    return "SpO2"
                default:
                    return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
                }
            }
            .joined(separator: " ")
    }
}

struct ChatFeedbackField: Equatable {
    let label: String
    let value: String
}

enum ChatFeedbackPresentation {
    private static let labelMap: [String: String] = [
        "hotwash_overall_feedback": "Overall Feedback",
        "hotwash_summary": "Summary",
        "hotwash_what_went_well": "What Went Well",
        "hotwash_improvements": "Opportunities to Improve",
        "hotwash_next_steps": "Suggested Next Steps",
        "feedback_summary": "Feedback Summary",
        "overall_feedback": "Overall Feedback",
        "overall_score": "Overall Score",
        "score": "Score",
        "strengths": "Strengths",
        "areas_for_improvement": "Areas for Improvement",
        "missed_actions": "Missed Actions",
        "critical_actions": "Critical Actions",
        "clinical_reasoning": "Clinical Reasoning",
    ]

    private static let hiddenKeys: Set<String> = ["db_pk", "id", "uuid", "created_at", "updated_at"]
    private static let preferredKeyOrder = [
        "hotwash_overall_feedback",
        "overall_feedback",
        "hotwash_summary",
        "feedback_summary",
        "overall_score",
        "score",
        "strengths",
        "hotwash_what_went_well",
        "areas_for_improvement",
        "hotwash_improvements",
        "critical_actions",
        "missed_actions",
        "clinical_reasoning",
        "hotwash_next_steps",
    ]

    static func fields(from row: [String: JSONValue]) -> [ChatFeedbackField] {
        orderedVisibleKeys(in: row)
            .filter { hiddenKeys.contains($0) == false }
            .compactMap { key in
                let rendered = ChatToolValueFormatter.render(row[key] ?? .null)
                guard rendered != "-", rendered.isEmpty == false else {
                    return nil
                }
                return ChatFeedbackField(
                    label: labelMap[key] ?? ChatToolValueFormatter.friendlyLabel(for: key),
                    value: rendered,
                )
            }
    }

    private static func orderedVisibleKeys(in row: [String: JSONValue]) -> [String] {
        let visibleKeys = row.keys.filter { hiddenKeys.contains($0) == false }
        let preferred = preferredKeyOrder.filter { visibleKeys.contains($0) }
        let remaining = visibleKeys
            .filter { preferred.contains($0) == false }
            .sorted()
        return preferred + remaining
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
