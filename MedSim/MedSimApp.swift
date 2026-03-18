//
//  MedSimApp.swift
//  MedSim
//
//  Created by Tyler Johnson on 2/8/26.
//

import AppShell
import SwiftUI
import UIKit

@main
struct MedSimApp: App {
    @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MedSimRootView()
        }
    }
}

private struct MedSimRootView: View {
    private let orientationCoordinator = OrientationCoordinator.shared

    var body: some View {
        AppShellRootView()
            .onPreferenceChange(AppShellOrientationPreferenceKey.self) { lock in
                orientationCoordinator.apply(lock: lock)
            }
            .onAppear {
                orientationCoordinator.reset()
            }
    }
}
