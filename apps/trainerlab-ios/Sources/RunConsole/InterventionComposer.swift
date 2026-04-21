import DesignSystem
import Sessions
import SharedModels
import SwiftUI

enum InterventionComposerSection: Hashable {
    case target
    case type
    case site
    case review
    case notes
}

struct InterventionComposerPrefill: Equatable {
    let interventionType: String
    let siteCode: String?
    let targetProblemID: Int?
    let status: InterventionStatus
    let effectiveness: InterventionEffectiveness
    let notes: String
    let tourniquetApplicationMode: TourniquetApplicationMode?

    init(
        interventionType: String,
        siteCode: String? = nil,
        targetProblemID: Int? = nil,
        status: InterventionStatus = .applied,
        effectiveness: InterventionEffectiveness = .effective,
        notes: String = "",
        tourniquetApplicationMode: TourniquetApplicationMode? = nil,
    ) {
        self.interventionType = interventionType
        self.siteCode = siteCode
        self.targetProblemID = targetProblemID
        self.status = status
        self.effectiveness = effectiveness
        self.notes = notes
        self.tourniquetApplicationMode = tourniquetApplicationMode
    }
}

struct InterventionComposerDraft: Equatable {
    var selectedTargetProblemID: Int?
    var selectedType: String?
    var selectedLocationLabel: String?
    var selectedLaterality: String?
    var status: InterventionStatus = .applied
    var effectiveness: InterventionEffectiveness = .effective
    var tourniquetApplicationMode: TourniquetApplicationMode = .hasty
    var notes = ""
    var activeSection: InterventionComposerSection = .target
    var notesExpanded = false

    init(prefilledTargetProblemID: Int? = nil) {
        selectedTargetProblemID = prefilledTargetProblemID
        activeSection = prefilledTargetProblemID == nil ? .target : .type
    }

    var selectedTourniquetApplicationMode: TourniquetApplicationMode? {
        selectedType == "tourniquet" ? tourniquetApplicationMode : nil
    }

    mutating func applyPrefill(_ prefill: InterventionComposerPrefill, dictionary: [InterventionGroup]) {
        selectedTargetProblemID = prefill.targetProblemID
        selectedType = prefill.interventionType
        status = prefill.status
        effectiveness = prefill.effectiveness
        notes = prefill.notes
        notesExpanded = !prefill.notes.isEmpty
        if let mode = prefill.tourniquetApplicationMode {
            tourniquetApplicationMode = mode
        }

        selectedLocationLabel = nil
        selectedLaterality = nil
        if
            let group = dictionary.first(where: { $0.interventionType == prefill.interventionType }),
            let siteCode = prefill.siteCode,
            let site = group.sites.first(where: { $0.code.caseInsensitiveCompare(siteCode) == .orderedSame })
        {
            selectedLocationLabel = site.locationLabel
            selectedLaterality = site.laterality
            activeSection = .review
        } else {
            activeSection = .type
        }
    }

    func resolvedSiteCode(in sites: [InterventionSite]) -> String? {
        guard let selectedLocationLabel else {
            return sites.count == 1 ? sites.first?.code : nil
        }

        let matchingSites = sites.filter { $0.locationLabel == selectedLocationLabel }
        if matchingSites.count == 1 {
            return matchingSites.first?.code
        }
        if let selectedLaterality {
            return matchingSites.first(where: { $0.laterality == selectedLaterality })?.code
        }
        return nil
    }
}

struct AvailableAccessInventory: Equatable {
    let ivSites: [InterventionAnnotation]
    let ioSites: [InterventionAnnotation]

    init(interventions: [InterventionAnnotation]) {
        let active = interventions
            .filter { $0.status.lowercased() != InterventionStatus.removed.rawValue }
            .sorted { $0.updatedAt > $1.updatedAt }

        ivSites = active.filter { $0.interventionType == "iv_access" }
        ioSites = active.filter { $0.interventionType == "io_access" }
    }

    var hasIV: Bool {
        !ivSites.isEmpty
    }

    var hasIO: Bool {
        !ioSites.isEmpty
    }

