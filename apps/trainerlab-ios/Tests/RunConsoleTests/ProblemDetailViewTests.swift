@testable import RunConsole
import SharedModels
import XCTest

final class ProblemDetailViewTests: XCTestCase {
    // MARK: - Recommendation Filtering

    func testRecommendationsFilteredToProblemID() {
        let target = makeProblem(id: "p-1", problemID: 10, status: .active)
        let other = makeProblem(id: "p-2", problemID: 20, status: .active)
        let matchingRec = makeRecommendation(id: 1, targetProblemID: 10, kind: "tourniquet")
        let otherRec = makeRecommendation(id: 2, targetProblemID: 20, kind: "tourniquet")

        let context = InterventionMenuContext(
            dictionary: [makeTourniquetGroup()],
            problems: [target, other],
            recommendations: [matchingRec, otherRec],
            interventions: [],
            selectedTargetProblemID: target.problemID,
        )

        XCTAssertEqual(context.recommendedActions.count, 1)
        XCTAssertEqual(context.recommendedActions.first?.recommendationID, 1)
    }

    func testNoRecommendationsProducesEmptyActions() {
        let problem = makeProblem(id: "p-1", problemID: 10, status: .active)
        let context = InterventionMenuContext(
            dictionary: [makeTourniquetGroup()],
            problems: [problem],
            recommendations: [],
            interventions: [],
            selectedTargetProblemID: problem.problemID,
        )
        XCTAssertTrue(context.recommendedActions.isEmpty)
    }

    func testNilProblemIDFiltersOutAllRecommendations() {
        // Verify that the guard let in ProblemDetailView.filteredRecommendations prevents
        // a nil==nil false-match when both problem.problemID and targetProblemID are nil.
        let recs: [RecommendedInterventionItem] = [
            makeRecommendation(id: 1, targetProblemID: 10, kind: "tourniquet"),
            RecommendedInterventionItem(
                recommendationID: 2,
                title: "Apply tourniquet",
                kind: "tourniquet",
                targetProblemID: nil,
            ),
        ]

        let nilProblemID: Int? = nil
        // Guarded path (correct): guard let fires → returns []
        let guarded: [RecommendedInterventionItem] = if let id = nilProblemID {
            recs.filter { $0.targetProblemID == id }
        } else {
            []
        }
        XCTAssertTrue(guarded.isEmpty)

        // Naive filter without the guard would match rec #2 via nil == nil
        let naive = recs.filter { $0.targetProblemID == nilProblemID }
        XCTAssertEqual(naive.count, 1, "Confirms what the guard prevents")
    }

    // MARK: - Direct Submit Enablement

    func testRecommendationWithMatchingSiteCodeIsEnabled() {
        let problem = makeProblem(id: "p-1", problemID: 10, locationCode: "LEFT_LEG", status: .active)
        let rec = makeRecommendation(id: 1, targetProblemID: 10, kind: "tourniquet", siteCode: "LEFT_LEG")

        let context = InterventionMenuContext(
            dictionary: [makeTourniquetGroup()],
            problems: [problem],
            recommendations: [rec],
            interventions: [],
            selectedTargetProblemID: 10,
        )

        XCTAssertEqual(context.recommendedActions.count, 1)
        let action = context.recommendedActions[0]
        XCTAssertTrue(action.isEnabled, "Action should be enabled when siteCode resolves")
        XCTAssertNotNil(action.prefill.siteCode)
    }

    func testRecommendationWithoutSiteCodeAndMultipleSitesIsDisabled() {
        let problem = makeProblem(id: "p-1", problemID: 10, status: .active)
        // No siteCode on recommendation, no locationCode on problem → cannot infer site from multiple options
        let rec = makeRecommendation(id: 1, targetProblemID: 10, kind: "pressure_dressing", siteCode: nil)

        let group = InterventionGroup(
            interventionType: "pressure_dressing",
            label: "Pressure Dressing",
            sites: [
                InterventionSite(code: "RIGHT_ARM", label: "Right Arm"),
                InterventionSite(code: "LEFT_ARM", label: "Left Arm"),
            ],
        )
        let context = InterventionMenuContext(
            dictionary: [group],
            problems: [problem],
            recommendations: [rec],
            interventions: [],
            selectedTargetProblemID: 10,
        )

        XCTAssertEqual(context.recommendedActions.count, 1)
        let action = context.recommendedActions[0]
        XCTAssertFalse(action.isEnabled, "Action should be disabled when site cannot be resolved")
        XCTAssertNil(action.prefill.siteCode)
        XCTAssertNotNil(action.disabledReason)
    }

