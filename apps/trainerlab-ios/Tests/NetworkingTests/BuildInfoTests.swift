import Foundation
@testable import Networking
import XCTest

final class BuildInfoResponseTests: XCTestCase {
    func testDecodesBuildInfoResponse() throws {
        let json = Data(
            #"""
            {
              "backend": {
                "version": "0.14.2",
                "commit": "abc1234def5678",
                "build_time": "2026-04-09T17:12:44Z"
              },
              "orchestrai": {
                "version": "1.9.0"
              }
            }
            """#.utf8,
        )

        let response = try JSONDecoder().decode(BuildInfoResponse.self, from: json)

        XCTAssertEqual(response.backend?.version, "0.14.2")
        XCTAssertEqual(response.backend?.commit, "abc1234def5678")
        XCTAssertEqual(response.backend?.buildTime, "2026-04-09T17:12:44Z")
        XCTAssertEqual(response.orchestrai?.version, "1.9.0")
    }

    func testDecodesNullBuildInfoSections() throws {
        let json = Data(#"{"backend":null,"orchestrai":null}"#.utf8)

        let response = try JSONDecoder().decode(BuildInfoResponse.self, from: json)

        XCTAssertNil(response.backend)
        XCTAssertNil(response.orchestrai)
    }

    func testDecodesNullBuildInfoFields() throws {
        let json = Data(
            #"""
            {
              "backend": {
                "version": null,
                "commit": null,
                "build_time": null
              },
              "orchestrai": {
                "version": null
              }
            }
            """#.utf8,
        )

        let response = try JSONDecoder().decode(BuildInfoResponse.self, from: json)

        XCTAssertNil(response.backend?.version)
        XCTAssertNil(response.backend?.commit)
        XCTAssertNil(response.backend?.buildTime)
        XCTAssertNil(response.orchestrai?.version)
    }

    func testSystemAPIBuildInfoRouteUsesExpectedContract() {
        let endpoint = SystemAPI.buildInfo()

        XCTAssertEqual(endpoint.path, "/api/v1/build-info/")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertFalse(endpoint.requiresAuth)
        XCTAssertFalse(endpoint.requiresAccountContext)
    }
}
