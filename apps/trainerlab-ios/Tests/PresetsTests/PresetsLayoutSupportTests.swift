@testable import Presets
import SharedModels
import SwiftUI
import XCTest

final class PresetsLayoutSupportTests: XCTestCase {
    func testPresetsLayoutUsesPadForRegularOrWideWidth() {
        XCTAssertEqual(PresetsLayoutMode.resolve(width: 900, horizontalSizeClass: .compact), .pad)
        XCTAssertEqual(PresetsLayoutMode.resolve(width: 768, horizontalSizeClass: .regular), .pad)
    }

    func testPresetsLayoutSeparatesNarrowPhoneAndPhone() {
        XCTAssertEqual(PresetsLayoutMode.resolve(width: 375, horizontalSizeClass: .compact), .narrowPhone)
        XCTAssertEqual(PresetsLayoutMode.resolve(width: 430, horizontalSizeClass: .compact), .phone)
    }

    func testSelectionDefaultsToFirstPresetOnPadOnly() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let presets = try decoder.decode(
            [ScenarioInstruction].self,
            from: Data(
                """
                [
                  {
                    "id": 9,
                    "owner_id": 1,
                    "title": "A",
                    "description": "A",
                    "instruction_text": "A",
                    "injuries": [],
                    "severity": "moderate",
                    "metadata": {},
                    "is_active": true,
                    "permissions": [],
                    "created_at": "2026-03-12T12:00:00Z",
                    "modified_at": "2026-03-12T12:00:00Z"
                  },
                  {
                    "id": 11,
                    "owner_id": 1,
                    "title": "B",
                    "description": "B",
                    "instruction_text": "B",
                    "injuries": [],
                    "severity": "high",
                    "metadata": {},
                    "is_active": true,
                    "permissions": [],
                    "created_at": "2026-03-12T12:00:00Z",
                    "modified_at": "2026-03-12T12:00:00Z"
                  }
                ]
                """.utf8
            )
        )

        XCTAssertEqual(
            PresetsWorkspaceSelection.resolvedSelectionID(currentSelectionID: nil, presets: presets, layoutMode: .pad),
            9
        )
        XCTAssertNil(
            PresetsWorkspaceSelection.resolvedSelectionID(currentSelectionID: nil, presets: presets, layoutMode: .phone)
        )
        XCTAssertEqual(
            PresetsWorkspaceSelection.resolvedSelectionID(currentSelectionID: 11, presets: presets, layoutMode: .pad),
            11
        )
    }
}
