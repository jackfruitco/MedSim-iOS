#if canImport(UIKit)
    import UIKit
#endif
import SwiftUI

enum ChatLabTheme {
    #if canImport(UIKit)
        static let systemBackground = Color(uiColor: .systemBackground)
    #else
        static let systemBackground = Color.white
    #endif
}

enum ChatLabSurfaceMode: Equatable {
    case narrowPhone
    case phone
    case pad

    static func resolve(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Self {
        if horizontalSizeClass == .regular || width >= 820 {
            return .pad
        }
        if width <= 390 {
            return .narrowPhone
        }
        return .phone
    }
}

enum ChatRunLayoutMode: Equatable {
    case compactMessenger
    case widePhoneMessenger
    case padWorkspace

    static func resolve(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Self {
        if horizontalSizeClass == .regular || width >= 820 {
            return .padWorkspace
        }
        if width <= 430 {
            return .compactMessenger
        }
        return .widePhoneMessenger
    }
}

enum ChatRunChromeMode: Equatable {
    case standard
    case keyboardCollapsed

    static func resolve(isKeyboardPresented: Bool) -> Self {
        isKeyboardPresented ? .keyboardCollapsed : .standard
    }
}

enum ChatToolsSection: String, CaseIterable {
    case activity
    case patientHistory
    case patientResults
    case simulationFeedback
    case simulationMetadata
    case requestLabs

    var title: String {
        switch self {
        case .activity:
            "Activity"
        case .patientHistory:
            "Patient History"
        case .patientResults:
            "Patient Results"
        case .simulationFeedback:
            "Simulation Feedback"
        case .simulationMetadata:
            "Simulation Metadata"
        case .requestLabs:
            "Request Labs"
        }
    }

    func defaultExpanded(for mode: ChatRunLayoutMode) -> Bool {
        switch mode {
        case .padWorkspace:
            true
        case .widePhoneMessenger:
            self == .activity || self == .patientResults || self == .requestLabs
        case .compactMessenger:
            self == .requestLabs
        }
    }
}
