import DesignSystem
import Networking
import SwiftUI

public struct FeedbackFormView: View {
    @ObservedObject private var viewModel: FeedbackViewModel
    private let onSubmitted: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case body
    }

    public init(
        viewModel: FeedbackViewModel,
        onSubmitted: @escaping @MainActor () -> Void,
    ) {
        self.viewModel = viewModel
        self.onSubmitted = onSubmitted
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let error = viewModel.presentableError {
                    Section {
                        InlineAppErrorView(error: error, actionLabel: "Retry")
                            .font(.footnote)
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(viewModel.categories, id: \.self) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .accessibilityIdentifier("feedback-category-picker")

                    Text(viewModel.selectedCategory.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.launchContext.attachedContextLines.isEmpty {
                    Section("Attached Context") {
                        ForEach(viewModel.launchContext.attachedContextLines, id: \.self) { line in
                            Text(line)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Details") {
                    TextField("Optional title", text: $viewModel.title)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .body
                        }
                        .accessibilityIdentifier("feedback-title-field")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.subheadline.weight(.semibold))

                        TextEditor(text: $viewModel.body)
                            .frame(minHeight: 180)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .focused($focusedField, equals: .body)
                            .accessibilityIdentifier("feedback-body-field")
                            .onChange(of: viewModel.body) { _, _ in
                                viewModel.clearSubmissionError()
                                viewModel.clearValidationIfNeeded()
                            }

                        if let bodyValidationMessage = viewModel.bodyValidationMessage {
                            Text(bodyValidationMessage)
                                .font(.footnote)
                                .foregroundStyle(TrainerLabTheme.danger)
                        } else {
                            Text("Tell us what happened, what you expected, or what would help.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Rating") {
                    FeedbackRatingPicker(rating: $viewModel.rating)
                }

                Section("Follow-Up") {
                    Toggle("Allow the team to follow up with you", isOn: $viewModel.allowFollowUp)
                }
            }
            .navigationTitle("Send Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let didSubmit = await viewModel.submit()
                            if didSubmit {
                                onSubmitted()
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Send")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                    .accessibilityIdentifier("feedback-submit-button")
                }
            }
        }
        .task {
            await viewModel.loadCategoriesIfNeeded()
            if viewModel.body.isEmpty {
                focusedField = .body
            }
        }
    }
}

private struct FeedbackRatingPicker: View {
    @Binding var rating: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(1 ... 5, id: \.self) { value in
                    Button {
                        rating = value
                    } label: {
                        Image(systemName: iconName(for: value))
                            .font(.title3)
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rate \(value) out of 5")
                    .accessibilityAddTraits(rating == value ? .isSelected : [])
                }

                Spacer(minLength: 12)

                Button("Clear") {
                    rating = nil
                }
                .buttonStyle(.bordered)
                .disabled(rating == nil)
                .accessibilityLabel("Clear rating")
            }

            Text(ratingDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var ratingDescription: String {
        guard let rating else {
            return "Rating is optional."
        }
        return "\(rating) out of 5 selected."
    }

    private func iconName(for value: Int) -> String {
        guard let rating else {
            return "star"
        }
        return value <= rating ? "star.fill" : "star"
    }
}
