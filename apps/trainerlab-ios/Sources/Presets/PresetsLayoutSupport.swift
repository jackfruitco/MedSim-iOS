import DesignSystem
import SharedModels
import SwiftUI

typealias PresetsLayoutMode = TrainerLabLayoutMode

enum PresetsWorkspaceSelection {
    static func resolvedSelectionID(
        currentSelectionID: Int?,
        presets: [ScenarioInstruction],
        layoutMode: PresetsLayoutMode
    ) -> Int? {
        if let currentSelectionID, presets.contains(where: { $0.id == currentSelectionID }) {
            return currentSelectionID
        }
        if layoutMode == .pad {
            return presets.first?.id
        }
        return nil
    }
}