    var preferredRouteToken: String? {
        if let newestIV = ivSites.first, let newestIO = ioSites.first {
            return newestIV.updatedAt >= newestIO.updatedAt ? "IV" : "IO"
        }
        if hasIV { return "IV" }
        if hasIO { return "IO" }
        return nil
    }

    func filteredSites(for group: InterventionGroup) -> [InterventionSite] {
        guard group.interventionType == "fluid_resuscitation" || group.interventionType == "blood_transfusion" else {
            return group.sites
        }

        var sites = group.sites.filter { site in
            (hasIV && site.code.uppercased().contains("IV")) || (hasIO && site.code.uppercased().contains("IO"))
        }

        if let preferredRouteToken {
            sites.sort { lhs, rhs in
                let leftPreferred = lhs.code.uppercased().contains(preferredRouteToken)
                let rightPreferred = rhs.code.uppercased().contains(preferredRouteToken)
                if leftPreferred != rightPreferred {
                    return leftPreferred
                }
                return lhs.label < rhs.label
            }
        }

        return sites
    }

    func disabledReason(for group: InterventionGroup) -> String? {
        guard group.interventionType == "fluid_resuscitation" || group.interventionType == "blood_transfusion" else {
            return nil
        }
        return hasIV || hasIO ? nil : "Requires IV or IO access"
    }
}

struct InterventionDisabledOption: Identifiable, Equatable {
    let id: String
    let title: String
    let reason: String
}

struct RecommendedInterventionAction: Identifiable, Equatable {
    let recommendationID: Int
    let title: String
    let subtitle: String?
    let validationStatus: String?
    let siteSummary: String?
    let disabledReason: String?
    let prefill: InterventionComposerPrefill

    var id: Int {
        recommendationID
    }

    var isEnabled: Bool {
        disabledReason == nil && prefill.siteCode != nil
    }
}

struct InterventionMenuContext {
    let selectedProblem: ProblemAnnotation?
    let accessInventory: AvailableAccessInventory
    let recommendedActions: [RecommendedInterventionAction]
    let availableGroups: [InterventionGroup]
    let disabledItems: [InterventionDisabledOption]
    let availableSitesByType: [String: [InterventionSite]]

    init(
        dictionary: [InterventionGroup],
        problems: [ProblemAnnotation],
        recommendations: [RecommendedInterventionItem],
        interventions: [InterventionAnnotation],
        selectedTargetProblemID: Int?,
    ) {
        let selectedProblem = problems.first(where: { $0.problemID == selectedTargetProblemID })
        let accessInventory = AvailableAccessInventory(interventions: interventions)

        var availableSitesByType: [String: [InterventionSite]] = [:]
        var disabledItems: [InterventionDisabledOption] = []
        for group in dictionary {
            let filteredSites = accessInventory.filteredSites(for: group)
            availableSitesByType[group.interventionType] = filteredSites
            if let reason = accessInventory.disabledReason(for: group) {
                disabledItems.append(
                    InterventionDisabledOption(
                        id: group.interventionType,
                        title: group.label,
                        reason: reason,
                    ),
                )
            }
        }

        let linkedRecommendations = recommendations
            .filter { selectedTargetProblemID != nil && $0.targetProblemID == selectedTargetProblemID }
            .sorted(by: Self.recommendationSortOrder)

        let recommendedActions: [RecommendedInterventionAction] = linkedRecommendations.compactMap { recommendation -> RecommendedInterventionAction? in
            guard let interventionType = Self.recommendedInterventionType(for: recommendation, dictionary: dictionary) else {
                return nil
            }
            guard let group = dictionary.first(where: { $0.interventionType == interventionType }) else { return nil }

            let prefill = Self.prefill(
                for: group,
                recommendation: recommendation,
                selectedProblem: selectedProblem,
                accessInventory: accessInventory,
                availableSites: availableSitesByType[group.interventionType] ?? group.sites,
            )
            let disabledReason = accessInventory.disabledReason(for: group)
                ?? (prefill.siteCode == nil && (availableSitesByType[group.interventionType] ?? group.sites).count > 1 ? "Choose site in edit" : nil)

            return RecommendedInterventionAction(
                recommendationID: recommendation.recommendationID,
                title: recommendation.title,
                subtitle: recommendation.rationale,
                validationStatus: recommendation.validationStatus,
                siteSummary: InterventionDisplayText.siteLabel(
                    siteCode: prefill.siteCode,
                    siteLabel: recommendation.siteLabel,
                    interventionType: interventionType,
                    dictionary: dictionary,
                ),
                disabledReason: disabledReason,
                prefill: prefill,
            )
        }

        let recommendedTypes = linkedRecommendations.compactMap { Self.recommendedInterventionType(for: $0, dictionary: dictionary) }
        let priorityOrder = Array(NSOrderedSet(array: recommendedTypes)) as? [String] ?? []
        var ordered = dictionary.sorted { lhs, rhs in
            let leftIndex = priorityOrder.firstIndex(of: lhs.interventionType) ?? .max
            let rightIndex = priorityOrder.firstIndex(of: rhs.interventionType) ?? .max
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
            return lhs.label < rhs.label
        }
        ordered.removeAll { accessInventory.disabledReason(for: $0) != nil }

        self.selectedProblem = selectedProblem
        self.accessInventory = accessInventory
        self.recommendedActions = recommendedActions
        self.availableSitesByType = availableSitesByType
        self.disabledItems = disabledItems
        availableGroups = ordered
    }

