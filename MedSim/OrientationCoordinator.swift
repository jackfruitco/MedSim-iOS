import AppShell
import UIKit

final class OrientationAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _: UIApplication,
        supportedInterfaceOrientationsFor _: UIWindow?,
    ) -> UIInterfaceOrientationMask {
        OrientationCoordinator.shared.supportedOrientations
    }
}

final class OrientationCoordinator {
    static let shared = OrientationCoordinator()

    private(set) var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown

    private init() {}

    func apply(lock: AppShellOrientationLock) {
        let next = Self.mask(for: lock)
        guard next != supportedOrientations else { return }
        supportedOrientations = next
        updateSystemOrientation()
    }

    func reset() {
        apply(lock: .system)
    }

    static func mask(for lock: AppShellOrientationLock) -> UIInterfaceOrientationMask {
        mask(for: lock, idiom: UIDevice.current.userInterfaceIdiom)
    }

    static func mask(for lock: AppShellOrientationLock, idiom: UIUserInterfaceIdiom) -> UIInterfaceOrientationMask {
        switch lock {
        case .system:
            .allButUpsideDown
        case .iPadLandscape:
            idiom == .pad ? [.landscapeLeft, .landscapeRight] : .allButUpsideDown
        }
    }

    private func updateSystemOrientation() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            return
        }

        if #available(iOS 16.0, *) {
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: supportedOrientations)
            windowScene.requestGeometryUpdate(preferences) { _ in }
        }

        windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        UIViewController.attemptRotationToDeviceOrientation()
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first(where: \.isKeyWindow)
    }
}
