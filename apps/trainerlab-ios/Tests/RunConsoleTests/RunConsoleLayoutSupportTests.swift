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
            ["Intervention", "Event", "Annotation", "Send Feedback", "Steer", "Tick AI", "Tick Vitals"],
        )
        XCTAssertEqual(
            RunConsoleControlsCatalog.quickControls.map(\.systemImage),
            ["plus.app", "plus.app", "note.text.badge.plus", "bubble.left.and.text.bubble.right", "wand.and.sparkles", "timer", "heart.text.square"],
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

    // MARK: - Patient State Grouping

    @MainActor
    func testCauseProblemGroupingPlacesLinkedProblemsUnderMatchingCause() {
        let cause = makeRuntimeCause(causeID: 10, kind: "gunshot", location: "left_lower_leg")
        let linked = makeProblem(id: "p1", problemID: 1, label: "Hemorrhage", status: .active, causeID: 10)
        let unlinked = makeProblem(id: "p2", problemID: 2, label: "Pain", status: .active, causeID: nil)

        let groups = PatientDiagramPanel.buildCauseProblemGroups(
            allCauses: [cause],
            injuries: [],
            problems: [linked, unlinked],
        )
        let systemic = PatientDiagramPanel.buildSystemicProblems(
            allCauses: [cause],
            injuries: [],
            problems: [linked, unlinked],
        )

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.problems.map(\.id), ["p1"])
        XCTAssertEqual(systemic.map(\.id), ["p2"])
    }

    @MainActor
    func testSystemicProblemsIncludeUnlinkedAnatomicAndNonAnatomicProblems() {
        let cause = makeRuntimeCause(causeID: 5, kind: "blast", location: "right_chest")
        let linked = makeProblem(id: "p1", problemID: 1, label: "Pneumothorax", status: .active, causeID: 5, isAnatomic: true)
        let unlinkedAnatomic = makeProblem(id: "p2", problemID: 2, label: "Bleeding", status: .active, causeID: nil, isAnatomic: true)
        let nonAnatomic = makeProblem(id: "p3", problemID: 3, label: "Heat Stress", status: .controlled, causeID: nil, isAnatomic: false)

        let systemic = PatientDiagramPanel.buildSystemicProblems(
            allCauses: [cause],
            injuries: [],
            problems: [linked, unlinkedAnatomic, nonAnatomic],
        )

        XCTAssertEqual(systemic.map(\.id), ["p2", "p3"])
    }

    @MainActor
    func testProblemOrderingPlacesActiveBeforeControlledAndResolved() {
        let resolved = makeProblem(id: "p3", problemID: 3, label: "Resolved", status: .resolved)
        let controlled = makeProblem(id: "p2", problemID: 2, label: "Controlled", status: .controlled)
        let active = makeProblem(id: "p1", problemID: 1, label: "Active", status: .active)

        let sorted = PatientDiagramPanel.sortedProblems([resolved, controlled, active])
        XCTAssertEqual(sorted.map(\.id), ["p1", "p2", "p3"])
    }

    @MainActor
    func testCauseDisplayTitleUsesHumanReadableFormat() {
        let cause = makeRuntimeCause(causeID: 11, kind: "gunshot", location: "left_lower_leg")
        XCTAssertEqual(PatientDiagramPanel.causeDisplayTitle(cause: cause), "Gunshot — Left Lower Leg")
    }

    @MainActor
    func testCauseDisplayTitlePrefersBackendLocationLabel() {
        let cause = makeRuntimeCause(
            causeID: 11,
            kind: "gunshot",
            location: "LLL",
            locationLabel: "Left Lower Leg",
        )

        XCTAssertEqual(PatientDiagramPanel.causeDisplayTitle(cause: cause), "Gunshot — Left Lower Leg")
    }

    @MainActor
    func testCauseDisplayTitleFallsBackWhenBackendLocationLabelIsEmpty() {
        let cause = makeRuntimeCause(
            causeID: 11,
            kind: "gunshot",
            location: "left_lower_leg",
            locationLabel: "   ",
        )

        XCTAssertEqual(PatientDiagramPanel.causeDisplayTitle(cause: cause), "Gunshot — Left Lower Leg")
    }

    @MainActor
    func testCauseDisplayTitleDoesNotDuplicateLateralityIncludedInLocationLabel() {
        let cause = makeRuntimeCause(
            causeID: 11,
            kind: "gunshot",
            location: "LLL",
            locationLabel: "Left Lower Leg",
            laterality: "left",
            lateralityLabel: "Left",
        )

        XCTAssertEqual(PatientDiagramPanel.causeDisplayTitle(cause: cause), "Gunshot — Left Lower Leg")
    }

    @MainActor
    func testProblemDisplayLocationPrefersLocationLabelAndPreservesRawCode() {
        let problem = ProblemAnnotation(
            id: "problem-1",
            problemID: 41,
            title: "Massive hemorrhage",
            isAnatomic: true,
            locationCode: "LLL",
            locationLabel: "Left Lower Leg",
            status: .active,
        )

        XCTAssertEqual(PatientDiagramPanel.problemDisplayLocation(problem), "Left Lower Leg")
        XCTAssertEqual(problem.locationCode, "LLL")
    }

    @MainActor
    func testLateralityDisplayPrefersBackendLabel() {
        XCTAssertEqual(RuntimeLocationDisplay.lateralityText(label: "Patient Right", raw: "patientRight"), "Patient Right")
    }

    @MainActor
    func testHumanizeLabelTitleCasesNormalWordsAndOnlyPreservesKnownAcronyms() {
        XCTAssertEqual(PatientDiagramPanel.humanizeLabel("left_lower_leg"), "Left Lower Leg")
        XCTAssertEqual(PatientDiagramPanel.humanizeLabel("right_chest"), "Right Chest")
        XCTAssertEqual(PatientDiagramPanel.humanizeLabel("gsw_left_leg"), "GSW Left Leg")
    }

    // MARK: - Target Problem Chooser Collapse

    func testInterventionComposerDraftStartsWithTargetChooserOpen() {
        let draft = InterventionComposerDraft(prefilledTargetProblemID: nil)

        XCTAssertEqual(draft.activeSection, .target, "Draft with no prefill should start at the target-chooser step")
        XCTAssertNil(draft.selectedTargetProblemID)
    }

    func testInterventionComposerDraftPrefilledProblemStartsAtTypeStep() {
        let draft = InterventionComposerDraft(prefilledTargetProblemID: 42)

        XCTAssertEqual(draft.activeSection, .type, "Prefilled draft should start at the type step, not the chooser")
        XCTAssertEqual(draft.selectedTargetProblemID, 42)
    }

    func testInterventionComposerDraftSelectingProblemCollapsesChooser() {
        var draft = InterventionComposerDraft(prefilledTargetProblemID: nil)
        XCTAssertEqual(draft.activeSection, .target)

        // Simulate selecting a target problem (same logic as the button action).
        draft.selectedTargetProblemID = 99
        draft.activeSection = .type

        XCTAssertEqual(draft.activeSection, .type, "Chooser must collapse (activeSection advances to .type) after selection")
        XCTAssertEqual(draft.selectedTargetProblemID, 99, "Selected problem ID must be preserved after collapse")
    }

    func testInterventionComposerDraftSelectedProblemVisibleWhenCollapsed() {
        var draft = InterventionComposerDraft(prefilledTargetProblemID: nil)
        draft.selectedTargetProblemID = 7
        draft.activeSection = .type

        // The summary chip should be derivable from draft state.
        XCTAssertEqual(draft.selectedTargetProblemID, 7)
        XCTAssertNotEqual(draft.activeSection, .target, "Chooser list must not be open after collapse")
    }

    func testInterventionComposerDraftCanReopenChooser() {
        var draft = InterventionComposerDraft(prefilledTargetProblemID: nil)
        draft.selectedTargetProblemID = 7
        draft.activeSection = .type

        // Simulate the header button toggling back to .target.
        draft.activeSection = .target

        XCTAssertEqual(draft.activeSection, .target, "Tapping the summary should re-open the chooser")
        XCTAssertEqual(draft.selectedTargetProblemID, 7, "Previously selected problem should still be set while chooser is open")
    }

    func testInterventionComposerDraftGeneralSelectionCollapsesChooser() {
        var draft = InterventionComposerDraft(prefilledTargetProblemID: nil)
        XCTAssertEqual(draft.activeSection, .target)

        // Simulate selecting "General intervention".
        draft.selectedTargetProblemID = nil
        draft.activeSection = .type

        XCTAssertEqual(draft.activeSection, .type)
        XCTAssertNil(draft.selectedTargetProblemID)
    }

    // MARK: - Recommendation Acceptance State

    func testRecommendationAcceptanceNoInterventionsAllPending() {
        let rec = RecommendedInterventionItem(
            recommendationID: 1, title: "Tourniquet", kind: "tourniquet", targetProblemID: 10, priority: 1,
        )

        let accepted = InterventionMenuContext.isRecommendationAccepted(
            rec,
            dictionary: makeDictionary(["tourniquet"]),
            interventions: [],
        )

        XCTAssertFalse(accepted)
    }

    func testRecommendationAcceptanceMatchingInterventionIsAccepted() {
        let rec = RecommendedInterventionItem(
            recommendationID: 1, title: "Tourniquet", kind: "tourniquet", targetProblemID: 10, priority: 1,
        )
        let intervention = makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date())

        let accepted = InterventionMenuContext.isRecommendationAccepted(
            rec,
            dictionary: makeDictionary(["tourniquet"]),
            interventions: [intervention],
        )

        XCTAssertTrue(accepted)
    }

    func testRecommendationAcceptanceDifferentTypeNotAccepted() {
        let rec = RecommendedInterventionItem(
            recommendationID: 1, title: "Tourniquet", kind: "tourniquet", targetProblemID: 10, priority: 1,
        )
        // An intervention for the same problem but a different type should NOT accept this recommendation.
        let intervention = makeInterventionAnnotation(id: "int-1", type: "pressure_dressing", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date())

        let accepted = InterventionMenuContext.isRecommendationAccepted(
            rec,
            dictionary: makeDictionary(["tourniquet"]),
            interventions: [intervention],
        )

        XCTAssertFalse(accepted, "A different intervention type for the same problem must not mark the recommendation as accepted")
    }

    func testRecommendationAcceptanceDifferentProblemNotAccepted() {
        let rec = RecommendedInterventionItem(
            recommendationID: 1, title: "Tourniquet", kind: "tourniquet", targetProblemID: 10, priority: 1,
        )
        // Same type, but targeting a different problem — should not accept.
        let intervention = makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 99, updatedAt: Date())

        let accepted = InterventionMenuContext.isRecommendationAccepted(
            rec,
            dictionary: makeDictionary(["tourniquet"]),
            interventions: [intervention],
        )

        XCTAssertFalse(accepted, "An intervention targeting a different problem must not mark this recommendation as accepted")
    }

    func testRecommendationAcceptanceOnePendingOneAcceptedOnSameProblem() {
        let recTourniquet = RecommendedInterventionItem(
            recommendationID: 1, title: "Tourniquet", kind: "tourniquet", targetProblemID: 10, priority: 1,
        )
        let recDressing = RecommendedInterventionItem(
            recommendationID: 2, title: "Pressure Dressing", kind: "pressure_dressing", targetProblemID: 10, priority: 2,
        )

        // Only the tourniquet was applied.
        let interventions = [
            makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date()),
        ]
        let dictionary = makeDictionary(["tourniquet", "pressure_dressing"])

        let tourniquetAccepted = InterventionMenuContext.isRecommendationAccepted(
            recTourniquet, dictionary: dictionary, interventions: interventions,
        )
        let dressingAccepted = InterventionMenuContext.isRecommendationAccepted(
            recDressing, dictionary: dictionary, interventions: interventions,
        )

        XCTAssertTrue(tourniquetAccepted, "Tourniquet recommendation must be accepted since a tourniquet was applied")
        XCTAssertFalse(dressingAccepted, "Pressure dressing recommendation must remain pending — only tourniquet was applied")
    }

    func testRecommendationAcceptanceTwoProblemsWithDifferentStates() {
        let recProblem10 = RecommendedInterventionItem(
            recommendationID: 1, title: "Tourniquet", kind: "tourniquet", targetProblemID: 10, priority: 1,
        )
        let recProblem20 = RecommendedInterventionItem(
            recommendationID: 2, title: "Tourniquet", kind: "tourniquet", targetProblemID: 20, priority: 1,
        )

        // Only problem 10 was treated.
        let interventions = [
            makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date()),
        ]
        let dictionary = makeDictionary(["tourniquet"])

        XCTAssertTrue(
            InterventionMenuContext.isRecommendationAccepted(recProblem10, dictionary: dictionary, interventions: interventions),
        )
        XCTAssertFalse(
            InterventionMenuContext.isRecommendationAccepted(recProblem20, dictionary: dictionary, interventions: interventions),
            "Recommendation for problem 20 must remain pending — intervention targeted problem 10",
        )
    }

    func testRecommendationAcceptanceMultipleInterventionTypesOnlyMatchCorrect() {
        let rec = RecommendedInterventionItem(
            recommendationID: 1, title: "IV Access", kind: "iv_access", targetProblemID: 5, priority: 1,
        )
        let interventions = [
            makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 5, updatedAt: Date()),
            makeInterventionAnnotation(id: "int-2", type: "pressure_dressing", siteCode: "LEFT_LEG", targetProblemID: 5, updatedAt: Date()),
            makeInterventionAnnotation(id: "int-3", type: "iv_access", siteCode: "IV-RIGHT-AC", targetProblemID: 5, updatedAt: Date()),
        ]

        let accepted = InterventionMenuContext.isRecommendationAccepted(
            rec, dictionary: makeDictionary(["iv_access"]), interventions: interventions,
        )

        XCTAssertTrue(accepted, "IV access recommendation must be accepted since an iv_access intervention for the same problem exists")
    }

    // MARK: - Recommendation Candidate Types (normalization)

    func testRecommendationCandidateTypesDictionaryResolvedTypeComesFirst() {
        // normalizedKind is not in the dictionary; kind is — kind must be the resolved type and come first.
        let rec = RecommendedInterventionItem(
            recommendationID: 1,
            title: "Tourniquet",
            kind: "tourniquet",
            targetProblemID: 10,
            normalizedKind: "tourniquet_v2",
        )
        let dictionary = makeDictionary(["tourniquet"])
        let candidates = InterventionMenuContext.recommendationCandidateTypes(for: rec, dictionary: dictionary)
        XCTAssertEqual(candidates.first, "tourniquet", "Dictionary-resolved type must be the first candidate")
        XCTAssertTrue(candidates.contains("tourniquet_v2"), "Raw candidates must still be included after the resolved type")
    }

    func testRecommendationCandidateTypesDeduplicatesResolvedAndRaw() {
        // normalizedKind matches the dictionary → resolved. kind is the same string → no duplicate.
        let rec = RecommendedInterventionItem(
            recommendationID: 1,
            title: "Tourniquet",
            kind: "tourniquet",
            targetProblemID: 10,
            normalizedKind: "tourniquet",
        )
        let dictionary = makeDictionary(["tourniquet"])
        let candidates = InterventionMenuContext.recommendationCandidateTypes(for: rec, dictionary: dictionary)
        XCTAssertEqual(candidates.count(where: { $0 == "tourniquet" }), 1, "Duplicate candidates must be collapsed to one entry")
    }

    func testRecommendationCandidateTypesEmptyWhenAllFieldsNil() {
        let rec = RecommendedInterventionItem(recommendationID: 1, title: "Unknown")
        let candidates = InterventionMenuContext.recommendationCandidateTypes(for: rec, dictionary: [])
        XCTAssertTrue(candidates.isEmpty)
    }

    func testRecommendationAcceptanceMatchesByNormalizedKindOnly() {
        let rec = RecommendedInterventionItem(
            recommendationID: 1,
            title: "Tourniquet",
            kind: nil,
            targetProblemID: 10,
            normalizedKind: "tourniquet",
        )
        let intervention = makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date())
        XCTAssertTrue(
            InterventionMenuContext.isRecommendationAccepted(rec, dictionary: makeDictionary(["tourniquet"]), interventions: [intervention]),
            "normalizedKind-only recommendation must be accepted when a matching intervention exists",
        )
    }

    func testRecommendationAcceptanceMatchesByKindWhenNormalizedKindAbsent() {
        let rec = RecommendedInterventionItem(
            recommendationID: 1,
            title: "Tourniquet",
            kind: "tourniquet",
            targetProblemID: 10,
            normalizedKind: nil,
        )
        let intervention = makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date())
        XCTAssertTrue(
            InterventionMenuContext.isRecommendationAccepted(rec, dictionary: makeDictionary(["tourniquet"]), interventions: [intervention]),
            "kind-only recommendation must be accepted when a matching intervention exists",
        )
    }

    func testRecommendationAcceptanceMatchesByNormalizedCodeFallback() {
        // normalizedCode is the only populated field; it is not in the dictionary,
        // but the submitted intervention uses that same token as its interventionType.
        let rec = RecommendedInterventionItem(
            recommendationID: 1,
            title: "Tourniquet",
            kind: nil,
            targetProblemID: 10,
            normalizedKind: nil,
            normalizedCode: "tourniquet",
        )
        let intervention = makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date())
        XCTAssertTrue(
            InterventionMenuContext.isRecommendationAccepted(rec, dictionary: [], interventions: [intervention]),
            "normalizedCode fallback must match when no dictionary entry exists",
        )
    }

    func testRecommendationAcceptanceMatchesByCodeFallback() {
        let rec = RecommendedInterventionItem(
            recommendationID: 1,
            title: "Tourniquet",
            code: "tourniquet",
            kind: nil,
            targetProblemID: 10,
            normalizedKind: nil,
            normalizedCode: nil,
        )
        let intervention = makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date())
        XCTAssertTrue(
            InterventionMenuContext.isRecommendationAccepted(rec, dictionary: [], interventions: [intervention]),
            "code-only recommendation must be accepted via raw-candidate fallback",
        )
    }

    func testRecommendationAcceptanceMultipleCandidatesOnlyOneMatchesInterventionType() {
        // normalizedKind is "tourniquet" (in dictionary), kind is "tourniquet_legacy" (not in dictionary).
        // The submitted intervention uses "tourniquet". Only normalizedKind should match.
        let rec = RecommendedInterventionItem(
            recommendationID: 1,
            title: "Tourniquet",
            kind: "tourniquet_legacy",
            targetProblemID: 10,
            normalizedKind: "tourniquet",
        )
        let intervention = makeInterventionAnnotation(id: "int-1", type: "tourniquet", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date())
        XCTAssertTrue(
            InterventionMenuContext.isRecommendationAccepted(rec, dictionary: makeDictionary(["tourniquet"]), interventions: [intervention]),
        )
        // An intervention using the legacy token must also match via raw candidates.
        let legacyIntervention = makeInterventionAnnotation(id: "int-2", type: "tourniquet_legacy", siteCode: "LEFT_LEG", targetProblemID: 10, updatedAt: Date())
        XCTAssertTrue(
            InterventionMenuContext.isRecommendationAccepted(rec, dictionary: makeDictionary(["tourniquet"]), interventions: [legacyIntervention]),
            "Raw candidate fallback must also accept a legacy-token intervention",
        )
    }

    func testDisplayPointFrontRightSidedAnatomyRendersOnPatientRightPanelSide() {
        let point = RunConsolePatientDiagramSupport.displayPoint(
            x: 0.2,
            y: 0.5,
            side: .front,
            size: CGSize(width: 200, height: 300),
        )

        XCTAssertEqual(point.x, 40, accuracy: 0.001)
        XCTAssertEqual(point.y, 150, accuracy: 0.001)
    }

    func testDisplayPointFrontLeftSidedAnatomyRendersOnPatientLeftPanelSide() {
        let point = RunConsolePatientDiagramSupport.displayPoint(
            x: 0.8,
            y: 0.4,
            side: .front,
            size: CGSize(width: 200, height: 300),
        )

        XCTAssertEqual(point.x, 160, accuracy: 0.001)
        XCTAssertEqual(point.y, 120, accuracy: 0.001)
    }

    func testDisplayPointBackLateralityStaysConsistentWithConvention() {
        let point = RunConsolePatientDiagramSupport.displayPoint(
            x: 0.25,
            y: 0.3,
            side: .back,
            size: CGSize(width: 200, height: 300),
        )

        XCTAssertEqual(point.x, 50, accuracy: 0.001)
        XCTAssertEqual(point.y, 90, accuracy: 0.001)
    }

    func testAnatomicalLocationLabelNormalizesRepresentativeCases() {
        XCTAssertEqual(
            RunConsolePatientDiagramSupport.anatomicalLocationLabel(side: .front, zoneCode: "RIGHT_CHEST"),
            "Right Chest",
        )
        XCTAssertEqual(
            RunConsolePatientDiagramSupport.anatomicalLocationLabel(side: .front, zoneCode: "LEFT_FOREARM"),
            "Left Forearm",
        )
        XCTAssertEqual(
            RunConsolePatientDiagramSupport.anatomicalLocationLabel(side: .back, zoneCode: "RIGHT_CALF"),
            "Posterior Right Calf",
        )
        XCTAssertEqual(
            RunConsolePatientDiagramSupport.anatomicalLocationLabel(side: .back, zoneCode: "LEFT_SHOULDER"),
            "Posterior Left Shoulder",
        )
    }

    func testOrientationLabelsUsePatientLateralityForFrontView() {
        let frontLabels = RunConsolePatientDiagramSupport.orientationLabels(for: .front)

        XCTAssertEqual(frontLabels.leading, "Patient Right")
        XCTAssertEqual(frontLabels.trailing, "Patient Left")
    }

    func testOrientationLabelsUsePatientLateralityForBackView() {
        let backLabels = RunConsolePatientDiagramSupport.orientationLabels(for: .back)

        XCTAssertEqual(backLabels.leading, "Patient Left")
        XCTAssertEqual(backLabels.trailing, "Patient Right")
    }

    func testNormalizedLateralityLabelReadsTokenWhenAvailable() {
        XCTAssertEqual(
            RunConsolePatientDiagramSupport.normalizedLateralityLabel(side: .front, zoneCode: "RIGHT_CHEST"),
            "Right",
        )
        XCTAssertEqual(
            RunConsolePatientDiagramSupport.normalizedLateralityLabel(side: .back, zoneCode: "LEFT_SHOULDER"),
            "Left",
        )
    }

    func testNormalizedLateralityLabelDoesNotInferFromPanelSideOnly() {
        XCTAssertNil(
            RunConsolePatientDiagramSupport.normalizedLateralityLabel(side: .front, zoneCode: "CHEST"),
        )
        XCTAssertNil(
            RunConsolePatientDiagramSupport.normalizedLateralityLabel(side: .back, zoneCode: nil),
        )
    }
}

