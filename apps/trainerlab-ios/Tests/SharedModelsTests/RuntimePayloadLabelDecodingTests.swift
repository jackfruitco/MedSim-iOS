import Foundation
import SharedModels
import XCTest

final class RuntimePayloadLabelDecodingTests: XCTestCase {
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
