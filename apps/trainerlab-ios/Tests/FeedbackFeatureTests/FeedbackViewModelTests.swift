@testable import FeedbackFeature
import Networking
import SharedModels
import XCTest

private enum MockFeedbackError: Error {
    case unused
}

private struct MockFeedbackHeaderProvider: FeedbackRequestHeaderProviding {
    var appVersionHeaderValue: String = "1.2.3 (45)"
    var sessionIDHeaderValue: String = "session-123"

    func requestHeaders() -> [String: String] {
        [
            "X-Platform": "ios",
            "X-App-Version": appVersionHeaderValue,
            "X-OS-Version": "18.0",
            "X-Device-Model": "iPhone17,1",
            "X-Session-ID": sessionIDHeaderValue,
        ]
    }
}

@MainActor
private final class MockFeedbackService: FeedbackServiceProtocol, @unchecked Sendable {
    var categoriesResult: Result<[FeedbackCategoryDTO], Error> = .failure(MockFeedbackError.unused)
    var submitResult: Result<FeedbackResponse, Error> = .failure(MockFeedbackError.unused)
    var submittedRequests: [FeedbackCreateRequest] = []

    func fetchFeedbackCategories() async throws -> [FeedbackCategoryDTO] {
        try categoriesResult.get()
    }

    func submitFeedback(_ request: FeedbackCreateRequest) async throws -> FeedbackResponse {
        submittedRequests.append(request)
        return try submitResult.get()
    }
}

@MainActor
final class FeedbackViewModelTests: XCTestCase {
    func testSubmitIsBlockedWhenTrimmedBodyIsEmpty() async {
        let service = MockFeedbackService()
        let viewModel = FeedbackViewModel(
            service: service,
            headerProvider: MockFeedbackHeaderProvider(),
            launchContext: FeedbackLaunchContext(scope: .general, sourceScreen: "main_menu"),
        )
        viewModel.body = "   \n"

        let didSubmit = await viewModel.submit()

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(viewModel.bodyValidationMessage, "Please enter a description.")
        XCTAssertTrue(service.submittedRequests.isEmpty)
    }

    func testSubmitIncludesInheritedSimulationAndConversationIDsAndTrimsContent() async {
        let service = MockFeedbackService()
        service.submitResult = .success(
            FeedbackResponse(
                id: 1,
                category: .simulationContent,
                title: "Great",
                body: "Trimmed body",
                simulationID: 77,
                conversationID: 15,
                rating: 5,
                allowFollowUp: true,
                context: nil,
                createdAt: nil,
            ),
        )
        let viewModel = FeedbackViewModel(
            service: service,
            headerProvider: MockFeedbackHeaderProvider(),
            launchContext: FeedbackLaunchContext(
                scope: .simulation,
                sourceScreen: "chat_run",
                simulationID: 77,
                conversationID: 15,
                labType: .chatlab,
                simulationDisplayName: "Jordan Alvarez",
                simulationStatus: "in_progress",
                conversationKind: "patient",
            ),
        )
        viewModel.title = "  Great  "
        viewModel.body = "  Trimmed body  "
        viewModel.rating = 5
        viewModel.allowFollowUp = true

        let didSubmit = await viewModel.submit()

        XCTAssertTrue(didSubmit)
        XCTAssertEqual(service.submittedRequests.count, 1)
        XCTAssertEqual(service.submittedRequests[0].simulationID, 77)
        XCTAssertEqual(service.submittedRequests[0].conversationID, 15)
        XCTAssertEqual(service.submittedRequests[0].title, "Great")
        XCTAssertEqual(service.submittedRequests[0].body, "Trimmed body")
        XCTAssertEqual(service.submittedRequests[0].context?["source_screen"], .string("chat_run"))
        XCTAssertEqual(service.submittedRequests[0].context?["submission_scope"], .string("simulation"))
        XCTAssertEqual(service.submittedRequests[0].context?["lab_type"], .string("chatlab"))
    }

    func testFailedSubmitPreservesFormContents() async {
        let service = MockFeedbackService()
        service.submitResult = .failure(APIClientError.http(statusCode: 500, detail: "Boom", correlationID: nil))
        let viewModel = FeedbackViewModel(
            service: service,
            headerProvider: MockFeedbackHeaderProvider(),
            launchContext: FeedbackLaunchContext(scope: .general, sourceScreen: "main_menu"),
        )
        viewModel.selectedCategory = .featureRequest
        viewModel.title = "Keep title"
        viewModel.body = "Keep body"
        viewModel.rating = 3
        viewModel.allowFollowUp = true

        let didSubmit = await viewModel.submit()

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(viewModel.selectedCategory, .featureRequest)
        XCTAssertEqual(viewModel.title, "Keep title")
        XCTAssertEqual(viewModel.body, "Keep body")
        XCTAssertEqual(viewModel.rating, 3)
        XCTAssertTrue(viewModel.allowFollowUp)
        XCTAssertNotNil(viewModel.presentableError)
    }

    func testCategoriesFallbackToLocalEnumWhenFetchFails() async {
        let service = MockFeedbackService()
        service.categoriesResult = .failure(APIClientError.http(statusCode: 503, detail: "Nope", correlationID: nil))
        let viewModel = FeedbackViewModel(
            service: service,
            headerProvider: MockFeedbackHeaderProvider(),
            launchContext: FeedbackLaunchContext(scope: .general, sourceScreen: "main_menu"),
        )

        await viewModel.loadCategoriesIfNeeded()

        XCTAssertEqual(viewModel.categories, FeedbackCategory.allCases)
    }

    func testSuccessfulSubmitClearsDraftAndMarksSuccess() async {
        let service = MockFeedbackService()
        service.submitResult = .success(
            FeedbackResponse(
                id: 2,
                category: .other,
                title: nil,
                body: "Thanks",
                simulationID: nil,
                conversationID: nil,
                rating: nil,
                allowFollowUp: false,
                context: nil,
                createdAt: nil,
            ),
        )
        let viewModel = FeedbackViewModel(
            service: service,
            headerProvider: MockFeedbackHeaderProvider(),
            launchContext: FeedbackLaunchContext(scope: .general, sourceScreen: "main_menu"),
        )
        viewModel.title = "Title"
        viewModel.body = "Body"
        viewModel.rating = 2
        viewModel.allowFollowUp = true

        let didSubmit = await viewModel.submit()

        XCTAssertTrue(didSubmit)
        XCTAssertTrue(viewModel.didSubmitSuccessfully)
        XCTAssertEqual(viewModel.title, "")
        XCTAssertEqual(viewModel.body, "")
        XCTAssertNil(viewModel.rating)
        XCTAssertFalse(viewModel.allowFollowUp)
    }
}
