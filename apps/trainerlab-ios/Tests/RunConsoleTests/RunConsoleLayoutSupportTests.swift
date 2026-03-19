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
            .narrowPhone,
        )
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 390, layoutMode: .compact),
            .narrowPhone,
        )
    }

    func testCompactDensityUsesStandardAbove390PointsOrOutsideCompactMode() {
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 393, layoutMode: .compact),
            .standard,
        )
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 430, layoutMode: .compact),
            .standard,
        )
        XCTAssertEqual(
            RunConsoleCompactDensity.resolve(width: 375, layoutMode: .regular),
            .standard,
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

    func testCompactControlPresentationUsesIconOnlyForCompactPhoneOnly() {
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                layoutMode: .compact,
                horizontalSizeClass: .compact,
            ),
            .iconOnly,
        )
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                layoutMode: .compact,
                horizontalSizeClass: .regular,
            ),
            .labeled,
        )
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                layoutMode: .regular,
                horizontalSizeClass: .compact,
            ),
            .labeled,
        )
    }

    func testTimelinePresentationNormalizesInlineTitles() {
        let injuryEntry = ClinicalTimelineEntry(
            dedupeKey: "injury-1",
            kind: .injury,
            title: "Injury Change",
            message: "Left arm",
            createdAt: Date(),
        )
        let lifecycleEntry = ClinicalTimelineEntry(
            dedupeKey: "run-1",
            kind: .lifecycle,
            title: "Run Started",
            message: "Run started",
            createdAt: Date(),
        )
        let noteEntry = ClinicalTimelineEntry(
            dedupeKey: "note-1",
            kind: .note,
            title: "Anything",
            message: "Trainer note",
            createdAt: Date(),
        )

        XCTAssertEqual(RunConsoleTimelinePresentation.chipText(for: .injury), "INJURY")
        XCTAssertEqual(RunConsoleTimelinePresentation.chipText(for: .loc), "LOC")
        XCTAssertEqual(RunConsoleTimelinePresentation.title(for: injuryEntry), "Change")
        XCTAssertEqual(RunConsoleTimelinePresentation.title(for: lifecycleEntry), "Run Started")
        XCTAssertEqual(RunConsoleTimelinePresentation.title(for: noteEntry), "Trainer Note")
    }

    func testLifecycleActionsMatchSessionStatus() {
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .seeded), [.start])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .running), [.pause, .stop])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .paused), [.resume, .stop])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .completed), [])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .failed), [])
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: nil), [])
    }
}
