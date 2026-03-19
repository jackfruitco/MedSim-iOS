import DesignSystem
import SwiftUI

typealias RunSummaryLayoutMode = TrainerLabLayoutMode

enum RunSummarySection: String, CaseIterable {
    case timeline
    case commandLog

    func defaultExpanded(for layoutMode: RunSummaryLayoutMode) -> Bool {
        switch layoutMode {
        case .pad:
            true
        case .phone, .narrowPhone:
            self == .timeline
        }
    }
}
