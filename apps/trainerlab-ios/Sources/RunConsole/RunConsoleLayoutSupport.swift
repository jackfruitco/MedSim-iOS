import DesignSystem
import SharedModels
import SwiftUI

enum RunConsoleLayoutMode: Equatable {
    case regular
    case compact

    static func resolve(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Self {
        if width >= 900, horizontalSizeClass != .compact {
            return .regular
        }
        return .compact
    }
}

enum RunConsoleCompactDensity: Equatable {
    case standard
    case narrowPhone

    static func resolve(width: CGFloat, layoutMode: RunConsoleLayoutMode) -> Self {
        guard layoutMode == .compact, width <= 390 else {
            return .standard
        }
        return .narrowPhone
    }
}

enum RunConsoleCompactControlPresentation: Equatable {
    case grid
    case phoneMenus

    static func resolve(
        width: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?,
    ) -> Self {
        switch TrainerLabLayoutMode.resolve(width: width, horizontalSizeClass: horizontalSizeClass) {
        case .pad:
            .grid
        case .phone, .narrowPhone:
            .phoneMenus
        }
    }
}

enum RunConsoleTimelinePresentation {
    static func chipText(for kind: ClinicalTimelineKind) -> String {
        switch kind {
        case .loc:
            "LOC"
        default:
            kind.rawValue.uppercased()
        }
    }

    static func title(for entry: ClinicalTimelineEntry) -> String {
        switch entry.kind {
        case .cause:
            "Cause Identified"
        case .injury:
            "Injury Added"
        case .illness:
            "Illness Added"
        case .intervention:
            "Intervention Applied"
        case .loc:
            "LOC Updated"
        case .problem:
            "Problem Updated"
        case .recommendation:
            "Recommendation"
        case .lifecycle:
            entry.title
        case .note:
            entry.title
        case .vitals:
            "Vitals Updated"
        }
    }
}

enum RunConsoleTimelineAccordion {
    static func toggledExpandedEntryKey(
        current: String?,
        tapped entry: ClinicalTimelineEntry,
    ) -> String? {
        current == entry.dedupeKey ? nil : entry.dedupeKey
    }

    static func isExpanded(
        _ entry: ClinicalTimelineEntry,
        expandedEntryKey: String?,
    ) -> Bool {
        expandedEntryKey == entry.dedupeKey
    }
}

enum RunConsoleControlGroup: String {
    case session = "Session Controls"
    case clinical = "Clinical Actions"
    case tools = "Run Tools"
    case admin = "Admin & Debug"
}

enum RunConsoleQuickAction: String, CaseIterable, Hashable, Identifiable {
    case intervention
    case event
    case steer
    case annotation
    case presets
    case sendFeedback
    case tickAI
    case tickVitals

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .intervention:
            "Intervention"
        case .event:
            "Event"
        case .steer:
            "Steer"
        case .annotation:
            "Annotation"
        case .presets:
            "Presets"
        case .sendFeedback:
            "Send Feedback"
        case .tickAI:
            "Tick AI"
        case .tickVitals:
            "Tick Vitals"
        }
    }

    var systemImage: String {
        switch self {
        case .intervention, .event:
            "plus.app"
        case .steer:
            "wand.and.sparkles"
        case .annotation:
            "note.text.badge.plus"
        case .presets:
            "shippingbox"
        case .sendFeedback:
            "bubble.left.and.text.bubble.right"
        case .tickAI:
            "timer"
        case .tickVitals:
            "heart.text.square"
        }
    }
}

enum RunConsoleControlItem: Hashable, Identifiable {
    case exit
    case lifecycle(RunConsoleLifecycleAction)
    case summary
    case quick(RunConsoleQuickAction)

    var id: String {
        switch self {
        case .exit:
            "exit"
        case let .lifecycle(action):
            "lifecycle-\(action.rawValue)"
        case .summary:
            "summary"
        case let .quick(action):
            "quick-\(action.rawValue)"
        }
    }

    var group: RunConsoleControlGroup {
        switch self {
        case .exit, .lifecycle, .summary:
            .session
        case .quick(.intervention), .quick(.event), .quick(.steer):
            .clinical
        case .quick(.annotation), .quick(.presets):
            .tools
        case .quick(.sendFeedback), .quick(.tickAI), .quick(.tickVitals):
            .admin
        }
    }

    var title: String {
        switch self {
        case .exit:
            "Exit"
        case let .lifecycle(action):
            action.title
        case .summary:
            "Summary"
        case let .quick(action):
            action.title
        }
    }

    var systemImage: String {
        switch self {
        case .exit:
            "xmark"
        case let .lifecycle(action):
            action.systemImage
        case .summary:
            "doc.text"
        case let .quick(action):
            action.systemImage
        }
    }

    var requiresCommandChannel: Bool {
        switch self {
        case .exit, .summary:
            false
        case .lifecycle, .quick:
            true
        }
    }
}

enum RunConsoleControlsCatalog {
    static func sessionControls(lifecycleActions: [RunConsoleLifecycleAction]) -> [RunConsoleControlItem] {
        [.exit] + lifecycleActions.map(RunConsoleControlItem.lifecycle) + [.summary]
    }

    static let clinicalControls: [RunConsoleControlItem] = [
        .quick(.intervention),
        .quick(.event),
        .quick(.steer),
    ]

    static let toolControls: [RunConsoleControlItem] = [
        .quick(.annotation),
        .quick(.presets),
    ]

    static let adminControls: [RunConsoleControlItem] = [
        .quick(.sendFeedback),
        .quick(.tickAI),
        .quick(.tickVitals),
    ]

    static var quickControls: [RunConsoleControlItem] {
        clinicalControls + toolControls + adminControls
    }
}

enum RunConsoleTimelineFilter: Hashable, CaseIterable, Identifiable {
    case all
    case kind(ClinicalTimelineKind)

