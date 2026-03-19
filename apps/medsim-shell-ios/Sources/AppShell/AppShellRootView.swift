import Auth
import ChatLabiOS
import DesignSystem
import Presets
import RunConsole
import Sessions
import SharedModels
import Summary
import SwiftUI

public struct AppShellRootView: View {
    private enum InternalApp {
        case trainerLab
        case chatLab
    }

    @StateObject private var model = AppShellModel()
    @State private var showEnvironment = false
    @State private var selectedApp: InternalApp?

    public init() {}

    public var body: some View {
        Group {
            if model.authViewModel.isAuthenticated {
                if let selectedApp {
                    switch selectedApp {
                    case .chatLab:
                        ChatLabRootView(
                            homeStore: model.makeChatLabHomeStore(),
                            makeRunStore: { simulation in
                                model.makeChatRunStore(simulation: simulation)
                            },
                            makeToolsStore: { simulationID in
                                model.makeChatToolsStore(simulationID: simulationID)
                            },
                            onExit: {
                                self.selectedApp = nil
                            },
                        )
                    case .trainerLab:
                        TrainerLabWorkspace(
                            model: model,
                            onExit: {
                                self.selectedApp = nil
                            },
                        )
                    }
                } else {
                    MainMenuView(
                        onOpenTrainerLab: {
                            selectedApp = .trainerLab
                        },
                        onOpenChatLab: {
                            selectedApp = .chatLab
                        },
                        onSignOut: {
                            selectedApp = nil
                            Task { await model.authViewModel.signOut() }
                        },
                    )
                }
            } else {
                AuthGateView(
                    viewModel: model.authViewModel,
                    appTitle: "MedSim",
                    appSubtitle: "TrainerLab + ChatLab",
                    environmentLabel: "Env: \(model.environmentStore.selection.rawValue) | \(model.environmentStore.baseURL.host() ?? "unknown")",
                    onOpenEnvironmentSwitcher: {
                        showEnvironment = true
                    },
                )
            }
        }
        .sheet(isPresented: $showEnvironment) {
            EnvironmentSwitcherView(store: model.environmentStore) {
                model.syncBaseURLFromEnvironment()
            }
        }
        .task {
            await model.authViewModel.restoreSessionIfAvailable()
        }
    }
}

private struct TrainerLabWorkspace: View {
    let model: AppShellModel
    let onExit: () -> Void

    @State private var selectedSession: TrainerSessionDTO?
    @State private var showPresets = false
    @State private var showSummary = false

    var body: some View {
        NavigationStack {
            Group {
                if let session = selectedSession {
                    RunConsoleScreen(
                        model: model,
                        session: session,
                        onBack: { selectedSession = nil },
                        onOpenSummary: { showSummary = true },
                    )
                } else {
                    SessionHubView(
                        viewModel: model.sessionHubViewModel,
                        onSelectSession: { session in
                            selectedSession = session
                        },
                        onOpenPresets: {
                            showPresets = true
                        },
                    )
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button("Main Menu") { onExit() }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPresets) {
            PresetsLibraryView(viewModel: model.presetsViewModel, activeSimulationID: selectedSession?.simulationID)
        }
        .sheet(isPresented: $showSummary) {
            if let session = selectedSession {
                RunSummaryView(viewModel: model.makeSummaryViewModel(simulationID: session.simulationID))
            } else {
                Text("No session selected")
            }
        }
    }
}

private struct RunConsoleScreen: View {
    let model: AppShellModel
    let session: TrainerSessionDTO
    let onBack: () -> Void
    let onOpenSummary: () -> Void

    @StateObject private var store: RunSessionStore

    init(
        model: AppShellModel,
        session: TrainerSessionDTO,
        onBack: @escaping () -> Void,
        onOpenSummary: @escaping () -> Void,
    ) {
        self.model = model
        self.session = session
        self.onBack = onBack
        self.onOpenSummary = onOpenSummary
        _store = StateObject(wrappedValue: model.makeRunSessionStore(session: session))
    }

    var body: some View {
        RunConsoleView(store: store, onBack: onBack, onOpenSummary: onOpenSummary)
            .appShellOrientationLock(.iPadLandscape)
    }
}

private struct MainMenuView: View {
    let onOpenTrainerLab: () -> Void
    let onOpenChatLab: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "cross.case.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(TrainerLabTheme.accentBlue)

                Text("MedSim")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("Choose an internal app to continue.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    menuButton(
                        title: "TrainerLab",
                        subtitle: "Run and manage live trainer sessions",
                        systemImage: "waveform.path.ecg",
                        action: onOpenTrainerLab,
                    )

                    menuButton(
                        title: "ChatLab",
                        subtitle: "Work simulations through the messaging runtime",
                        systemImage: "message.badge",
                        action: onOpenChatLab,
                    )
                }
                .padding(.top, 8)

                Button("Sign Out", action: onSignOut)
                    .buttonStyle(.bordered)

                Spacer()
            }
            .padding(24)
            .appShellMenuNavigationChromeHidden()
        }
    }

    private func menuButton(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(TrainerLabTheme.accentBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    @ViewBuilder
    func appShellMenuNavigationChromeHidden() -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
            toolbar(.hidden, for: .navigationBar)
        #else
            self
        #endif
    }
}
