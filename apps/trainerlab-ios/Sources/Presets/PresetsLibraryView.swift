import DesignSystem
import SharedModels
import SwiftUI

public struct PresetsLibraryView: View {
    @ObservedObject private var viewModel: PresetsViewModel
    private let activeSimulationID: Int?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var presetSearch = ""
    @State private var selectedPresetID: Int?
    @State private var draftTitle = ""
    @State private var draftDescription = ""
    @State private var draftInstruction = ""
    @State private var draftSeverity = "moderate"
    @State private var draftIsActive = true
    @State private var shareSearch = ""
    @State private var sharingPreset: ScenarioInstruction?

    public init(viewModel: PresetsViewModel, activeSimulationID: Int?) {
        self.viewModel = viewModel
        self.activeSimulationID = activeSimulationID
    }

    public var body: some View {
        GeometryReader { proxy in
            let layoutMode = PresetsLayoutMode.resolve(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass
            )

            Group {
                if layoutMode == .pad {
                    padWorkspace
                } else {
                    phoneWorkspace(layoutMode: layoutMode)
                }
            }
            .background(TrainerLabTheme.setupBackground.ignoresSafeArea())
            .sheet(item: $sharingPreset) { preset in
                presetShareSheet(preset: preset)
                    .presentationDetents([.medium, .large])
            }
            .onReceive(viewModel.$presets) { presets in
                syncSelection(with: presets, layoutMode: layoutMode)
            }
            .onChange(of: selectedPresetID) { _, newSelection in
                if let preset = viewModel.presets.first(where: { $0.id == newSelection }) {
                    loadDraft(from: preset)
                }
            }
            .task {
                await viewModel.loadPresets()
                syncSelection(with: viewModel.presets, layoutMode: layoutMode)
            }
        }
    }

