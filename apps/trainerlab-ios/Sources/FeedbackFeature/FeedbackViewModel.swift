import Foundation
import Networking
import SharedModels

@MainActor
public final class FeedbackViewModel: ObservableObject {
    @Published public private(set) var categories: [FeedbackCategory] = FeedbackCategory.allCases
    @Published public var selectedCategory: FeedbackCategory
    @Published public var title = ""
    @Published public var body = ""
    @Published public var rating: Int?
    @Published public var allowFollowUp = false
    @Published public private(set) var isLoadingCategories = false
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var presentableError: PresentableAppError?
    @Published public private(set) var bodyValidationMessage: String?
    @Published public private(set) var didSubmitSuccessfully = false

    public let simulationID: Int?
    public let conversationID: Int?
    public let launchContext: FeedbackLaunchContext

    private let service: FeedbackServiceProtocol
    private let headerProvider: FeedbackRequestHeaderProviding
    private var hasLoadedCategories = false

    public init(
        service: FeedbackServiceProtocol,
        headerProvider: FeedbackRequestHeaderProviding,
        launchContext: FeedbackLaunchContext,
    ) {
        self.service = service
        self.headerProvider = headerProvider
        self.launchContext = launchContext
        selectedCategory = launchContext.defaultCategory
        simulationID = launchContext.simulationID
        conversationID = launchContext.conversationID
    }

    public var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var canSubmit: Bool {
        !trimmedBody.isEmpty && !isSubmitting
    }

    public func loadCategoriesIfNeeded() async {
        guard !hasLoadedCategories, !isLoadingCategories else { return }
        isLoadingCategories = true
        defer {
            isLoadingCategories = false
            hasLoadedCategories = true
        }

        do {
            let fetched = try await service.fetchFeedbackCategories().map(\.value)
            let uniqueCategories = fetched.reduce(into: [FeedbackCategory]()) { result, category in
                if result.contains(category) == false {
                    result.append(category)
                }
            }
            if !uniqueCategories.isEmpty {
                categories = uniqueCategories
                if categories.contains(selectedCategory) == false {
                    selectedCategory = launchContext.defaultCategory
                }
            }
        } catch {
            categories = FeedbackCategory.allCases
        }
    }

    public func clearSubmissionError() {
        presentableError = nil
    }

    public func clearValidationIfNeeded() {
        if trimmedBody.isEmpty {
            bodyValidationMessage = "Please enter a description."
        } else {
            bodyValidationMessage = nil
        }
    }

    public func makeCreateRequest() -> FeedbackCreateRequest? {
        let body = trimmedBody
        guard !body.isEmpty else {
            return nil
        }

        let title = trimmedTitle

        return FeedbackCreateRequest(
            category: selectedCategory,
            title: title.isEmpty ? nil : title,
            body: body,
            simulationID: simulationID,
            conversationID: conversationID,
            rating: rating,
            allowFollowUp: allowFollowUp,
            context: launchContext.requestContext(appVersion: headerProvider.appVersionHeaderValue),
        )
    }

    @discardableResult
    public func submit() async -> Bool {
        bodyValidationMessage = nil
        presentableError = nil
        didSubmitSuccessfully = false

        guard let request = makeCreateRequest() else {
            bodyValidationMessage = "Please enter a description."
            return false
        }
        guard !isSubmitting else { return false }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await service.submitFeedback(request)
            didSubmitSuccessfully = true
            clearDraft()
            return true
        } catch {
            presentableError = AppErrorPresenter.present(error)
            return false
        }
    }

    private func clearDraft() {
        title = ""
        body = ""
        rating = nil
        allowFollowUp = false
    }
}
