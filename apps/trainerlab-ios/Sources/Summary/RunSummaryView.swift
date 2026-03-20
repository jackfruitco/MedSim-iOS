import DesignSystem
import SharedModels
import SwiftUI

public struct RunSummaryView: View {
    @ObservedObject private var viewModel: RunSummaryViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var expandedSections = Set<RunSummarySection>()
    @State private var lastLayoutMode: RunSummaryLayoutMode?

    public init(viewModel: RunSummaryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { proxy in
            let layoutMode = RunSummaryLayoutMode.resolve(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass
            )

            ScrollView {
                VStack(alignment: .leading, spacing: layoutMode == .pad ? 18 : 14) {
                    Text("Run Summary")
                        .font(layoutMode == .pad ? .largeTitle.bold() : .title.bold())

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if let notReadyMessage = viewModel.notReadyMessage {
                        Text(notReadyMessage)
                            .foregroundStyle(.secondary)
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(TrainerLabTheme.danger)
                    } else if let summary = viewModel.summary {
                        summaryMetrics(summary, layoutMode: layoutMode)

                        if let debrief = summary.aiDebrief {
                            debriefSection(debrief, layoutMode: layoutMode)
                        }

                        if layoutMode == .pad {
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
            .onAppear {
                syncExpandedSections(for: layoutMode)
            }
            .onChange(of: layoutMode) { _, newValue in
                syncExpandedSections(for: newValue)
            }
        }
        .task {
            await viewModel.load()
        }
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
            spacing: 12
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
                .trainerCardStyle(background: TrainerLabTheme.setupSurface)
            }
        }
    }

    private func collapsibleSection(
        _ section: RunSummarySection,
        title: String,
        layoutMode _: RunSummaryLayoutMode,
        @ViewBuilder content: () -> some View
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
        .trainerCardStyle(background: TrainerLabTheme.setupSurface)
    }

    private func sectionCard(
        title: String,
        expanded: Bool,
        layoutMode: RunSummaryLayoutMode,
        @ViewBuilder content: () -> some View
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
        .trainerCardStyle(background: TrainerLabTheme.setupSurface)
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
            RunSummarySection.allCases.filter { $0.defaultExpanded(for: layoutMode) }
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

    func humanizeEventType(_ eventType: String, payload _: [String: JSONValue]) -> String {
        let canonical = eventType.hasPrefix("trainerlab.")
            ? String(eventType.dropFirst("trainerlab.".count))
            : eventType

        switch canonical {
        case "run.started": return "Run Started"
        case "run.paused": return "Run Paused"
        case "run.resumed": return "Run Resumed"
        case "run.stopped", "run.completed": return "Run Stopped"
        case "vital.created", "vital.updated": return "Vital Range Set"
        case "note.created", "note_updated", "note.updated": return "Trainer Note"
        case "injury.created", "injury.updated": return "Cause Added"
        case "illness.created", "illness.updated": return "Cause Added"
        case "problem.created", "problem.updated", "problem.resolved", "problem.status_updated": return "Problem Updated"
        case "recommended_intervention.created", "recommended_intervention.updated", "recommended_intervention.cleared": return "Recommendation Updated"
        default:
            if canonical.contains("intervention") { return "Intervention Applied" }
            if canonical.contains("adjustment") {
                if canonical.contains("avpu") { return "AVPU Change" }
                return "Adjustment"
            }
            return canonical
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    func humanizeCommandType(_ commandType: String) -> String {
        commandType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
