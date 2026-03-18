import SwiftUI
@testable import Summary
import XCTest

final class RunSummaryLayoutSupportTests: XCTestCase {
    func testRunSummaryLayoutUsesPadForRegularOrWideWidth() {
        XCTAssertEqual(RunSummaryLayoutMode.resolve(width: 900, horizontalSizeClass: .compact), .pad)
        XCTAssertEqual(RunSummaryLayoutMode.resolve(width: 768, horizontalSizeClass: .regular), .pad)
    }

    func testRunSummaryLayoutSeparatesPhoneTiers() {
        XCTAssertEqual(RunSummaryLayoutMode.resolve(width: 375, horizontalSizeClass: .compact), .narrowPhone)
        XCTAssertEqual(RunSummaryLayoutMode.resolve(width: 430, horizontalSizeClass: .compact), .phone)
    }

    func testRunSummarySectionDefaultsCollapseCommandLogOnPhone() {
        XCTAssertTrue(RunSummarySection.timeline.defaultExpanded(for: .phone))
        XCTAssertFalse(RunSummarySection.commandLog.defaultExpanded(for: .phone))
        XCTAssertTrue(RunSummarySection.commandLog.defaultExpanded(for: .pad))
    }
}
