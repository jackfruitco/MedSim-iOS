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
            "Feedback"
        case .simulationMetadata:
            "Simulation Metadata"
        case .requestLabs:
            "Request Labs"
        }
    }

    func defaultExpanded(for mode: ChatRunLayoutMode) -> Bool {
        switch mode {
        case .padWorkspace:
            self != .activity
        case .widePhoneMessenger:
            self == .patientResults || self == .requestLabs
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

struct ChatPatientHistoryItem: Equatable {
    let displayLabel: String?
    let displayQualifier: String?
    let displayText: String

    var titleText: String? {
        switch (displayLabel, displayQualifier) {
        case let (label?, qualifier?) where !qualifier.isEmpty:
            "\(label) — \(qualifier)"
        case let (label?, _):
            label
        default:
            nil
        }
    }
}

enum ChatPatientHistoryPresentation {
    private static let noisyTrailingLabelTokens: Set<String> = [
        "now",
        "current",
    ]

    static func item(from row: [String: JSONValue]) -> ChatPatientHistoryItem? {
        let summary = firstRenderedString(in: row, keys: ["summary"])
        let parsedSummary = parseSummary(summary)

        let explicitLabel = normalizedLabelCandidate(firstRenderedString(in: row, keys: ["label", "display_label", "title"]))
        let rawKey = firstRenderedString(in: row, keys: ["key", "field", "attribute"]) ?? parsedSummary.key
        let label = explicitLabel ?? rawKey.flatMap(displayLabel(for:)) ?? normalizedLabelCandidate(parsedSummary.label)

        let qualifierInfo = normalizeQualifier(
            firstRenderedString(in: row, keys: ["qualifier", "status", "timing", "timeframe", "duration", "when"])
                ?? parsedSummary.qualifier,
        )

        let narrative = sanitizeNarrative(
            firstRenderedString(in: row, keys: ["value", "text", "narrative", "details", "description", "answer"])
                ?? parsedSummary.narrative,
        )

        let displayQualifier = shouldDisplayQualifier(qualifierInfo, alongside: narrative) ? qualifierInfo.text : nil
        let displayText = if let narrative, !narrative.isEmpty {
            narrative
        } else if let qualifier = qualifierInfo.text, !qualifier.isEmpty {
            qualifier
        } else {
            ""
        }

        guard label != nil || !displayText.isEmpty else {
            return nil
        }

        return ChatPatientHistoryItem(
            displayLabel: label,
            displayQualifier: displayQualifier,
            displayText: displayText,
        )
    }

    static func displayLabel(for rawKey: String) -> String? {
        let cleanedKey = rawKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !cleanedKey.isEmpty else {
            return nil
        }

        let normalizedKey = stripNoisySuffixes(from: cleanedKey)
        let tokens = normalizedKey
            .split(separator: "_")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else {
            return nil
        }

        return tokens.enumerated()
            .map { index, token in
                formattedHistoryLabelToken(token, isFirst: index == 0)
            }
            .joined(separator: " ")
    }

    private struct ParsedSummary {
        var key: String?
        var label: String?
        var qualifier: String?
        var narrative: String?
    }

    private struct NormalizedQualifier {
        let text: String?
        let isPureTimingOrStatus: Bool
        let fullyRecognized: Bool
    }

    private static func firstRenderedString(in row: [String: JSONValue], keys: [String]) -> String? {
        for key in keys {
            guard let value = row[key] else {
                continue
            }

            let rendered = renderedString(from: value)
            if let rendered, !rendered.isEmpty {
                return rendered
            }
        }

        return nil
    }

    private static func renderedString(from value: JSONValue) -> String? {
        switch value {
        case .null:
            return nil
        default:
            let rendered = cleanInlineText(ChatToolValueFormatter.render(value))
            return rendered.isEmpty ? nil : rendered
        }
    }

    private static func parseSummary(_ summary: String?) -> ParsedSummary {
        guard let summary, !summary.isEmpty else {
            return ParsedSummary()
        }

        let nsSummary = summary as NSString
        let pattern = #"(?i)^history\s+of\s+([a-z0-9_]+)(?:\s*\(([^)]*)\))?\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: summary, range: NSRange(location: 0, length: nsSummary.length))
        {
            let key = match.range(at: 1).location != NSNotFound ? nsSummary.substring(with: match.range(at: 1)) : nil
            let qualifier = match.range(at: 2).location != NSNotFound ? nsSummary.substring(with: match.range(at: 2)) : nil
            return ParsedSummary(
                key: key,
                label: nil,
                qualifier: qualifier,
                narrative: nil,
            )
        }

        if summary.contains("_"), summary.contains(" ") == false {
            return ParsedSummary(key: summary, label: nil, qualifier: nil, narrative: nil)
        }

        if let range = summary.range(of: ":", options: .backwards) {
            let left = cleanInlineText(String(summary[..<range.lowerBound]))
            let right = cleanInlineText(String(summary[range.upperBound...]))
            if !left.isEmpty, !right.isEmpty, left.split(separator: " ").count <= 4 {
                return ParsedSummary(key: nil, label: left, qualifier: nil, narrative: right)
            }
        }

        if let range = summary.range(of: " — ") {
            let left = cleanInlineText(String(summary[..<range.lowerBound]))
            let right = cleanInlineText(String(summary[range.upperBound...]))
            if !left.isEmpty, !right.isEmpty, left.split(separator: " ").count <= 5 {
                return ParsedSummary(key: nil, label: left, qualifier: nil, narrative: right)
            }
        }

        if summary.split(separator: " ").count <= 4 {
            return ParsedSummary(key: nil, label: summary, qualifier: nil, narrative: nil)
        }

        return ParsedSummary(key: nil, label: nil, qualifier: nil, narrative: summary)
    }

    private static func sanitizeNarrative(_ text: String?) -> String? {
        guard var cleaned = text.map(cleanInlineText), !cleaned.isEmpty else {
            return nil
        }

        let pattern = #"\(([^()]*)\)\s*$"#
        let nsCleaned = cleaned as NSString
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: nsCleaned.length)),
           match.range(at: 1).location != NSNotFound
        {
            let metadata = nsCleaned.substring(with: match.range(at: 1))
            let qualifier = normalizeQualifier(metadata)
            if qualifier.fullyRecognized {
                let baseRange = NSRange(location: 0, length: match.range.location)
                cleaned = cleanInlineText(nsCleaned.substring(with: baseRange))
            }
        }

        return cleaned.isEmpty ? nil : cleaned
    }

    private static func normalizeQualifier(_ raw: String?) -> NormalizedQualifier {
        guard let raw, !raw.isEmpty else {
            return NormalizedQualifier(text: nil, isPureTimingOrStatus: true, fullyRecognized: true)
        }

        let normalized = cleanInlineText(raw)
            .lowercased()
            .replacingOccurrences(of: "on-going", with: "ongoing")
            .replacingOccurrences(of: "on going", with: "ongoing")
        let fragments = normalized
            .split(separator: ",")
            .map { cleanInlineText(String($0)) }
            .filter { !$0.isEmpty }

        var ongoing = false
        var timePhrase: String?
        var otherFragments: [String] = []
        var fullyRecognized = true
        var isPureTimingOrStatus = true

        for fragment in fragments {
            switch fragment {
            case "ongoing":
                ongoing = true
            case "same day", "same-day", "current", "now":
                continue
            default:
                if let normalizedTime = normalizeTimeFragment(fragment) {
                    timePhrase = normalizedTime
                    continue
                }

                fullyRecognized = false
                isPureTimingOrStatus = false
                if otherFragments.contains(fragment) == false {
                    otherFragments.append(fragment)
                }
            }
        }

        var components: [String] = []
        if ongoing {
            if let timePhrase {
                components.append("ongoing \(timePhrase)")
            } else {
                components.append("ongoing")
            }
        } else if let timePhrase {
            components.append(timePhrase)
        }
        for fragment in otherFragments where components.contains(fragment) == false {
            components.append(fragment)
        }

        let text = components.joined(separator: ", ")
        return NormalizedQualifier(
            text: text.isEmpty ? nil : text,
            isPureTimingOrStatus: isPureTimingOrStatus,
            fullyRecognized: fullyRecognized,
        )
    }

    private static func normalizeTimeFragment(_ fragment: String) -> String? {
        var cleaned = fragment
        if cleaned.hasPrefix("for since ") {
            cleaned = "since " + String(cleaned.dropFirst("for since ".count))
        }

        if cleaned.hasPrefix("ongoing since ") {
            let remainder = cleanInlineText(String(cleaned.dropFirst("ongoing since ".count)))
            return remainder.isEmpty ? "ongoing" : "ongoing since \(remainder)"
        }

        if cleaned.hasPrefix("since ") {
            let remainder = cleanInlineText(String(cleaned.dropFirst("since ".count)))
            switch remainder {
            case "morning":
                return "since this morning"
            case "afternoon":
                return "since this afternoon"
            case "evening":
                return "since this evening"
            case "night":
                return "since tonight"
            case "today":
                return "since today"
            default:
                return remainder.isEmpty ? nil : "since \(remainder)"
            }
        }

        if cleaned.hasPrefix("for ") {
            let remainder = cleanInlineText(String(cleaned.dropFirst("for ".count)))
            return remainder.isEmpty ? nil : "for \(remainder)"
        }

        return nil
    }

    private static func shouldDisplayQualifier(_ qualifier: NormalizedQualifier, alongside narrative: String?) -> Bool {
        guard let text = qualifier.text, !text.isEmpty else {
            return false
        }

        guard let narrative, !narrative.isEmpty else {
            return false
        }

        if qualifier.isPureTimingOrStatus {
            return false
        }

        return comparableText(narrative).contains(comparableText(text)) == false
    }

    private static func comparableText(_ text: String) -> String {
        cleanInlineText(text)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9 ]+"#, with: "", options: .regularExpression)
    }

    private static func stripNoisySuffixes(from key: String) -> String {
        var tokens = key
            .split(separator: "_")
            .map(String.init)
            .filter { !$0.isEmpty }

        while let lastToken = tokens.last, noisyTrailingLabelTokens.contains(lastToken) {
            tokens.removeLast()
        }

        return tokens.joined(separator: "_")
    }

    private static func formattedHistoryLabelToken(_ token: String, isFirst: Bool) -> String {
        switch token.lowercased() {
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
            let lowercased = token.lowercased()
            guard isFirst else {
                return lowercased
            }
            return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
        }
    }

    private static func normalizedLabelCandidate(_ rawLabel: String?) -> String? {
        guard let rawLabel else {
            return nil
        }

        let cleaned = cleanInlineText(rawLabel)
        guard !cleaned.isEmpty else {
            return nil
        }

        if cleaned.contains("_"), cleaned.contains(" ") == false {
            return displayLabel(for: cleaned)
        }

        return cleaned
    }

    private static func cleanInlineText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,.;:])"#, with: "$1", options: .regularExpression)
    }
}

