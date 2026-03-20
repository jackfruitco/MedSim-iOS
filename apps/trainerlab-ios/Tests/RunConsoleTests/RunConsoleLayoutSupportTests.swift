@testable import RunConsole
import SharedModels
import SwiftUI
import XCTest

final class RunConsoleLayoutSupportTests: XCTestCase {
    func testLayoutModeUsesRegularForWideNonCompactWidth() {
        let mode = RunConsoleLayoutMode.resolve(width: 1024, horizontalSizeClass: .regular)
        XCTAssertEqual(mode, .regular)
    }

    func testLayoutModeUsesCompactBelowWidthThreshold() {
        let mode = RunConsoleLayoutMode.resolve(width: 820, horizontalSizeClass: .regular)
        XCTAssertEqual(mode, .compact)
    }

    func testLayoutModeUsesCompactForCompactSizeClass() {
        let mode = RunConsoleLayoutMode.resolve(width: 1024, horizontalSizeClass: .compact)
        XCTAssertEqual(mode, .compact)
    }

    func testCompactDensityUsesNarrowPhoneAtOrBelow390Points() {
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 320, layoutMode: .compact),
            .narrowPhone
        )
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 390, layoutMode: .compact),
            .narrowPhone
        )
    }

    func testCompactDensityUsesStandardAbove390PointsOrOutsideCompactMode() {
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 393, layoutMode: .compact),
            .standard
        )
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 430, layoutMode: .compact),
            .standard
        )
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 375, layoutMode: .regular),
            .standard
        )
    }

    func testCompactMetricsTightenControlsAndVitalsForNarrowPhone() {
        let metrics = RunConsoleCompactMetrics.resolve(width: 375, layoutMode: .compact)

        XCTAssertEqual(metrics.controlColumnMinimum, 92)
        XCTAssertEqual(metrics.vitalsColumnMinimum, 92)
        XCTAssertEqual(metrics.compactControlColumnCount, 3)
        XCTAssertEqual(metrics.compactVitalsColumnCount, 3)
        XCTAssertEqual(metrics.cardPadding, 8)
        XCTAssertEqual(metrics.gridSpacing, 6)
        XCTAssertEqual(metrics.buttonMinHeight, 38)
        XCTAssertEqual(metrics.vitalCellPadding, 6)
        XCTAssertEqual(metrics.vitalValueVerticalPadding, 3)
    }

    func testCompactMetricsPreserveStandardCompactSpacingAboveNarrowPhoneThreshold() {
        let metrics = RunConsoleCompactMetrics.resolve(width: 430, layoutMode: .compact)

        XCTAssertEqual(metrics.controlColumnMinimum, 104)
        XCTAssertEqual(metrics.vitalsColumnMinimum, 104)
        XCTAssertEqual(metrics.compactControlColumnCount, 3)
        XCTAssertEqual(metrics.compactVitalsColumnCount, 3)
        XCTAssertEqual(metrics.cardPadding, 10)
        XCTAssertEqual(metrics.gridSpacing, 6)
        XCTAssertEqual(metrics.buttonMinHeight, 40)
        XCTAssertEqual(metrics.vitalCellPadding, 7)
        XCTAssertEqual(metrics.vitalValueVerticalPadding, 3)
    }

    func testCompactControlPresentationUsesPhoneMenusForSharedPhoneBreakpoints() {
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                width: 375,
                horizontalSizeClass: .compact
            ),
            .phoneMenus
        )
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                width: 430,
                horizontalSizeClass: .compact
            ),
            .phoneMenus
        )
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                width: 700,
                horizontalSizeClass: .regular
            ),
            .grid
        )
    }

    func testTimelinePresentationNormalizesInlineTitles() {
        let injuryEntry = ClinicalTimelineEntry(
            dedupeKey: "injury-1",
            kind: .injury,
            title: "Injury Change",
            message: "Left arm",
            createdAt: Date()
        )
        let lifecycleEntry = ClinicalTimelineEntry(
            dedupeKey: "run-1",
            kind: .lifecycle,
            title: "Run Started",
            message: "Run started",
            createdAt: Date()
        )
        let noteEntry = ClinicalTimelineEntry(
            dedupeKey: "note-1",
            kind: .note,
            title: "Anything",
            message: "Trainer note",
            createdAt: Date()
        )

        XCTAssertEqual(RunConsoleTimelinePresentation.chipText(for: .injury), "INJURY")
        XCTAssertEqual(RunConsoleTimelinePresentation.chipText(for: .loc), "LOC")
        XCTAssertEqual(RunConsoleTimelinePresentation.title(for: injuryEntry), "Change")
        XCTAssertEqual(RunConsoleTimelinePresentation.title(for: lifecycleEntry), "Run Started")
        XCTAssertEqual(RunConsoleTimelinePresentation.title(for: noteEntry), "Trainer Note")
    }

    func testControlCatalogSeparatesSessionAndQuickControls() {
        let sessionControls = RunConsoleControlsCatalog.sessionControls(lifecycleActions: [.pause, .stop])

        XCTAssertEqual(sessionControls.map(\.title), ["Exit", "Pause", "Stop", "Summary"])
        XCTAssertEqual(sessionControls.map(\.group), [.session, .session, .session, .session])
        XCTAssertEqual(
            RunConsoleControlsCatalog.quickControls.map(\.title),
            ["Intervention", "Event", "Annotation", "Steer", "Tick AI", "Tick Vitals"]
        )
        XCTAssertEqual(
            RunConsoleControlsCatalog.quickControls.map(\.systemImage),
            ["plus.app", "plus.app", "note.text.badge.plus", "wand.and.sparkles", "timer", "heart.text.square"]
        )
    }

    func testTimelineFiltersHideNotesFromRunConsole() {
        let causeEntry = ClinicalTimelineEntry(
            dedupeKey: "cause-1",
            kind: .cause,
            title: "Cause",
            message: "Left arm injury",
            createdAt: Date()
        )
        let noteEntry = ClinicalTimelineEntry(
            dedupeKey: "note-1",
            kind: .note,
            title: "Trainer Note",
            message: "Internal note",
            createdAt: Date()
        )
        let visibleEntries = RunConsoleTimelineFilter.visibleEntries(
            from: [causeEntry, noteEntry],
            matching: .all
        )

        XCTAssertFalse(RunConsoleTimelineFilter.allCases.contains(.kind(.note)))
        XCTAssertEqual(visibleEntries, [causeEntry])
    }

    func testLifecycleActionsMatchSessionStatus() {
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .seeded), [.start])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .running), [.pause, .stop])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .paused), [.resume, .stop])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .completed), [])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .failed), [])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: nil), [])
    }

    func testDebriefAnnotationOptionsUseBackendValuesAndHumanLabels() {
        XCTAssertEqual(
            DebriefAnnotationCatalog.learningObjectiveOptions,
            AnnotationLearningObjective.allCases.map {
                DebriefAnnotationOption(value: $0, label: $0.displayLabel)
            }
        )
        XCTAssertEqual(
            DebriefAnnotationCatalog.outcomeOptions,
            AnnotationOutcome.allCases.map {
                DebriefAnnotationOption(value: $0, label: $0.displayLabel)
            }
        )
        XCTAssertEqual(
            DebriefAnnotationCatalog.learningObjectiveOptions.first,
            DebriefAnnotationOption(value: .assessment, label: "Assessment")
        )
        XCTAssertEqual(
            DebriefAnnotationCatalog.outcomeOptions,
            [
                DebriefAnnotationOption(value: .correct, label: "Correct"),
                DebriefAnnotationOption(value: .incorrect, label: "Incorrect"),
                DebriefAnnotationOption(value: .missed, label: "Missed"),
                DebriefAnnotationOption(value: .improvised, label: "Improvised"),
                DebriefAnnotationOption(value: .pending, label: "Pending"),
            ]
        )
    }
}