    func availableSites(for group: InterventionGroup) -> [InterventionSite] {
        availableSitesByType[group.interventionType] ?? group.sites
    }

    func prefill(for interventionType: String) -> InterventionComposerPrefill? {
        guard let group = availableGroups.first(where: { $0.interventionType == interventionType }) else { return nil }
        return Self.prefill(
            for: group,
            recommendation: nil,
            selectedProblem: selectedProblem,
            accessInventory: accessInventory,
            availableSites: availableSites(for: group),
        )
    }

    private static func recommendedInterventionType(
        for recommendation: RecommendedInterventionItem,
        dictionary: [InterventionGroup],
    ) -> String? {
        let candidates = [
            recommendation.normalizedKind,
            recommendation.kind,
            recommendation.normalizedCode,
            recommendation.code,
        ].compactMap { candidate -> String? in
            guard let candidate, !candidate.isEmpty else { return nil }
            return candidate
        }

        return candidates.first { candidate in
            dictionary.contains(where: { $0.interventionType == candidate })
        }
    }

    private static func recommendationSortOrder(
        _ lhs: RecommendedInterventionItem,
        _ rhs: RecommendedInterventionItem,
    ) -> Bool {
        let leftPriority = lhs.priority ?? .max
        let rightPriority = rhs.priority ?? .max
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func prefill(
        for group: InterventionGroup,
        recommendation: RecommendedInterventionItem?,
        selectedProblem: ProblemAnnotation?,
        accessInventory: AvailableAccessInventory,
        availableSites: [InterventionSite],
    ) -> InterventionComposerPrefill {
        let explicitSiteCode = recommendation?.siteCode
        let inferredSiteCode = explicitSiteCode.flatMap { siteCode in
            availableSites.first(where: { $0.code.caseInsensitiveCompare(siteCode) == .orderedSame })?.code
        } ?? inferredSiteCode(for: group, selectedProblem: selectedProblem, availableSites: availableSites, accessInventory: accessInventory)

        return InterventionComposerPrefill(
            interventionType: group.interventionType,
            siteCode: inferredSiteCode,
            targetProblemID: recommendation?.targetProblemID ?? selectedProblem?.problemID,
            status: .applied,
            effectiveness: .effective,
            notes: "",
            tourniquetApplicationMode: group.interventionType == "tourniquet" ? .hasty : nil,
        )
    }

    private static func inferredSiteCode(
        for group: InterventionGroup,
        selectedProblem: ProblemAnnotation?,
        availableSites: [InterventionSite],
        accessInventory _: AvailableAccessInventory,
    ) -> String? {
        if group.interventionType == "fluid_resuscitation" || group.interventionType == "blood_transfusion" {
            return availableSites.first?.code
        }

        guard let selectedProblem else {
            return availableSites.count == 1 ? availableSites.first?.code : nil
        }

        guard let locationCode = selectedProblem.locationCode?.uppercased(), !locationCode.isEmpty else {
            return availableSites.count == 1 ? availableSites.first?.code : nil
        }

        if let exactMatch = availableSites.first(where: { $0.code.uppercased() == locationCode }) {
            return exactMatch.code
        }

        let locationTokens = Set(locationCode.split(whereSeparator: { $0 == "_" || $0 == "-" }).map(String.init))
        let preferredLaterality = locationTokens.contains("LEFT") ? "left" : (locationTokens.contains("RIGHT") ? "right" : nil)

        let sortedCandidates = availableSites
            .filter { site in
                preferredLaterality == nil || site.laterality == preferredLaterality
            }
            .sorted { lhs, rhs in
                let leftScore = siteScore(lhs, locationTokens: locationTokens)
                let rightScore = siteScore(rhs, locationTokens: locationTokens)
                if leftScore != rightScore {
                    return leftScore > rightScore
                }
                return lhs.label < rhs.label
            }

        if let best = sortedCandidates.first, siteScore(best, locationTokens: locationTokens) > 0 {
            return best.code
        }

        return availableSites.count == 1 ? availableSites.first?.code : nil
    }

    private static func siteScore(_ site: InterventionSite, locationTokens: Set<String>) -> Int {
        let tokens = Set(
            site.code.uppercased()
                .split(whereSeparator: { $0 == "_" || $0 == "-" })
                .map(String.init),
        )
        return tokens.intersection(locationTokens).count
    }
}

struct InterventionComposerSheet: View {
    let dictionary: [InterventionGroup]
    let problems: [ProblemAnnotation]
    let recommendations: [RecommendedInterventionItem]
    let interventions: [InterventionAnnotation]
    let prefilledTargetProblemID: Int?
    let canMutate: Bool
    let onSubmit: (String, String, Int?, InterventionStatus, InterventionEffectiveness, String, TourniquetApplicationMode?) -> Void

