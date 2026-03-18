import SwiftUI

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
    case patientHistory
    case patientResults
    case simulationFeedback
    case simulationMetadata
    case requestLabs

    var title: String {
        switch self {
        case .patientHistory:
            return "Patient History"
        case .patientResults:
            return "Patient Results"
        case .simulationFeedback:
            return "Simulation Feedback"
        case .simulationMetadata:
            return "Simulation Metadata"
        case .requestLabs:
            return "Request Labs"
        }
    }

    func defaultExpanded(for mode: ChatRunLayoutMode) -> Bool {
        switch mode {
        case .padWorkspace:
            return true
        case .widePhoneMessenger:
            return self == .patientResults || self == .requestLabs
        case .compactMessenger:
            return self == .requestLabs
        }
    }
}
