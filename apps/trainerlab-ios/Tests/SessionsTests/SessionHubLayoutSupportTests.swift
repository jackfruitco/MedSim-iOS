@testable import Sessions
import SwiftUI
import XCTest

final class SessionHubLayoutSupportTests: XCTestCase {
    func testSessionHubLayoutUsesPadForRegularOrWideWidth() {
        XCTAssertEqual(SessionHubLayoutMode.resolve(width: 900, horizontalSizeClass: .compact), .pad)
        XCTAssertEqual(SessionHubLayoutMode.resolve(width: 768, horizontalSizeClass: .regular), .pad)
    }

    func testSessionHubLayoutSeparatesNarrowPhoneAndPhone() {
        XCTAssertEqual(SessionHubLayoutMode.resolve(width: 375, horizontalSizeClass: .compact), .narrowPhone)
        XCTAssertEqual(SessionHubLayoutMode.resolve(width: 430, horizontalSizeClass: .compact), .phone)
    }
}