    private var padWorkspace: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                header(titleFont: .largeTitle.bold(), showRefreshCard: true)
                presetSearchField
                presetSidebar
            }
            .frame(width: 330)

            VStack(alignment: .leading, spacing: 16) {
                header(titleFont: .title.bold(), showRefreshCard: false)
                presetEditorCard(layoutMode: .pad)
                if let selectedPreset {
                    shareManager(preset: selectedPreset, layoutMode: .pad)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(maxWidth: 1220, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func phoneWorkspace(layoutMode: PresetsLayoutMode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(
                    titleFont: layoutMode == .narrowPhone ? .title2.bold() : .title.bold(),
                    showRefreshCard: false
                )
                presetSearchField
                presetEditorCard(layoutMode: layoutMode)

                if let error = viewModel.errorMessage {
                    HStack(spacing: 12) {
                        Text(error)
                            .foregroundStyle(TrainerLabTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Retry") {
                            Task { await viewModel.loadPresets() }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if viewModel.isLoading, viewModel.presets.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if filteredPresets.isEmpty {
                    ContentUnavailableView(
                        "No Presets",
                        systemImage: "shippingbox",
                        description: Text("Create a preset to speed up scenario changes.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPresets) { preset in
                            phonePresetCard(preset: preset, layoutMode: layoutMode)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else if viewModel.hasMore, presetSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Load More") {
                            Task { await viewModel.loadMorePresets() }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(layoutMode == .narrowPhone ? 16 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(titleFont: Font, showRefreshCard: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Presets Library")
                    .font(titleFont)
                Spacer()
                Button("Refresh") {
                    Task { await viewModel.loadPresets() }
                }
                .buttonStyle(.bordered)
            }

            if showRefreshCard {
                Text("Search, edit, share, and apply scenario presets without leaving the workspace.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.errorMessage, showRefreshCard {
                HStack(spacing: 12) {
                    Text(error)
                        .foregroundStyle(TrainerLabTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Retry") {
                        Task { await viewModel.loadPresets() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var presetSearchField: some View {
        TextField("Search presets", text: $presetSearch)
            .textFieldStyle(.roundedBorder)
    }

    private var presetSidebar: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Button {
                    selectedPresetID = nil
                    resetDraftForNewPreset()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Preset")
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TrainerLabTheme.setupSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(filteredPresets) { preset in
                    Button {
                        selectedPresetID = preset.id
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(preset.instructionText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            severityBadge(preset.severity)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedPresetID == preset.id ? TrainerLabTheme.setupSurface : TrainerLabTheme.setupSurface.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selectedPresetID == preset.id ? TrainerLabTheme.accentBlue : Color.clear, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if viewModel.hasMore {
                    Button("Load More") {
                        Task { await viewModel.loadMorePresets() }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func phonePresetCard(preset: ScenarioInstruction, layoutMode: PresetsLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.headline)
                    Text(preset.description.isEmpty ? preset.instructionText : preset.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 10)
                severityBadge(preset.severity)
            }

            Text(preset.instructionText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            if layoutMode == .narrowPhone {
                Menu("Actions") {
                    presetActionButtons(for: preset, menu: true)
                }
                .buttonStyle(.bordered)
            } else {
                VStack(spacing: 8) {
                    presetActionButtons(for: preset, menu: false)
                }
            }
        }
        .padding(14)
        .trainerCardStyle(background: TrainerLabTheme.setupSurface)
    }

    @ViewBuilder
    private func presetActionButtons(for preset: ScenarioInstruction, menu: Bool) -> some View {
        let duplicateButton = Button("Duplicate") {
            Task { await viewModel.duplicatePreset(id: preset.id) }
        }

        let deleteButton = Button("Delete", role: .destructive) {
            Task { await viewModel.deletePreset(id: preset.id) }
        }

        let shareButton = Button("Share") {
            shareSearch = ""
            Task { await viewModel.searchAccounts(query: "") }
            sharingPreset = preset
        }

        let editButton = Button("Edit") {
            selectedPresetID = preset.id
            loadDraft(from: preset)
        }

        if menu {
            editButton
            duplicateButton
            shareButton
            if let activeSimulationID {
                Button("Apply") {
                    Task { await viewModel.applyPreset(id: preset.id, simulationID: activeSimulationID) }
                }
            }
            deleteButton
        } else {
            editButton
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
            duplicateButton
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
            shareButton
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let activeSimulationID {
                Button("Apply") {
                    Task { await viewModel.applyPreset(id: preset.id, simulationID: activeSimulationID) }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            deleteButton
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func presetEditorCard(layoutMode: PresetsLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedPreset == nil ? "Create Preset" : "Edit Preset")
                    .font(.headline)
                Spacer()
                if selectedPreset != nil {
                    Button("New Preset") {
                        selectedPresetID = nil
                        resetDraftForNewPreset()
                    }
                    .buttonStyle(.bordered)
                }
            }

            TextField("Preset title", text: $draftTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Short description", text: $draftDescription)
                .textFieldStyle(.roundedBorder)

            TextField("Instruction text", text: $draftInstruction, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3 ... 8)

            if layoutMode == .pad {
                Picker("Severity", selection: $draftSeverity) {
                    severityOptions
                }
                .pickerStyle(.segmented)
            } else {
                Picker("Severity", selection: $draftSeverity) {
                    severityOptions
                }
                .pickerStyle(.menu)
            }

            Toggle("Preset active", isOn: $draftIsActive)

            HStack(spacing: 10) {
                Button(selectedPreset == nil ? "Create Preset" : "Save Changes") {
                    Task { await saveCurrentDraft() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let selectedPreset {
                    Button("Duplicate") {
                        Task { await viewModel.duplicatePreset(id: selectedPreset.id) }
                    }
                    .buttonStyle(.bordered)

                    if let activeSimulationID {
                        Button("Apply") {
                            Task { await viewModel.applyPreset(id: selectedPreset.id, simulationID: activeSimulationID) }
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Delete", role: .destructive) {
                        Task {
                            await viewModel.deletePreset(id: selectedPreset.id)
                            selectedPresetID = nil
                            resetDraftForNewPreset()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .trainerCardStyle(background: TrainerLabTheme.setupSurface)
    }

    private func shareManager(preset: ScenarioInstruction, layoutMode _: PresetsLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share Preset")
                .font(.headline)

            TextField("Search recipient for share/unshare", text: $shareSearch)
                .textFieldStyle(.roundedBorder)
                .onChange(of: shareSearch) { _, value in
                    Task { await viewModel.searchAccounts(query: value) }
                }

            if viewModel.accountResults.isEmpty {
                Text("Search by name or email to manage access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.accountResults) { user in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.fullName)
                                    .font(.subheadline.bold())
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 10)
                            HStack(spacing: 8) {
                                Button("Share") {
                                    Task { await viewModel.sharePreset(id: preset.id, userID: user.id) }
                                }
                                .buttonStyle(.bordered)

                                Button("Unshare") {
                                    Task { await viewModel.unsharePreset(id: preset.id, userID: user.id) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding(18)
        .trainerCardStyle(background: TrainerLabTheme.setupSurface)
    }

    private func presetShareSheet(preset: ScenarioInstruction) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(preset.title)
                        .font(.title3.bold())

                    shareManager(preset: preset, layoutMode: .phone)
                }
                .padding(20)
            }
            .navigationTitle("Share Preset")
        }
    }

    @ViewBuilder
    private var severityOptions: some View {
        Text("low").tag("low")
        Text("moderate").tag("moderate")
        Text("high").tag("high")
        Text("critical").tag("critical")
    }

    private var filteredPresets: [ScenarioInstruction] {
        let query = presetSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.presets }
        return viewModel.presets.filter { preset in
            preset.title.lowercased().contains(query) ||
                preset.instructionText.lowercased().contains(query) ||
                preset.severity.lowercased().contains(query)
        }
    }

    private var selectedPreset: ScenarioInstruction? {
        guard let selectedPresetID else { return nil }
        return viewModel.presets.first(where: { $0.id == selectedPresetID })
    }

    private func severityBadge(_ severity: String) -> some View {
        Text(severity.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }

    private func syncSelection(with presets: [ScenarioInstruction], layoutMode: PresetsLayoutMode) {
        selectedPresetID = PresetsWorkspaceSelection.resolvedSelectionID(
            currentSelectionID: selectedPresetID,
            presets: filteredPresets.isEmpty ? presets : filteredPresets,
            layoutMode: layoutMode
        )

        if let selectedPreset = presets.first(where: { $0.id == selectedPresetID }) {
            loadDraft(from: selectedPreset)
        } else if selectedPresetID == nil {
            resetDraftForNewPreset()
        }
    }

    private func loadDraft(from preset: ScenarioInstruction) {
        draftTitle = preset.title
        draftDescription = preset.description
        draftInstruction = preset.instructionText
        draftSeverity = preset.severity
        draftIsActive = preset.isActive
    }

    private func resetDraftForNewPreset() {
        draftTitle = ""
        draftDescription = ""
        draftInstruction = ""
        draftSeverity = "moderate"
        draftIsActive = true
        shareSearch = ""
    }

    private func saveCurrentDraft() async {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = draftDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction = draftInstruction.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return }

        if let selectedPreset {
            await viewModel.updatePreset(
                id: selectedPreset.id,
                title: title,
                description: description,
                instruction: instruction,
                severity: draftSeverity,
                isActive: draftIsActive
            )
        } else {
            await viewModel.createPreset(
                title: title,
                description: description,
                instruction: instruction,
                severity: draftSeverity
            )
            selectedPresetID = viewModel.presets.first?.id
            if let selectedPreset = viewModel.presets.first {
                loadDraft(from: selectedPreset)
            } else {
                resetDraftForNewPreset()
            }
        }
    }
}
