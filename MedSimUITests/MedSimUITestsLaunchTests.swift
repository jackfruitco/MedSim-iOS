//
//  MedSimUITestsLaunchTests.swift
//  MedSimUITests
//
//  Created by Tyler Johnson on 2/8/26.
//

import XCTest

final class MedSimUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting-reset-auth")
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testReadmeAuthScreenshot() {
        let app = XCUIApplication()
        app.launchArguments += ["-readme-screenshot-screen", "auth"]
        app.launch()

        XCTAssertTrue(app.staticTexts["auth-brand-title"].waitForExistence(timeout: 5))
        attachScreenshot(from: app, named: "README Auth")
    }

    @MainActor
    func testReadmeTrainerHubScreenshot() {
        let app = XCUIApplication()
        app.launchArguments += ["-readme-screenshot-screen", "trainer-hub"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Session Hub"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create Session"].waitForExistence(timeout: 5))
        attachScreenshot(from: app, named: "README Trainer Hub")
    }

    @MainActor
    func testReadmeChatLabScreenshot() {
        let app = XCUIApplication()
        app.launchArguments += ["-readme-screenshot-screen", "chat-lab"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ChatLab"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Jordan Alvarez"].waitForExistence(timeout: 5))
        attachScreenshot(from: app, named: "README ChatLab")
    }

    @MainActor
    private func attachScreenshot(from app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