    @State private var draft: InterventionComposerDraft
    @Environment(\.dismiss) private var dismiss

    init(
        dictionary: [InterventionGroup],
        problems: [ProblemAnnotation],
        recommendations: [RecommendedInterventionItem],
        interventions: [InterventionAnnotation],
        prefilledTargetProblemID: Int?,
        initialPrefill: InterventionComposerPrefill? = nil,
        canMutate: Bool,
        onSubmit: @escaping (String, String, Int?, InterventionStatus, InterventionEffectiveness, String, TourniquetApplicationMode?) -> Void,
    ) {
        self.dictionary = dictionary
        self.problems = problems
        self.recommendations = recommendations
        self.interventions = interventions
        self.prefilledTargetProblemID = prefilledTargetProblemID
        self.canMutate = canMutate
        self.onSubmit = onSubmit
        var initialDraft = InterventionComposerDraft(
            prefilledTargetProblemID: prefilledTargetProblemID ?? initialPrefill?.targetProblemID,
        )
        if let initialPrefill {
            initialDraft.applyPrefill(initialPrefill, dictionary: dictionary)
        }
        _draft = State(initialValue: initialDraft)
    }

    private var context: InterventionMenuContext {
        InterventionMenuContext(
            dictionary: dictionary,
            problems: problems,
            recommendations: recommendations,
            interventions: interventions,
            selectedTargetProblemID: draft.selectedTargetProblemID,
        )
    }

    private var selectedGroup: InterventionGroup? {
        guard let selectedType = draft.selectedType else { return nil }
        return dictionary.first(where: { $0.interventionType == selectedType })
    }

    private var selectedSites: [InterventionSite] {
        guard let selectedGroup else { return [] }
        return context.availableSites(for: selectedGroup)
    }

    private var locationGroups: [(location: String, sites: [InterventionSite])] {
        InterventionSite.grouped(selectedSites)
    }

