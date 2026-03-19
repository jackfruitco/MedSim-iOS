//
//  MedSimUITests.swift
//  MedSimUITests
//
//  Created by Tyler Johnson on 2/8/26.
//

import XCTest

final class MedSimUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsMedSimBrandingOnAuthGate() {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting-reset-auth")
        app.launch()

        XCTAssertTrue(app.staticTexts["auth-brand-title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["auth-brand-title"].label, "MedSim")
        XCTAssertTrue(app.staticTexts["auth-brand-subtitle"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        throw XCTSkip("Launch performance measurement is unstable in merge-gating simulator runs; launch coverage remains in the UI smoke tests.")
    }
}
