import SharedModels
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

public struct ChatLabHomeView: View {
    @ObservedObject private var store: ChatLabHomeStore
    private let onOpenSimulation: (ChatSimulation) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showCreateSheet = false

    public init(
        store: ChatLabHomeStore,
        onOpenSimulation: @escaping (ChatSimulation) -> Void,
    ) {
        self.store = store
        self.onOpenSimulation = onOpenSimulation
    }

    public var body: some View {
        GeometryReader { proxy in
            let layoutMode = ChatLabSurfaceMode.resolve(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
            )

            ScrollView {
                VStack(alignment: .leading, spacing: layoutMode == .pad ? 18 : 12) {
                    header(layoutMode: layoutMode)

                    Toggle("Include message content in search", isOn: $store.includeMessageSearch)
                        .font(.footnote)

                    if let error = store.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    content(layoutMode: layoutMode)
                }
                .frame(maxWidth: layoutMode == .pad ? 980 : .infinity, alignment: .leading)
                .padding(layoutMode == .pad ? 24 : 16)
                .frame(maxWidth: .infinity)
            }
            .background(Color.secondary.opacity(0.04).ignoresSafeArea())
            .navigationTitle("ChatLab")
            .sheet(isPresented: $showCreateSheet) {
                ChatCreateSimulationSheet(
                    store: store,
                    layoutMode: layoutMode,
                    onCreated: { simulation in
                        showCreateSheet = false
                        onOpenSimulation(simulation)
                    },
                )
                .presentationDetents(layoutMode == .pad ? [.large] : [.medium, .large])
            }
        }
        .task {
            await store.loadInitial()
            await store.loadModifierGroups()
            store.startAutoRefresh()
        }
        .onDisappear {
            store.stopAutoRefresh()
        }
    }

    @ViewBuilder
    private func header(layoutMode: ChatLabSurfaceMode) -> some View {
        switch layoutMode {
        case .pad:
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ChatLab")
                        .font(.largeTitle.bold())
                    Text("Search existing patient conversations or launch a new simulation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Search simulations", text: $store.searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await store.search() }
                        }
                }

