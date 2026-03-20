import DesignSystem
import Sessions
import SharedModels
import SwiftUI

public struct RunConsoleView: View {
    @ObservedObject private var store: RunSessionStore
    private let onBack: () -> Void
    private let onOpenSummary: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Sheet visibility
    @State private var showInterventionSheet = false
    @State private var showEventSheet = false
    @State private var showSteerSheet = false
    @State private var showNoteSheet = false
    @State private var showAnnotationSheet = false

    /// Injury detail
    @State private var quickActionInjury: InjuryAnnotation?

    /// Timeline filter
    @State private var selectedTimelineFilter: TimelineFilter = .all

    // Collapsible panels
    @State private var isOperationalLogExpanded = false
    @State private var activeInfoPanel: ActiveInfoPanel? = .scenarioBrief
    @State private var isLoadingRuntimeState = false
    @State private var showScenarioBriefEditSheet = false
    @Namespace private var segmentNS

    // Intervention sheet state
    @State private var selectedInterventionType: String?
    @State private var selectedLocationLabel: String?
    @State private var selectedLaterality: String?
    @State private var selectedInterventionStatus: InterventionStatus = .applied
    @State private var interventionNotes = ""
    @State private var interventionTargetProblemID: Int?

    /// Steer sheet state
    @State private var steerDraft = ""

    // Event sheet state
    @State private var injuryCategory = ""
    @State private var injuryLocation = ""
    @State private var injuryKind = ""
    @State private var injuryDescription = ""
    @State private var illnessName = ""
    @State private var illnessNameCustom = ""
    @State private var illnessDescription = ""
    @State private var illnessMarchCategory = "R"
    @State private var illnessSeverity = "moderate"
    @State private var vitalType = "heart_rate"
    @State private var vitalMin = "80"
    @State private var vitalMax = "100"
    @State private var eventMode = "injury"

    /// Note composer
    @State private var trainerNoteDraft = ""

    /// AVPU
    @State private var selectedAVPU: AVPUState = .alert

    /// Terminal card dismissed
    @State private var terminalCardDismissed = false

    public init(
        store: RunSessionStore,
        onBack: @escaping () -> Void,
        onOpenSummary: @escaping () -> Void,
    ) {
        self.store = store
        self.onBack = onBack
        self.onOpenSummary = onOpenSummary
    }

