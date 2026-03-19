@testable import ChatLabiOS
import SwiftUI
import XCTest

final class ChatLayoutSupportTests: XCTestCase {
    func testSurfaceModeUsesPadForRegularOrWideLayout() {
        XCTAssertEqual(ChatLabSurfaceMode.resolve(width: 900, horizontalSizeClass: .compact), .pad)
        XCTAssertEqual(ChatLabSurfaceMode.resolve(width: 768, horizontalSizeClass: .regular), .pad)
    }

    func testSurfaceModeDistinguishesNarrowAndPhone() {
        XCTAssertEqual(ChatLabSurfaceMode.resolve(width: 375, horizontalSizeClass: .compact), .narrowPhone)
        XCTAssertEqual(ChatLabSurfaceMode.resolve(width: 430, horizontalSizeClass: .compact), .phone)
    }

    func testRunLayoutModeUsesThreeTiers() {
        XCTAssertEqual(ChatRunLayoutMode.resolve(width: 390, horizontalSizeClass: .compact), .compactMessenger)
        XCTAssertEqual(ChatRunLayoutMode.resolve(width: 480, horizontalSizeClass: .compact), .widePhoneMessenger)
        XCTAssertEqual(ChatRunLayoutMode.resolve(width: 900, horizontalSizeClass: .compact), .padWorkspace)
    }

    func testToolSectionDefaultsMatchLayoutMode() {
        XCTAssertTrue(ChatToolsSection.requestLabs.defaultExpanded(for: .compactMessenger))
        XCTAssertFalse(ChatToolsSection.patientHistory.defaultExpanded(for: .compactMessenger))
        XCTAssertTrue(ChatToolsSection.patientResults.defaultExpanded(for: .widePhoneMessenger))
        XCTAssertTrue(ChatToolsSection.simulationMetadata.defaultExpanded(for: .padWorkspace))
    }

    func testChromeModeCollapsesWhenKeyboardIsPresented() {
        XCTAssertEqual(ChatRunChromeMode.resolve(isKeyboardPresented: true), .keyboardCollapsed)
        XCTAssertEqual(ChatRunChromeMode.resolve(isKeyboardPresented: false), .standard)
    }
}
