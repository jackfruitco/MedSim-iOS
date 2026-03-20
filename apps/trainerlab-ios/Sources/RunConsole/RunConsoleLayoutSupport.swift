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
    case labeled
    case iconOnly

    static func resolve(
        layoutMode: RunConsoleLayoutMode,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Self {
        guard layoutMode == .compact, horizontalSizeClass == .compact else {
            return .labeled
        }
        return .iconOnly
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
        case .cause, .injury, .illness, .intervention, .loc, .problem, .recommendation:
            "Change"
        case .lifecycle:
            entry.title
        case .note:
            "Trainer Note"
        case .vitals:
            entry.title
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
        vitalValueVerticalPadding: 3
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
        vitalValueVerticalPadding: 3
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
            []
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

struct PatientDiagramPanel: View {
    let injuries: [InjuryAnnotation]
    let allCauses: [RuntimeCauseState]
    let interventions: [InterventionAnnotation]
    let problems: [ProblemAnnotation]
    let recommendations: [RecommendedInterventionItem]
    let pulses: [PulseAnnotation]
    let canMutate: Bool
    var onSelectInjury: ((InjuryAnnotation) -> Void)?
    var onUpdateProblemStatus: ((ProblemAnnotation, ProblemLifecycleState) -> Void)?

    @State private var selected: PatientDiagramSelection?
    @State private var injuriesExpanded = true
    @State private var problemsExpanded = true
    @State private var interventionsExpanded = true
    @State private var pulsesExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            diagramArea
            detailPanels
        }
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
                    BodyOutlineShape()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        .padding(12)
                    markersOverlay(side: side, size: geo.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
        size: CGSize
    ) -> some View {
        let cx = injury.x * size.width
        let cy = injury.y * size.height
        let colocatedInterventions = interventions.filter { isColocated($0, with: injury) }
        let colocatedProblems = problems.filter { isColocated($0, with: injury) }

        return ZStack {
            // Base injury marker
            Image(systemName: "x.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(injuryColor(for: injury))
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .onTapGesture {
                    selected = .injury(injury)
                    onSelectInjury?(injury)
                }

            // Intervention badge stack (offset right)
            ForEach(Array(colocatedInterventions.enumerated()), id: \.element.id) { idx, intervention in
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(TrainerLabTheme.accentBlue)
                    .offset(x: 10 + CGFloat(idx) * 6, y: -6)
                    .onTapGesture { selected = .intervention(intervention) }
            }

            // Problem badge stack (offset below the cause marker)
            ForEach(Array(colocatedProblems.enumerated()), id: \.element.id) { idx, problem in
                problemBadge(problem)
                    .offset(x: CGFloat(idx) * 6, y: 12 + CGFloat(idx) * 4)
                    .onTapGesture { selected = .problem(problem) }
            }
        }
        .position(x: cx, y: cy)
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
        let cx = intervention.x * size.width
        let cy = intervention.y * size.height
        return Image(systemName: "plus.circle.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(TrainerLabTheme.accentBlue)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            .position(x: cx, y: cy)
            .onTapGesture { selected = .intervention(intervention) }
    }

    private func problemMarker(_ problem: ProblemAnnotation, size: CGSize) -> some View {
        let cx = (problem.x ?? 0.5) * size.width
        let cy = (problem.y ?? 0.5) * size.height
        return ZStack {
            Image(systemName: "circle.circle.fill")
                .font(.system(size: 14, weight: .bold))
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
        .position(x: cx, y: cy)
        .onTapGesture { selected = .problem(problem) }
    }

    private func pulseMarker(_ pulse: PulseAnnotation, size: CGSize) -> some View {
        let cx = pulse.x * size.width
        let cy = pulse.y * size.height
        return Image(systemName: pulse.present ? "circle.dotted.circle" : "circle.dotted.circle.fill")
            .font(.system(size: 12))
            .foregroundStyle(pulse.present ? .cyan : .gray)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            .position(x: cx, y: cy)
            .onTapGesture { selected = .pulse(pulse) }
    }

    private func problemBadge(_ problem: ProblemAnnotation) -> some View {
        ZStack {
            Circle()
                .fill(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                .frame(width: 12, height: 12)
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
        abs(intervention.x - injury.x) < 0.05 && abs(intervention.y - injury.y) < 0.05 && intervention.side == injury.side
    }

    private func isColocated(_ problem: ProblemAnnotation, with injury: InjuryAnnotation) -> Bool {
        guard let px = problem.x, let py = problem.y, let ps = problem.side else { return false }
        return abs(px - injury.x) < 0.05 && abs(py - injury.y) < 0.05 && ps == injury.side
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

    // MARK: - Detail Panels

    private var detailPanels: some View {
        VStack(spacing: 6) {
            // Systemic problems floating badges (non-anatomic)
            let systemicProblems = problems.filter { !$0.isAnatomic }
            if !systemicProblems.isEmpty {
                systemicProblemsBanner(systemicProblems)
            }

            if !allCauses.isEmpty || !injuries.isEmpty {
                causesDisclosure
            }
            if !problems.isEmpty {
                problemsDisclosure
            }
            if !interventions.isEmpty {
                interventionsDisclosure
            }
            if !pulses.isEmpty {
                pulsesDisclosure
            }

            // Selected detail overlay
            if let selected {
                selectedDetailCard(selected)
            }
        }
    }

    // MARK: - Systemic Problems Banner

    private func systemicProblemsBanner(_ systemicProblems: [ProblemAnnotation]) -> some View {
        VStack(spacing: 4) {
            ForEach(systemicProblems) { problem in
                HStack(spacing: 6) {
                    Image(systemName: "circle.circle.fill")
                        .font(.caption)
                        .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                        .modifier(PulsingModifier(active: problem.isUncontrolled))
                    if problem.isUncontrolled {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Text(problem.label)
                        .font(.caption.bold())
                        .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : .primary)
                    Spacer()
                    Text(problem.controlState.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(problem.isUncontrolled ? TrainerLabTheme.danger.opacity(0.12) : TrainerLabTheme.success.opacity(0.08))
                )
            }
        }
    }

    // MARK: - Disclosure Groups

    private var causesDisclosure: some View {
        DisclosureGroup(isExpanded: $injuriesExpanded) {
            VStack(spacing: 4) {
                if !allCauses.isEmpty {
                    ForEach(Array(allCauses.enumerated()), id: \.offset) { _, cause in
                        causeRow(cause)
                    }
                } else {
                    ForEach(injuries) { injury in
                        injuryRow(injury)
                    }
                }
            }
        } label: {
            Label("Causes (\(!allCauses.isEmpty ? allCauses.count : injuries.count))", systemImage: "x.circle")
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .tint(.secondary)
    }

    private var problemsDisclosure: some View {
        DisclosureGroup(isExpanded: $problemsExpanded) {
            VStack(spacing: 4) {
                ForEach(problems) { problem in
                    problemRow(problem)
                }
            }
        } label: {
            let uncontrolledCount = problems.filter(\.isUncontrolled).count
            HStack(spacing: 4) {
                Label("Problems (\(problems.count))", systemImage: "circle.circle")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                if uncontrolledCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .tint(.secondary)
    }

    private var interventionsDisclosure: some View {
        DisclosureGroup(isExpanded: $interventionsExpanded) {
            VStack(spacing: 4) {
                ForEach(interventions) { intervention in
                    interventionRow(intervention)
                }
            }
        } label: {
            Label("Interventions (\(interventions.count))", systemImage: "plus.circle")
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .tint(.secondary)
    }

    private var pulsesDisclosure: some View {
        let presentCount = pulses.filter(\.present).count
        return DisclosureGroup(isExpanded: $pulsesExpanded) {
            VStack(spacing: 4) {
                ForEach(pulses) { pulse in
                    pulseRow(pulse)
                }
            }
        } label: {
            Label("Pulses (\(presentCount)/\(pulses.count))", systemImage: "circle.dotted.circle")
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .tint(.secondary)
    }

    // MARK: - Row Views

    private func injuryRow(_ injury: InjuryAnnotation) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "x.circle.fill")
                .font(.caption)
                .foregroundStyle(injuryColor(for: injury))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(injury.kind.uppercased())\(injury.category.map { " (\($0.uppercased()))" } ?? "") — \(injury.locationCode)")
                    .font(.caption2.bold())
                    .lineLimit(1)
                Text(injury.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { onSelectInjury?(injury) }
    }

    private func causeRow(_ cause: RuntimeCauseState) -> some View {
        let title = cause.primaryLabel
        let location = cause.anatomicalLocation ?? cause.injuryLocation ?? "No body location"
        let kind = (cause.kind ?? cause.code ?? "cause").replacingOccurrences(of: "_", with: " ").capitalized

        return HStack(spacing: 6) {
            Image(systemName: "x.circle.fill")
                .font(.caption)
                .foregroundStyle((cause.kind ?? "").lowercased() == "illness" ? TrainerLabTheme.warning : TrainerLabTheme.danger)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind)
                    .font(.caption2.bold())
                    .lineLimit(1)
                Text("\(title) — \(location)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func problemRow(_ problem: ProblemAnnotation) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.circle.fill")
                .font(.caption)
                .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                .modifier(PulsingModifier(active: problem.isUncontrolled))
            if problem.isUncontrolled {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(problem.label)
                    .font(.caption2.bold())
                    .lineLimit(1)
                if let severity = problem.severity {
                    Text(severity.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if !recommendations(for: problem).isEmpty {
                    Text("\(recommendations(for: problem).count) linked recommendation\(recommendations(for: problem).count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(problem.status.rawValue.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(problem.isUncontrolled ? TrainerLabTheme.danger.opacity(0.15) : TrainerLabTheme.success.opacity(0.15))
                )
        }
        .padding(.vertical, 3)
    }

    private func interventionRow(_ intervention: InterventionAnnotation) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.caption)
                .foregroundStyle(TrainerLabTheme.accentBlue)
            VStack(alignment: .leading, spacing: 1) {
                Text(intervention.interventionType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.bold())
                    .lineLimit(1)
                Text("\(intervention.siteCode.replacingOccurrences(of: "_", with: " ").capitalized) — \(intervention.effectiveness.capitalized)")
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

    private func pulseRow(_ pulse: PulseAnnotation) -> some View {
        HStack(spacing: 6) {
            Image(systemName: pulse.present ? "circle.dotted.circle" : "circle.dotted.circle.fill")
                .font(.caption)
                .foregroundStyle(pulse.present ? .cyan : .gray)
            VStack(alignment: .leading, spacing: 1) {
                Text(pulse.locationLabel)
                    .font(.caption2.bold())
                HStack(spacing: 4) {
                    Text(pulse.quality.capitalized)
                    if !pulse.colorNormal { Text("· \(pulse.colorDescription.capitalized)") }
                    if !pulse.temperatureNormal { Text("· \(pulse.temperatureDescription.capitalized)") }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            if !pulse.present {
                Text("ABSENT")
                    .font(.caption2.bold())
                    .foregroundStyle(TrainerLabTheme.danger)
            }
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
                    Text("Location: \(injury.locationCode) · \(injury.side.rawValue.capitalized)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Cause Type: \(injury.kind.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(.caption2)
                }
            case let .intervention(intervention):
                VStack(alignment: .leading, spacing: 4) {
                    Text(intervention.title)
                        .font(.caption.bold())
                    Text("Site: \(intervention.siteCode.replacingOccurrences(of: "_", with: " ").capitalized) · \(intervention.side.rawValue.capitalized)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Effectiveness: \(intervention.effectiveness.capitalized) — \(intervention.status.capitalized)")
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
                    Text("Status: \(problem.status.rawValue.capitalized)")
                        .font(.caption2)
                        .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
                    if let severity = problem.severity {
                        Text("Severity: \(severity.capitalized)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if problem.isAnatomic, let loc = problem.locationCode {
                        Text("Location: \(loc)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Systemic (no body location)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !recommendations(for: problem).isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommended Interventions")
                                .font(.caption2.bold())
                            recommendationWrap(for: problem)
                        }
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
                .fill(TrainerLabTheme.tacticalSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(TrainerLabTheme.tacticalBorder, lineWidth: 1)
        )
    }

    private func recommendations(for problem: ProblemAnnotation) -> [RecommendedInterventionItem] {
        recommendations.filter { $0.targetProblemID == problem.problemID }
    }

    @ViewBuilder
    private func recommendationWrap(for problem: ProblemAnnotation) -> some View {
        let linkedRecommendations = recommendations(for: problem)
        if linkedRecommendations.isEmpty {
            EmptyView()
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], spacing: 6) {
                ForEach(linkedRecommendations) { recommendation in
                    Text(recommendation.title)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(TrainerLabTheme.accentBlue.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func problemStatusButton(
        _ title: String,
        status: ProblemLifecycleState,
        for problem: ProblemAnnotation
    ) -> some View {
        Button(title) {
            onUpdateProblemStatus?(problem, status)
        }
        .font(.caption2.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .tint(problem.status == status ? TrainerLabTheme.accentBlue : .secondary)
    }
}

// MARK: - Body Outline Shape

struct BodyOutlineShape: Shape {
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

        // Torso
        p.move(to: CGPoint(x: w * 0.35, y: h * 0.14))
        p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.14))
        p.addQuadCurve(to: CGPoint(x: w * 0.62, y: h * 0.46), control: CGPoint(x: w * 0.68, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.48))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.46))
        p.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.14), control: CGPoint(x: w * 0.32, y: h * 0.30))

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

// MARK: - Pulsing Animation Modifier

struct PulsingModifier: ViewModifier {
    let active: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && isPulsing ? 1.25 : 1.0)
            .animation(
                active ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear {
                if active { isPulsing = true }
            }
            .onChange(of: active) { _, newValue in
                isPulsing = newValue
            }
    }
}