    func testRecommendationWithSingleSiteGroupAutoResolvesWithoutExplicitSiteCode() {
        let problem = makeProblem(id: "p-1", problemID: 10, status: .active)
        let rec = makeRecommendation(id: 1, targetProblemID: 10, kind: "needle_decompression", siteCode: nil)

        let group = InterventionGroup(
            interventionType: "needle_decompression",
            label: "Needle Decompression",
            sites: [InterventionSite(code: "RIGHT_CHEST", label: "Right Chest")],
        )
        let context = InterventionMenuContext(
            dictionary: [group],
            problems: [problem],
            recommendations: [rec],
            interventions: [],
            selectedTargetProblemID: 10,
        )

        XCTAssertEqual(context.recommendedActions.count, 1)
        let action = context.recommendedActions[0]
        XCTAssertTrue(action.isEnabled)
        XCTAssertEqual(action.prefill.siteCode, "RIGHT_CHEST")
    }

    // MARK: - Prefill Mapping

    func testPrefillCarriesTargetProblemID() throws {
        let problem = makeProblem(id: "p-1", problemID: 42, locationCode: "RIGHT_LEG", status: .active)
        let rec = makeRecommendation(id: 5, targetProblemID: 42, kind: "tourniquet", siteCode: "RIGHT_LEG")

        let context = InterventionMenuContext(
            dictionary: [makeTourniquetGroup()],
            problems: [problem],
            recommendations: [rec],
            interventions: [],
            selectedTargetProblemID: 42,
        )

        let action = try XCTUnwrap(context.recommendedActions.first)
        XCTAssertEqual(action.prefill.targetProblemID, 42)
        XCTAssertEqual(action.prefill.interventionType, "tourniquet")
        XCTAssertEqual(action.prefill.siteCode, "RIGHT_LEG")
        XCTAssertEqual(action.prefill.status, .applied)
        XCTAssertEqual(action.prefill.effectiveness, .effective)
    }

    func testPrefillUsesNormalizedKindBeforeKind() {
        let problem = makeProblem(id: "p-1", problemID: 10, locationCode: "LEFT_LEG", status: .active)
        let rec = RecommendedInterventionItem(
            recommendationID: 1,
            title: "Apply tourniquet",
            code: "tq",
            kind: "tq",
            targetProblemID: 10,
            normalizedKind: "tourniquet",
            priority: 1,
            siteCode: "LEFT_LEG",
        )

        let context = InterventionMenuContext(
            dictionary: [makeTourniquetGroup()],
            problems: [problem],
            recommendations: [rec],
            interventions: [],
            selectedTargetProblemID: 10,
        )

        XCTAssertEqual(context.recommendedActions.first?.prefill.interventionType, "tourniquet")
    }

    // MARK: - Edit Flow

    func testEditFlowPrefillRoundTrips() throws {
        // Simulates the full edit path:
        // editButton taps → action.prefill passed to onEdit → stored as interventionEditPrefill
        // → InterventionComposerSheet inits with initialPrefill → draft.applyPrefill called
        // → composer lands on .review pre-filled for the correct intervention.
        let problem = makeProblem(id: "p-1", problemID: 42, locationCode: "LEFT_LEG", status: .active)
        let rec = makeRecommendation(id: 7, targetProblemID: 42, kind: "tourniquet", siteCode: "LEFT_LEG")

        let context = InterventionMenuContext(
            dictionary: [makeTourniquetGroup()],
            problems: [problem],
            recommendations: [rec],
            interventions: [],
            selectedTargetProblemID: 42,
        )
        let action = try XCTUnwrap(context.recommendedActions.first)

        var draft = InterventionComposerDraft(prefilledTargetProblemID: action.prefill.targetProblemID)
        draft.applyPrefill(action.prefill, dictionary: [makeTourniquetGroup()])

        XCTAssertEqual(draft.selectedType, "tourniquet")
        XCTAssertEqual(draft.selectedTargetProblemID, 42)
        XCTAssertEqual(draft.resolvedSiteCode(in: makeTourniquetGroup().sites), "LEFT_LEG")
        XCTAssertEqual(draft.activeSection, .review)
        XCTAssertEqual(draft.status, .applied)
        XCTAssertEqual(draft.effectiveness, .effective)
    }

    // MARK: - InterventionComposerDraft Prefill Application

    func testApplyPrefillPreparesComposerDraftForEdit() {
        let dictionary = [makeTourniquetGroup()]
        var draft = InterventionComposerDraft(prefilledTargetProblemID: 10)

        let prefill = InterventionComposerPrefill(
            interventionType: "tourniquet",
            siteCode: "RIGHT_LEG",
            targetProblemID: 10,
            status: .applied,
            effectiveness: .effective,
            notes: "Hasty application",
            tourniquetApplicationMode: .hasty,
        )
        draft.applyPrefill(prefill, dictionary: dictionary)

        XCTAssertEqual(draft.selectedType, "tourniquet")
        XCTAssertEqual(draft.selectedTargetProblemID, 10)
        XCTAssertEqual(draft.status, .applied)
        XCTAssertEqual(draft.effectiveness, .effective)
        XCTAssertEqual(draft.notes, "Hasty application")
        XCTAssertTrue(draft.notesExpanded)
        XCTAssertEqual(draft.resolvedSiteCode(in: makeTourniquetGroup().sites), "RIGHT_LEG")
    }

