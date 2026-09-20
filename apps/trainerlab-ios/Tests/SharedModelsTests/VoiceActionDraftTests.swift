import Foundation
@testable import SharedModels
import XCTest

final class VoiceActionDraftTests: XCTestCase {
    private let dictionary = [
        InterventionGroup(interventionType: "tourniquet", label: "Tourniquet", sites: []),
        InterventionGroup(interventionType: "oxygen", label: "Oxygen", sites: []),
    ]

    func testNegationPlansAndAmbiguityDoNotProduceSuggestions() {
        for text in [
            "No tourniquet applied", "They did not give oxygen", "They didn't apply tourniquet",
            "Will apply tourniquet", "Planning oxygen", "Maybe oxygen", "Oxygen?",
            "Preparing tourniquet", "Consider oxygen", "Without oxygen",
        ] {
            let draft = VoiceActionDraft(transcript: text)
            XCTAssertTrue(draft.needsClarification, text)
            XCTAssertTrue(draft.candidates(in: dictionary).isEmpty, text)
        }
    }

    func testCandidatesAreDeduplicatedAndNeverInferStructuredDetails() {
        let draft = VoiceActionDraft(transcript: "Tourniquet applied, tourniquet tightened and oxygen given")
        XCTAssertEqual(draft.candidates(in: dictionary).map(\.interventionType), ["tourniquet", "oxygen"])
        XCTAssertTrue(VoiceActionDraft(transcript: "Unknown action").candidates(in: dictionary).isEmpty)
    }

    func testCorrectionPreservesOriginalAndStableCaptureIdentity() throws {
        var draft = VoiceActionDraft(transcript: "No tourniquet applied", captureID: "capture-123")
        draft.reviewedTranscript = "Tourniquet applied"
        XCTAssertEqual(draft.originalTranscript, "No tourniquet applied")
        XCTAssertEqual(draft.captureID, "capture-123")
        XCTAssertFalse(draft.needsClarification)
        let request = InterventionEventRequest(
            interventionType: "tourniquet", clientEventID: draft.captureID, siteCode: "left_arm",
            targetProblemID: 4, voiceProvenance: draft.confirmedProvenance,
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(InterventionEventRequest.self, from: data)
        XCTAssertEqual(decoded.voiceProvenance, draft.confirmedProvenance)
        XCTAssertEqual(decoded.clientEventID, "capture-123")
        XCTAssertEqual(decoded.effectiveness, .unknown)
    }

    func testBlankOrOversizedDraftCannotBeReviewed() {
        XCTAssertFalse(VoiceActionDraft(transcript: "  ").canReview)
        XCTAssertFalse(VoiceActionDraft(transcript: String(repeating: "a", count: 2001)).canReview)
        var draft = VoiceActionDraft(transcript: "Oxygen given")
        draft.reviewedTranscript = ""
        XCTAssertFalse(draft.canReview)
    }
}
