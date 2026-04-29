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

public enum TrainerLabSurfaceRole: Equatable {
    case setupCard
    case tacticalPanel
    case floatingOverlay
    case chip

    var fallbackBackground: Color {
        switch self {
        case .setupCard:
            TrainerLabTheme.setupSurface
        case .tacticalPanel:
            TrainerLabTheme.tacticalSurfaceElevated
        case .floatingOverlay:
            TrainerLabTheme.setupSurface.opacity(0.86)
        case .chip:
            Color.secondary.opacity(0.08)
        }
    }

    var strokeColor: Color {
        switch self {
        case .setupCard:
            Color.primary.opacity(0.08)
        case .tacticalPanel:
            TrainerLabTheme.tacticalBorder
        case .floatingOverlay:
            Color.primary.opacity(0.10)
        case .chip:
            Color.primary.opacity(0.07)
        }
    }
}

public extension View {
    func trainerGlassSurface(
        role: TrainerLabSurfaceRole,
        cornerRadius: CGFloat = 14,
        interactive: Bool = false,
        tint: Color? = nil,
    ) -> some View {
        modifier(
            TrainerLabGlassSurfaceModifier(
                role: role,
                cornerRadius: cornerRadius,
                interactive: interactive,
                tint: tint,
            ),
        )
    }

    func trainerCardStyle(
        background: Color = TrainerLabTheme.tacticalSurface,
        glassRole: TrainerLabSurfaceRole? = nil,
        cornerRadius: CGFloat = 14,
        interactive: Bool = false,
        tint: Color? = nil,
    ) -> some View {
        modifier(
            TrainerLabCardStyleModifier(
                background: background,
                glassRole: glassRole,
                cornerRadius: cornerRadius,
                interactive: interactive,
                tint: tint,
            ),
        )
    }

    @ViewBuilder
    func trainerGlassButtonStyle(prominent: Bool = false) -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                if prominent {
                    buttonStyle(.glassProminent)
                } else {
                    buttonStyle(.glass)
                }
            } else if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        #else
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        #endif
    }
}

private struct TrainerLabCardStyleModifier: ViewModifier {
    let background: Color
    let glassRole: TrainerLabSurfaceRole?
    let cornerRadius: CGFloat
    let interactive: Bool
    let tint: Color?

    func body(content: Content) -> some View {
        let paddedContent = content.padding(12)

        if let glassRole {
            paddedContent
                .trainerGlassSurface(
                    role: glassRole,
                    cornerRadius: cornerRadius,
                    interactive: interactive,
                    tint: tint,
                )
        } else {
            paddedContent
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(TrainerLabTheme.tacticalBorder, lineWidth: 1),
                )
        }
    }
}

private struct TrainerLabGlassSurfaceModifier: ViewModifier {
    let role: TrainerLabSurfaceRole
    let cornerRadius: CGFloat
    let interactive: Bool
    let tint: Color?

    func body(content: Content) -> some View {
        glassSurface(content)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(role.strokeColor, lineWidth: 1),
            )
    }

    @ViewBuilder
    private func glassSurface(_ content: Content) -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(
                        glassConfiguration,
                        in: .rect(cornerRadius: cornerRadius),
                    )
            } else {
                fallbackSurface(content)
            }
        #else
            fallbackSurface(content)
        #endif
    }

    private func fallbackSurface(_ content: Content) -> some View {
        content
            .background(fallbackBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var fallbackBackground: AnyShapeStyle {
        switch role {
        case .floatingOverlay:
            return AnyShapeStyle(.regularMaterial)
        default:
            return AnyShapeStyle(role.fallbackBackground)
        }
    }

    #if os(iOS)
        @available(iOS 26.0, *)
        private var glassConfiguration: Glass {
            var glass = Glass.regular
            if let tint {
                glass = glass.tint(tint)
            }
            if interactive {
                glass = glass.interactive()
            }
            return glass
        }
    #endif
}