                VStack(alignment: .trailing, spacing: 10) {
                    Button("Search") {
                        Task { await store.search() }
                    }
                    .buttonStyle(.bordered)

                    Button("New Simulation") {
                        showCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(minWidth: 180)
            }
            .padding(20)
            .background(ChatLabTheme.systemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.primary.opacity(0.04), radius: 18, y: 8)

        case .phone:
            VStack(alignment: .leading, spacing: 10) {
                TextField("Search simulations", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await store.search() }
                    }

                HStack(spacing: 10) {
                    Button("Search") {
                        Task { await store.search() }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                    Button("New Simulation") {
                        showCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }

        case .narrowPhone:
            VStack(alignment: .leading, spacing: 10) {
                TextField("Search simulations", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await store.search() }
                    }

                Button("Search") {
                    Task { await store.search() }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("New Simulation") {
                    showCreateSheet = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func content(layoutMode: ChatLabSurfaceMode) -> some View {
        if store.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if store.simulations.isEmpty {
            ContentUnavailableView(
                "No Simulations",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Create a simulation to start ChatLab."),
            )
            .frame(maxWidth: .infinity, minHeight: 260)
        } else {
            LazyVStack(spacing: layoutMode == .pad ? 14 : 10) {
                ForEach(store.simulations) { simulation in
                    Button {
                        onOpenSimulation(simulation)
                    } label: {
                        ChatSimulationCard(simulation: simulation, layoutMode: layoutMode)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await store.loadMoreIfNeeded(current: simulation)
                        }
                    }
                }
            }
        }
    }
}

private struct ChatSimulationCard: View {
    let simulation: ChatSimulation
    let layoutMode: ChatLabSurfaceMode

    var body: some View {
        VStack(alignment: .leading, spacing: layoutMode == .pad ? 12 : 8) {
            switch layoutMode {
            case .narrowPhone:
                VStack(alignment: .leading, spacing: 8) {
                    titleRow(showTrailingStatus: false)
                    detailsBlock
                    statusBadge
                }

            case .phone:
                HStack(alignment: .top, spacing: 10) {
                    titleAndDetails
                    Spacer(minLength: 12)
                    statusBadge
                }

            case .pad:
                HStack(alignment: .top, spacing: 14) {
                    titleAndDetails
                    Spacer(minLength: 20)
                    VStack(alignment: .trailing, spacing: 8) {
                        statusBadge
                        if let endTimestamp = simulation.endTimestamp {
                            Text("Ended \(endTimestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(layoutMode == .pad ? 18 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChatLabTheme.systemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.primary.opacity(0.04), radius: 12, y: 6)
    }

    private var titleAndDetails: some View {
        VStack(alignment: .leading, spacing: layoutMode == .pad ? 6 : 4) {
            titleRow(showTrailingStatus: false)
            detailsBlock
        }
    }

    private func titleRow(showTrailingStatus: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: layoutMode == .pad ? 42 : 36, height: layoutMode == .pad ? 42 : 36)
                .overlay(
                    Text(simulation.patientInitials)
                        .font(.caption.bold()),
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(simulation.patientDisplayName)
                    .font(layoutMode == .pad ? .title3.bold() : .headline)
                    .foregroundStyle(.primary)
                if let complaint = primarySummaryText {
                    Text(complaint)
                        .font(layoutMode == .pad ? .subheadline : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(layoutMode == .narrowPhone ? 3 : 2)
                }
            }

            if showTrailingStatus {
                Spacer(minLength: 8)
                statusBadge
            }
        }
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(simulation.startTimestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            if simulation.status != .inProgress, !simulation.terminalReasonText.isEmpty {
                Text(simulation.terminalReasonText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(layoutMode == .pad ? 2 : 3)
            }
        }
    }

    private var primarySummaryText: String? {
        if let complaint = simulation.chiefComplaint, !complaint.isEmpty {
            return complaint
        }
        if let diagnosis = simulation.diagnosis, !diagnosis.isEmpty {
            return diagnosis
        }
        return nil
    }

    private var statusBadge: some View {
        Text(statusText(simulation.status))
            .font(.caption.bold())
            .foregroundStyle(statusColor(simulation.status))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor(simulation.status).opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusText(_ status: SimulationTerminalState) -> String {
        switch status {
        case .inProgress:
            "In Progress"
        case .completed:
            "Completed"
        case .timedOut:
            "Timed Out"
        case .failed:
            "Failed"
        case .canceled:
            "Canceled"
        case .unknown:
            "Unknown"
        }
    }

    private func statusColor(_ status: SimulationTerminalState) -> Color {
        switch status {
        case .inProgress:
            .blue
        case .completed:
            .green
        case .timedOut:
            .orange
        case .failed:
            .red
        case .canceled:
            .gray
        case .unknown:
            .secondary
        }
    }
}

private struct ChatCreateSimulationSheet: View {
    @ObservedObject var store: ChatLabHomeStore
    let layoutMode: ChatLabSurfaceMode
    let onCreated: (ChatSimulation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var creating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected Modifiers") {
                    if store.modifierGroups.isEmpty {
                        Text("No modifiers available.")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(store.modifierGroups, id: \.group) { group in
                    Section(group.group) {
                        ForEach(group.modifiers, id: \.key) { modifier in
                            Toggle(
                                modifier.description,
                                isOn: Binding(
                                    get: { store.selectedModifiers.contains(modifier.key) },
                                    set: { _ in store.toggleModifier(modifier.key) },
                                ),
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: layoutMode == .pad ? 680 : .infinity)
            .navigationTitle("New Chat Simulation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if creating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task {
                                creating = true
                                defer { creating = false }
                                if let created = await store.quickCreateSimulation() {
                                    onCreated(created)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
