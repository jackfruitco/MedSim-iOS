import DesignSystem
import Sessions
import SharedModels
import SwiftUI

struct ProblemDetailView: View {
    let problem: ProblemAnnotation
    let allRecommendations: [RecommendedInterventionItem]
    let allProblems: [ProblemAnnotation]
    let allCauses: [RuntimeCauseState]
    let interventions: [InterventionAnnotation]
    let dictionary: [InterventionGroup]
    let canMutate: Bool
    let onSubmit: (String, String, Int?, InterventionStatus, InterventionEffectiveness, String, TourniquetApplicationMode?) -> Void
    let onEdit: (InterventionComposerPrefill) -> Void

    @Environment(\.dismiss) private var dismiss

    private var filteredRecommendations: [RecommendedInterventionItem] {
        guard let problemID = problem.problemID else { return [] }
        return allRecommendations.filter { $0.targetProblemID == problemID }
    }

    private var menuContext: InterventionMenuContext {
        InterventionMenuContext(
            dictionary: dictionary,
            problems: allProblems,
            recommendations: filteredRecommendations,
            interventions: interventions,
            selectedTargetProblemID: problem.problemID,
        )
    }

    private var linkedCause: RuntimeCauseState? {
        guard let causeID = problem.causeID else { return nil }
        return allCauses.first { $0.causeID == causeID }
    }

    private var sectionSurface: Color {
        TrainerLabTheme.tacticalSurface
    }

    private var rowSurface: Color {
        TrainerLabTheme.tacticalSurfaceElevated
    }

    private var subtleBorder: Color {
        TrainerLabTheme.tacticalBorder
    }

    private var primaryText: Color {
        .white.opacity(0.94)
    }

    private var secondaryText: Color {
        .white.opacity(0.72)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    problemHeader
                    recommendationsCard
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(TrainerLabTheme.tacticalBackground.ignoresSafeArea())
            .navigationTitle(problem.label)
            .modifier(InlineNavigationTitleModifier())
            .modifier(ProblemDetailNavigationBarModifier())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(primaryText)
                }
            }
            .tint(TrainerLabTheme.accentBlue)
        }
    }

    // MARK: - Problem Header

    private var problemHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(problem.label)
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    if let description = problem.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                    }
                }
                Spacer(minLength: 8)
                statusBadge
            }

            Divider()
                .overlay(TrainerLabTheme.tacticalBorder.opacity(0.85))

            metadataGrid
        }
        .trainerCardStyle(background: sectionSurface)
    }

    private var statusBadge: some View {
        Text(problem.status.rawValue.uppercased())
            .font(.caption.bold())
            .foregroundStyle(problem.isUncontrolled ? TrainerLabTheme.danger : TrainerLabTheme.success)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    problem.isUncontrolled
                        ? TrainerLabTheme.danger.opacity(0.15)
                        : TrainerLabTheme.success.opacity(0.15),
                ),
            )
            .overlay(
                Capsule()
                    .stroke(problem.isUncontrolled ? TrainerLabTheme.danger.opacity(0.45) : TrainerLabTheme.success.opacity(0.45), lineWidth: 1),
            )
    }

    private var metadataGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            if let severity = problem.severity {
                metadataCell(label: "Severity", value: severity.capitalized)
            }
            metadataCell(label: "Category", value: problem.isAnatomic ? "Anatomic" : "Systemic")
            if let cause = linkedCause {
                metadataCell(label: "Cause", value: cause.primaryLabel)
            } else if let causeKind = problem.causeKind {
                metadataCell(label: "Cause Type", value: SimulationEventRegistry.humanizedLabel(causeKind))
            }
            if problem.isAnatomic, let loc = problem.locationCode {
                metadataCell(label: "Location", value: InterventionDisplayText.normalizedSiteCode(loc))
            }
        }
    }

    private func metadataCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.caption)
                .foregroundStyle(primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(subtleBorder, lineWidth: 1),
        )
    }

    // MARK: - Recommendations

    private var recommendationsCard: some View {
        let context = menuContext
        return VStack(alignment: .leading, spacing: 10) {
            Text("Recommended Interventions")
                .font(.caption.bold())
                .foregroundStyle(secondaryText)

            if context.recommendedActions.isEmpty {
                emptyRecommendationsView
            } else {
                ForEach(context.recommendedActions) { action in
                    recommendationRow(action)
                }
            }
        }
        .trainerCardStyle(background: sectionSurface)
    }

    private var emptyRecommendationsView: some View {
        Text("No recommendations for this problem.")
            .font(.caption)
            .foregroundStyle(secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }

    private func recommendationRow(_ action: RecommendedInterventionAction) -> some View {
        HStack(alignment: .top, spacing: 10) {
            submitButton(action)
            editButton(action)
        }
    }

    private func submitButton(_ action: RecommendedInterventionAction) -> some View {
        Button {
            guard action.isEnabled, canMutate else { return }
            performSubmit(action)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(!action.isEnabled || !canMutate ? secondaryText : primaryText)
                if let subtitle = action.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                if let siteSummary = action.siteSummary, !siteSummary.isEmpty {
                    Text(siteSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TrainerLabTheme.accentBlue)
                }
                if let disabledReason = action.disabledReason {
                    Text(disabledReason)
                        .font(.caption)
                        .foregroundStyle(TrainerLabTheme.warning)
                } else if let validationStatus = action.validationStatus {
                    Text(SimulationEventRegistry.humanizedLabel(validationStatus))
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(rowSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(subtleBorder, lineWidth: 1),
            )
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled || !canMutate)
        .opacity(action.isEnabled && canMutate ? 1 : 0.68)
    }

    private func editButton(_ action: RecommendedInterventionAction) -> some View {
        Button {
            onEdit(action.prefill)
            dismiss()
        } label: {
            Image(systemName: "pencil")
                .font(.callout.weight(.semibold))
                .foregroundStyle(TrainerLabTheme.accentBlue)
                .frame(width: 40, height: 40)
                .background(rowSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(subtleBorder, lineWidth: 1),
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(action.title)")
    }

    private func performSubmit(_ action: RecommendedInterventionAction) {
        guard let siteCode = action.prefill.siteCode else { return }
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

private struct ProblemDetailNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .toolbarBackground(TrainerLabTheme.tacticalBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        #else
            content
        #endif
    }
}
