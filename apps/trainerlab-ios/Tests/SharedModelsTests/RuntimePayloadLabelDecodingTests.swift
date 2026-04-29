import Foundation
import SharedModels
import XCTest

final class RuntimePayloadLabelDecodingTests: XCTestCase {
    func testRuntimeCauseStateDecodesAnatomyLateralityAndInjuryLocationLabels() throws {
        let json = """
        {
          "id": 11,
          "kind": "gunshot",
          "anatomical_location": "chest",
          "anatomical_location_label": "Chest",
          "laterality": "left",
          "laterality_label": "Left",
          "injury_location": "LLL",
          "injury_location_label": "Left Lower Leg"
        }
        """

        let cause = try JSONDecoder().decode(RuntimeCauseState.self, from: Data(json.utf8))

        XCTAssertEqual(cause.anatomicalLocation, "chest")
        XCTAssertEqual(cause.anatomicalLocationLabel, "Chest")
        XCTAssertEqual(cause.laterality, "left")
        XCTAssertEqual(cause.lateralityLabel, "Left")
        XCTAssertEqual(cause.injuryLocation, "LLL")
        XCTAssertEqual(cause.injuryLocationLabel, "Left Lower Leg")
    }

    func testRuntimeCauseStateDecodesWithoutOptionalLabels() throws {
        let json = """
        {
          "id": 11,
          "kind": "gunshot",
          "anatomical_location": "chest",
          "laterality": "left",
          "injury_location": "LLL"
        }
        """

        let cause = try JSONDecoder().decode(RuntimeCauseState.self, from: Data(json.utf8))

        XCTAssertEqual(cause.anatomicalLocation, "chest")
        XCTAssertNil(cause.anatomicalLocationLabel)
        XCTAssertEqual(cause.laterality, "left")
        XCTAssertNil(cause.lateralityLabel)
        XCTAssertEqual(cause.injuryLocation, "LLL")
        XCTAssertNil(cause.injuryLocationLabel)
    }

    func testRuntimeLocationDisplayPrependsLateralityWhenSeparate() {
        XCTAssertEqual(
            RuntimeLocationDisplay.locationText(
                preferredLabel: "Chest",
                rawLocation: "chest",
                lateralityLabel: "Left",
                laterality: "left",
                includesLateralityWhenSeparate: true,
            ),
            "Left Chest",
        )
    }

    func testRuntimeLocationDisplayDoesNotDuplicateLateralityInLocationLabel() {
        XCTAssertEqual(
            RuntimeLocationDisplay.locationText(
                preferredLabel: "Left Lower Leg",
                rawLocation: "LLL",
                lateralityLabel: "Left",
                laterality: "left",
                includesLateralityWhenSeparate: true,
            ),
            "Left Lower Leg",
        )
    }

    func testRuntimeAnatomicalLocationDisplayMapsKnownInjuryCodes() {
        XCTAssertEqual(
            RuntimeAnatomicalLocationDisplay.label(preferredLabel: nil, rawCode: "LLL"),
            "Left Lower Leg",
        )
        XCTAssertEqual(
            RuntimeAnatomicalLocationDisplay.label(preferredLabel: nil, rawCode: "TLA"),
            "Left Anterior Chest",
        )
        XCTAssertEqual(
            RuntimeAnatomicalLocationDisplay.label(preferredLabel: nil, rawCode: "JRN"),
            "Right Junctional Neck",
        )
    }

    func testRuntimeAnatomicalLocationDisplayNormalizesRawCodes() {
        XCTAssertEqual(
            RuntimeAnatomicalLocationDisplay.label(preferredLabel: nil, rawCode: "  lll  "),
            "Left Lower Leg",
        )
    }

    func testRuntimeAnatomicalLocationDisplayPrefersBackendLabel() {
        XCTAssertEqual(
            RuntimeAnatomicalLocationDisplay.label(
                preferredLabel: "Provider Supplied Location",
                rawCode: "LLL",
            ),
            "Provider Supplied Location",
        )
    }

    func testRuntimeAnatomicalLocationDisplayDoesNotDuplicateLaterality() {
        XCTAssertEqual(
            RuntimeAnatomicalLocationDisplay.label(
                preferredLabel: nil,
                rawCode: "LLL",
                lateralityLabel: "Left",
                laterality: "left",
                includeLateralityWhenSeparate: true,
            ),
            "Left Lower Leg",
        )
    }

    func testRuntimeProblemStateDecodesAnatomyAndLateralityLabels() throws {
        let json = """
        {
          "problem_id": 21,
          "title": "External hemorrhage",
          "anatomical_location": "LLL",
          "anatomical_location_label": "Left Lower Leg",
          "laterality": "left",
          "laterality_label": "Left",
          "status": "active"
        }
        """

        let problem = try JSONDecoder().decode(RuntimeProblemState.self, from: Data(json.utf8))

        XCTAssertEqual(problem.anatomicalLocation, "LLL")
        XCTAssertEqual(problem.anatomicalLocationLabel, "Left Lower Leg")
        XCTAssertEqual(problem.laterality, "left")
        XCTAssertEqual(problem.lateralityLabel, "Left")
    }

    func testRuntimeProblemStateDecodesWithoutOptionalLabels() throws {
        let json = """
        {
          "problem_id": 21,
          "title": "External hemorrhage",
          "anatomical_location": "LLL",
          "laterality": "left",
          "status": "active"
        }
        """

        let problem = try JSONDecoder().decode(RuntimeProblemState.self, from: Data(json.utf8))

        XCTAssertEqual(problem.anatomicalLocation, "LLL")
        XCTAssertNil(problem.anatomicalLocationLabel)
        XCTAssertEqual(problem.laterality, "left")
        XCTAssertNil(problem.lateralityLabel)
    }

    func testRuntimeAssessmentFindingStateDecodesAnatomyAndLateralityLabels() throws {
        let json = """
        {
          "finding_id": 31,
          "title": "Bleeding",
          "anatomical_location": "LLL",
          "anatomical_location_label": "Left Lower Leg",
          "laterality": "left",
          "laterality_label": "Left",
          "status": "present"
        }
        """

        let finding = try JSONDecoder().decode(RuntimeAssessmentFindingState.self, from: Data(json.utf8))

        XCTAssertEqual(finding.anatomicalLocation, "LLL")
        XCTAssertEqual(finding.anatomicalLocationLabel, "Left Lower Leg")
        XCTAssertEqual(finding.laterality, "left")
        XCTAssertEqual(finding.lateralityLabel, "Left")
    }

    func testRuntimeAssessmentFindingStateDecodesWithoutOptionalLabels() throws {
        let json = """
        {
          "finding_id": 31,
          "title": "Bleeding",
          "anatomical_location": "LLL",
          "laterality": "left",
          "status": "present"
        }
        """

        let finding = try JSONDecoder().decode(RuntimeAssessmentFindingState.self, from: Data(json.utf8))

        XCTAssertEqual(finding.anatomicalLocation, "LLL")
        XCTAssertNil(finding.anatomicalLocationLabel)
        XCTAssertEqual(finding.laterality, "left")
        XCTAssertNil(finding.lateralityLabel)
    }
}
