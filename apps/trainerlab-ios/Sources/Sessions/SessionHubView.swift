import DesignSystem
import Networking
import SharedModels
import SwiftUI

public struct SessionHubView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject private var viewModel: SessionHubViewModel
    private let onSelectSession: (TrainerSessionDTO) -> Void
    private let onOpenPresets: () -> Void

    @State private var showCreateSessionSheet = false
    @State private var createDraft = TrainerSessionCreateDraft.default

    public init(
        viewModel: SessionHubViewModel,
        onSelectSession: @escaping (TrainerSessionDTO) -> Void,
        onOpenPresets: @escaping () -> Void,
    ) {
        self.viewModel = viewModel
        self.onSelectSession = onSelectSession
        self.onOpenPresets = onOpenPresets
    }

    public var body: some View {
        GeometryReader { proxy in
            let layoutMode = SessionHubLayoutMode.resolve(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
            )

            ScrollView {
                VStack(alignment: .leading, spacing: layoutMode == .pad ? 20 : 14) {
                    header(layoutMode: layoutMode)

                    TextField("Search sessions", text: $viewModel.searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: viewModel.searchQuery) { _, _ in
                            viewModel.onSearchQueryChanged()
                        }

                    if let error = viewModel.presentableError {
                        InlineAppErrorView(error: error, actionLabel: "Retry") {
                            Task { await viewModel.reloadAuthoritativeSessions(reason: "retry") }
                        }
                    }

                    content(layoutMode: layoutMode, width: proxy.size.width)
                }
                .frame(maxWidth: layoutMode == .pad ? 1100 : .infinity, alignment: .leading)
                .padding(layoutMode == .pad ? 24 : 16)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await viewModel.loadSessions()
            }
            .background(TrainerLabTheme.setupBackground.ignoresSafeArea())
        }
        .task {
            await viewModel.loadSessions()
            await viewModel.startLiveUpdates()
        }
        .refreshable {
            await viewModel.reloadAuthoritativeSessions(reason: "pull_to_refresh")
        }
        .onDisappear {
            viewModel.stopLiveUpdates()
        }
        .sheet(isPresented: $showCreateSessionSheet) {
            CreateTrainerSessionSheet(
                draft: $createDraft,
                isCreating: viewModel.isLoading,
                presentableError: viewModel.presentableError,
                onCancel: {
                    showCreateSessionSheet = false
                },
                onCreate: {
                    Task {
                        await viewModel.createSession(draft: createDraft)
                        if viewModel.presentableError == nil {
                            createDraft = .default
                            showCreateSessionSheet = false
                        }
                    }
                },
            )
        }
    }

    @ViewBuilder
    private func header(layoutMode: SessionHubLayoutMode) -> some View {
        switch layoutMode {
        case .pad:
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Session Hub")
                        .font(.largeTitle.bold())
                    Text("Browse active simulations, resume runs, or create a new trainer session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Presets Library", action: onOpenPresets)
                        .trainerGlassButtonStyle()
                    Button("Create Session", action: openCreateSessionSheet)
                    .trainerGlassButtonStyle(prominent: true)
                }
            }
            .padding(20)
            .trainerCardStyle(
                background: TrainerLabTheme.setupSurface,
                glassRole: .setupCard,
                tint: TrainerLabTheme.accentBlue.opacity(0.06),
            )

        case .phone:
            VStack(alignment: .leading, spacing: 10) {
                Text("Session Hub")
                    .font(.title.bold())
                HStack(spacing: 10) {
                    Button("Presets Library", action: onOpenPresets)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Button("Create Session", action: openCreateSessionSheet)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }

        case .narrowPhone:
            VStack(alignment: .leading, spacing: 10) {
                Text("Session Hub")
                    .font(.title2.bold())
                Button("Presets Library", action: onOpenPresets)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("Create Session", action: openCreateSessionSheet)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func content(layoutMode: SessionHubLayoutMode, width: CGFloat) -> some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if viewModel.sessions.isEmpty {
            ContentUnavailableView(
                "No Sessions",
                systemImage: "waveform.path.ecg.rectangle",
                description: Text("Create a session to start TrainerLab."),
            )
            .frame(maxWidth: .infinity, minHeight: 260)
        } else if layoutMode == .pad {
            LazyVGrid(columns: gridColumns(for: width), spacing: 16) {
                ForEach(viewModel.sessions) { session in
                    Button {
                        onSelectSession(session)
                    } label: {
                        SessionCard(session: session, layoutMode: layoutMode)
                    }
                    .buttonStyle(.plain)
                }
            }
            loadMoreFooter
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.sessions) { session in
                    Button {
                        onSelectSession(session)
                    } label: {
                        SessionCard(session: session, layoutMode: layoutMode)
                    }
                    .buttonStyle(.plain)
                }
            }
            loadMoreFooter
        }
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if viewModel.isLoadingMore {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 44)
        } else if viewModel.hasMore {
            Button("Load More") {
                Task { await viewModel.loadMoreSessions() }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private func gridColumns(for width: CGFloat) -> [GridItem] {
        let columnCount = width >= 1100 ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    private func openCreateSessionSheet() {
        createDraft = .default
        showCreateSessionSheet = true
    }
}

private struct CreateTrainerSessionSheet: View {
    @Binding var draft: TrainerSessionCreateDraft
    let isCreating: Bool
    let presentableError: PresentableAppError?
    let onCancel: () -> Void
    let onCreate: () -> Void

    @State private var showStartConfirmation = false

    private var canStart: Bool {
        !draft.patientSeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.tickIntervalSeconds >= 5
            && draft.tickIntervalSeconds <= 60
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scenario") {
                    Picker("Preset", selection: $draft.preset) {
                        ForEach(TrainerSessionScenarioPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Patient/problem seed", text: $draft.patientSeed, axis: .vertical)
                        .lineLimit(1 ... 3)

                    TextField("Trainer directive", text: $draft.directives, axis: .vertical)
                        .lineLimit(3 ... 6)
                }

                Section("Runtime") {
                    Stepper(
                        "Tick interval: \(draft.tickIntervalSeconds)s",
                        value: $draft.tickIntervalSeconds,
                        in: 5 ... 60,
                        step: 5,
                    )
                }

                if let presentableError {
                    Section {
                        InlineAppErrorView(error: presentableError)
                    }
                }

                Section {
                    Button {
                        showStartConfirmation = true
                    } label: {
                        if isCreating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Start Seeding")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canStart || isCreating)
                } footer: {
                    Text("TrainerLab will create the session, seed the initial runtime, and unlock live controls when the scenario is ready.")
                }
            }
            .navigationTitle("Create Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .confirmationDialog(
                "Start seeding this trainer session?",
                isPresented: $showStartConfirmation,
                titleVisibility: Visibility.visible,
            ) {
                Button("Start Seeding", action: onCreate)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The selected preset and directive will be sent to the runtime. You can still steer the scenario after it starts.")
            }
        }
    }
}

private struct SessionCard: View {
    let session: TrainerSessionDTO
    let layoutMode: SessionHubLayoutMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch layoutMode {
            case .narrowPhone:
                VStack(alignment: .leading, spacing: 8) {
                    titleBlock
                    metadataBlock
                    statusBadge
                }
            case .phone, .pad:
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        titleBlock
                        metadataBlock
                    }
                    Spacer(minLength: 12)
                    statusBadge
                }
            }
        }
        .padding(layoutMode == .pad ? 18 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .trainerCardStyle(background: TrainerLabTheme.setupSurface)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Simulation #\(session.simulationID)")
                .font(layoutMode == .pad ? .title3.bold() : .headline)
                .foregroundStyle(.primary)
            Text("Trainer Run")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            metadataRow("Created", value: session.createdAt.formatted(date: .abbreviated, time: .shortened))
            metadataRow("Updated", value: session.modifiedAt.formatted(date: .abbreviated, time: .shortened))
            metadataRow("Tick", value: "\(session.tickIntervalSeconds)s")
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusBadge: some View {
        Text(session.status.rawValue.capitalized)
            .font(.caption.bold())
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch session.status {
        case .seeding:
            TrainerLabTheme.warning
        case .seeded:
            TrainerLabTheme.accentBlue
        case .running:
            TrainerLabTheme.success
        case .paused:
            TrainerLabTheme.warning
        case .completed:
            TrainerLabTheme.success
        case .failed:
            TrainerLabTheme.danger
        }
    }
}
