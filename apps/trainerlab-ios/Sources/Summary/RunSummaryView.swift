import DesignSystem
import FeedbackFeature
import Networking
import SharedModels
import SwiftUI

public struct RunSummaryView: View {
    @ObservedObject private var viewModel: RunSummaryViewModel
    private let feedbackService: FeedbackServiceProtocol?
    private let feedbackHeaderProvider: FeedbackRequestHeaderProviding?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var expandedSections = Set<RunSummarySection>()
    @State private var lastLayoutMode: RunSummaryLayoutMode?
    @State private var activeFeedbackContext: FeedbackLaunchContext?
    @State private var feedbackSuccessMessage: String?
    @State private var correctionText = ""
    @State private var correctionClaimID: String?
    @State private var showCorrection = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var observationID = 0

    public init(
        viewModel: RunSummaryViewModel,
        feedbackService: FeedbackServiceProtocol? = nil,
        feedbackHeaderProvider: FeedbackRequestHeaderProviding? = nil,
    ) {
        self.viewModel = viewModel
        self.feedbackService = feedbackService
        self.feedbackHeaderProvider = feedbackHeaderProvider
    }

    public var body: some View {
        GeometryReader { proxy in
            let layoutMode = RunSummaryLayoutMode.resolve(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
            )

            ScrollView {
                VStack(alignment: .leading, spacing: layoutMode == .pad ? 18 : 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("Run Summary")
                            .font(layoutMode == .pad ? .largeTitle.bold() : .title.bold())

                        Spacer(minLength: 12)

                        if feedbackService != nil, feedbackHeaderProvider != nil {
                            Button("Send Feedback") {
                                activeFeedbackContext = feedbackLaunchContext()
                            }
                            .trainerGlassButtonStyle()
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if let notReadyMessage = viewModel.notReadyMessage {
                        Text(notReadyMessage)
                            .foregroundStyle(.secondary)
                    } else if let error = viewModel.presentableError, viewModel.summary == nil {
                        InlineAppErrorView(error: error)
                    } else if let summary = viewModel.summary {
                        if let error = viewModel.presentableError {
                            InlineAppErrorView(error: error)
                        }
                        summaryMetrics(summary, layoutMode: layoutMode)
                        reviewStatus(summary)

                        if let debrief = summary.aiDebrief, summary.debriefStatus == nil || summary.debriefStatus == "ready" {
                            debriefSection(debrief, layoutMode: layoutMode)
                        } else if summary.debriefStatus == nil {
                            Text(viewModel.isWaitingForDebrief
                                ? "Waiting for debrief…"
                                : "Debrief is not available yet. Pull to refresh.")
                                .foregroundStyle(.secondary)
                        }

                        if let evidence = summary.evidence {
                            sectionCard(title: "Recorded evidence", expanded: true, layoutMode: layoutMode) {
                                Text("Recorded actions and instructor observations are shown separately. An absent record does not prove an action was missed.")
                                    .font(.caption).foregroundStyle(.secondary)
                                if (summary.evidenceOmittedCount ?? 0) > 0 {
                                    Text("Some repeated patient-state updates are omitted from this review.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                DisclosureGroup("Browse \(evidence.count) supporting records") {
                                    LazyVStack(alignment: .leading, spacing: 12) {
                                        ForEach(evidence) { item in
                                            evidenceRow(item)
                                        }
                                    }
                                }
                            }
                        } else if layoutMode == .pad {
                            HStack(alignment: .top, spacing: 16) {
                                sectionCard(title: "Timeline", expanded: true, layoutMode: layoutMode) {
                                    timelineContent(summary)
                                }
                                sectionCard(title: "Command Log", expanded: true, layoutMode: layoutMode) {
                                    commandLogContent(summary)
                                }
                            }
                        } else {
                            collapsibleSection(.timeline, title: "Timeline", layoutMode: layoutMode) {
                                timelineContent(summary)
                            }
                            collapsibleSection(.commandLog, title: "Command Log", layoutMode: layoutMode) {
                                commandLogContent(summary)
                            }
                        }
                    } else {
                        Text("Summary not available")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: layoutMode == .pad ? 1080 : .infinity, alignment: .leading)
                .padding(layoutMode == .pad ? 24 : 20)
                .frame(maxWidth: .infinity)
            }
            .background(TrainerLabTheme.setupBackground.ignoresSafeArea())
            .refreshable {
                await viewModel.loadUntilReady()
            }
            .onAppear {
                syncExpandedSections(for: layoutMode)
            }
            .onChange(of: layoutMode) { _, newValue in
                syncExpandedSections(for: newValue)
            }
        }
        .task(id: observationID) {
            await viewModel.loadUntilReady()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                observationID += 1
            }
        }
        .sheet(isPresented: $showCorrection) {
            NavigationStack {
                Form {
                    Section("Instructor observation or correction") {
                        TextField("What should the debrief account for?", text: $correctionText, axis: .vertical)
                            .lineLimit(4 ... 10)
                        Text("This updates the debrief evidence. It does not record a performed treatment or change the completed patient state.")
                            .font(.caption)
                    }
                }
                .navigationTitle("Review Debrief")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCorrection = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let text = correctionText.trimmingCharacters(in: .whitespacesAndNewlines)
                            let claimID = correctionClaimID
                            showCorrection = false
                            Task {
                                await viewModel.submitReview(correction: text, claimID: claimID)
                                observationID += 1
                            }
                        }
                        .disabled(correctionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || correctionText.count > 1500)
                    }
                }
            }
        }
        .sheet(item: $activeFeedbackContext) { context in
            if let feedbackService, let feedbackHeaderProvider {
                FeedbackFormView(
                    viewModel: FeedbackViewModel(
                        service: feedbackService,
                        headerProvider: feedbackHeaderProvider,
                        launchContext: context,
                    ),
                    onSubmitted: {
                        feedbackSuccessMessage = "Feedback sent."
                    },
                )
            }
        }
        .overlay(alignment: .top) {
            if let feedbackSuccessMessage {
                FeedbackSuccessBanner(message: feedbackSuccessMessage)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
        }
        .task(id: feedbackSuccessMessage) {
            guard feedbackSuccessMessage != nil else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled {
                feedbackSuccessMessage = nil
            }
        }
    }