    static var allCases: [RunConsoleTimelineFilter] {
        [.all, .kind(.lifecycle), .kind(.cause), .kind(.problem), .kind(.recommendation), .kind(.intervention), .kind(.loc), .kind(.vitals), .kind(.note)]
    }

    var id: String {
        switch self {
        case .all:
            "all"
        case let .kind(kind):
            kind.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            "All Events"
        case .kind(.lifecycle):
            "Lifecycle"
        case .kind(.cause):
            "Causes"
        case .kind(.problem):
            "Problems"
        case .kind(.recommendation):
            "Recommendations"
        case .kind(.intervention):
            "Intervention"
        case .kind(.loc):
            "LOC"
        case .kind(.vitals):
            "Vitals"
        case .kind(.injury):
            "Injury"
        case .kind(.illness):
            "Illness"
        case .kind(.note):
            "Notes"
        }
    }

    static func visibleEntries(
        from entries: [ClinicalTimelineEntry],
        matching filter: RunConsoleTimelineFilter,
    ) -> [ClinicalTimelineEntry] {
        switch filter {
        case .all:
            entries
        case let .kind(kind):
            entries.filter { $0.kind == kind }
        }
    }
}

enum RunConsoleVitalsPresentation {
    private static let preferredVitalKeyOrder: [String: Int] = [
        "heart_rate": 0,
        "spo2": 1,
        "etco2": 2,
        "blood_pressure": 3,
        "blood_glucose": 4,
        "blood_glucose_level": 5,
    ]

    static func orderedVitals(_ vitals: [VitalStatusSnapshot]) -> [VitalStatusSnapshot] {
        vitals.sorted { lhs, rhs in
            let lhsIndex = preferredVitalKeyOrder[lhs.key] ?? Int.max
            let rhsIndex = preferredVitalKeyOrder[rhs.key] ?? Int.max
            return lhsIndex == rhsIndex ? lhs.key < rhs.key : lhsIndex < rhsIndex
        }
    }
}

struct RunConsoleCompactMetrics {
    let sectionSpacing: CGFloat
    let cardPadding: CGFloat
    let gridSpacing: CGFloat
    let controlColumnMinimum: CGFloat
    let vitalsColumnMinimum: CGFloat
    let compactControlColumnCount: Int
    let compactVitalsColumnCount: Int
    let controlLabelFont: Font
    let buttonFont: Font
    let vitalLabelFont: Font
    let vitalValueFont: Font
    let buttonControlSize: ControlSize
    let buttonMinHeight: CGFloat
    let vitalCellPadding: CGFloat
    let vitalValueVerticalPadding: CGFloat

    static func resolve(width: CGFloat, layoutMode: RunConsoleLayoutMode) -> Self {
        switch RunConsoleCompactDensity.resolve(width: width, layoutMode: layoutMode) {
        case .standard:
            .standard
        case .narrowPhone:
            .narrowPhone
        }
    }

    static let standard = Self(
        sectionSpacing: 9,
        cardPadding: 10,
        gridSpacing: 6,
        controlColumnMinimum: 104,
        vitalsColumnMinimum: 104,
        compactControlColumnCount: 3,
        compactVitalsColumnCount: 3,
        controlLabelFont: .caption2.bold(),
        buttonFont: .caption.weight(.semibold),
        vitalLabelFont: .caption2.bold(),
        vitalValueFont: .caption.monospacedDigit(),
        buttonControlSize: .small,
        buttonMinHeight: 40,
        vitalCellPadding: 7,
        vitalValueVerticalPadding: 3,
    )

    static let narrowPhone = Self(
        sectionSpacing: 8,
        cardPadding: 8,
        gridSpacing: 6,
        controlColumnMinimum: 92,
        vitalsColumnMinimum: 92,
        compactControlColumnCount: 3,
        compactVitalsColumnCount: 3,
        controlLabelFont: .caption2.bold(),
        buttonFont: .caption.weight(.semibold),
        vitalLabelFont: .caption2.bold(),
        vitalValueFont: .caption.monospacedDigit(),
        buttonControlSize: .small,
        buttonMinHeight: 38,
        vitalCellPadding: 6,
        vitalValueVerticalPadding: 3,
    )
}

struct RunConsoleRegularVitalsMetrics {
    let sectionSpacing: CGFloat
    let cardPadding: CGFloat
    let inlineGroupSpacing: CGFloat
    let fallbackRowSpacing: CGFloat
    let vitalsRowSpacing: CGFloat
    let vitalCellSpacing: CGFloat
    let vitalValueFont: Font
    let vitalValueVerticalPadding: CGFloat
    let avpuSpacing: CGFloat
    let avpuChipSpacing: CGFloat
    let avpuChipHorizontalPadding: CGFloat
    let avpuChipMinHeight: CGFloat
    let maxHeight: CGFloat

    static let standard = Self(
        sectionSpacing: 5,
        cardPadding: 5,
        inlineGroupSpacing: 10,
        fallbackRowSpacing: 5,
        vitalsRowSpacing: 5,
        vitalCellSpacing: 3,
        vitalValueFont: .footnote.monospacedDigit(),
        vitalValueVerticalPadding: 3,
        avpuSpacing: 6,
        avpuChipSpacing: 5,
        avpuChipHorizontalPadding: 8,
        avpuChipMinHeight: 28,
        maxHeight: 118,
    )
}

// MARK: - InterventionMARCHGroup

enum InterventionMARCHGroup: String, CaseIterable {
    case massiveHemorrhage = "M – Massive Hemorrhage"
    case airway = "A – Airway"
    case respiration = "R – Respiration"
    case access = "C – Circulation / Access"

    var interventionTypes: [String] {
        switch self {
        case .massiveHemorrhage:
            ["tourniquet", "junctional_tourniquet", "wound_packing", "pressure_dressing", "hemostatic_agent", "pelvic_binder"]
        case .airway:
            ["npa", "opa", "surgical_cric", "advanced_airway"]
        case .respiration:
            ["needle_decompression", "chest_tube"]
        case .access:
            ["iv_access", "io_access", "fluid_resuscitation", "blood_transfusion"]
        }
    }

