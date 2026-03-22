import DesignSystem
import SharedModels
import SwiftUI

public struct SessionHubView: View {
    @ObservedObject private var viewModel: SessionHubViewModel
    private let onSelectSession: (TrainerSessionDTO) -> Void
    private let onOpenPresets: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

                    if let error = viewModel.errorMessage {
                        HStack(spacing: 12) {
                            Text(error)
                                .foregroundStyle(TrainerLabTheme.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Retry") {
                                Task { await viewModel.loadSessions() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    content(layoutMode: layoutMode, width: proxy.size.width)
                }
                .frame(maxWidth: layoutMode == .pad ? 1100 : .infinity, alignment: .leading)
                .padding(layoutMode == .pad ? 24 : 16)
                .frame(maxWidth: .infinity)
            }
            .background(TrainerLabTheme.setupBackground.ignoresSafeArea())
        }
        .task {
            await viewModel.loadSessions()
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
                        .buttonStyle(.bordered)
                    Button("Create Session") {
                        Task { await viewModel.createSession() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .trainerCardStyle(background: TrainerLabTheme.setupSurface)

        case .phone:
            VStack(alignment: .leading, spacing: 10) {
                Text("Session Hub")
                    .font(.title.bold())
                HStack(spacing: 10) {
                    Button("Presets Library", action: onOpenPresets)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Button("Create Session") {
                        Task { await viewModel.createSession() }
                    }
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
                Button("Create Session") {
                    Task { await viewModel.createSession() }
                }
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
