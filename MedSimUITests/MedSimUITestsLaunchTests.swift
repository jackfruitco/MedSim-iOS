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
    func testChatRunAndToolsTrayScreenshots() {
        let app = XCUIApplication()
        app.launchArguments += ["-readme-screenshot-screen", "chat-run"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["chat-message-timeline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chat-more-tools-button"].waitForExistence(timeout: 5))
        attachScreenshot(from: app, named: "ChatRun Conversation")

        app.buttons["chat-more-tools-button"].tap()
        XCTAssertTrue(app.buttons["chat-tool-patientResults"].waitForExistence(timeout: 3))
        attachScreenshot(from: app, named: "ChatRun Tools Tray")
    }

    @MainActor
    func testChatRunDarkModeScreenshot() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-readme-screenshot-screen", "chat-run",
            "-AppleInterfaceStyle", "Dark",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["chat-message-timeline"].waitForExistence(timeout: 5))
        attachScreenshot(from: app, named: "ChatRun Dark Mode")
    }

    @MainActor
    func testChatRunAccessibilityTextScreenshot() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-readme-screenshot-screen", "chat-run",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["chat-message-timeline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chat-more-tools-button"].isHittable)
        attachScreenshot(from: app, named: "ChatRun Accessibility Text")
    }

    @MainActor
    func testChatRunLandscapeScreenshot() {
        let app = XCUIApplication()
        app.launchArguments += ["-readme-screenshot-screen", "chat-run"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }

        XCTAssertTrue(app.descendants(matching: .any)["chat-message-timeline"].waitForExistence(timeout: 5))
        attachScreenshot(from: app, named: "ChatRun Landscape")
    }

    @MainActor
    func testChatRunAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-readme-screenshot-screen", "chat-run"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["chat-message-timeline"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(
            for: [.contrast, .dynamicType, .hitRegion, .sufficientElementDescription, .textClipped],
        ) { issue in
            print("Accessibility audit issue: \(String(reflecting: issue))")
            dump(issue)
            return false
        }
    }

    @MainActor
    private func attachScreenshot(from app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
