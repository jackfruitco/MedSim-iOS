import Auth
import ChatLabiOS
import DesignSystem
import Networking
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
    @State private var showAccountBilling = false
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
                        currentAccountName: model.accountSessionStore.currentAccount?.name ?? "No account selected",
                        currentAccountType: model.accountSessionStore.currentAccount?.accountType ?? model.accountSessionStore.accessSnapshot?.accountType,
                        accessMessage: model.accountSessionStore.errorMessage,
                        trainerLabEnabled: model.accountSessionStore.isProductEnabled("trainerlab"),
                        trainerLabMessage: availabilityMessage(for: "trainerlab"),
                        chatLabEnabled: model.accountSessionStore.isProductEnabled("chatlab"),
                        chatLabMessage: availabilityMessage(for: "chatlab"),
                        onOpenTrainerLab: {
                            selectedApp = .trainerLab
                        },
                        onOpenChatLab: {
                            selectedApp = .chatLab
                        },
                        onOpenAccountBilling: {
                            showAccountBilling = true
                        },
                        onSignOut: {
                            selectedApp = nil
                            showAccountBilling = false
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
        .sheet(isPresented: $showAccountBilling) {
            AccountBillingSheet(
                accountStore: model.accountSessionStore,
                billingService: model.billingService,
                onAccountSwitched: {
                    model.resetScopedWorkspaceState()
                },
            )
        }
        .task {
            await model.authViewModel.restoreSessionIfAvailable()
        }
    }

    private func availabilityMessage(for productCode: String) -> String? {
        if model.accountSessionStore.isBootstrapping {
            return "Loading account access..."
        }

        guard let account = model.accountSessionStore.currentAccount ?? model.accountSessionStore.accessSnapshot.map({
            AccountOut(
                uuid: $0.accountUUID,
                name: $0.accountName,
                slug: "",
                accountType: $0.accountType,
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: $0.membershipRole,
                membershipStatus: nil,
                isActiveContext: true,
            )
        }) else {
            return "Select an account to continue."
        }

        guard let access = model.accountSessionStore.productAccess(code: productCode) else {
            return "Unavailable for \(account.name)."
        }

        return access.enabled ? nil : "Not included for \(account.name)."
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
                        onBack: {
                            selectedSession = nil
                            Task { await model.sessionHubViewModel.loadSessions() }
                        },
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
    private struct MenuButtonContent {
        let title: String
        let subtitle: String
        let systemImage: String
        let isEnabled: Bool
        let availabilityMessage: String?
    }

    let currentAccountName: String
    let currentAccountType: String?
    let accessMessage: String?
    let trainerLabEnabled: Bool
    let trainerLabMessage: String?
    let chatLabEnabled: Bool
    let chatLabMessage: String?
    let onOpenTrainerLab: () -> Void
    let onOpenChatLab: () -> Void
    let onOpenAccountBilling: () -> Void
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

                VStack(spacing: 6) {
                    Text(currentAccountName)
                        .font(.headline)
                    if let currentAccountType, !currentAccountType.isEmpty {
                        Text(currentAccountType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())

                VStack(spacing: 12) {
                    menuButton(
                        MenuButtonContent(
                            title: "TrainerLab",
                            subtitle: "Run and manage live trainer sessions",
                            systemImage: "waveform.path.ecg",
                            isEnabled: trainerLabEnabled,
                            availabilityMessage: trainerLabMessage,
                        ),
                        action: onOpenTrainerLab,
                    )

                    menuButton(
                        MenuButtonContent(
                            title: "ChatLab",
                            subtitle: "Work simulations through the messaging runtime",
                            systemImage: "message.badge",
                            isEnabled: chatLabEnabled,
                            availabilityMessage: chatLabMessage,
                        ),
                        action: onOpenChatLab,
                    )
                }
                .padding(.top, 8)

                Button("Account & Billing", action: onOpenAccountBilling)
                    .buttonStyle(.borderedProminent)

                if let accessMessage, !accessMessage.isEmpty {
                    Text(accessMessage)
                        .font(.footnote)
                        .foregroundStyle(TrainerLabTheme.danger)
                        .multilineTextAlignment(.center)
                }

                Button("Sign Out", action: onSignOut)
                    .buttonStyle(.bordered)

                Spacer()
            }
            .padding(24)
            .appShellMenuNavigationChromeHidden()
        }
    }

    private func menuButton(
        _ content: MenuButtonContent,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: content.systemImage)
                    .font(.title2.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(TrainerLabTheme.accentBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.headline)
                    Text(content.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let availabilityMessage = content.availabilityMessage, !content.isEnabled {
                        Text(availabilityMessage)
                            .font(.caption)
                            .foregroundStyle(TrainerLabTheme.warning)
                    }
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
        .disabled(!content.isEnabled)
        .opacity(content.isEnabled ? 1 : 0.62)
    }
}

private struct AccountBillingSheet: View {
    @ObservedObject var accountStore: AccountSessionStore
    @ObservedObject var billingService: AppleBillingService
    let onAccountSwitched: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let currentAccount = accountStore.currentAccount {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentAccount.name)
                                .font(.headline)
                            Text(currentAccount.accountType.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if accountStore.availableAccounts.isEmpty {
                        Text("No accessible accounts were returned for this user.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(accountStore.availableAccounts) { account in
                            Button {
                                Task {
                                    do {
                                        try await accountStore.switchAccount(to: account.uuid)
                                        await MainActor.run {
                                            onAccountSwitched()
                                        }
                                    } catch {
                                        // Surface the backend error through the shared store state.
                                    }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(account.name)
                                            .foregroundStyle(.primary)
                                        Text(account.accountType.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if account.uuid == accountStore.selectedAccountUUID || account.isActiveContext {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(TrainerLabTheme.accentBlue)
                                    }
                                }
                            }
                            .disabled(accountStore.isSwitching || !account.isActive)
                        }
                    }

                    if let errorMessage = accountStore.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TrainerLabTheme.danger)
                    }
                }

                if accountStore.isCurrentAccountPersonal {
                    ForEach(BillingProductGroup.allCases) { group in
                        Section(group.title) {
                            ForEach(billingService.entries(for: group)) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.title)
                                                .font(.headline)
                                            Text(entry.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(entry.price)
                                            .font(.subheadline.weight(.semibold))
                                    }

                                    Button(entry.isAvailable ? "Purchase" : "Unavailable") {
                                        Task {
                                            await billingService.purchase(productID: entry.productID)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!entry.isAvailable || billingService.isProcessing)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section("Restore") {
                        Button("Restore Purchases") {
                            Task {
                                await billingService.restorePurchases()
                            }
                        }
                        .disabled(billingService.isProcessing)

                        if billingService.hasPendingSyncRetry {
                            Button("Retry Sync") {
                                Task {
                                    await billingService.retryPendingSync()
                                }
                            }
                            .disabled(billingService.isProcessing)
                        }

                        if let catalogErrorMessage = billingService.catalogErrorMessage, !catalogErrorMessage.isEmpty {
                            Text(catalogErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(TrainerLabTheme.warning)
                        }

                        if let syncErrorMessage = billingService.syncErrorMessage, !syncErrorMessage.isEmpty {
                            Text(syncErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(TrainerLabTheme.danger)
                        }
                    }
                } else {
                    Section("Billing") {
                        Text("App Store billing is only available for personal accounts in this version.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Account & Billing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await billingService.loadProductsIfNeeded()
        }
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