    static func group(for interventionType: String) -> Self? {
        allCases.first { $0.interventionTypes.contains(interventionType) }
    }
}

enum RunConsoleLifecycleAction: String, CaseIterable {
    case start
    case pause
    case resume
    case stop

    var title: String {
        switch self {
        case .start:
            "Start"
        case .pause:
            "Pause"
        case .resume:
            "Resume"
        case .stop:
            "Stop"
        }
    }

    var systemImage: String {
        switch self {
        case .start:
            "play.fill"
        case .pause:
            "pause.fill"
        case .resume:
            "playpause.fill"
        case .stop:
            "stop.fill"
        }
    }

    static func visibleActions(for status: TrainerSessionStatus?) -> [Self] {
        switch status {
        case .seeding:
            [.start]
        case .seeded:
            [.start]
        case .running:
            [.pause, .stop]
        case .paused:
            [.resume, .stop]
        case .completed, .failed, .none:
            []
        }
    }
}

// MARK: - TransportChip

struct TransportChip: View {
    let banner: TransportBanner

    var body: some View {
        if banner.visible {
            Label(banner.message, systemImage: iconName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(chipColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(chipColor.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private var chipColor: Color {
        switch banner.style {
        case .healthy: TrainerLabTheme.success
        case .warning: TrainerLabTheme.warning
        case .error: TrainerLabTheme.danger
        }
    }

    private var iconName: String {
        switch banner.style {
        case .healthy: "antenna.radiowaves.left.and.right"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        }
    }
}

// MARK: - PatientDiagramPanel

enum PatientDiagramSelection: Equatable {
    case injury(InjuryAnnotation)
    case intervention(InterventionAnnotation)
    case problem(ProblemAnnotation)
    case pulse(PulseAnnotation)
}

struct PatientCauseProblemGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let problems: [ProblemAnnotation]
}

struct PatientDiagramPanel: View {
    let injuries: [InjuryAnnotation]
    let allCauses: [RuntimeCauseState]
    let interventions: [InterventionAnnotation]
    let problems: [ProblemAnnotation]
    let pulses: [PulseAnnotation]
    let pendingInterventionProblemIDs: Set<Int>
    let canMutate: Bool
    let layoutMode: RunConsoleLayoutMode
    let compactMetrics: RunConsoleCompactMetrics
    var onSelectInjury: ((InjuryAnnotation) -> Void)?
    var onSelectProblem: ((ProblemAnnotation) -> Void)?
    var onUpdateProblemStatus: ((ProblemAnnotation, ProblemLifecycleState) -> Void)?

    @State private var selected: PatientDiagramSelection?
    private let displayConvention: BodyDisplayOrientationConvention = RunConsolePatientDiagramSupport.displayOrientationConvention

    var body: some View {
        VStack(spacing: containerSpacing) {
            diagramSection
            causesAndProblemsSection
            if !pulses.isEmpty {
                pulsesSummarySection
            }

            if let selected {
                selectedDetailCard(selected)
            }
        }
    }

    private var containerSpacing: CGFloat {
        layoutMode == .compact ? compactMetrics.sectionSpacing : 10
    }

    private var sectionCornerRadius: CGFloat {
        layoutMode == .compact ? 10 : 12
    }

    private var headerPadding: CGFloat {
        layoutMode == .compact ? compactMetrics.cardPadding : 10
    }

    private var sectionContentPadding: CGFloat {
        layoutMode == .compact ? compactMetrics.cardPadding : 10
    }

    private var rowSpacing: CGFloat {
        layoutMode == .compact ? 6 : 8
    }

    private var diagramHeight: CGFloat {
        if layoutMode == .compact {
            return compactMetrics.cardPadding <= 8 ? 220 : 240
        }
        return 310
    }

    private var diagramSection: some View {
        staticSection(title: "Patient Diagram", systemImage: "figure.stand") {
            VStack(alignment: .leading, spacing: 6) {
                diagramArea
                    .frame(height: diagramHeight)
                if shouldShowDiagramLegend {
                    diagramLegend
                }
            }
        }
    }

    private func countBadge(_ count: Int) -> some View {
        countBadge(String(count))
    }

    private func countBadge(_ label: String) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
    }

    private func staticSection(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TrainerLabTheme.accentBlue)
                Text(title)
                    .font(layoutMode == .compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(headerPadding)
            Divider()
                .overlay(TrainerLabTheme.tacticalBorder.opacity(0.85))
            content()
                .padding(sectionContentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .fill(TrainerLabTheme.tacticalSurfaceElevated),
        )
        .overlay(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .stroke(TrainerLabTheme.tacticalBorder, lineWidth: 1),
        )
    }

    private var causesAndProblemsSection: some View {
        staticSection(title: "Patient Problems", systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: rowSpacing + 4) {
                ForEach(causeProblemGroups) { group in
                    causeProblemGroupView(group)
                }
                if !systemicProblems.isEmpty {
                    causeProblemGroupView(
                        PatientCauseProblemGroup(
                            id: "systemic-problems",
                            title: "Systemic Problems",
                            problems: systemicProblems,
                        ),
                    )
                }
                if causeProblemGroups.isEmpty, systemicProblems.isEmpty {
                    Text("No current problems.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func causeProblemGroupView(_ group: PatientCauseProblemGroup) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            Text(group.title)
                .font(layoutMode == .compact ? .subheadline.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            ForEach(group.problems) { problem in
                problemRow(problem)
            }
        }
        .padding(layoutMode == .compact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var pulsesSummarySection: some View {
        staticSection(title: "Pulses", systemImage: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    countBadge("\(pulses.filter(\.present).count)/\(pulses.count)")
                    Text("present")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: layoutMode == .compact ? 130 : 150), spacing: 6)], spacing: 6) {
                    ForEach(pulses) { pulse in
                        pulseChip(pulse)
                    }
                }
            }
        }
    }

    private func pulseChip(_ pulse: PulseAnnotation) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(pulse.present ? TrainerLabTheme.success : TrainerLabTheme.danger)
                .frame(width: 7, height: 7)
            Text(pulse.locationLabel)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(pulse.present ? "Present" : "Absent")
                .font(.caption2)
                .foregroundStyle(pulse.present ? .secondary : TrainerLabTheme.danger)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Body Diagram

    private var diagramArea: some View {
        HStack(alignment: .top, spacing: 8) {
            bodyPanel(title: "Front", side: .front)
            bodyPanel(title: "Back", side: .back)
        }
    }

    private func bodyPanel(title: String, side: InjuryZoneSide) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(TrainerLabTheme.tacticalSurface)
                    bodySilhouette(for: side)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        .padding(12)
                    Path { path in
                        let x = geo.size.width * 0.5
                        path.move(to: CGPoint(x: x, y: 10))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height - 10))
                    }
                    .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    orientationOverlay(for: side)
                    markersOverlay(side: side, size: geo.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func bodySilhouette(for side: InjuryZoneSide) -> BodySilhouetteShape {
        BodySilhouetteShape(side: side)
    }

    private func orientationOverlay(for side: InjuryZoneSide) -> some View {
        BodyOrientationLabels(
            leadingText: RunConsolePatientDiagramSupport.orientationLabels(for: side).leading,
            trailingText: RunConsolePatientDiagramSupport.orientationLabels(for: side).trailing,
        )
        .padding(8)
    }

    @ViewBuilder
    private func markersOverlay(side: InjuryZoneSide, size: CGSize) -> some View {
        let visibleInjuries = injuries.filter { $0.side == side && $0.status != .inactive }
        let visibleInterventions = interventions.filter { $0.side == side }
        let visibleProblems = problems.filter { $0.isAnatomic && $0.side == side }
        let visiblePulses = pulses.filter { $0.side == side }

        // Pulse markers (bottom layer)
        ForEach(visiblePulses) { pulse in
            pulseMarker(pulse, size: size)
        }

        // Cause markers with stacked badges
        ForEach(visibleInjuries) { injury in
            injuryMarkerStack(injury: injury, interventions: visibleInterventions, problems: visibleProblems, size: size)
        }

        // Standalone intervention markers (not co-located with an injury)
        ForEach(standaloneInterventions(from: visibleInterventions, injuries: visibleInjuries)) { intervention in
            interventionMarker(intervention, size: size)
        }

        // Standalone anatomic problem markers (not co-located with an injury)
        ForEach(standaloneProblems(from: visibleProblems, injuries: visibleInjuries)) { problem in
            problemMarker(problem, size: size)
        }
    }

    // MARK: - Injury Marker with Stacked Badges

    private func injuryMarkerStack(
        injury: InjuryAnnotation,
        interventions: [InterventionAnnotation],
        problems: [ProblemAnnotation],
        size: CGSize,
    ) -> some View {
        let center = displayPoint(x: injury.x, y: injury.y, for: injury.side, in: size)
        let colocatedInterventions = interventions.filter { isColocated($0, with: injury) }
        let colocatedProblems = problems.filter { isColocated($0, with: injury) }

        return ZStack {
            // Base injury marker
            Image(systemName: "x.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(injuryColor(for: injury))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .onTapGesture {
                    selected = .injury(injury)
                    onSelectInjury?(injury)
                }

            // Intervention badge stack (offset right)
            ForEach(Array(colocatedInterventions.enumerated()), id: \.element.id) { idx, intervention in
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(TrainerLabTheme.accentBlue)
                    .offset(x: 11 + CGFloat(idx) * 7, y: -8)
                    .onTapGesture { selected = .intervention(intervention) }
            }

            // Problem badge stack (offset below the cause marker)
            ForEach(Array(colocatedProblems.enumerated()), id: \.element.id) { idx, problem in
                problemBadge(problem)
                    .offset(x: CGFloat(idx) * 7, y: 13 + CGFloat(idx) * 5)
                    .onTapGesture {
                        if let onSelectProblem {
                            onSelectProblem(problem)
                        } else {
                            selected = .problem(problem)
                        }
                    }
            }
        }
        .position(center)
    }

    private func injuryColor(for injury: InjuryAnnotation) -> Color {
        switch injury.status {
        case .pending: TrainerLabTheme.warning
        case .active: injury.kind.lowercased() == "illness" ? TrainerLabTheme.warning : TrainerLabTheme.danger
        case .inactive: .gray
        }
    }

    // MARK: - Standalone Markers

    private func interventionMarker(_ intervention: InterventionAnnotation, size: CGSize) -> some View {
        let center = displayPoint(x: intervention.x, y: intervention.y, for: intervention.side, in: size)
        return Image(systemName: "plus.circle.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(TrainerLabTheme.accentBlue)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            .position(center)
            .onTapGesture { selected = .intervention(intervention) }
    }

    private func problemMarker(_ problem: ProblemAnnotation, size: CGSize) -> some View {
        let center = displayPoint(x: problem.x ?? 0.5, y: problem.y ?? 0.5, for: problem.side ?? .front, in: size)
        return ZStack {
            Image(systemName: "circle.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
            if problem.isUncontrolled {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
                    .offset(x: 8, y: -8)
            }
        }
        .scaleEffect(problem.isUncontrolled ? 1.0 : 1.0)
        .modifier(PulsingModifier(active: problem.isUncontrolled))
        .shadow(color: problem.isUncontrolled ? TrainerLabTheme.danger.opacity(0.6) : .clear, radius: 4)
        .position(center)
        .onTapGesture {
            if let onSelectProblem {
                onSelectProblem(problem)
            } else {
                selected = .problem(problem)
            }
        }
    }

    private func pulseMarker(_ pulse: PulseAnnotation, size: CGSize) -> some View {
        let center = displayPoint(x: pulse.x, y: pulse.y, for: pulse.side, in: size)
        return Image(systemName: pulse.present ? "circle.dotted.circle" : "circle.dotted.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(pulse.present ? .cyan : .gray)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            .position(center)
            .onTapGesture { selected = .pulse(pulse) }
    }

    private func problemBadge(_ problem: ProblemAnnotation) -> some View {
        ZStack {
            Circle()
                .fill(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                .frame(width: 13, height: 13)
            if problem.isUncontrolled {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.yellow)
            }
        }
        .modifier(PulsingModifier(active: problem.isUncontrolled))
    }

    // MARK: - Colocation Helpers

    private func isColocated(_ intervention: InterventionAnnotation, with injury: InjuryAnnotation) -> Bool {
        let unitSize = CGSize(width: 1, height: 1)
        let injuryDisplay = displayPoint(x: injury.x, y: injury.y, for: injury.side, in: unitSize)
        let interventionDisplay = displayPoint(x: intervention.x, y: intervention.y, for: intervention.side, in: unitSize)
        return abs(interventionDisplay.x - injuryDisplay.x) < 0.05 &&
            abs(interventionDisplay.y - injuryDisplay.y) < 0.05 &&
            intervention.side == injury.side
    }

    private func isColocated(_ problem: ProblemAnnotation, with injury: InjuryAnnotation) -> Bool {
        guard let px = problem.x, let py = problem.y, let ps = problem.side else { return false }
        let unitSize = CGSize(width: 1, height: 1)
        let injuryDisplay = displayPoint(x: injury.x, y: injury.y, for: injury.side, in: unitSize)
        let problemDisplay = displayPoint(x: px, y: py, for: ps, in: unitSize)
        return abs(problemDisplay.x - injuryDisplay.x) < 0.05 &&
            abs(problemDisplay.y - injuryDisplay.y) < 0.05 &&
            ps == injury.side
    }

    private func standaloneInterventions(from interventions: [InterventionAnnotation], injuries: [InjuryAnnotation]) -> [InterventionAnnotation] {
        interventions.filter { intervention in
            !injuries.contains { injury in isColocated(intervention, with: injury) }
        }
    }

    private func standaloneProblems(from problems: [ProblemAnnotation], injuries: [InjuryAnnotation]) -> [ProblemAnnotation] {
        problems.filter { problem in
            !injuries.contains { injury in isColocated(problem, with: injury) }
        }
    }

    // MARK: - Row Views

    private func problemRow(_ problem: ProblemAnnotation) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(problem.label)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                if let anatomicalLabel = anatomicalLocationLabel(for: problem) {
                    Text(anatomicalLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let problemID = problem.problemID, pendingInterventionProblemIDs.contains(problemID) {
                ProgressView()
                    .controlSize(.mini)
            }
            Text(problem.status.rawValue.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(problem.isUncontrolled ? TrainerLabTheme.danger.opacity(0.15) : TrainerLabTheme.success.opacity(0.15)),
                )
            if onSelectProblem != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onSelectProblem?(problem) }
    }

    private func interventionRow(_ intervention: InterventionAnnotation) -> some View {
        let fallbackSummary = InterventionDisplayText.siteLabel(
            siteCode: intervention.siteCode,
            siteLabel: intervention.siteLabel,
        ) ?? intervention.siteCode
        let siteSummary = anatomicalLocationLabel(for: intervention) ?? fallbackSummary
        return HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.caption)
                .foregroundStyle(TrainerLabTheme.accentBlue)
            VStack(alignment: .leading, spacing: 1) {
                Text(SimulationEventRegistry.humanizedLabel(intervention.interventionType))
                    .font(.caption2.bold())
                    .lineLimit(1)
                Text("\(siteSummary) — \(SimulationEventRegistry.humanizedLabel(intervention.effectiveness))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(intervention.status.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Selected Detail Card

    private func selectedDetailCard(_ sel: PatientDiagramSelection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Detail")
                    .font(.caption.bold())
                Spacer()
                Button { selected = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Divider()
            switch sel {
            case let .injury(injury):
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(injury.kind.uppercased())\(injury.category.map { " (\($0.uppercased()))" } ?? "")")
                        .font(.caption.bold())
                    Text(injury.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Location: \(anatomicalLocationLabel(for: injury) ?? injury.locationCode)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Cause Type: \(injury.kind.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(.caption2)
                }
            case let .intervention(intervention):
                VStack(alignment: .leading, spacing: 4) {
                    let fallbackSummary = InterventionDisplayText.siteLabel(
                        siteCode: intervention.siteCode,
                        siteLabel: intervention.siteLabel,
                    ) ?? intervention.siteCode
                    let siteSummary = anatomicalLocationLabel(for: intervention) ?? fallbackSummary
                    Text(intervention.title)
                        .font(.caption.bold())
                    Text("Site: \(siteSummary)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Effectiveness: \(SimulationEventRegistry.humanizedLabel(intervention.effectiveness)) — \(intervention.status.capitalized)")
                        .font(.caption2)
                    if let validationStatus = intervention.validationStatus {
                        Text("Validation: \(validationStatus.replacingOccurrences(of: "_", with: " ").capitalized)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let adjudicationReason = intervention.adjudicationReason, !adjudicationReason.isEmpty {
                        Text(adjudicationReason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            case let .problem(problem):
                VStack(alignment: .leading, spacing: 4) {
                    Text(problem.label)
                        .font(.caption.bold())
                    if let problemID = problem.problemID, pendingInterventionProblemIDs.contains(problemID) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Intervention pending")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Status: \(problem.status.rawValue.capitalized)")
                        .font(.caption2)
                        .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                    if let severity = problem.severity {
                        Text("Severity: \(severity.capitalized)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if problem.isAnatomic {
                        Text("Location: \(anatomicalLocationLabel(for: problem) ?? problem.locationCode ?? "Unknown")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Systemic (no body location)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if canMutate {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Instructor Override")
                                .font(.caption2.bold())
                            HStack(spacing: 6) {
                                problemStatusButton("Active", status: .active, for: problem)
                                problemStatusButton("Treated", status: .treated, for: problem)
                                problemStatusButton("Controlled", status: .controlled, for: problem)
                                problemStatusButton("Resolved", status: .resolved, for: problem)
                            }
                        }
                    }
                }
            case let .pulse(pulse):
                VStack(alignment: .leading, spacing: 4) {
                    Text(pulse.locationLabel)
                        .font(.caption.bold())
                    Text("Present: \(pulse.present ? "Yes" : "No") — \(pulse.quality.capitalized)")
                        .font(.caption2)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("Color").font(.caption2.bold())
                            Text(pulse.colorDescription.capitalized)
                                .font(.caption2)
                                .foregroundStyle(pulse.colorNormal ? .secondary : TrainerLabTheme.warning)
                        }
                        VStack(alignment: .leading) {
                            Text("Condition").font(.caption2.bold())
                            Text(pulse.conditionDescription.capitalized)
                                .font(.caption2)
                                .foregroundStyle(pulse.conditionNormal ? .secondary : TrainerLabTheme.warning)
                        }
                        VStack(alignment: .leading) {
                            Text("Temp").font(.caption2.bold())
                            Text(pulse.temperatureDescription.capitalized)
                                .font(.caption2)
                                .foregroundStyle(pulse.temperatureNormal ? .secondary : TrainerLabTheme.warning)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(TrainerLabTheme.tacticalSurfaceElevated),
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(TrainerLabTheme.tacticalBorder, lineWidth: 1),
        )
    }

    private func problemStatusButton(
        _ title: String,
        status: ProblemLifecycleState,
        for problem: ProblemAnnotation,
    ) -> some View {
        Button(title) {
            onUpdateProblemStatus?(problem, status)
        }
        .font(.caption2.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .tint(problem.status == status ? TrainerLabTheme.accentBlue : .secondary)
    }

    private var shouldShowDiagramLegend: Bool {
        !(layoutMode == .compact && compactMetrics.cardPadding <= 8)
    }

    private var diagramLegend: some View {
        HStack(spacing: 10) {
            legendItem(icon: "x.circle.fill", color: TrainerLabTheme.danger, label: "Cause/Injury")
            legendItem(icon: "circle.circle.fill", color: TrainerLabTheme.warning, label: "Problem")
            legendItem(icon: "plus.circle.fill", color: TrainerLabTheme.accentBlue, label: "Intervention")
            legendItem(icon: "circle.dotted.circle", color: .cyan, label: "Pulse")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private func legendItem(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(label)
        }
    }

    private func displayPoint(x: Double, y: Double, for side: InjuryZoneSide, in size: CGSize) -> CGPoint {
        RunConsolePatientDiagramSupport.displayPoint(
            x: CGFloat(x),
            y: CGFloat(y),
            side: side,
            size: size,
            convention: displayConvention,
        )
    }

    private func anatomicalLocationLabel(for problem: ProblemAnnotation) -> String? {
        if let displayLocation = Self.problemDisplayLocation(problem) {
            return displayLocation
        }
        return RunConsolePatientDiagramSupport.anatomicalLocationLabel(
            side: problem.side,
            zoneCode: problem.locationCode,
        )
    }

    private func anatomicalLocationLabel(for injury: InjuryAnnotation) -> String? {
        if let knownLabel = RuntimeAnatomicalLocationDisplay.knownLabel(for: injury.locationCode) {
            return knownLabel
        }
        return RunConsolePatientDiagramSupport.anatomicalLocationLabel(
            side: injury.side,
            zoneCode: injury.locationCode,
        )
    }

    private func anatomicalLocationLabel(for intervention: InterventionAnnotation) -> String? {
        RunConsolePatientDiagramSupport.anatomicalLocationLabel(
            side: intervention.side,
            zoneCode: intervention.siteCode,
        )
    }

    private var causeProblemGroups: [PatientCauseProblemGroup] {
        Self.buildCauseProblemGroups(allCauses: allCauses, injuries: injuries, problems: problems)
    }

    private var systemicProblems: [ProblemAnnotation] {
        Self.buildSystemicProblems(allCauses: allCauses, injuries: injuries, problems: problems)
    }

    static func buildCauseProblemGroups(
        allCauses: [RuntimeCauseState],
        injuries: [InjuryAnnotation],
        problems: [ProblemAnnotation],
    ) -> [PatientCauseProblemGroup] {
        if !allCauses.isEmpty {
            return allCauses.enumerated().compactMap { index, cause in
                let linkedProblems = sortedProblems(
                    problems.filter { problem in
                        guard let problemCauseID = problem.causeID, let causeID = cause.causeID else { return false }
                        return problemCauseID == causeID
                    },
                )
                guard !linkedProblems.isEmpty else { return nil }
                return PatientCauseProblemGroup(
                    id: "cause-\(cause.causeID.map(String.init) ?? "idx-\(index)")",
                    title: causeDisplayTitle(cause: cause),
                    problems: linkedProblems,
                )
            }
        }

        return injuries.compactMap { injury in
            let linkedProblems = sortedProblems(
                problems.filter { problem in
                    guard let causeID = injury.causeID else { return false }
                    return problem.causeID == causeID
                },
            )
            guard !linkedProblems.isEmpty else { return nil }
            return PatientCauseProblemGroup(
                id: "injury-\(injury.id)",
                title: injuryDisplayTitle(injury: injury),
                problems: linkedProblems,
            )
        }
    }

    static func buildSystemicProblems(
        allCauses: [RuntimeCauseState],
        injuries: [InjuryAnnotation],
        problems: [ProblemAnnotation],
    ) -> [ProblemAnnotation] {
        let visibleCauseIDs: Set<Int> = Set(
            allCauses.isEmpty ? injuries.compactMap(\.causeID) : allCauses.compactMap(\.causeID),
        )
        let linkedProblemIDs: Set<String> = Set(
            problems.compactMap { problem in
                guard let causeID = problem.causeID, visibleCauseIDs.contains(causeID) else { return nil }
                return problem.id
            },
        )
        return sortedProblems(
            problems.filter { problem in
                !linkedProblemIDs.contains(problem.id)
            },
        )
    }

    static func sortedProblems(_ problems: [ProblemAnnotation]) -> [ProblemAnnotation] {
        problems.sorted { lhs, rhs in
            let lhsRank = problemStatusRank(lhs.status)
            let rhsRank = problemStatusRank(rhs.status)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    static func problemStatusRank(_ status: ProblemLifecycleState) -> Int {
        switch status {
        case .active: 0
        case .treated: 1
        case .controlled: 2
        case .resolved: 3
        }
    }

    static func causeDisplayTitle(cause: RuntimeCauseState) -> String {
        let kind = humanizeLabel(cause.kind ?? cause.code ?? cause.primaryLabel)
        if let location = causeDisplayLocation(cause) {
            return "\(kind) — \(location)"
        }
        return kind
    }

    static func causeDisplayLocation(_ cause: RuntimeCauseState) -> String? {
        RuntimeAnatomicalLocationDisplay.label(
            preferredLabel: cause.anatomicalLocationLabel,
            rawCode: cause.anatomicalLocation,
            fallbackRawCode: cause.injuryLocation,
            fallbackLabel: cause.injuryLocationLabel,
            lateralityLabel: cause.lateralityLabel,
            laterality: cause.laterality,
            includeLateralityWhenSeparate: true,
        )
    }

    static func problemDisplayLocation(_ problem: ProblemAnnotation) -> String? {
        if let locationLabel = nonEmpty(problem.locationLabel) {
            return locationLabel
        }
        if let knownLabel = RuntimeAnatomicalLocationDisplay.knownLabel(for: problem.locationCode) {
            return knownLabel
        }
        return RunConsolePatientDiagramSupport.anatomicalLocationLabel(
            side: problem.side,
            zoneCode: problem.locationCode,
        ) ?? RuntimeAnatomicalLocationDisplay.label(
            preferredLabel: nil,
            rawCode: problem.locationCode,
        )
    }

    static func assessmentFindingDisplayLocation(_ finding: RuntimeAssessmentFindingState) -> String? {
        RuntimeAnatomicalLocationDisplay.label(
            preferredLabel: finding.anatomicalLocationLabel,
            rawCode: finding.anatomicalLocation,
            lateralityLabel: finding.lateralityLabel,
            laterality: finding.laterality,
            includeLateralityWhenSeparate: true,
        )
    }

    static func injuryDisplayTitle(injury: InjuryAnnotation) -> String {
        let kind = humanizeLabel(injury.kind)
        let location = RuntimeAnatomicalLocationDisplay.label(
            preferredLabel: nil,
            rawCode: injury.locationCode,
        ) ?? humanizeLabel(injury.locationCode)
        return "\(kind) — \(location)"
    }

    static func humanizeLabel(_ raw: String) -> String {
        RuntimeLocationDisplay.humanizeLabel(raw)
    }

    static func nonEmpty(_ text: String?) -> String? {
        RuntimeLocationDisplay.nonEmpty(text)
    }
}

enum BodyDisplayOrientationConvention {
    case patientAnatomical
    case viewerMirrored
}

enum RunConsolePatientDiagramSupport {
    static let displayOrientationConvention: BodyDisplayOrientationConvention = .patientAnatomical

    static func orientationLabels(for side: InjuryZoneSide) -> (leading: String, trailing: String) {
        switch side {
        case .front:
            ("Patient Right", "Patient Left")
        case .back:
            ("Patient Left", "Patient Right")
        }
    }

    /// Coordinates are rendered in patient-anatomy orientation, not viewer selfie orientation.
    /// If older payloads are discovered to be viewer-mirrored, change displayOrientationConvention
    /// (or side-specific logic) instead of introducing ad hoc flips in marker views.
    static func displayPoint(
        x: CGFloat,
        y: CGFloat,
        side: InjuryZoneSide,
        size: CGSize,
        convention: BodyDisplayOrientationConvention = displayOrientationConvention,
    ) -> CGPoint {
        let normalizedX: CGFloat = switch convention {
        case .patientAnatomical:
            x
        case .viewerMirrored:
            side == .front ? 1 - x : x
        }

        return CGPoint(x: normalizedX * size.width, y: y * size.height)
    }

    static func anatomicalLocationLabel(side: InjuryZoneSide?, zoneCode: String?) -> String? {
        guard let zoneCode, !zoneCode.isEmpty else { return nil }
        let cleaned = zoneCode
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .uppercased()

        let tokens = cleaned.split(separator: "_").map(String.init)
        let resolvedSide = normalizedLateralityLabel(side: side, zoneCode: zoneCode)

        let regionTokens = tokens.filter {
            !["LEFT", "RIGHT", "FRONT", "BACK", "ANTERIOR", "POSTERIOR"].contains($0)
        }
        let region = regionTokens.isEmpty ? nil : regionTokens.map(\.capitalized).joined(separator: " ")

        let plane: String? = if tokens.contains("POSTERIOR") || tokens.contains("BACK") || side == .back {
            "Posterior"
        } else if tokens.contains("ANTERIOR") || tokens.contains("FRONT") {
            "Anterior"
        } else {
            nil
        }

        var parts: [String] = []
        if let plane { parts.append(plane) }
        if let resolvedSide { parts.append(resolvedSide) }
        if let region { parts.append(region) }

        if parts.isEmpty {
            return cleaned.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return parts.joined(separator: " ")
    }

    static func normalizedLateralityLabel(side: InjuryZoneSide?, zoneCode: String?) -> String? {
        _ = side
        let cleaned = zoneCode?
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .uppercased() ?? ""
        let tokens = cleaned.split(separator: "_").map(String.init)

        if tokens.contains("RIGHT") { return "Right" }
        if tokens.contains("LEFT") { return "Left" }
        return nil
    }
}

// MARK: - Body Silhouettes

private struct BodySilhouetteShape: Shape {
    let side: InjuryZoneSide

    func path(in rect: CGRect) -> Path {
        switch side {
        case .front:
            AnteriorBodyShape().path(in: rect)
        case .back:
            PosteriorBodyShape().path(in: rect)
        }
    }
}

private struct BodyOrientationLabels: View {
    let leadingText: String
    let trailingText: String

    var body: some View {
        VStack {
            HStack {
                Text(leadingText)
                Spacer()
                Text(trailingText)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct AnteriorBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // Head
        let headCX = w * 0.5
        let headCY = h * 0.08
        let headR = min(w, h) * 0.055
        p.addEllipse(in: CGRect(x: headCX - headR, y: headCY - headR, width: headR * 2, height: headR * 2.2))

        // Neck
        p.move(to: CGPoint(x: w * 0.47, y: h * 0.115))
        p.addLine(to: CGPoint(x: w * 0.47, y: h * 0.14))
        p.move(to: CGPoint(x: w * 0.53, y: h * 0.115))
        p.addLine(to: CGPoint(x: w * 0.53, y: h * 0.14))

        // Torso (anterior)
        p.move(to: CGPoint(x: w * 0.35, y: h * 0.14))
        p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.14))
        p.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.47), control: CGPoint(x: w * 0.68, y: h * 0.29))
        p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.47))
        p.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.14), control: CGPoint(x: w * 0.32, y: h * 0.29))

        // Left arm
        p.move(to: CGPoint(x: w * 0.35, y: h * 0.15))
        p.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.32), control: CGPoint(x: w * 0.24, y: h * 0.18))
        p.addLine(to: CGPoint(x: w * 0.15, y: h * 0.46))
        p.move(to: CGPoint(x: w * 0.35, y: h * 0.17))
        p.addQuadCurve(to: CGPoint(x: w * 0.21, y: h * 0.33), control: CGPoint(x: w * 0.27, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.46))

        // Right arm
        p.move(to: CGPoint(x: w * 0.65, y: h * 0.15))
        p.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.32), control: CGPoint(x: w * 0.76, y: h * 0.18))
        p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.46))
        p.move(to: CGPoint(x: w * 0.65, y: h * 0.17))
        p.addQuadCurve(to: CGPoint(x: w * 0.79, y: h * 0.33), control: CGPoint(x: w * 0.73, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.46))

        // Left leg
        p.move(to: CGPoint(x: w * 0.44, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.92))
        p.move(to: CGPoint(x: w * 0.50, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.43, y: h * 0.92))

        // Right leg
        p.move(to: CGPoint(x: w * 0.56, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.92))
        p.move(to: CGPoint(x: w * 0.50, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.57, y: h * 0.92))

        // Feet
        p.move(to: CGPoint(x: w * 0.38, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.95))
        p.move(to: CGPoint(x: w * 0.43, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.95))
        p.move(to: CGPoint(x: w * 0.62, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.95))
        p.move(to: CGPoint(x: w * 0.57, y: h * 0.92))
        p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.95))

        return p
    }
}

private struct PosteriorBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        let headCX = w * 0.5
        let headCY = h * 0.08
        let headR = min(w, h) * 0.055
        p.addEllipse(in: CGRect(x: headCX - headR, y: headCY - headR, width: headR * 2, height: headR * 2.2))

        p.move(to: CGPoint(x: w * 0.47, y: h * 0.115))
        p.addLine(to: CGPoint(x: w * 0.47, y: h * 0.145))
        p.move(to: CGPoint(x: w * 0.53, y: h * 0.115))
        p.addLine(to: CGPoint(x: w * 0.53, y: h * 0.145))

        // Torso (posterior): slightly broader shoulders and straighter flank to differentiate from anterior.
        p.move(to: CGPoint(x: w * 0.33, y: h * 0.145))
        p.addQuadCurve(to: CGPoint(x: w * 0.67, y: h * 0.145), control: CGPoint(x: w * 0.50, y: h * 0.11))
        p.addQuadCurve(to: CGPoint(x: w * 0.60, y: h * 0.49), control: CGPoint(x: w * 0.70, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.49))
        p.addQuadCurve(to: CGPoint(x: w * 0.33, y: h * 0.145), control: CGPoint(x: w * 0.30, y: h * 0.34))

        // Arms
        p.move(to: CGPoint(x: w * 0.33, y: h * 0.16))
        p.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.34), control: CGPoint(x: w * 0.22, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.15, y: h * 0.47))
        p.move(to: CGPoint(x: w * 0.67, y: h * 0.16))
        p.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.34), control: CGPoint(x: w * 0.78, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.47))

        // Legs
        p.move(to: CGPoint(x: w * 0.43, y: h * 0.49))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.39, y: h * 0.93))
        p.move(to: CGPoint(x: w * 0.57, y: h * 0.49))
        p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.72))
        p.addLine(to: CGPoint(x: w * 0.61, y: h * 0.93))
        p.move(to: CGPoint(x: w * 0.49, y: h * 0.49))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.73))
        p.addLine(to: CGPoint(x: w * 0.45, y: h * 0.92))
        p.move(to: CGPoint(x: w * 0.51, y: h * 0.49))
        p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.73))
        p.addLine(to: CGPoint(x: w * 0.55, y: h * 0.92))

        // Heels
        p.move(to: CGPoint(x: w * 0.39, y: h * 0.93))
        p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.96))
        p.move(to: CGPoint(x: w * 0.61, y: h * 0.93))
        p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.96))

        return p
    }
}

// MARK: - Pulsing Animation Modifier

struct PulsingModifier: ViewModifier {
    let active: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && isPulsing ? 1.25 : 1.0)
            .animation(
                active ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: isPulsing,
            )
            .onAppear {
                if active { isPulsing = true }
            }
            .onChange(of: active) { _, newValue in
                isPulsing = newValue
            }
    }
}
