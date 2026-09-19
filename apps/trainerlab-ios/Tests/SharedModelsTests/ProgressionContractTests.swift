import Foundation
import SharedModels
import XCTest

final class ProgressionContractTests: XCTestCase {
    func testPlanDecodesPortrayalAndActiveClockExpiry() throws {
        let json = """
        {"status":"active","version":3,"ends_at":90,
         "portrayal":{"behavior":"Restless","speech":"I feel dizzy"}}
        """
        let plan = try JSONDecoder().decode(ProgressionPlanDTO.self, from: Data(json.utf8))
        XCTAssertEqual(plan.version, 3)
        XCTAssertEqual(plan.endsAt, 90)
        XCTAssertEqual(plan.portrayal?.behavior, "Restless")
        XCTAssertEqual(plan.portrayal?.speech, "I feel dizzy")
    }

    func testEmptyAndExpiredPlansDoNotRequirePortrayal() throws {
        let empty = try JSONDecoder().decode(ProgressionPlanDTO.self, from: Data("{}".utf8))
        XCTAssertEqual(empty.status, "awaiting_plan")
        XCTAssertNil(empty.portrayal)
        let expired = try JSONDecoder().decode(ProgressionPlanDTO.self, from: Data(#"{"status":"expired","portrayal":{}}"#.utf8))
        XCTAssertEqual(expired.portrayal?.behavior, "")
        XCTAssertEqual(expired.portrayal?.speech, "")
    }

    func testDecisionIsSeparateFromAuthoritativePatientState() throws {
        let json = #"{"id":4,"title":"Hypoxia","description":"A possible branch","status":"pending"}"#
        let decision = try JSONDecoder().decode(ScenarioDecisionDTO.self, from: Data(json.utf8))
        XCTAssertEqual(decision.id, 4)
        XCTAssertEqual(decision.status, "pending")
        let body = try JSONEncoder().encode(ScenarioDecisionRequest(approved: false))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: Bool], ["approved": false])
    }
}