enum ChatFeedbackKind: Equatable {
    case boolTrue // green checkmark.square.fill
    case boolFalse // red x.square.fill
    case partial // yellow exclamationmark.square.fill
    case text(String)
}

struct ChatFeedbackField: Equatable {
    let label: String
    let kind: ChatFeedbackKind
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

    /// Converts a raw feedback key to a human-readable label.
    /// Checks the static label map first; falls back to stripping the `hotwash_`
    /// prefix and converting snake_case to Title Case.
    static func humanizedLabel(for key: String) -> String {
        if let mapped = labelMap[key] {
            return mapped
        }
        var normalized = key
        if normalized.hasPrefix("hotwash_") {
            normalized = String(normalized.dropFirst("hotwash_".count))
        }
        return normalized
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    /// Classifies a JSONValue into a renderable kind.
    ///
    /// Boolish mapping is intentionally conservative:
    /// - Native JSON booleans (`JSONValue.bool`) are always boolish — this is the primary
    ///   mechanism the backend uses for true/false feedback fields.
    /// - String "yes" / "no" are accepted as the most universal natural-language equivalents.
    /// - String "partial" is accepted for partial-credit outcomes.
    ///
    /// Speculative synonyms ("correct", "pass", "incorrect", "fail") have been deliberately
    /// excluded because they are not verified as values the backend actually sends in feedback
    /// payloads. Any unknown string renders as plain text, which is safe and non-lossy.
    ///
    /// Backend dependency: verify whether additional string boolish values exist in the
    /// SimWorks feedback schema and extend this list only when confirmed.
    static func detectKind(from value: JSONValue) -> ChatFeedbackKind? {
        switch value {
        case let .bool(flag):
            return flag ? .boolTrue : .boolFalse
        case let .string(text):
            switch text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            case "yes":
                return .boolTrue
            case "no":
                return .boolFalse
            case "partial":
                return .partial
            default:
                return text.isEmpty ? nil : .text(text)
            }
        case let .number(n):
            let rendered = ChatToolValueFormatter.render(.number(n))
            return .text(rendered)
        case let .array(arr):
            let rendered = arr.map { ChatToolValueFormatter.render($0) }.joined(separator: ", ")
            return rendered.isEmpty ? nil : .text(rendered)
        case let .object(dict):
            let rendered = ChatToolValueFormatter.render(.object(dict))
            return rendered.isEmpty ? nil : .text(rendered)
        case .null:
            return nil
        }
    }

    static func fields(from row: [String: JSONValue]) -> [ChatFeedbackField] {
        orderedVisibleKeys(in: row)
            .filter { hiddenKeys.contains($0) == false }
            .compactMap { key in
                guard let value = row[key], let kind = detectKind(from: value) else {
                    return nil
                }
                return ChatFeedbackField(label: humanizedLabel(for: key), kind: kind)
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
