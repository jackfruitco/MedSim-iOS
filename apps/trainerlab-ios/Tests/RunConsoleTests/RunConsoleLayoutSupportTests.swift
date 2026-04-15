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

    func testCompactControlPresentationUsesPhoneMenusForSharedPhoneBreakpoints() {
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                width: 375,
                horizontalSizeClass: .compact,
            ),
            .phoneMenus,
        )
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                width: 430,
                horizontalSizeClass: .compact,
            ),
            .phoneMenus,
        )
        XCTAssertEqual(
            RunConsoleCompactControlPresentation.resolve(
                width: 700,
                horizontalSizeClass: .regular,
            ),
            .grid,
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
        XCTAssertEqual(RunConsoleTimelinePresentation.title(for: noteEntry), "Anything")
    }

    func testTimelineAccordionTogglesSingleExpandedEntryByDedupeKey() {
        let first = ClinicalTimelineEntry(
            dedupeKey: "entry-1",
            kind: .note,
            title: "Trainer Note",
            message: "First",
            createdAt: Date(),
        )
        let second = ClinicalTimelineEntry(
            dedupeKey: "entry-2",
            kind: .intervention,
            title: "Intervention",
            message: "Second",
            createdAt: Date(),
        )

        let expandedFirst = RunConsoleTimelineAccordion.toggledExpandedEntryKey(
            current: nil,
            tapped: first,
        )
        XCTAssertEqual(expandedFirst, "entry-1")
        XCTAssertTrue(RunConsoleTimelineAccordion.isExpanded(first, expandedEntryKey: expandedFirst))
        XCTAssertFalse(RunConsoleTimelineAccordion.isExpanded(second, expandedEntryKey: expandedFirst))

        let expandedSecond = RunConsoleTimelineAccordion.toggledExpandedEntryKey(
            current: expandedFirst,
            tapped: second,
        )
        XCTAssertEqual(expandedSecond, "entry-2")
        XCTAssertFalse(RunConsoleTimelineAccordion.isExpanded(first, expandedEntryKey: expandedSecond))
        XCTAssertTrue(RunConsoleTimelineAccordion.isExpanded(second, expandedEntryKey: expandedSecond))

        let collapsed = RunConsoleTimelineAccordion.toggledExpandedEntryKey(
            current: expandedSecond,
            tapped: second,
        )
        XCTAssertNil(collapsed)
    }

    func testControlCatalogSeparatesSessionAndQuickControls() {
        let sessionControls = RunConsoleControlsCatalog.sessionControls(lifecycleActions: [.pause, .stop])

        XCTAssertEqual(sessionControls.map(\.title), ["Exit", "Pause", "Stop", "Summary"])
        XCTAssertEqual(sessionControls.map(\.group), [.session, .session, .session, .session])
        XCTAssertEqual(
            RunConsoleControlsCatalog.quickControls.map(\.title),
            ["Intervention", "Event", "Annotation", "Steer", "Tick AI", "Tick Vitals"],
        )
        XCTAssertEqual(
            RunConsoleControlsCatalog.quickControls.map(\.systemImage),
            ["plus.app", "plus.app", "note.text.badge.plus", "wand.and.sparkles", "timer", "heart.text.square"],
        )
    }

    func testTimelineFiltersIncludeNotesInRunConsole() {
        let causeEntry = ClinicalTimelineEntry(
            dedupeKey: "cause-1",
            kind: .cause,
            title: "Cause",
            message: "Left arm injury",
            createdAt: Date(),
        )
        let noteEntry = ClinicalTimelineEntry(
            dedupeKey: "note-1",
            kind: .note,
            title: "Trainer Note",
            message: "Internal note",
            createdAt: Date(),
        )
        let visibleEntries = RunConsoleTimelineFilter.visibleEntries(
            from: [causeEntry, noteEntry],
            matching: .all,
        )

        XCTAssertTrue(RunConsoleTimelineFilter.allCases.contains(.kind(.note)))
        XCTAssertEqual(visibleEntries, [causeEntry, noteEntry])
        XCTAssertEqual(
            RunConsoleTimelineFilter.visibleEntries(from: [causeEntry, noteEntry], matching: .kind(.note)),
            [noteEntry],
        )
    }

    func testLifecycleActionsMatchSessionStatus() {
        XCTAssertEqual(RunConsoleLifecycleAction.visibleActions(for: .seeding), [])
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
            },
        )
        XCTAssertEqual(
            DebriefAnnotationCatalog.outcomeOptions,
            AnnotationOutcome.allCases.map {
                DebriefAnnotationOption(value: $0, label: $0.displayLabel)
            },
        )
        XCTAssertEqual(
            DebriefAnnotationCatalog.learningObjectiveOptions.first,
            DebriefAnnotationOption(value: .assessment, label: "Assessment"),
        )
        XCTAssertEqual(
            DebriefAnnotationCatalog.outcomeOptions,
            [
                DebriefAnnotationOption(value: .correct, label: "Correct"),
                DebriefAnnotationOption(value: .incorrect, label: "Incorrect"),
                DebriefAnnotationOption(value: .missed, label: "Missed"),
                DebriefAnnotationOption(value: .improvised, label: "Improvised"),
                DebriefAnnotationOption(value: .pending, label: "Pending"),
            ],
        )
    }

    func testOperationalLogPresentationUsesCanonicalLifecycleTitleAndDetail() {
        let event = EventEnvelope(
            eventID: "evt-1",
            eventType: "simulation.state_changed",
            createdAt: Date(),
            correlationID: nil,
            payload: [
                "status": .string("failed"),
                "terminal_reason_text": .string("Runtime provider timed out."),
            ],
        )

        let row = RunConsoleOperationalLogPresentation.row(for: event)

        XCTAssertEqual(row.title, "Scenario Failed")
        XCTAssertEqual(row.detail, "Runtime provider timed out.")
        XCTAssertEqual(row.canonicalEventType, SimulationEventType.simulationStatusUpdated)
    }

    func testOperationalLogPresentationCanonicalizesLegacyAliases() {
        let event = EventEnvelope(
            eventID: "evt-2",
            eventType: "summary.updated",
            createdAt: Date(),
            correlationID: nil,
            payload: [:],
        )

        let row = RunConsoleOperationalLogPresentation.row(for: event)

        XCTAssertEqual(row.title, "Summary Updated")
        XCTAssertNil(row.detail)
        XCTAssertEqual(row.canonicalEventType, SimulationEventType.simulationSummaryUpdated)
    }

    func testAvailableAccessInventoryDerivesIVAndIOAvailability() {
        let none = AvailableAccessInventory(interventions: [])
        XCTAssertFalse(none.hasIV)
        XCTAssertFalse(none.hasIO)

        let ivOnly = AvailableAccessInventory(interventions: [
            makeInterventionAnnotation(id: "iv-1", type: "iv_access", siteCode: "IV-RIGHT-AC", updatedAt: Date(timeIntervalSince1970: 20)),
        ])
        XCTAssertTrue(ivOnly.hasIV)
        XCTAssertFalse(ivOnly.hasIO)

        let both = AvailableAccessInventory(interventions: [
            makeInterventionAnnotation(id: "iv-1", type: "iv_access", siteCode: "IV-RIGHT-AC", updatedAt: Date(timeIntervalSince1970: 10)),
            makeInterventionAnnotation(id: "io-1", type: "io_access", siteCode: "IO-LEFT-PROX-TIBIA", updatedAt: Date(timeIntervalSince1970: 20)),
        ])
        XCTAssertTrue(both.hasIV)
        XCTAssertTrue(both.hasIO)
        XCTAssertEqual(both.preferredRouteToken, "IO")
    }

    func testInterventionMenuContextDisablesFluidActionsWithoutAccess() {
        let context = InterventionMenuContext(
            dictionary: [
                InterventionGroup(
                    interventionType: "fluid_resuscitation",
                    label: "Fluid Resuscitation",
                    sites: [
                        InterventionSite(code: "FR-IV-LINE", label: "IV Line"),
                        InterventionSite(code: "FR-IO-LINE", label: "IO Line"),
                    ],
                ),
            ],
            problems: [],
            recommendations: [],
            interventions: [],
            selectedTargetProblemID: nil,
        )

        XCTAssertTrue(context.availableGroups.isEmpty)
        XCTAssertEqual(context.disabledItems.first?.reason, "Requires IV or IO access")
    }

    func testInterventionMenuContextPrefersRecommendedTypesAndProblemSiteDefaults() {
        let dictionary = [
            InterventionGroup(
                interventionType: "tourniquet",
                label: "Tourniquet",
                sites: [
                    InterventionSite(code: "RIGHT_LEG", label: "Right Leg"),
                    InterventionSite(code: "LEFT_LEG", label: "Left Leg"),
                ],
            ),
            InterventionGroup(
                interventionType: "pressure_dressing",
                label: "Pressure Dressing",
                sites: [
                    InterventionSite(code: "RIGHT_LEG", label: "Right Leg"),
                    InterventionSite(code: "LEFT_LEG", label: "Left Leg"),
                ],
            ),
        ]
        let problem = ProblemAnnotation(
            id: "problem-1",
            problemID: 41,
            title: "Massive hemorrhage",
            description: "Left lower leg bleeding",
            isAnatomic: true,
            locationCode: "LEFT_LOWER_LEG",
            side: .front,
            x: 0.4,
            y: 0.7,
            status: .active,
        )
        let recommendation = RecommendedInterventionItem(
            recommendationID: 7,
            title: "Apply tourniquet",
            kind: "tourniquet",
            targetProblemID: 41,
            priority: 1,
        )

        let context = InterventionMenuContext(
            dictionary: dictionary,
            problems: [problem],
            recommendations: [recommendation],
            interventions: [],
            selectedTargetProblemID: 41,
        )

        XCTAssertEqual(context.availableGroups.map(\.interventionType), ["tourniquet", "pressure_dressing"])
        XCTAssertEqual(context.recommendedActions.first?.prefill.siteCode, "LEFT_LEG")
    }

    func testInterventionComposerDraftAppliesPrefillAndResolvesSiteCode() {
        let dictionary = [
            InterventionGroup(
                interventionType: "tourniquet",
                label: "Tourniquet",
                sites: [
                    InterventionSite(code: "RIGHT_LEG", label: "Right Leg"),
                    InterventionSite(code: "LEFT_LEG", label: "Left Leg"),
                ],
            ),
        ]
        var draft = InterventionComposerDraft(prefilledTargetProblemID: 41)
        draft.applyPrefill(
            InterventionComposerPrefill(
                interventionType: "tourniquet",
                siteCode: "LEFT_LEG",
                targetProblemID: 41,
            ),
            dictionary: dictionary,
        )

        XCTAssertEqual(draft.selectedType, "tourniquet")
        XCTAssertEqual(draft.selectedLocationLabel, "Leg")
        XCTAssertEqual(draft.selectedLaterality, "left")
        XCTAssertEqual(draft.resolvedSiteCode(in: dictionary[0].sites), "LEFT_LEG")
    }

    func testInterventionDisplayTextHumanizesSiteCodes() {
        XCTAssertEqual(InterventionDisplayText.normalizedSiteCode("IV-RIGHT-AC"), "Right AC")
        XCTAssertEqual(
            InterventionDisplayText.siteLabel(siteCode: "IO-LEFT-PROX-TIBIA", siteLabel: nil),
            "Left Proximal Tibia",
        )
        XCTAssertEqual(InterventionDisplayText.normalizedSiteCode("LEFT_LEG"), "Left Leg")
        XCTAssertEqual(InterventionDisplayText.normalizedSiteCode("RIGHT_CHEST"), "Right Chest")
    }
}

private func makeInterventionAnnotation(
    id: String,
    type: String,
    siteCode: String,
    updatedAt: Date,
) -> InterventionAnnotation {
    InterventionAnnotation(
        id: id,
        interventionID: Int(id.split(separator: "-").last ?? "1"),
        interventionType: type,
        siteCode: siteCode,
        side: .front,
        x: 0.4,
        y: 0.4,
        effectiveness: "effective",
        status: InterventionStatus.applied.rawValue,
        updatedAt: updatedAt,
    )
}