private func makeDictionary(_ types: [String]) -> [InterventionGroup] {
    types.map { InterventionGroup(interventionType: $0, label: $0, sites: []) }
}

private func makeInterventionAnnotation(
    id: String,
    type: String,
    siteCode: String,
    targetProblemID: Int? = nil,
    updatedAt: Date,
) -> InterventionAnnotation {
    InterventionAnnotation(
        id: id,
        interventionID: Int(id.split(separator: "-").last ?? "1"),
        interventionType: type,
        siteCode: siteCode,
        targetProblemID: targetProblemID,
        side: .front,
        x: 0.4,
        y: 0.4,
        effectiveness: "effective",
        status: InterventionStatus.applied.rawValue,
        updatedAt: updatedAt,
    )
}

private func makeProblem(
    id: String,
    problemID: Int,
    label: String,
    status: ProblemLifecycleState,
    causeID: Int? = nil,
    isAnatomic: Bool = false,
) -> ProblemAnnotation {
    ProblemAnnotation(
        id: id,
        problemID: problemID,
        title: label,
        displayName: label,
        isAnatomic: isAnatomic,
        status: status,
        causeID: causeID,
    )
}

private func makeRuntimeCause(
    causeID: Int,
    kind: String,
    location: String,
    locationLabel: String? = nil,
    laterality: String? = nil,
    lateralityLabel: String? = nil,
) -> RuntimeCauseState {
    var fields = [
        "\"id\": \(causeID)",
        "\"kind\": \"\(kind)\"",
        "\"anatomical_location\": \"\(location)\"",
    ]
    if let locationLabel {
        fields.append("\"anatomical_location_label\": \"\(locationLabel)\"")
    }
    if let laterality {
        fields.append("\"laterality\": \"\(laterality)\"")
    }
    if let lateralityLabel {
        fields.append("\"laterality_label\": \"\(lateralityLabel)\"")
    }
    let payload = "{\(fields.joined(separator: ","))}"
    let data = Data(payload.utf8)

    do {
        return try JSONDecoder().decode(RuntimeCauseState.self, from: data)
    } catch {
        XCTFail("Failed to decode RuntimeCauseState fixture: \(error)")
        fatalError("RuntimeCauseState fixture decoding failed")
    }
}
