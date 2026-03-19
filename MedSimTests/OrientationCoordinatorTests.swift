import AppShell
@testable import MedSim
import UIKit
import XCTest

final class OrientationCoordinatorTests: XCTestCase {
    func testSystemLockAllowsPortraitAndLandscape() {
        XCTAssertEqual(
            OrientationCoordinator.mask(for: .system, idiom: .phone),
            .allButUpsideDown
        )
    }

    func testIPadLandscapeLockUsesLandscapeOnly() {
        XCTAssertEqual(
            OrientationCoordinator.mask(for: .iPadLandscape, idiom: .pad),
            [.landscapeLeft, .landscapeRight]
        )
    }

    func testPhoneIgnoresIPadLandscapeLock() {
        XCTAssertEqual(
            OrientationCoordinator.mask(for: .iPadLandscape, idiom: .phone),
            .allButUpsideDown
        )
    }
}