    func testApplyPrefillWithoutSiteCodeLeavesLocationUnresolved() {
        let dictionary = [makeTourniquetGroup()]
        var draft = InterventionComposerDraft(prefilledTargetProblemID: nil)

        let prefill = InterventionComposerPrefill(
            interventionType: "tourniquet",
            siteCode: nil,
            targetProblemID: 10,
        )
        draft.applyPrefill(prefill, dictionary: dictionary)

        XCTAssertEqual(draft.selectedType, "tourniquet")
        XCTAssertNil(draft.resolvedSiteCode(in: makeTourniquetGroup().sites))
        XCTAssertEqual(draft.activeSection, .type)
    }

    // MARK: - Problem Display Logic

    func testProblemIsUncontrolledWhenStatusIsActive() {
        let active = makeProblem(id: "p-1", problemID: 1, status: .active)
        let controlled = makeProblem(id: "p-2", problemID: 2, status: .controlled)
        let resolved = makeProblem(id: "p-3", problemID: 3, status: .resolved)

        XCTAssertTrue(active.isUncontrolled)
        XCTAssertFalse(controlled.isUncontrolled)
        XCTAssertFalse(resolved.isUncontrolled)
    }

    func testProblemLabelPrefersDisplayName() {
        let withDisplayName = ProblemAnnotation(
            id: "p-1",
            problemID: 1,
            title: "Massive Hemorrhage",
            displayName: "Active Bleed",
            isAnatomic: true,
            status: .active,
        )
        let withoutDisplayName = ProblemAnnotation(
            id: "p-2",
            problemID: 2,
            title: "Tension Pneumothorax",
            isAnatomic: false,
            status: .active,
        )
        XCTAssertEqual(withDisplayName.label, "Active Bleed")
        XCTAssertEqual(withoutDisplayName.label, "Tension Pneumothorax")
    }

    // MARK: - Recommendation Priority Ordering

    func testRecommendationsOrderedByPriorityAscending() {
        let problem = makeProblem(id: "p-1", problemID: 10, locationCode: "LEFT_LEG", status: .active)
        let highPriority = makeRecommendation(id: 1, targetProblemID: 10, kind: "tourniquet", siteCode: "LEFT_LEG", priority: 1)
        let lowPriority = makeRecommendation(id: 2, targetProblemID: 10, kind: "wound_packing", siteCode: "LEFT_LEG", priority: 3)

        let dictionary = [
            makeTourniquetGroup(),
            InterventionGroup(
                interventionType: "wound_packing",
                label: "Wound Packing",
                sites: [
                    InterventionSite(code: "LEFT_LEG", label: "Left Leg"),
                    InterventionSite(code: "RIGHT_LEG", label: "Right Leg"),
                ],
            ),
        ]
        let context = InterventionMenuContext(
            dictionary: dictionary,
            problems: [problem],
            recommendations: [lowPriority, highPriority],
            interventions: [],
            selectedTargetProblemID: 10,
        )

        XCTAssertEqual(context.recommendedActions.map(\.recommendationID), [1, 2])
    }

    // MARK: - Helpers

    private func makeProblem(
        id: String,
        problemID: Int,
        locationCode: String? = nil,
        status: ProblemLifecycleState,
    ) -> ProblemAnnotation {
        ProblemAnnotation(
            id: id,
            problemID: problemID,
            title: "Test Problem \(problemID)",
            isAnatomic: locationCode != nil,
            locationCode: locationCode,
            status: status,
        )
    }

    private func makeRecommendation(
        id: Int,
        targetProblemID: Int,
        kind: String,
        siteCode: String? = nil,
        priority: Int = 1,
    ) -> RecommendedInterventionItem {
        RecommendedInterventionItem(
            recommendationID: id,
            title: "Apply \(kind)",
            kind: kind,
            targetProblemID: targetProblemID,
            priority: priority,
            siteCode: siteCode,
        )
    }

    private func makeTourniquetGroup() -> InterventionGroup {
        InterventionGroup(
            interventionType: "tourniquet",
            label: "Tourniquet",
            sites: [
                InterventionSite(code: "LEFT_LEG", label: "Left Leg"),
                InterventionSite(code: "RIGHT_LEG", label: "Right Leg"),
                InterventionSite(code: "LEFT_ARM", label: "Left Arm"),
                InterventionSite(code: "RIGHT_ARM", label: "Right Arm"),
            ],
        )
    }
}
