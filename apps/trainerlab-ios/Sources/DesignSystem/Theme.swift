#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

/// Shared three-tier layout mode used by Sessions, Presets, and Summary modules.
/// Breakpoints: narrowPhone ≤390px, phone <820px, pad ≥820px or .regular size class.
public enum TrainerLabLayoutMode: Equatable {
    case narrowPhone
    case phone
    case pad

    public static func resolve(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Self {
        if horizontalSizeClass == .regular || width >= 820 {
            return .pad
        }
        if width <= 390 {
            return .narrowPhone
        }
        return .phone
    }
}

public enum TrainerLabTheme {
    public static let tacticalBackground = Color(red: 0.08, green: 0.10, blue: 0.13)
    public static let tacticalSurface = Color(red: 0.12, green: 0.15, blue: 0.20)
    public static let tacticalSurfaceElevated = Color(red: 0.16, green: 0.19, blue: 0.25)
    public static let tacticalBorder = Color(red: 0.25, green: 0.30, blue: 0.38)
    #if canImport(UIKit)
    public static let setupBackground = Color(uiColor: .systemGroupedBackground)
    public static let setupSurface = Color(uiColor: .systemBackground)
    #else
    public static let setupBackground = Color(red: 0.95, green: 0.96, blue: 0.97)
    public static let setupSurface = Color.white
    #endif

    public static let accentBlue = Color(red: 0.22, green: 0.56, blue: 0.94)
    public static let success = Color(red: 0.12, green: 0.66, blue: 0.32)
    public static let warning = Color(red: 0.90, green: 0.62, blue: 0.13)
    public static let danger = Color(red: 0.83, green: 0.23, blue: 0.23)

    public static let avpuAlert = Color.green
    public static let avpuVerbal = Color.orange
    public static let avpuPain = Color.red
    public static let avpuUnalert = Color.primary
}

public extension View {
    func trainerCardStyle(background: Color = TrainerLabTheme.tacticalSurface) -> some View {
        self
            .padding(12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TrainerLabTheme.tacticalBorder, lineWidth: 1)
            )
    }
}