    private func feedbackLaunchContext() -> FeedbackLaunchContext {
        FeedbackLaunchContext(
            scope: .simulation,
            sourceScreen: "trainer_run_summary",
            simulationID: viewModel.simulationID,
            labType: .trainerlab,
            simulationDisplayName: "Simulation #\(viewModel.simulationID)",
            simulationStatus: viewModel.summary?.status,
        )
    }

    private func summaryMetrics(_ summary: RunSummary, layoutMode: RunSummaryLayoutMode) -> some View {
        let items = [
            SummaryMetric(title: "Simulation", value: "#\(summary.simulationID)", tint: TrainerLabTheme.accentBlue),
            SummaryMetric(title: "Status", value: summary.status.capitalized, tint: statusColor(summary.status)),
            SummaryMetric(title: "Started", value: formatRunTime(summary.runStartedAt, start: summary.runStartedAt, end: summary.runCompletedAt), tint: .secondary),
            SummaryMetric(title: "Completed", value: formatRunTime(summary.runCompletedAt, start: summary.runStartedAt, end: summary.runCompletedAt), tint: .secondary),
            SummaryMetric(title: "Events", value: "\(summary.eventTypeCounts.values.reduce(0, +))", tint: TrainerLabTheme.warning),
        ]

        return LazyVGrid(
            columns: summaryMetricColumns(for: layoutMode),
            spacing: 12,
        ) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(layoutMode == .pad ? .title3.bold() : .headline)
                        .foregroundStyle(item.tint)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .trainerCardStyle(
                    background: TrainerLabTheme.setupSurface,
                    glassRole: .setupCard,
                    tint: item.tint.opacity(0.08),
                )
            }
        }
    }

    private func collapsibleSection(
        _ section: RunSummarySection,
        title: String,
        layoutMode _: RunSummaryLayoutMode,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                toggle(section)
            } label: {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expandedSections.contains(section) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .trainerCardStyle(background: TrainerLabTheme.setupSurface, glassRole: .setupCard)
    }

    private func sectionCard(
        title: String,
        expanded: Bool,
        layoutMode: RunSummaryLayoutMode,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if layoutMode != .pad {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            if expanded {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .trainerCardStyle(background: TrainerLabTheme.setupSurface, glassRole: .setupCard)
    }

    private func timelineContent(_ summary: RunSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(summary.timelineHighlights.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(humanizeEventType(item.eventType, payload: item.payload))
                        .font(.subheadline.bold())
                    Text(formatRunTime(item.createdAt, start: summary.runStartedAt, end: summary.runCompletedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func commandLogContent(_ summary: RunSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(summary.commandLog.enumerated()), id: \.offset) { _, command in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(humanizeCommandType(command.commandType))
                            .font(.subheadline.bold())
                        Spacer()
                        Text(command.status.capitalized)
                            .font(.caption.bold())
                            .foregroundStyle(command.status == "processed" ? TrainerLabTheme.success : TrainerLabTheme.warning)
                    }
                    Text(formatRunTime(command.issuedAt, start: summary.runStartedAt, end: summary.runCompletedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func debriefSection(_ debrief: RunDebriefOutput, layoutMode: RunSummaryLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI Debrief")
                .font(layoutMode == .pad ? .title2.bold() : .title3.bold())

            if let claims = debrief.claims {
                if claims.isEmpty {
                    Text("There is not enough recorded evidence for an assessment. Add an instructor observation to continue the review.")
                }
                ForEach(claims) { claim in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(claim.category.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption.bold()).foregroundStyle(.secondary)
                        Text(claim.text)
                        DisclosureGroup("Supporting records (\(claim.evidenceIDs.count))") {
                            ForEach((viewModel.summary?.evidence ?? []).filter { claim.evidenceIDs.contains($0.id) }) { item in
                                evidenceRow(item)
                            }
                        }
                        Button("Correct this claim") {
                            correctionText = ""
                            correctionClaimID = claim.id
                            showCorrection = true
                        }
                        .disabled(viewModel.isSubmittingReview || viewModel.hasQueuedReview)
                    }
                    .padding(14)
                    .trainerCardStyle(background: TrainerLabTheme.setupSurface)
                }
            } else {
                legacyDebrief(debrief, layoutMode: layoutMode)
            }
        }
    }

    private func legacyDebrief(_ debrief: RunDebriefOutput, layoutMode: RunSummaryLayoutMode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Summary")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(debrief.narrativeSummary)
                    .font(.subheadline)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .trainerCardStyle(background: TrainerLabTheme.setupSurface)

            if !debrief.strengths.isEmpty || !debrief.misses.isEmpty {
                if layoutMode == .pad {
                    HStack(alignment: .top, spacing: 12) {
                        debriefListCard(title: "Strengths", items: debrief.strengths, tint: TrainerLabTheme.success)
                        debriefListCard(title: "Missed / Delayed", items: debrief.misses, tint: TrainerLabTheme.danger)
                    }
                } else {
                    debriefListCard(title: "Strengths", items: debrief.strengths, tint: TrainerLabTheme.success)
                    debriefListCard(title: "Missed / Delayed", items: debrief.misses, tint: TrainerLabTheme.danger)
                }
            }

            if !debrief.teachingPoints.isEmpty {
                debriefListCard(title: "Teaching Points", items: debrief.teachingPoints, tint: TrainerLabTheme.accentBlue)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Overall Assessment")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(debrief.overallAssessment)
                    .font(.subheadline)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .trainerCardStyle(background: TrainerLabTheme.setupSurface)
        }
    }

    @ViewBuilder
    private func reviewStatus(_ summary: RunSummary) -> some View {
        if let status = summary.debriefStatus {
            VStack(alignment: .leading, spacing: 8) {
                switch status {
                case "generating":
                    Label(viewModel.isWaitingForDebrief
                        ? "Preparing debrief from recorded evidence…"
                        : "Still processing. Pull to refresh its status.", systemImage: "hourglass")
                case "failed":
                    Text("Debrief generation failed. Your scenario evidence is available below.")
                case "stale":
                    Text("The evidence changed. Generate an updated debrief.")
                case "ready":
                    Text("AI-generated review · verify against supporting records")
                        .font(.caption).foregroundStyle(.secondary)
                default:
                    Text("Scenario evidence is ready for review.")
                }
                if viewModel.hasQueuedReview {
                    Label("Review saved on this device; awaiting delivery", systemImage: "arrow.triangle.2.circlepath")
                }
                if let error = viewModel.reviewError {
                    InlineAppErrorView(error: error)
                }
                if let rejected = viewModel.rejectedCorrection {
                    Button("Edit undelivered correction") {
                        correctionText = rejected
                        correctionClaimID = nil
                        showCorrection = true
                    }
                }
                HStack {
                    if status != "generating" {
                        Button(status == "ready" ? "Regenerate" : "Generate debrief") {
                            Task {
                                await viewModel.submitReview()
                                observationID += 1
                            }
                        }
                        .trainerGlassButtonStyle()
                    }
                    Button("Add observation") {
                        correctionText = ""
                        correctionClaimID = nil
                        showCorrection = true
                    }
                    .trainerGlassButtonStyle()
                }
                .disabled(viewModel.isSubmittingReview || viewModel.hasQueuedReview)
            }
        }
    }

    private func evidenceRow(_ evidence: DebriefEvidence) -> some View {
        DisclosureGroup {
            Text(evidence.detail).font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(evidence.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption).foregroundStyle(.secondary)
                Text(humanizeEventType(evidence.eventType, payload: evidence.facts))
                    .font(.subheadline)
                Text(formatRunTime(evidence.createdAt, start: viewModel.summary?.runStartedAt, end: viewModel.summary?.runCompletedAt))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func debriefListCard(title: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(tint)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(.subheadline)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .trainerCardStyle(background: TrainerLabTheme.setupSurface)
    }

    private func summaryMetricColumns(for layoutMode: RunSummaryLayoutMode) -> [GridItem] {
        switch layoutMode {
        case .pad:
            Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        case .phone:
            Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        case .narrowPhone:
            [GridItem(.flexible(), spacing: 12)]
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed":
            TrainerLabTheme.success
        case "failed":
            TrainerLabTheme.danger
        case "paused":
            TrainerLabTheme.warning
        default:
            TrainerLabTheme.accentBlue
        }
    }

    private func syncExpandedSections(for layoutMode: RunSummaryLayoutMode) {
        guard lastLayoutMode != layoutMode || expandedSections.isEmpty else { return }
        expandedSections = Set(
            RunSummarySection.allCases.filter { $0.defaultExpanded(for: layoutMode) },
        )
        lastLayoutMode = layoutMode
    }

    private func toggle(_ section: RunSummarySection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }
}

private struct SummaryMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

// MARK: - Date formatting helpers

private extension RunSummaryView {
    static let isoFormatterFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let isoFormatterPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return RunSummaryView.isoFormatterFractional.date(from: s)
            ?? RunSummaryView.isoFormatterPlain.date(from: s)
    }

    /// Formats an ISO-8601 timestamp for display.
    /// - Shows only HH:mm:ss when start and end are on the same day.
    /// - Prepends "dd MMM" when they span multiple days (same year).
    /// - Prepends "dd MMM yyyy" when they span multiple years.
    func formatRunTime(_ isoString: String?, start: String?, end: String?) -> String {
        guard let date = parseDate(isoString) else { return isoString ?? "-" }
        let startDate = parseDate(start)
        let endDate = parseDate(end)
        let cal = Calendar.current

        var needsDate = false
        var needsYear = false
        if let s = startDate, let e = endDate {
            needsDate = !cal.isDate(s, inSameDayAs: e)
            needsYear = cal.component(.year, from: s) != cal.component(.year, from: e)
        }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        if needsYear {
            df.dateFormat = "dd MMM yyyy HH:mm:ss"
        } else if needsDate {
            df.dateFormat = "dd MMM HH:mm:ss"
        } else {
            df.dateFormat = "HH:mm:ss"
        }
        return df.string(from: date)
    }

    func humanizeEventType(_ eventType: String, payload: [String: JSONValue]) -> String {
        SimulationEventRegistry.displayTitle(for: eventType, payload: payload)
    }

    func humanizeCommandType(_ commandType: String) -> String {
        commandType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