    public var body: some View {
        GeometryReader { proxy in
            let layoutMode = RunConsoleLayoutMode.resolve(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
            )
            let compactMetrics = RunConsoleCompactMetrics.resolve(
                width: proxy.size.width,
                layoutMode: layoutMode,
            )

            ZStack {
                TrainerLabTheme.tacticalBackground.ignoresSafeArea()

                Group {
                    if layoutMode == .regular {
                        regularConsoleLayout
                    } else {
                        compactConsoleLayout(compactMetrics: compactMetrics)
                    }
                }

                // Terminal end-state overlay
                if let card = store.state.terminalCard, !terminalCardDismissed {
                    terminalCardOverlay(card: card)
                }
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showInterventionSheet, onDismiss: resetInterventionSheet) {
            interventionSheet
                .presentationDetents([.fraction(0.7)])
        }
        .sheet(item: $quickActionInjury, onDismiss: resetInterventionSheet) { injury in
            quickActionSheet(for: injury)
                .presentationDetents([.fraction(0.55)])
        }
        .sheet(isPresented: $showEventSheet) {
            eventSheet
                .presentationDetents([.fraction(0.55)])
        }
        .sheet(isPresented: $showSteerSheet) {
            steerSheet
                .presentationDetents([.fraction(0.35)])
        }
        .sheet(isPresented: $showNoteSheet) {
            NoteComposerSheet(
                draft: $trainerNoteDraft,
                onSubmit: {
                    addTrainerNote()
                    showNoteSheet = false
                },
            )
            .presentationDetents([.height(180)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAnnotationSheet) {
            DebriefAnnotationSheet { observationText, learningObjective, outcome in
                store.createDebriefAnnotation(
                    observationText: observationText,
                    learningObjective: learningObjective,
                    outcome: outcome,
                )
                showAnnotationSheet = false
            }
            .presentationDetents([.fraction(0.55)])
        }
        .sheet(isPresented: $showScenarioBriefEditSheet) {
            if let brief = store.scenarioBrief ?? store.runtimeState?.scenarioBrief {
                ScenarioBriefEditSheet(brief: brief) { request in
                    store.updateScenarioBrief(request)
                    showScenarioBriefEditSheet = false
                }
                .presentationDetents([.fraction(0.65)])
            }
        }
        .task {
            store.startConsole()
            await store.loadRuntimeState()
            await store.loadControlPlaneDebug()
        }
        .onDisappear {
            store.stopConsole()
        }
        .onChange(of: store.state.terminalCard) { _, newValue in
            if newValue != nil {
                terminalCardDismissed = false
            }
        }
    }

    // MARK: - Layouts

    private var regularConsoleLayout: some View {
        VStack(spacing: 10) {
            regularCommandBar
            topVitalsTable(layoutMode: .regular, compactMetrics: .standard)
            if store.state.conflictBanner != nil {
                conflictBanner
            }

            HStack(alignment: .top, spacing: 10) {
                leftPatientPane(layoutMode: .regular)
                    .frame(minWidth: 420, idealWidth: 440, maxWidth: 520)

                ScrollView {
                    VStack(spacing: 10) {
                        combinedInfoPanel
                        centerTimelinePane(layoutMode: .regular)
                        bottomLogPane(layoutMode: .regular)
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(12)
    }

    private func compactConsoleLayout(compactMetrics: RunConsoleCompactMetrics) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                compactCommandPanel(compactMetrics: compactMetrics)
                topVitalsTable(layoutMode: .compact, compactMetrics: compactMetrics)
                if store.state.conflictBanner != nil {
                    conflictBanner
                }
                leftPatientPane(layoutMode: .compact)
                combinedInfoPanel
                centerTimelinePane(layoutMode: .compact)
                bottomLogPane(layoutMode: .compact)
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Vitals table

    private func topVitalsTable(
        layoutMode: RunConsoleLayoutMode,
        compactMetrics: RunConsoleCompactMetrics,
    ) -> some View {
        VStack(alignment: .leading, spacing: layoutMode == .compact ? 6 : 4) {
            Text("Patient Vitals")
                .font(layoutMode == .compact ? .subheadline.bold() : .headline)

            if orderedVitals.isEmpty {
                Text("Waiting for vital ranges from runtime events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if layoutMode == .regular {
                HStack(spacing: 8) {
                    ForEach(orderedVitals) { vital in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vitalDisplayName(vital.key))
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            VitalValueCell(vital: vital, valueText: displayValue(vital))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                LazyVGrid(
                    columns: compactVitalsColumns(for: compactMetrics),
                    spacing: compactMetrics.gridSpacing,
                ) {
                    ForEach(orderedVitals) { vital in
                        compactVitalCell(vital, compactMetrics: compactMetrics)
                    }
                }
            }
        }
        .modifier(
            RunConsoleCardModifier(
                background: TrainerLabTheme.tacticalSurfaceElevated,
                padding: layoutMode == .compact ? compactMetrics.cardPadding : 8,
            ),
        )
    }

    // MARK: - Command bars

    private var regularCommandBar: some View {
        HStack(spacing: 10) {
            Button("Exit") { onBack() }
                .buttonStyle(.bordered)

            ForEach(lifecycleActions, id: \.self) { action in
                lifecycleActionButton(action, compact: false)
            }

            quickAction("Add Intervention", systemImage: "cross.vial.fill", enabled: canMutate) {
                interventionTargetProblemID = nil
                showInterventionSheet = true
            }
            quickAction("Add Event", systemImage: "bolt.heart.fill", enabled: canMutate) {
                showEventSheet = true
            }
            quickAction("Add Note", systemImage: "note.text.badge.plus", enabled: canMutate) {
                showNoteSheet = true
            }
            quickAction("Add Annotation", systemImage: "text.badge.plus", enabled: canMutate) {
                showAnnotationSheet = true
            }
            quickAction("Steer AI", systemImage: "wand.and.sparkles", enabled: canMutate) {
                showSteerSheet = true
            }
            quickAction("Tick AI", systemImage: "timer", enabled: canMutate) {
                store.triggerRunTick()
            }
            quickAction("Tick Vitals", systemImage: "heart.text.square", enabled: canMutate) {
                store.triggerVitalsTick()
            }

            Spacer(minLength: 10)

            TransportChip(banner: store.state.transportBanner)

            Label(formattedStopwatch, systemImage: "stopwatch.fill")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Button("Run Summary") { onOpenSummary() }
                .buttonStyle(.borderedProminent)
        }
        .padding(10)
        .background(TrainerLabTheme.tacticalSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compactCommandPanel(compactMetrics: RunConsoleCompactMetrics) -> some View {
        let controlPresentation = RunConsoleCompactControlPresentation.resolve(
            layoutMode: .compact,
            horizontalSizeClass: horizontalSizeClass,
        )

        return VStack(alignment: .leading, spacing: compactMetrics.sectionSpacing) {
            if !lifecycleActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Controls")
                        .font(compactMetrics.controlLabelFont)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: compactControlColumns(for: compactMetrics),
                        spacing: compactMetrics.gridSpacing,
                    ) {
                        compactBackAction(compactMetrics: compactMetrics, controlPresentation: controlPresentation)
                            .frame(maxWidth: .infinity)
                        ForEach(lifecycleActions, id: \.self) { action in
                            lifecycleActionButton(
                                action,
                                compact: true,
                                compactMetrics: compactMetrics,
                                controlPresentation: controlPresentation,
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Scenario Actions")
                    .font(compactMetrics.controlLabelFont)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: compactControlColumns(for: compactMetrics),
                    spacing: compactMetrics.gridSpacing,
                ) {
                    compactScenarioAction(
                        "Add Intervention", systemImage: "cross.vial.fill",
                        compactMetrics: compactMetrics,
                        action: {
                            interventionTargetProblemID = nil
                            showInterventionSheet = true
                        },
                        controlPresentation: controlPresentation,
                    )
                    compactScenarioAction(
                        "Add Event", systemImage: "bolt.heart.fill",
                        compactMetrics: compactMetrics,
                        action: { showEventSheet = true },
                        controlPresentation: controlPresentation,
                    )
                    compactScenarioAction(
                        "Steer AI", systemImage: "wand.and.sparkles",
                        compactMetrics: compactMetrics,
                        action: { showSteerSheet = true },
                        controlPresentation: controlPresentation,
                    )
                    compactScenarioAction(
                        "Add Note", systemImage: "note.text.badge.plus",
                        compactMetrics: compactMetrics,
                        action: { showNoteSheet = true },
                        controlPresentation: controlPresentation,
                    )
                    compactScenarioAction(
                        "Add Annotation", systemImage: "text.badge.plus",
                        compactMetrics: compactMetrics,
                        action: { showAnnotationSheet = true },
                        controlPresentation: controlPresentation,
                    )
                    compactScenarioAction(
                        "Tick AI", systemImage: "timer",
                        compactMetrics: compactMetrics,
                        action: { store.triggerRunTick() },
                        controlPresentation: controlPresentation,
                    )
                    compactScenarioAction(
                        "Tick Vitals", systemImage: "heart.text.square",
                        compactMetrics: compactMetrics,
                        action: { store.triggerVitalsTick() },
                        controlPresentation: controlPresentation,
                    )
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: compactMetrics.gridSpacing) {
                    TransportChip(banner: store.state.transportBanner)
                    stopwatchStatus
                    Spacer(minLength: 0)
                    compactSummaryButton(compactMetrics: compactMetrics)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: compactMetrics.gridSpacing) {
                            TransportChip(banner: store.state.transportBanner)
                            stopwatchStatus
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            TransportChip(banner: store.state.transportBanner)
                            stopwatchStatus
                        }
                    }

                    compactSummaryButton(compactMetrics: compactMetrics)
                }
            }
        }
        .modifier(
            RunConsoleCardModifier(
                background: TrainerLabTheme.tacticalSurfaceElevated,
                padding: compactMetrics.cardPadding,
            ),
        )
    }

    // MARK: - Conflict banner

    private var conflictBanner: some View {
        Text(store.state.conflictBanner ?? "")
            .font(.caption)
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TrainerLabTheme.danger.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Patient pane (body diagram + detail panels + AVPU)

    private func leftPatientPane(layoutMode: RunConsoleLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patient State")
                .font(layoutMode == .compact ? .subheadline.bold() : .headline)

            PatientDiagramPanel(
                injuries: store.state.injuryAnnotations,
                allCauses: store.runtimeState?.currentSnapshot.causes ?? [],
                interventions: store.state.interventionAnnotations,
                problems: store.state.problemAnnotations,
                recommendations: store.state.recommendedInterventions,
                pulses: store.state.pulseAnnotations,
                canMutate: canMutate,
                onSelectInjury: { injury in
                    quickActionInjury = injury
                },
                onUpdateProblemStatus: { problem, status in
                    if let problemID = problem.problemID {
                        store.updateProblemStatus(problemID: problemID, status: status)
                    }
                },
            )
            .frame(minHeight: 380, maxHeight: .infinity)

            if !store.state.recommendedInterventions.isEmpty {
                recommendedInterventionsPanel
            }

            Text("AVPU")
                .font(.subheadline.bold())

            if layoutMode == .regular {
                HStack(spacing: 8) {
                    avpuButton(.alert, label: "Alert")
                    avpuButton(.verbal, label: "Verbal")
                    avpuButton(.pain, label: "Pain")
                    avpuButton(.unalert, label: "Unalert")
                }
            } else {
                LazyVGrid(columns: compactActionColumns, spacing: 8) {
                    avpuButton(.alert, label: "Alert")
                    avpuButton(.verbal, label: "Verbal")
                    avpuButton(.pain, label: "Pain")
                    avpuButton(.unalert, label: "Unalert")
                }
            }
        }
        .trainerCardStyle()
    }

    private var recommendedInterventionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Interventions")
                .font(.subheadline.bold())

            ForEach(groupedRecommendations, id: \.priority) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.priority)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(group.items) { recommendation in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                Text(recommendation.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if let targetProblem = linkedProblemLabel(for: recommendation) {
                                    Text(targetProblem)
                                        .font(.caption2.bold())
                                        .foregroundStyle(TrainerLabTheme.accentBlue)
                                }
                            }
                            if let rationale = recommendation.rationale, !rationale.isEmpty {
                                Text(rationale)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let validationStatus = recommendation.validationStatus, !validationStatus.isEmpty {
                                Text(validationStatus.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption2.bold())
                                    .foregroundStyle(TrainerLabTheme.warning)
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Combined Info Panel (Scenario Brief + AI Instructor)

    private enum ActiveInfoPanel: Equatable { case scenarioBrief, aiInstructor, annotations }

    private var combinedInfoPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Segmented pill + collapse button
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    infoPanelSegment(.scenarioBrief, label: "Scenario Brief")
                    infoPanelSegment(.aiInstructor, label: "AI Instructor")
                    infoPanelSegment(.annotations, label: "Annotations")
                }
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))

                if activeInfoPanel != nil {
                    Button {
                        withAnimation(.spring(duration: 0.25)) { activeInfoPanel = nil }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.callout.bold())
                            .foregroundStyle(.secondary)
                            .padding(7)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }

            if activeInfoPanel != nil {
                Divider()
                    .padding(.vertical, 8)

                if activeInfoPanel == .scenarioBrief {
                    scenarioBriefContent
                } else if activeInfoPanel == .aiInstructor {
                    aiInstructorContent
                } else if activeInfoPanel == .annotations {
                    annotationsContent
                }
            }
        }
        .trainerCardStyle(background: TrainerLabTheme.tacticalSurfaceElevated)
        .task(id: activeInfoPanel) {
            // Auto-collapse Scenario Brief after 2 minutes
            guard activeInfoPanel == .scenarioBrief else { return }
            try? await Task.sleep(nanoseconds: 120_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                if activeInfoPanel == .scenarioBrief { activeInfoPanel = nil }
            }
        }
    }

    @ViewBuilder
    private func infoPanelSegment(_ panel: ActiveInfoPanel, label: String) -> some View {
        let isActive = activeInfoPanel == panel
        Button {
            withAnimation(.spring(duration: 0.25)) {
                activeInfoPanel = isActive ? nil : panel
            }
            if !isActive {
                Task { await fetchInfoPanelData(for: panel) }
            }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                    .frame(maxWidth: .infinity)
                if isLoadingRuntimeState, panel == .aiInstructor {
                    ProgressView().controlSize(.mini)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(TrainerLabTheme.accentBlue.opacity(0.22))
                        .matchedGeometryEffect(id: "segmentSelector", in: segmentNS)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? TrainerLabTheme.accentBlue : Color.white.opacity(0.78))
        .animation(.spring(duration: 0.25), value: activeInfoPanel)
    }

    @ViewBuilder private var scenarioBriefContent: some View {
        if isLoadingRuntimeState, store.runtimeState == nil {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else if let brief = store.scenarioBrief ?? store.runtimeState?.scenarioBrief {
            VStack(alignment: .leading, spacing: 8) {
                if canMutate {
                    HStack {
                        Spacer()
                        Button { showScenarioBriefEditSheet = true } label: {
                            Label("Edit Brief", systemImage: "pencil.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(TrainerLabTheme.accentBlue)
                    }
                }
                Text(brief.readAloudBrief)
                    .font(.subheadline)

                briefRow(label: "Environment", value: brief.environment)
                if let loc = brief.locationOverview {
                    briefRow(label: "Location", value: loc)
                }
                if let threat = brief.threatContext {
                    briefRow(label: "Threat", value: threat)
                }
                if !brief.evacuationOptions.isEmpty {
                    briefListRow(label: "Evacuation", values: brief.evacuationOptions)
                }
                if let evacTime = brief.evacuationTime {
                    briefRow(label: "EVAC ETA", value: evacTime)
                }
                if !brief.specialConsiderations.isEmpty {
                    briefListRow(label: "Special", values: brief.specialConsiderations)
                }
            }
        } else {
            Text("No scenario brief available.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var aiInstructorContent: some View {
        if let rs = store.runtimeState {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Runtime")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    debugMetaRow(label: "Status", value: rs.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    if let tickInterval = rs.tickIntervalSeconds {
                        debugMetaRow(label: "Tick Interval", value: "\(tickInterval)s")
                    }
                    if let nextTickAt = rs.nextTickAt {
                        debugMetaRow(label: "Next Tick", value: nextTickAt.formatted(date: .omitted, time: .standard))
                    }
                    if let lastAITickAt = rs.lastAITickAt {
                        debugMetaRow(label: "Last AI Tick", value: lastAITickAt.formatted(date: .omitted, time: .standard))
                    }
                    if !rs.pendingRuntimeReasons.isEmpty {
                        debugMetaRow(label: "Pending Runtime Reasons", value: "\(rs.pendingRuntimeReasons.count)")
                    }
                    if !rs.currentlyProcessingReasons.isEmpty {
                        debugMetaRow(label: "Processing Reasons", value: "\(rs.currentlyProcessingReasons.count)")
                    }
                    if !rs.lastRuntimeError.isEmpty {
                        Text(rs.lastRuntimeError)
                            .font(.caption)
                            .foregroundStyle(TrainerLabTheme.danger)
                    }
                }

                if let plan = rs.aiPlan {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Focus")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(plan.summary)
                            .font(.subheadline)
                    }
                    if !plan.rationale.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rationale")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(plan.rationale)
                                .font(.caption)
                                .foregroundStyle(Color(white: 0.70))
                        }
                    }
                    if !plan.upcomingChanges.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upcoming Changes")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(plan.upcomingChanges, id: \.self) { change in
                                Text("• " + change)
                                    .font(.caption)
                                    .foregroundStyle(Color(white: 0.70))
                            }
                        }
                    }
                    if !plan.monitoringFocus.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monitoring")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(plan.monitoringFocus, id: \.self) { focus in
                                Text("• " + focus)
                                    .font(.caption)
                                    .foregroundStyle(Color(white: 0.70))
                            }
                        }
                    }
                }
                if !rs.aiRationaleNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Notes")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        ForEach(rs.aiRationaleNotes, id: \.self) { note in
                            Text("• " + note)
                                .font(.caption)
                                .foregroundStyle(Color(white: 0.70))
                        }
                    }
                }
                if let debug = store.controlPlaneDebug {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Control Plane Debug")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        debugMetaRow(label: "Current Step", value: "\(debug.currentStepIndex)")
                        if !debug.executionPlan.isEmpty {
                            ForEach(Array(debug.executionPlan.prefix(4).enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(index == debug.currentStepIndex ? "•" : "◦")
                                        .foregroundStyle(index == debug.currentStepIndex ? TrainerLabTheme.accentBlue : .secondary)
                                    Text(step)
                                        .font(.caption)
                                        .foregroundStyle(Color(white: 0.70))
                                }
                            }
                        }
                        if !debug.lastFailedStep.isEmpty {
                            debugMetaRow(label: "Last Failed Step", value: debug.lastFailedStep)
                        }
                        if !debug.lastFailedError.isEmpty {
                            Text(debug.lastFailedError)
                                .font(.caption)
                                .foregroundStyle(TrainerLabTheme.warning)
                        }
                    }
                }
                if rs.aiPlan == nil, rs.aiRationaleNotes.isEmpty {
                    Text("No AI plan available yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if canMutate {
                        Button("Tick AI") {
                            store.triggerRunTick()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)

                        Button("Tick Vitals") {
                            store.triggerVitalsTick()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }

                    Button("Refresh") {
                        Task { await fetchRuntimeState() }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        } else if isLoadingRuntimeState {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            Text("Could not load runtime state.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var annotationsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Debrief annotations stay separate from live simulation notes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if canMutate {
                    Button {
                        showAnnotationSheet = true
                    } label: {
                        Label("Add Annotation", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TrainerLabTheme.accentBlue)
                }
            }

            if store.debriefAnnotations.isEmpty {
                Text("No debrief annotations yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.debriefAnnotations.prefix(8)) { annotation in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(annotation.learningObjectiveLabel)
                                .font(.caption2.bold())
                                .foregroundStyle(TrainerLabTheme.accentBlue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(TrainerLabTheme.accentBlue.opacity(0.14))
                                .clipShape(Capsule())
                            Text(annotation.outcomeLabel)
                                .font(.caption2.bold())
                                .foregroundStyle(annotationOutcomeColor(annotation.outcome))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(annotationOutcomeColor(annotation.outcome).opacity(0.14))
                                .clipShape(Capsule())
                            Spacer()
                            Text(annotation.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(annotation.observationText)
                            .font(.subheadline)
                        if let linkedEventID = annotation.linkedEventID {
                            Text("Linked event #\(linkedEventID)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func briefRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func briefListRow(label: String, values: [String]) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(values, id: \.self) { value in
                    Text("• \(value)")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fetchRuntimeState() async {
        isLoadingRuntimeState = true
        await store.loadRuntimeState()
        await store.loadControlPlaneDebug()
        isLoadingRuntimeState = false
    }

    private func fetchInfoPanelData(for panel: ActiveInfoPanel) async {
        switch panel {
        case .scenarioBrief, .aiInstructor:
            await fetchRuntimeState()
        case .annotations:
            await store.loadAnnotations()
        }
    }

    // MARK: - Timeline pane

    private func centerTimelinePane(layoutMode: RunConsoleLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            timelineHeader(layoutMode: layoutMode)

            if filteredTimelineEntries.isEmpty {
                Text(selectedTimelineFilter == .all ? "No timeline entries yet" : "No matching timeline entries")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                timelineEntries
            }
        }
        .trainerCardStyle()
    }

    private var timelineEntries: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(filteredTimelineEntries.prefix(160)) { item in
                let isSuperseded = item.metadata["superseded_by"] != nil
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        timelineKindChip(item.kind)
                        Text(RunConsoleTimelinePresentation.title(for: item))
                            .font(.subheadline.bold())
                            .lineLimit(2)
                            .strikethrough(isSuperseded, color: .secondary)
                            .foregroundStyle(isSuperseded ? Color.secondary : Color.white)
                        Spacer(minLength: 8)
                        Text(item.createdAt.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.message)
                        .font(.caption)
                        .foregroundStyle(isSuperseded ? Color(white: 0.45) : Color(white: 0.70))
                        .strikethrough(isSuperseded, color: Color(white: 0.45))

                    // Intervention effectiveness / status badges
                    if item.kind == .intervention {
                        HStack(spacing: 6) {
                            if let effectiveness = item.metadata["effectiveness"] {
                                effectivenessBadge(effectiveness)
                            }
                            if let status = item.metadata["intervention_status"] {
                                interventionStatusBadge(status)
                            }
                            if isSuperseded {
                                Text("Updated")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSuperseded
                    ? TrainerLabTheme.tacticalSurfaceElevated.opacity(0.5)
                    : TrainerLabTheme.tacticalSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(TrainerLabTheme.tacticalBorder.opacity(0.6), lineWidth: 1),
                )
                .opacity(isSuperseded ? 0.65 : 1.0)
            }
        }
    }

    private func effectivenessBadge(_ value: String) -> some View {
        let color: Color = switch value {
        case "effective": TrainerLabTheme.success
        case "partially_effective": TrainerLabTheme.warning
        case "ineffective": TrainerLabTheme.danger
        default: Color.secondary
        }
        let label = value.replacingOccurrences(of: "_", with: " ").capitalized
        return Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private func interventionStatusBadge(_ value: String) -> some View {
        Text(value.capitalized)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Operational log

    private func bottomLogPane(layoutMode _: RunConsoleLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isOperationalLogExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isOperationalLogExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.bold())
                        Text("Operational Log")
                            .font(.headline)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
                if store.state.pendingCommandCount > 0 {
                    HStack(spacing: 8) {
                        Text("Pending: \(store.state.pendingCommandCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Clear Failed") {
                            Task { await store.purgeAbandonedCommands() }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
            }

            if isOperationalLogExpanded {
                operationalLogEntries
            } else {
                Text("Tap to view recent runtime events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .trainerCardStyle(background: TrainerLabTheme.tacticalSurfaceElevated)
    }

    private var operationalLogEntries: some View {
        LazyVStack(alignment: .leading, spacing: 6) {
            if operationalItems.isEmpty {
                Text("No runtime events yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(operationalItems.prefix(30), id: \.eventID) { item in
                    Text("[\(item.createdAt.formatted(date: .omitted, time: .standard))] \(item.eventType)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Terminal card overlay

    private func terminalCardOverlay(card: TerminalCard) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: terminalCardIcon(card.status))
                        .font(.title2)
                        .foregroundStyle(terminalCardColor(card.status))
                    Text(terminalCardTitle(card.status))
                        .font(.title3.bold())
                    Spacer()
                    Button {
                        withAnimation { terminalCardDismissed = true }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let reason = terminalCardMessage(card) {
                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let completedAt = card.completedAt {
                    Text("\(terminalTimestampLabel(card.status)) \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if canRetryInitialSimulation {
                    Button("Retry Simulation") {
                        store.retryInitialSimulation()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }

                Button("View Run Summary") {
                    onOpenSummary()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(18)
            .background(TrainerLabTheme.tacticalSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(terminalCardColor(card.status).opacity(0.4), lineWidth: 1),
            )
            .padding(16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func terminalCardTitle(_ status: TrainerSessionStatus) -> String {
        switch status {
        case .completed: "Session Complete"
        case .failed: "Session Failed"
        default: "Session Ended"
        }
    }

    private func terminalCardMessage(_ card: TerminalCard) -> String? {
        if let reason = card.reasonText?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
            return reason
        }

        if card.status == .failed {
            return "We could not start this simulation. Please try again."
        }

        return nil
    }

    private func terminalTimestampLabel(_ status: TrainerSessionStatus) -> String {
        switch status {
        case .completed:
            "Completed at"
        case .failed:
            "Failed at"
        default:
            "Ended at"
        }
    }

    private func terminalCardIcon(_ status: TrainerSessionStatus) -> String {
        switch status {
        case .completed: "checkmark.seal.fill"
        case .failed: "exclamationmark.triangle.fill"
        default: "stop.circle.fill"
        }
    }

    private func terminalCardColor(_ status: TrainerSessionStatus) -> Color {
        switch status {
        case .completed: TrainerLabTheme.success
        case .failed: TrainerLabTheme.danger
        default: TrainerLabTheme.warning
        }
    }

    // MARK: - Intervention sheet (structured picker)

    private var interventionSheet: some View {
        InterventionPickerSheet(
            dictionary: store.interventionDictionary,
            problems: store.state.problemAnnotations,
            prefilledTargetProblemID: interventionTargetProblemID,
            canMutate: canMutate,
        ) { type, siteCode, targetProblemID, status, effectiveness, notes in
            store.addIntervention(
                interventionType: type,
                siteCode: siteCode,
                targetProblemID: targetProblemID,
                status: status,
                effectiveness: effectiveness,
                notes: notes,
            )
            showInterventionSheet = false
        }
    }

    private func quickActionSheet(for injury: InjuryAnnotation) -> some View {
        InjuryQuickActionSheet(
            injury: injury,
            dictionary: store.interventionDictionary,
            canMutate: canMutate,
        ) { type, siteCode, status, effectiveness in
            store.addIntervention(
                interventionType: type,
                siteCode: siteCode,
                targetProblemID: store.state.problemAnnotations.first(where: { $0.causeID == injury.causeID })?.problemID,
                status: status,
                effectiveness: effectiveness,
            )
        }
    }

    private func resetInterventionSheet() {
        selectedInterventionType = nil
        selectedLocationLabel = nil
        selectedLaterality = nil
        selectedInterventionStatus = .applied
        interventionNotes = ""
        interventionTargetProblemID = nil
    }

    // MARK: - Steer sheet

    private var steerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Direct the AI to adjust the simulation in a specific direction.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("e.g. Patient is deteriorating rapidly...", text: $steerDraft, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)

                Text("\(steerDraft.count)/2000")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Button("Send Steer Prompt") {
                    store.steerPrompt(steerDraft)
                    steerDraft = ""
                    showSteerSheet = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(steerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canMutate)

                Spacer()
            }
            .padding()
            .navigationTitle("Steer AI")
            .inlineNavBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        steerDraft = ""
                        showSteerSheet = false
                    }
                }
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Event sheet

    private var eventSheet: some View {
        NavigationStack {
            Form {
                Picker("Event Type", selection: $eventMode) {
                    Text("Injury").tag("injury")
                    Text("Illness").tag("illness")
                    Text("Vitals").tag("vitals")
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .onChange(of: eventMode) { _, _ in
                    injuryCategory = ""
                    injuryLocation = ""
                    injuryKind = ""
                    injuryDescription = ""
                    illnessName = ""
                    illnessNameCustom = ""
                    illnessMarchCategory = "R"
                }

                if eventMode == "injury" {
                    eventInjurySection
                }

                if eventMode == "illness" {
                    eventIllnessSection
                }

                if eventMode == "vitals" {
                    eventVitalsSection
                }

                Section {
                    Button("Submit Event") {
                        switch eventMode {
                        case "injury":
                            store.addInjuryEvent(category: injuryCategory, location: injuryLocation, kind: injuryKind, description: injuryDescription)
                        case "illness":
                            let name = illnessName == "other" ? illnessNameCustom : illnessName
                            store.addIllnessEvent(name: name, description: illnessDescription, marchCategory: illnessMarchCategory, severity: illnessSeverity)
                        default:
                            let min = Int(vitalMin) ?? 80
                            let max = Int(vitalMax) ?? 100
                            store.addVitalEvent(type: vitalType, min: min, max: max)
                        }
                        showEventSheet = false
                    }
                    .disabled(!canMutate || !eventFormIsValid)
                }
            }
            .navigationTitle("Add Event")
            .inlineNavBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEventSheet = false }
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private var eventFormIsValid: Bool {
        switch eventMode {
        case "injury": !injuryCategory.isEmpty && !injuryLocation.isEmpty && !injuryKind.isEmpty
        case "illness": !illnessName.isEmpty && (illnessName != "other" || !illnessNameCustom.isEmpty)
        default: !vitalType.isEmpty
        }
    }

    @ViewBuilder
    private var eventInjurySection: some View {
        let dict = store.injuryDictionary
        Section("Injury Details") {
            // Step 1: Category
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if injuryCategory.isEmpty {
                    let cats: [DictionaryItem] = dict?.categories ?? defaultInjuryCategories
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(cats) { item in
                            eventChip(item.label, selected: false) {
                                injuryCategory = item.code
                                injuryLocation = ""
                                injuryKind = ""
                            }
                        }
                    }
                } else {
                    let label = (dict?.categories ?? defaultInjuryCategories).first { $0.code == injuryCategory }?.label ?? injuryCategory
                    selectedEventChip(label) { injuryCategory = ""; injuryLocation = ""; injuryKind = "" }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            // Step 2: Region (only after category selected)
            if !injuryCategory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Region")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if injuryLocation.isEmpty {
                        let regions: [DictionaryItem] = dict?.regions ?? []
                        if regions.isEmpty {
                            TextField("Region (e.g. left upper arm)", text: $injuryLocation)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                                ForEach(regions) { item in
                                    eventChip(item.label, selected: false) {
                                        injuryLocation = item.code
                                        injuryKind = ""
                                    }
                                }
                            }
                        }
                    } else {
                        let label = (dict?.regions ?? []).first { $0.code == injuryLocation }?.label ?? injuryLocation
                        selectedEventChip(label) { injuryLocation = ""; injuryKind = "" }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            // Step 3: Kind (only after region selected)
            if !injuryLocation.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kind")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    if injuryKind.isEmpty {
                        let kinds: [DictionaryItem] = dict?.kinds ?? []
                        if kinds.isEmpty {
                            TextField("Kind (e.g. laceration, fracture)", text: $injuryKind)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                                ForEach(kinds) { item in
                                    eventChip(item.label, selected: false) {
                                        injuryKind = item.code
                                    }
                                }
                            }
                        }
                    } else {
                        let label = (dict?.kinds ?? []).first { $0.code == injuryKind }?.label ?? injuryKind
                        selectedEventChip(label) { injuryKind = "" }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            TextField("Description (optional)", text: $injuryDescription, axis: .vertical)
                .lineLimit(1 ... 3)
        }
    }

    private var eventIllnessSection: some View {
        Section("Illness Details") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Illness")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if illnessName.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                        ForEach(commonIllnesses, id: \.code) { item in
                            eventChip(item.label, selected: false) {
                                illnessName = item.code
                            }
                        }
                    }
                } else if illnessName == "other" {
                    selectedEventChip("Other") { illnessName = ""; illnessNameCustom = "" }
                    TextField("Specify illness...", text: $illnessNameCustom)
                } else {
                    let label = commonIllnesses.first { $0.code == illnessName }?.label ?? illnessName
                    selectedEventChip(label) { illnessName = "" }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            TextField("Description (optional)", text: $illnessDescription, axis: .vertical)
                .lineLimit(1 ... 3)

            VStack(alignment: .leading, spacing: 4) {
                Text("MARCH Category")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Picker("MARCH Category", selection: $illnessMarchCategory) {
                    Text("M – Hemorrhage").tag("M")
                    Text("A – Airway").tag("A")
                    Text("R – Respiration").tag("R")
                    Text("C – Circulation").tag("C")
                    Text("H1 – Hypothermia").tag("H1")
                    Text("H2 – Head/Brain").tag("H2")
                    Text("PC – Penetrating/Chest").tag("PC")
                }
                .pickerStyle(.menu)
            }
            .listRowBackground(Color.clear)

            VStack(alignment: .leading, spacing: 4) {
                Text("Severity")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Picker("Severity", selection: $illnessSeverity) {
                    Text("Low").tag("low")
                    Text("Moderate").tag("moderate")
                    Text("High").tag("high")
                    Text("Critical").tag("critical")
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
        }
    }

    private var eventVitalsSection: some View {
        Section("Vital Override") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vital")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Picker("Vital Type", selection: $vitalType) {
                    Text("Heart Rate (bpm)").tag("heart_rate")
                    Text("Resp. Rate (/min)").tag("respiratory_rate")
                    Text("SpO₂ (%)").tag("spo2")
                    Text("EtCO₂ (mmHg)").tag("etco2")
                    Text("Blood Glucose (mg/dL)").tag("blood_glucose")
                    Text("Blood Pressure (mmHg)").tag("blood_pressure")
                }
                .pickerStyle(.menu)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vitalType == "blood_pressure" ? "Systolic Min" : "Min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Min", text: $vitalMin)
                        .numericKeyboard()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(vitalType == "blood_pressure" ? "Systolic Max" : "Max")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("Max", text: $vitalMax)
                        .numericKeyboard()
                }
            }
        }
    }

    private func eventChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func selectedEventChip(_ label: String, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private var defaultInjuryCategories: [DictionaryItem] {
        [
            DictionaryItem(code: "M", label: "Massive Hemorrhage"),
            DictionaryItem(code: "A", label: "Airway"),
            DictionaryItem(code: "R", label: "Respiration"),
            DictionaryItem(code: "C", label: "Circulation"),
            DictionaryItem(code: "H1", label: "Hypothermia"),
            DictionaryItem(code: "H2", label: "Head / Brain"),
            DictionaryItem(code: "PC", label: "Penetrating / Chest"),
        ]
    }

    private var commonIllnesses: [DictionaryItem] {
        [
            DictionaryItem(code: "tension_pneumothorax", label: "Tension Pneumothorax"),
            DictionaryItem(code: "hemorrhagic_shock", label: "Hemorrhagic Shock"),
            DictionaryItem(code: "sepsis", label: "Sepsis"),
            DictionaryItem(code: "hyperthermia", label: "Hyperthermia"),
            DictionaryItem(code: "hypothermia", label: "Hypothermia"),
            DictionaryItem(code: "anaphylaxis", label: "Anaphylaxis"),
            DictionaryItem(code: "airway_obstruction", label: "Airway Obstruction"),
            DictionaryItem(code: "other", label: "Other…"),
        ]
    }

    // MARK: - Helpers

    private var stopwatchStatus: some View {
        Label(formattedStopwatch, systemImage: "stopwatch.fill")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private func timelineHeader(layoutMode: RunConsoleLayoutMode) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Timeline")
                .font(layoutMode == .compact ? .subheadline.bold() : .headline)

            Spacer()

            Menu {
                Picker("Event Type", selection: $selectedTimelineFilter) {
                    ForEach(TimelineFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
            } label: {
                Label(selectedTimelineFilter.title, systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filteredTimelineEntries: [ClinicalTimelineEntry] {
        switch selectedTimelineFilter {
        case .all:
            store.state.clinicalTimelineEntries
        case let .kind(kind):
            store.state.clinicalTimelineEntries.filter { $0.kind == kind }
        }
    }

    private func addTrainerNote() {
        let trimmed = trainerNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addTrainerNote(trimmed)
        trainerNoteDraft = ""
        selectedTimelineFilter = .all
    }

    private func annotationOutcomeColor(_ outcome: AnnotationOutcome) -> Color {
        switch outcome {
        case .correct:
            TrainerLabTheme.success
        case .incorrect, .missed:
            TrainerLabTheme.danger
        case .improvised, .pending:
            TrainerLabTheme.warning
        }
    }

    private func debugMetaRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 118, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(Color(white: 0.70))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func avpuButton(_ stateValue: AVPUState, label: String) -> some View {
        Button {
            selectedAVPU = stateValue
            store.adjustAVPU(stateValue)
        } label: {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(avpuColor(stateValue))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selectedAVPU == stateValue ? Color.white : Color.clear, lineWidth: 2),
                )
        }
        .buttonStyle(.plain)
        .disabled(!canMutate)
        .opacity(canMutate ? 1 : 0.55)
    }

    private func avpuColor(_ value: AVPUState) -> Color {
        switch value {
        case .alert: TrainerLabTheme.avpuAlert
        case .verbal: TrainerLabTheme.avpuVerbal
        case .pain: TrainerLabTheme.avpuPain
        case .unalert: TrainerLabTheme.avpuUnalert
        }
    }

    private var canMutate: Bool {
        store.state.commandChannelAvailable
    }

    private var canRetryInitialSimulation: Bool {
        store.state.session?.status == .failed && store.state.session?.retryable == true
    }

    private var sessionStatus: TrainerSessionStatus? {
        store.state.session?.status
    }

    private var lifecycleActions: [RunConsoleLifecycleAction] {
        RunConsoleLifecycleAction.visibleActions(for: sessionStatus)
    }

    private var orderedVitals: [VitalStatusSnapshot] {
        let preferred = ["heart_rate", "spo2", "etco2", "blood_pressure", "blood_glucose", "blood_glucose_level"]
        return store.state.vitals.sorted { lhs, rhs in
            let li = preferred.firstIndex(of: lhs.key) ?? Int.max
            let ri = preferred.firstIndex(of: rhs.key) ?? Int.max
            return li == ri ? lhs.key < rhs.key : li < ri
        }
    }

    private var groupedRecommendations: [(priority: String, items: [RecommendedInterventionItem])] {
        let grouped = Dictionary(grouping: store.state.recommendedInterventions) { recommendation in
            recommendation.priority?.capitalized ?? "Unprioritized"
        }
        return grouped
            .map { (priority: $0.key, items: $0.value.sorted { $0.title < $1.title }) }
            .sorted { lhs, rhs in
                recommendationPriorityRank(lhs.priority) < recommendationPriorityRank(rhs.priority)
            }
    }

    private func recommendationPriorityRank(_ priority: String) -> Int {
        switch priority.lowercased() {
        case "critical": 0
        case "high": 1
        case "medium", "moderate": 2
        case "low": 3
        default: 4
        }
    }

    private func linkedProblemLabel(for recommendation: RecommendedInterventionItem) -> String? {
        guard let problemID = recommendation.targetProblemID else { return nil }
        return store.state.problemAnnotations.first(where: { $0.problemID == problemID })?.label
    }

    private var operationalItems: [EventEnvelope] {
        var seen = Set<String>()
        var result: [EventEnvelope] = []
        for event in store.state.timeline.reversed() where !seen.contains(event.eventID) {
            seen.insert(event.eventID)
            result.append(event)
        }
        return result
    }

    private var formattedStopwatch: String {
        let seconds = max(store.state.stopwatchElapsedSeconds, 0)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private func timelineKindChip(_ kind: ClinicalTimelineKind) -> some View {
        Text(RunConsoleTimelinePresentation.chipText(for: kind))
            .font(.caption2.bold())
            .foregroundStyle(timelineColor(for: kind))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(timelineColor(for: kind).opacity(0.14))
            .clipShape(Capsule())
    }

    private func timelineColor(for kind: ClinicalTimelineKind) -> Color {
        switch kind {
        case .lifecycle: TrainerLabTheme.accentBlue
        case .cause, .injury, .illness, .loc, .problem: TrainerLabTheme.danger
        case .recommendation: TrainerLabTheme.warning
        case .intervention: TrainerLabTheme.success
        case .note: Color.cyan
        case .vitals: TrainerLabTheme.warning
        }
    }

    private func vitalDisplayName(_ key: String) -> String {
        switch key {
        case "heart_rate": "HR"
        case "spo2": "SpO2"
        case "etco2": "ETCO2"
        case "blood_pressure": "BP"
        case "blood_glucose", "blood_glucose_level": "Glucose"
        default: key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func displayValue(_ vital: VitalStatusSnapshot) -> String {
        if vital.key == "blood_pressure", let dia = vital.currentDiastolicValue {
            return "\(vital.currentValue)/\(dia)"
        }
        return "\(vital.currentValue)"
    }

    // MARK: - Grid helpers

    private func compactControlColumns(for compactMetrics: RunConsoleCompactMetrics) -> [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: compactMetrics.controlColumnMinimum), spacing: compactMetrics.gridSpacing), count: compactMetrics.compactControlColumnCount)
    }

    private func compactVitalsColumns(for compactMetrics: RunConsoleCompactMetrics) -> [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: compactMetrics.vitalsColumnMinimum), spacing: compactMetrics.gridSpacing), count: compactMetrics.compactVitalsColumnCount)
    }

    private var compactActionColumns: [GridItem] {
        [GridItem(.flexible(minimum: 120), spacing: 8), GridItem(.flexible(minimum: 120), spacing: 8)]
    }

    // MARK: - Button helpers

    private func lifecycleActionButton(
        _ action: RunConsoleLifecycleAction,
        compact: Bool,
        compactMetrics: RunConsoleCompactMetrics = .standard,
        controlPresentation: RunConsoleCompactControlPresentation = .labeled,
    ) -> some View {
        quickAction(action.title, systemImage: action.systemImage, enabled: canMutate, compact: compact, compactMetrics: compactMetrics, controlPresentation: controlPresentation) {
            switch action {
            case .start: store.start()
            case .pause: store.pause()
            case .resume: store.resume()
            case .stop: store.stop()
            }
        }
    }

    private func compactBackAction(compactMetrics: RunConsoleCompactMetrics, controlPresentation: RunConsoleCompactControlPresentation) -> some View {
        quickAction("Exit", systemImage: "xmark", enabled: true, compact: true, compactMetrics: compactMetrics, controlPresentation: controlPresentation) {
            onBack()
        }
    }

    private func compactScenarioAction(
        _ title: String, systemImage: String,
        compactMetrics: RunConsoleCompactMetrics,
        action: @escaping () -> Void,
        controlPresentation: RunConsoleCompactControlPresentation,
    ) -> some View {
        quickAction(title, systemImage: systemImage, enabled: canMutate, compact: true, compactMetrics: compactMetrics, controlPresentation: controlPresentation, action: action)
            .frame(maxWidth: .infinity)
    }

    private func quickAction(
        _ title: String, systemImage: String, enabled: Bool,
        compact: Bool = false,
        compactMetrics: RunConsoleCompactMetrics = .standard,
        controlPresentation: RunConsoleCompactControlPresentation = .labeled,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            if compact, controlPresentation == .iconOnly {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: compactMetrics.buttonMinHeight)
            } else {
                Label(title, systemImage: systemImage)
                    .font(compact ? compactMetrics.buttonFont : .body)
                    .lineLimit(compact ? 2 : 1)
                    .multilineTextAlignment(compact ? .center : .leading)
                    .frame(maxWidth: compact ? .infinity : nil)
                    .frame(minHeight: compact ? compactMetrics.buttonMinHeight : nil)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(compact ? compactMetrics.buttonControlSize : .regular)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }

    private func compactSummaryButton(compactMetrics: RunConsoleCompactMetrics) -> some View {
        Button("Run Summary") { onOpenSummary() }
            .buttonStyle(.borderedProminent)
            .controlSize(compactMetrics.buttonControlSize)
            .frame(minHeight: compactMetrics.buttonMinHeight)
    }

    private func compactVitalCell(_ vital: VitalStatusSnapshot, compactMetrics: RunConsoleCompactMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vitalDisplayName(vital.key))
                .font(compactMetrics.vitalLabelFont)
                .foregroundStyle(.secondary)
            VitalValueCell(vital: vital, valueText: displayValue(vital), font: compactMetrics.vitalValueFont, verticalPadding: compactMetrics.vitalValueVerticalPadding)
                .frame(maxWidth: .infinity)
        }
        .padding(compactMetrics.vitalCellPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrainerLabTheme.tacticalSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Intervention picker sheet

private struct InterventionPickerSheet: View {
    let dictionary: [InterventionGroup]
    let problems: [ProblemAnnotation]
    let prefilledTargetProblemID: Int?
    let canMutate: Bool
    let onSubmit: (String, String, Int, InterventionStatus, InterventionEffectiveness, String) -> Void

    @State private var selectedType: String?
    @State private var selectedTargetProblemID: Int?
    @State private var selectedLocationLabel: String?
    @State private var selectedLaterality: String?
    @State private var status: InterventionStatus = .applied
    @State private var effectiveness: InterventionEffectiveness = .effective
    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss

    private var selectedGroup: InterventionGroup? {
        guard let type = selectedType else { return nil }
        return dictionary.first { $0.interventionType == type }
    }

    private var locationGroups: [(location: String, sites: [InterventionSite])] {
        guard let group = selectedGroup else { return [] }
        return InterventionSite.grouped(group.sites)
    }

    private var resolvedSiteCode: String? {
        guard let group = selectedGroup, let locLabel = selectedLocationLabel else { return nil }
        let matchingSites = group.sites.filter { $0.locationLabel == locLabel }
        if matchingSites.count == 1 {
            return matchingSites.first?.code
        }
        if let lat = selectedLaterality {
            return matchingSites.first { $0.laterality == lat }?.code
        }
        return nil
    }

    private var canSubmit: Bool {
        canMutate && resolvedSiteCode != nil && selectedTargetProblemID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if !problems.isEmpty {
                    Section("Target Problem") {
                        ForEach(problems) { problem in
                            Button {
                                selectedTargetProblemID = problem.problemID
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(problem.label)
                                            .foregroundStyle(.primary)
                                        Text(problem.status.rawValue.capitalized)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedTargetProblemID == problem.problemID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Section("Target Problem") {
                        Text("A target problem is required by the backend before an intervention can be submitted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Step 1: Intervention type (MARCH grouped)
                Section("Intervention Type") {
                    if let type = selectedType {
                        let label = dictionary.first { $0.interventionType == type }?.label ?? type
                        selectedChip(label) {
                            selectedType = nil
                            selectedLocationLabel = nil
                            selectedLaterality = nil
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(InterventionMARCHGroup.allCases, id: \.self) { marchGroup in
                                let types = marchGroup.interventionTypes.compactMap { code in
                                    dictionary.first { $0.interventionType == code }
                                }
                                if !types.isEmpty {
                                    Text(marchGroup.rawValue)
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    LazyVGrid(
                                        columns: [GridItem(.adaptive(minimum: 140), spacing: 8)],
                                        spacing: 8,
                                    ) {
                                        ForEach(types) { group in
                                            typeChip(group)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                // Step 2: Location (visible after type selected)
                if let group = selectedGroup, !locationGroups.isEmpty {
                    Section("Location") {
                        if let locLabel = selectedLocationLabel {
                            selectedChip(locLabel) {
                                selectedLocationLabel = nil
                                selectedLaterality = nil
                            }
                            // Laterality inline after location selected
                            let sites = group.sites.filter { $0.locationLabel == locLabel }
                            let needsLat = sites.contains { $0.laterality != nil }
                            if needsLat {
                                if let lat = selectedLaterality {
                                    selectedChip(lat.capitalized) { selectedLaterality = nil }
                                } else {
                                    HStack(spacing: 8) {
                                        lateralityChip("left", label: "Left")
                                        lateralityChip("right", label: "Right")
                                        Spacer()
                                    }
                                }
                            }
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                                spacing: 8,
                            ) {
                                ForEach(locationGroups, id: \.location) { entry in
                                    locationChip(entry.location)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                // Effectiveness + Status + Notes (visible after type selected)
                if selectedType != nil {
                    Section("Effectiveness") {
                        Picker("Effectiveness", selection: $effectiveness) {
                            Text("Unknown").tag(InterventionEffectiveness.unknown)
                            Text("Effective").tag(InterventionEffectiveness.effective)
                            Text("Partial").tag(InterventionEffectiveness.partiallyEffective)
                            Text("Ineffective").tag(InterventionEffectiveness.ineffective)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }

                    Section("Status") {
                        Picker("Status", selection: $status) {
                            Text("Applied").tag(InterventionStatus.applied)
                            Text("Adjusted").tag(InterventionStatus.adjusted)
                            Text("Reassessed").tag(InterventionStatus.reassessed)
                            Text("Removed").tag(InterventionStatus.removed)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }

                    Section("Notes (optional)") {
                        TextField("Additional notes...", text: $notes, axis: .vertical)
                            .lineLimit(1 ... 3)
                    }
                }
            }
            .navigationTitle("Add Intervention")
            .inlineNavBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        guard let siteCode = resolvedSiteCode,
                              let type = selectedType,
                              let selectedTargetProblemID else { return }
                        onSubmit(type, siteCode, selectedTargetProblemID, status, effectiveness, notes)
                    }
                    .disabled(!canSubmit)
                }
            }
        }
        .onAppear {
            if selectedTargetProblemID == nil {
                selectedTargetProblemID = prefilledTargetProblemID
            }
        }
    }

    private func selectedChip(_ label: String, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func typeChip(_ group: InterventionGroup) -> some View {
        Button {
            selectedType = group.interventionType
            selectedLocationLabel = nil
            selectedLaterality = nil
        } label: {
            Text(group.label)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func locationChip(_ location: String) -> some View {
        Button {
            selectedLocationLabel = location
            selectedLaterality = nil
        } label: {
            Text(location)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func lateralityChip(_ lat: String, label: String) -> some View {
        let selected = selectedLaterality == lat
        return Button {
            selectedLaterality = selected ? nil : lat
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: 80)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Injury quick-action sheet

private struct InjuryQuickActionSheet: View {
    let injury: InjuryAnnotation
    let dictionary: [InterventionGroup]
    let canMutate: Bool
    let onApply: (String, String, InterventionStatus, InterventionEffectiveness) -> Void

    @State private var selectedSuggestionType: String?
    @State private var selectedSiteCode: String?
    @State private var status: InterventionStatus = .applied
    @State private var effectiveness: InterventionEffectiveness = .effective
    @Environment(\.dismiss) private var dismiss

    private var suggestions: [InterventionSuggestion] {
        []
    }

    private var selectedGroup: InterventionGroup? {
        guard let type = selectedSuggestionType else { return nil }
        return InterventionDictionary.group(for: type, in: dictionary)
    }

    private var canSubmit: Bool {
        canMutate && selectedSuggestionType != nil && selectedSiteCode != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                injurySummarySection
                suggestionsSection
                siteSection
                statusSections
            }
            .navigationTitle("Quick Action")
            .inlineNavBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        guard let type = selectedSuggestionType, let site = selectedSiteCode else { return }
                        onApply(type, site, status, effectiveness)
                        dismiss()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var injurySummarySection: some View {
        Section("Cause") {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(injury.kind.uppercased())\(injury.category.map { " (\($0.uppercased()))" } ?? "")")
                    .font(.subheadline.bold())
                Text(injury.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Location: \(injury.locationCode) · \(injury.side.rawValue.capitalized)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var suggestionsSection: some View {
        if !suggestions.isEmpty {
            Section("Suggested Interventions") {
                ForEach(suggestions, id: \.interventionType) { suggestion in
                    suggestionRow(suggestion)
                }
            }
        } else {
            Section {
                Text("Backend-authored recommended interventions now appear in the main patient panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func suggestionRow(_ suggestion: InterventionSuggestion) -> some View {
        let selected = selectedSuggestionType == suggestion.interventionType
        return Button {
            if selected {
                selectedSuggestionType = nil
                selectedSiteCode = nil
            } else {
                selectedSuggestionType = suggestion.interventionType
                let group = InterventionDictionary.group(for: suggestion.interventionType, in: dictionary)
                selectedSiteCode = group?.sites.count == 1 ? group?.sites.first?.code : nil
            }
        } label: {
            HStack {
                Text(suggestion.label)
                    .font(.subheadline)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder private var siteSection: some View {
        if let group = selectedGroup, group.sites.count > 1 {
            Section("Site") {
                ForEach(group.sites, id: \.code) { site in
                    Button {
                        selectedSiteCode = site.code
                    } label: {
                        HStack {
                            Text(site.label)
                            Spacer()
                            if selectedSiteCode == site.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder private var statusSections: some View {
        if selectedSuggestionType != nil {
            Section("Effectiveness") {
                Picker("Effectiveness", selection: $effectiveness) {
                    Text("Unknown").tag(InterventionEffectiveness.unknown)
                    Text("Effective").tag(InterventionEffectiveness.effective)
                    Text("Partial").tag(InterventionEffectiveness.partiallyEffective)
                    Text("Ineffective").tag(InterventionEffectiveness.ineffective)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            Section("Status") {
                Picker("Status", selection: $status) {
                    Text("Applied").tag(InterventionStatus.applied)
                    Text("Adjusted").tag(InterventionStatus.adjusted)
                    Text("Removed").tag(InterventionStatus.removed)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - Timeline filter

private enum TimelineFilter: Hashable, CaseIterable, Identifiable {
    case all
    case kind(ClinicalTimelineKind)

    static var allCases: [TimelineFilter] {
        [.all, .kind(.lifecycle), .kind(.cause), .kind(.problem), .kind(.recommendation), .kind(.intervention), .kind(.loc), .kind(.note), .kind(.vitals)]
    }

    var id: String {
        switch self {
        case .all: "all"
        case let .kind(kind): kind.rawValue
        }
    }

    var title: String {
        switch self {
        case .all: "All Events"
        case .kind(.lifecycle): "Lifecycle"
        case .kind(.cause): "Causes"
        case .kind(.problem): "Problems"
        case .kind(.recommendation): "Recommendations"
        case .kind(.intervention): "Intervention"
        case .kind(.loc): "LOC"
        case .kind(.note): "Notes"
        case .kind(.vitals): "Vitals"
        case .kind(.injury): "Injury"
        case .kind(.illness): "Illness"
        }
    }
}

// MARK: - Card modifier

private struct RunConsoleCardModifier: ViewModifier {
    let background: Color
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TrainerLabTheme.tacticalBorder, lineWidth: 1),
            )
    }
}

// MARK: - Vital value cell

private struct VitalValueCell: View {
    let vital: VitalStatusSnapshot
    let valueText: String
    let font: Font
    let verticalPadding: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lastChangeToken = 0
    @State private var shimmerOffset: CGFloat = -0.8
    @State private var shimmerVisible = false
    @State private var pulseVisible = false
    @State private var finishTask: Task<Void, Never>?

    init(
        vital: VitalStatusSnapshot,
        valueText: String,
        font: Font = .subheadline.monospacedDigit(),
        verticalPadding: CGFloat = 6,
    ) {
        self.vital = vital
        self.valueText = valueText
        self.font = font
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(TrainerLabTheme.tacticalSurfaceElevated)

            HStack(spacing: 4) {
                Text(valueText)
                    .font(font)
                    .foregroundStyle(.white)
                Image(systemName: trendIcon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(trendColor)
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 6)

            if reduceMotion {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(pulseVisible ? 0.22 : 0))
                    .animation(.easeOut(duration: 0.25), value: pulseVisible)
            } else {
                GeometryReader { proxy in
                    let width = max(proxy.size.width * 0.4, 32)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.12), Color.white.opacity(0.35), Color.white.opacity(0.12), .clear],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .frame(width: width)
                        .offset(x: shimmerOffset * proxy.size.width)
                        .opacity(shimmerVisible ? 1 : 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .allowsHitTesting(false)
            }
        }
        .onAppear { lastChangeToken = vital.changeToken }
        .onDisappear { finishTask?.cancel() }
        .onChange(of: vital.changeToken) { _, newToken in
            guard newToken != lastChangeToken else { return }
            lastChangeToken = newToken
            triggerChangeAnimation()
        }
    }

    private var trendIcon: String {
        switch vital.trend {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .flat: "minus"
        }
    }

    private var trendColor: Color {
        switch vital.trend {
        case .up: TrainerLabTheme.warning
        case .down: TrainerLabTheme.success
        case .flat: .secondary
        }
    }

    private func triggerChangeAnimation() {
        finishTask?.cancel()
        if reduceMotion {
            pulseVisible = true
            finishTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                pulseVisible = false
            }
        } else {
            shimmerOffset = -0.8
            shimmerVisible = false
            withAnimation(.linear(duration: 0.55)) {
                shimmerOffset = 1.0
                shimmerVisible = true
            }
            finishTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                shimmerVisible = false
            }
        }
    }
}

// MARK: - Platform helpers

private extension View {
    @ViewBuilder func inlineNavBarTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }

    @ViewBuilder func numericKeyboard() -> some View {
        #if os(iOS)
            keyboardType(.numberPad)
        #else
            self
        #endif
    }
}

// MARK: - Note composer sheet

private struct NoteComposerSheet: View {
    @Binding var draft: String
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Add a simulation note event for the live run…", text: $draft, axis: .vertical)
                    .lineLimit(1 ... 4)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit {
                        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        onSubmit()
                    }

                Button(action: onSubmit) {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .onAppear { focused = true }
    }
}

struct DebriefAnnotationOption<Value: Hashable & Sendable>: Equatable {
    let value: Value
    let label: String
}

enum DebriefAnnotationCatalog {
    static let learningObjectiveOptions = AnnotationLearningObjective.allCases.map {
        DebriefAnnotationOption(value: $0, label: $0.displayLabel)
    }

    static let outcomeOptions = AnnotationOutcome.allCases.map {
        DebriefAnnotationOption(value: $0, label: $0.displayLabel)
    }
}

private struct DebriefAnnotationSheet: View {
    let onSubmit: (String, AnnotationLearningObjective, AnnotationOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var observationText = ""
    @State private var learningObjective: AnnotationLearningObjective = .other
    @State private var outcome: AnnotationOutcome = .pending

    var body: some View {
        NavigationStack {
            Form {
                Section("Observation") {
                    TextField("What should be captured for debrief?", text: $observationText, axis: .vertical)
                        .lineLimit(3 ... 6)
                }

                Section("Learning Objective") {
                    Picker("Learning Objective", selection: $learningObjective) {
                        ForEach(DebriefAnnotationCatalog.learningObjectiveOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                }

                Section("Outcome") {
                    Picker("Outcome", selection: $outcome) {
                        ForEach(DebriefAnnotationCatalog.outcomeOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Add Annotation")
            .inlineNavBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSubmit(
                            observationText.trimmingCharacters(in: .whitespacesAndNewlines),
                            learningObjective,
                            outcome,
                        )
                        dismiss()
                    }
                    .disabled(observationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Scenario Brief Edit Sheet

private struct ScenarioBriefEditSheet: View {
    let brief: ScenarioBriefOut
    let onSave: (ScenarioBriefUpdateRequest) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var readAloudBrief: String
    @State private var environment: String
    @State private var locationOverview: String
    @State private var threatContext: String
    @State private var evacuationOptions: String
    @State private var evacuationTime: String
    @State private var specialConsiderations: String

    init(brief: ScenarioBriefOut, onSave: @escaping (ScenarioBriefUpdateRequest) -> Void) {
        self.brief = brief
        self.onSave = onSave
        _readAloudBrief = State(initialValue: brief.readAloudBrief)
        _environment = State(initialValue: brief.environment)
        _locationOverview = State(initialValue: brief.locationOverview ?? "")
        _threatContext = State(initialValue: brief.threatContext ?? "")
        _evacuationOptions = State(initialValue: brief.evacuationOptions.joined(separator: ", "))
        _evacuationTime = State(initialValue: brief.evacuationTime ?? "")
        _specialConsiderations = State(initialValue: brief.specialConsiderations.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Read-Aloud Brief") {
                    TextField("Brief", text: $readAloudBrief, axis: .vertical)
                        .lineLimit(3 ... 6)
                }
                Section("Environment") {
                    TextField("Environment", text: $environment)
                }
                Section("Location") {
                    TextField("Location overview", text: $locationOverview)
                }
                Section("Threat") {
                    TextField("Threat context", text: $threatContext)
                }
                Section("Evacuation") {
                    TextField("Options (comma or newline separated)", text: $evacuationOptions, axis: .vertical)
                        .lineLimit(2 ... 4)
                    TextField("ETA", text: $evacuationTime)
                }
                Section("Special Considerations") {
                    TextField("Special considerations (comma or newline separated)", text: $specialConsiderations, axis: .vertical)
                        .lineLimit(2 ... 4)
                }
            }
            .navigationTitle("Edit Scenario Brief")
            .inlineNavBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(ScenarioBriefUpdateRequest(
                            readAloudBrief: readAloudBrief,
                            environment: environment,
                            locationOverview: locationOverview.isEmpty ? nil : locationOverview,
                            threatContext: threatContext.isEmpty ? nil : threatContext,
                            evacuationOptions: parseList(from: evacuationOptions),
                            evacuationTime: evacuationTime.isEmpty ? nil : evacuationTime,
                            specialConsiderations: parseList(from: specialConsiderations),
                        ))
                    }
                    .disabled(readAloudBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func parseList(from input: String) -> [String]? {
        let normalized = input.replacingOccurrences(of: "\n", with: ",")
        let values = normalized
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? nil : values
    }
}
