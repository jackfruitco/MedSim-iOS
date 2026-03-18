import SwiftUI

public enum AppShellOrientationLock: Equatable, Sendable {
    case system
    case iPadLandscape
}

public struct AppShellOrientationPreferenceKey: PreferenceKey {
    public static let defaultValue: AppShellOrientationLock = .system

    public static func reduce(value: inout AppShellOrientationLock, nextValue: () -> AppShellOrientationLock) {
        let next = nextValue()
        if next != .system {
            value = next
        }
    }
}

public extension View {
    func appShellOrientationLock(_ lock: AppShellOrientationLock) -> some View {
        preference(key: AppShellOrientationPreferenceKey.self, value: lock)
    }
}
