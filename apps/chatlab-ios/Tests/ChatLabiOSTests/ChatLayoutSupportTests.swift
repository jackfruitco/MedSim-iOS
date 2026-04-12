@testable import ChatLabiOS
import SharedModels
import SwiftUI
import XCTest

final class ChatLayoutSupportTests: XCTestCase {
    func testSurfaceModeUsesPadForRegularOrWideLayout() {
        XCTAssertEqual(ChatLabSurfaceMode.resolve(width: 900, horizontalSizeClass: .compact), .pad)
        XCTAssertEqual(ChatLabSurfaceMode.resolve(width: 768, horizontalSizeClass: .regular), .pad)
    }

    func testSurfaceModeDistinguishesNarrowAndPhone() {
        XCTAssertEqual(ChatLabSurfaceMode.resolve(width: 375, horizontalSizeClass: .compact), .narrowPhone)
        XCTAssertEqual(ChatLabSurfaceMode.resolve(width: 430, horizontalSizeClass: .compact), .phone)
    }

    func testRunLayoutModeUsesThreeTiers() {
        XCTAssertEqual(ChatRunLayoutMode.resolve(width: 390, horizontalSizeClass: .compact), .compactMessenger)
        XCTAssertEqual(ChatRunLayoutMode.resolve(width: 480, horizontalSizeClass: .compact), .widePhoneMessenger)
        XCTAssertEqual(ChatRunLayoutMode.resolve(width: 900, horizontalSizeClass: .compact), .padWorkspace)
    }

    func testToolSectionDefaultsMatchLayoutMode() {
        // requestLabs is the only section expanded by default on compact phone
        XCTAssertTrue(ChatToolsSection.requestLabs.defaultExpanded(for: .compactMessenger))
        XCTAssertFalse(ChatToolsSection.patientHistory.defaultExpanded(for: .compactMessenger))
        // Activity is intentionally never expanded by default (it's debug/staff info)
        XCTAssertFalse(ChatToolsSection.activity.defaultExpanded(for: .widePhoneMessenger))
        XCTAssertFalse(ChatToolsSection.activity.defaultExpanded(for: .padWorkspace))
        XCTAssertTrue(ChatToolsSection.patientResults.defaultExpanded(for: .widePhoneMessenger))
        XCTAssertTrue(ChatToolsSection.simulationMetadata.defaultExpanded(for: .padWorkspace))
    }

    func testChromeModeCollapsesWhenKeyboardIsPresented() {
        XCTAssertEqual(ChatRunChromeMode.resolve(isKeyboardPresented: true), .keyboardCollapsed)
        XCTAssertEqual(ChatRunChromeMode.resolve(isKeyboardPresented: false), .standard)
    }

    func testBubbleFooterPrefersInlineOnlyWhenMetadataFits() {
        XCTAssertTrue(
            ChatBubbleFooterLayout.prefersInline(
                in: .init(
                    content: "Short reply",
                    metadataText: "9:41 AM Delivered",
                    bubbleWidth: 320,
                    hasMedia: false,
                    hasError: false,
                    hasRetryAction: false,
                ),
            ),
        )

        XCTAssertFalse(
            ChatBubbleFooterLayout.prefersInline(
                in: .init(
                    content: String(repeating: "A", count: 90),
                    metadataText: "9:41 AM Delivered",
                    bubbleWidth: 220,
                    hasMedia: false,
                    hasError: false,
                    hasRetryAction: false,
                ),
            ),
        )
        XCTAssertFalse(
            ChatBubbleFooterLayout.prefersInline(
                in: .init(
                    content: "Short reply",
                    metadataText: "9:41 AM Failed",
                    bubbleWidth: 320,
                    hasMedia: false,
                    hasError: false,
                    hasRetryAction: true,
                ),
            ),
        )
    }

    func testFeedbackPresentationUsesFriendlyLabels() {
        let fields = ChatFeedbackPresentation.fields(from: [
            "hotwash_overall_feedback": .string("Strong prioritization."),
            "areas_for_improvement": .array([.string("Clarify handoff"), .string("Reassess sooner")]),
        ])

        XCTAssertEqual(fields.first?.label, "Overall Feedback")
        if case let .text(value) = fields.first?.kind {
            XCTAssertEqual(value, "Strong prioritization.")
        } else {
            XCTFail("Expected .text kind for overall feedback")
        }
        XCTAssertEqual(fields.last?.label, "Areas for Improvement")
        if case let .text(value) = fields.last?.kind {
            XCTAssertEqual(value, "Clarify handoff, Reassess sooner")
        } else {
            XCTFail("Expected .text kind for areas for improvement")
        }
    }

    func testPatientHistoryLabelPrettificationUsesGenericNormalization() {
        XCTAssertEqual(ChatPatientHistoryPresentation.displayLabel(for: "symptom_onset"), "Symptom onset")
        XCTAssertEqual(ChatPatientHistoryPresentation.displayLabel(for: "urinary_frequency_now"), "Urinary frequency")
        XCTAssertEqual(ChatPatientHistoryPresentation.displayLabel(for: "pain_location"), "Pain location")
        XCTAssertEqual(ChatPatientHistoryPresentation.displayLabel(for: "chief_complaint_current"), "Chief complaint")
    }

    func testPatientHistoryItemRemovesHistoryPrefixAndAvoidsDuplicatedTiming() {
        let item = ChatPatientHistoryPresentation.item(from: [
            "summary": .string("History of symptom_onset (ongoing, since morning)"),
            "value": .string(" since around breakfast (same day) "),
        ])

        XCTAssertEqual(item?.displayLabel, "Symptom onset")
        XCTAssertNil(item?.displayQualifier)
        XCTAssertEqual(item?.displayText, "since around breakfast")
        XCTAssertFalse(item?.titleText?.contains("History of") ?? false)
    }

    func testPatientHistoryMetadataNormalizationAvoidsMachineishTimingText() {
        let item = ChatPatientHistoryPresentation.item(from: [
            "summary": .string("History of urinary_frequency_now (on going, for since morning)"),
        ])

        XCTAssertEqual(item?.displayLabel, "Urinary frequency")
        XCTAssertNil(item?.displayQualifier)
        XCTAssertEqual(item?.displayText, "ongoing since this morning")
        XCTAssertFalse(item?.displayText.contains("for since") ?? false)
        XCTAssertFalse(item?.displayText.contains("on going") ?? false)
    }

    func testPatientHistoryRendersLabelAndNarrativeWhenOnlyStructuredFieldsExist() {
        let item = ChatPatientHistoryPresentation.item(from: [
            "key": .string("pain_location"),
            "value": .string("lower abdomen"),
        ])

        XCTAssertEqual(item?.displayLabel, "Pain location")
        XCTAssertEqual(item?.displayText, "lower abdomen")
    }

    func testPatientHistoryFallsBackGracefullyWhenLabelIsMissing() {
        let item = ChatPatientHistoryPresentation.item(from: [
            "value": .string("needing to pee more often with lower belly discomfort"),
        ])

        XCTAssertNil(item?.displayLabel)
        XCTAssertEqual(item?.displayText, "needing to pee more often with lower belly discomfort")
    }
}
