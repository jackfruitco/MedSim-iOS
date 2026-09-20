import Foundation

/// A capture is a proposal until the instructor confirms a structured action.
public struct VoiceActionDraft: Equatable, Sendable {
    public let captureID: String
    public let originalTranscript: String
    public var reviewedTranscript: String

    public init(transcript: String, captureID: String = UUID().uuidString.lowercased()) {
        self.captureID = captureID
        originalTranscript = transcript
        reviewedTranscript = transcript
    }

    public var needsClarification: Bool {
        let words = Set(reviewedTranscript.lowercased().components(separatedBy: .alphanumerics.inverted))
        return !words.isDisjoint(with: [
            "no", "not", "never", "didn", "didn't", "hasn", "without", "don", "don't",
            "will", "would", "should", "could", "might", "plan", "planning", "going",
            "maybe", "unsure", "if", "consider", "considering", "prepare", "preparing",
        ]) || reviewedTranscript.contains("?")
    }

    /// Conservative vocabulary matching, not clinical interpretation. Never infer site,
    /// dose, completion, effectiveness, or a target from speech.
    public func candidates(in dictionary: [InterventionGroup]) -> [InterventionGroup] {
        guard !needsClarification else { return [] }
        let text = " " + Self.normalized(reviewedTranscript) + " "
        return dictionary.filter { group in
            [group.label, group.interventionType.replacingOccurrences(of: "_", with: " ")]
                .contains { text.contains(" " + Self.normalized($0) + " ") }
        }
    }

    public var canReview: Bool {
        !originalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !reviewedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && originalTranscript.count <= 2000 && reviewedTranscript.count <= 2000
    }

    public var confirmedProvenance: VoiceActionProvenance {
        VoiceActionProvenance(
            captureID: captureID,
            originalTranscript: originalTranscript,
            reviewedTranscript: reviewedTranscript,
        )
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}

public struct VoiceActionProvenance: Codable, Equatable, Sendable {
    public let captureID: String
    public let originalTranscript: String
    public let reviewedTranscript: String
    public let source: String
    public let confirmed: Bool

    public init(captureID: String, originalTranscript: String, reviewedTranscript: String) {
        self.captureID = captureID
        self.originalTranscript = originalTranscript
        self.reviewedTranscript = reviewedTranscript
        source = "push_to_talk"
        confirmed = true
    }

    enum CodingKeys: String, CodingKey {
        case captureID = "capture_id"
        case originalTranscript = "original_transcript"
        case reviewedTranscript = "reviewed_transcript"
        case source, confirmed
    }
}
