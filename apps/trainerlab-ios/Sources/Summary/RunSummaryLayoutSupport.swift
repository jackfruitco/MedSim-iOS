import DesignSystem
import SwiftUI

typealias RunSummaryLayoutMode = TrainerLabLayoutMode

enum RunSummarySection: String, CaseIterable {
    case timeline
    case commandLog

    func defaultExpanded(for layoutMode: RunSummaryLayoutMode) -> Bool {
        switch layoutMode {
        case .pad:
            return true
        case .phone, .narrowPhone:
            return self == .timeline
        }
    }
}