    private var canSubmit: Bool {
        guard canMutate, let selectedType = draft.selectedType else { return false }
        guard let group = dictionary.first(where: { $0.interventionType == selectedType }) else { return false }
        return draft.resolvedSiteCode(in: context.availableSites(for: group)) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    targetProblemSection
                    if !context.recommendedActions.isEmpty {
                        recommendedSection
                    }
                    fullFormSection
                    if !context.disabledItems.isEmpty {
                        disabledItemsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Add Intervention")
            .modifier(InterventionComposerInlineTitleModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: submitCurrentDraft)
                        .disabled(!canSubmit)
                }
            }
        }
    }

    private var targetProblemSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Problem")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Button {
                draft.selectedTargetProblemID = nil
                draft.activeSection = .type
            } label: {
                selectionRow(
                    title: "General intervention",
                    subtitle: "Not tied to a single problem",
                    selected: draft.selectedTargetProblemID == nil,
                )
            }
            .buttonStyle(.plain)

            ForEach(problems) { problem in
                Button {
                    draft.selectedTargetProblemID = problem.problemID
                    draft.activeSection = .type
                    refreshDefaultsForCurrentType()
                } label: {
                    selectionRow(
                        title: problem.label,
                        subtitle: problem.status.rawValue.capitalized,
                        selected: draft.selectedTargetProblemID == problem.problemID,
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(context.recommendedActions) { action in
                HStack(alignment: .top, spacing: 10) {
                    Button(
                        action: { submit(action) },
                        label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(action.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let subtitle = action.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let siteSummary = action.siteSummary, !siteSummary.isEmpty {
                                    Text(siteSummary)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(TrainerLabTheme.accentBlue)
                                }
                                if let disabledReason = action.disabledReason {
                                    Text(disabledReason)
                                        .font(.caption2)
                                        .foregroundStyle(TrainerLabTheme.warning)
                                } else if let validationStatus = action.validationStatus {
                                    Text(SimulationEventRegistry.humanizedLabel(validationStatus))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        },
                    )
                    .buttonStyle(.plain)
                    .disabled(!action.isEnabled || !canMutate)

                    Button {
                        draft.applyPrefill(action.prefill, dictionary: dictionary)
                        draft.activeSection = .review
                    } label: {
                        Image(systemName: "pencil")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(TrainerLabTheme.accentBlue)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var fullFormSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Full Form")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            collapsibleSection(
                title: "Intervention Type",
                section: .type,
                summary: draft.selectedType.map { InterventionDisplayText.interventionTypeLabel($0, dictionary: dictionary) },
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(context.availableGroups, id: \.id) { group in
                        compactChip(
                            title: group.label,
                            selected: draft.selectedType == group.interventionType,
                        ) {
                            selectInterventionType(group.interventionType)
                        }
                    }
                }
            }

            if selectedGroup != nil {
                collapsibleSection(
                    title: "Site",
                    section: .site,
                    summary: draft.resolvedSiteCode(in: selectedSites).flatMap {
                        InterventionDisplayText.siteLabel(
                            siteCode: $0,
                            siteLabel: nil,
                            interventionType: draft.selectedType,
                            dictionary: dictionary,
                        )
                    },
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(locationGroups, id: \.location) { entry in
                                compactChip(
                                    title: entry.location,
                                    selected: draft.selectedLocationLabel == entry.location,
                                ) {
                                    draft.selectedLocationLabel = entry.location
                                    draft.selectedLaterality = entry.sites.count == 1 ? entry.sites.first?.laterality : nil
                                    draft.activeSection = draft.resolvedSiteCode(in: selectedSites) == nil ? .site : .review
                                }
                            }
                        }

                        let matchingSites = selectedSites.filter { $0.locationLabel == draft.selectedLocationLabel }
                        if matchingSites.contains(where: { $0.laterality != nil }) {
                            HStack(spacing: 8) {
                                compactChip(title: "Left", selected: draft.selectedLaterality == "left") {
                                    draft.selectedLaterality = draft.selectedLaterality == "left" ? nil : "left"
                                    draft.activeSection = draft.resolvedSiteCode(in: selectedSites) == nil ? .site : .review
                                }
                                compactChip(title: "Right", selected: draft.selectedLaterality == "right") {
                                    draft.selectedLaterality = draft.selectedLaterality == "right" ? nil : "right"
                                    draft.activeSection = draft.resolvedSiteCode(in: selectedSites) == nil ? .site : .review
                                }
                                Spacer()
                            }
                        }
                    }
                }

                collapsibleSection(
                    title: "Status & Effectiveness",
                    section: .review,
                    summary: "\(draft.status.rawValue.capitalized) · \(SimulationEventRegistry.humanizedLabel(draft.effectiveness.rawValue))",
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Status")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                chipGrid(
                                    items: InterventionStatus.allCases.map { ($0.rawValue.capitalized, $0) },
                                    selected: draft.status,
                                ) { value in
                                    draft.status = value
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Effectiveness")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                chipGrid(
                                    items: InterventionEffectiveness.allCases.map { (SimulationEventRegistry.humanizedLabel($0.rawValue), $0) },
                                    selected: draft.effectiveness,
                                ) { value in
                                    draft.effectiveness = value
                                }
                            }
                        }

                        if draft.selectedType == "tourniquet" {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Application Mode")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                chipGrid(
                                    items: TourniquetApplicationMode.allCases.map { (SimulationEventRegistry.humanizedLabel($0.rawValue), $0) },
                                    selected: draft.tourniquetApplicationMode,
                                ) { value in
                                    draft.tourniquetApplicationMode = value
                                }
                            }
                        }
                    }
                }

                collapsibleSection(
                    title: "Notes",
                    section: .notes,
                    summary: draft.notes.isEmpty ? nil : draft.notes,
                ) {
                    TextField("Optional notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2 ... 4)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var disabledItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unavailable Right Now")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(context.disabledItems) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                    Text(item.reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func collapsibleSection(
        title: String,
        section: InterventionComposerSection,
        summary: String?,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                draft.activeSection = section
                if section == .notes {
                    draft.notesExpanded = true
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        if let summary, draft.activeSection != section {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Image(systemName: draft.activeSection == section ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if draft.activeSection == section || (section == .notes && draft.notesExpanded) {
                content()
            }
        }
    }

    private func chipGrid<Value: Hashable>(
        items: [(String, Value)],
        selected: Value,
        onSelect: @escaping (Value) -> Void,
    ) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(items, id: \.0) { item in
                compactChip(title: item.0, selected: item.1 == selected) {
                    onSelect(item.1)
                }
            }
        }
    }

    private func compactChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .padding(.horizontal, 8)
                .background(selected ? TrainerLabTheme.accentBlue : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func selectionRow(title: String, subtitle: String, selected: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(TrainerLabTheme.accentBlue)
            }
        }
        .padding(10)
        .background(Color.white.opacity(selected ? 0.08 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func selectInterventionType(_ interventionType: String) {
        draft.selectedType = interventionType
        draft.selectedLocationLabel = nil
        draft.selectedLaterality = nil
        draft.notes = ""
        draft.notesExpanded = false
        draft.tourniquetApplicationMode = .hasty
        refreshDefaultsForCurrentType()
    }

    private func refreshDefaultsForCurrentType() {
        guard let selectedType = draft.selectedType, let prefill = context.prefill(for: selectedType) else {
            draft.activeSection = .type
            return
        }
        draft.applyPrefill(prefill, dictionary: dictionary)
        draft.activeSection = prefill.siteCode == nil ? .site : .review
    }

    private func submitCurrentDraft() {
        guard
            let selectedType = draft.selectedType,
            let selectedGroup,
            let siteCode = draft.resolvedSiteCode(in: context.availableSites(for: selectedGroup))
        else {
            return
        }

        onSubmit(
            selectedType,
            siteCode,
            draft.selectedTargetProblemID,
            draft.status,
            draft.effectiveness,
            draft.notes,
            draft.selectedTourniquetApplicationMode,
        )
        dismiss()
    }

    private func submit(_ action: RecommendedInterventionAction) {
        guard action.isEnabled, let siteCode = action.prefill.siteCode else { return }
        onSubmit(
            action.prefill.interventionType,
            siteCode,
            action.prefill.targetProblemID,
            action.prefill.status,
            action.prefill.effectiveness,
            action.prefill.notes,
            action.prefill.tourniquetApplicationMode,
        )
        dismiss()
    }
}

private struct InterventionComposerInlineTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content.navigationBarTitleDisplayMode(.inline)
        #else
            content
        #endif
    }
}
