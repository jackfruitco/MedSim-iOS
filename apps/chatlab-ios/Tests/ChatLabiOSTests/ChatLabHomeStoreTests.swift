@testable import ChatLabiOS
import Networking
import SharedModels
import XCTest

private enum StubError: Error { case sentinel }

private final class StubChatLabService: ChatLabServiceProtocol, @unchecked Sendable {
    var listSimulationsResult: Result<PaginatedResponse<ChatSimulation>, Error> = .success(
        PaginatedResponse(items: [], nextCursor: nil, hasMore: false)
    )
    var listSimulationsCallCount = 0
    var listSimulationsDelay: UInt64 = 0

    func listSimulations(limit _: Int, cursor _: String?, status _: String?, query _: String?, searchMessages _: Bool) async throws -> PaginatedResponse<ChatSimulation> {
        listSimulationsCallCount += 1
        if listSimulationsDelay > 0 {
            try? await Task.sleep(nanoseconds: listSimulationsDelay)
        }
        return try listSimulationsResult.get()
    }

    func quickCreateSimulation(request _: ChatQuickCreateRequest) async throws -> ChatSimulation { throw StubError.sentinel }
    func getSimulation(simulationID _: Int) async throws -> ChatSimulation { throw StubError.sentinel }
    func endSimulation(simulationID _: Int) async throws -> ChatSimulation { throw StubError.sentinel }
    func retryInitial(simulationID _: Int) async throws -> ChatSimulation { throw StubError.sentinel }
    func retryFeedback(simulationID _: Int) async throws -> ChatSimulation { throw StubError.sentinel }
    func listConversations(simulationID _: Int) async throws -> ChatConversationListResponse { throw StubError.sentinel }
    func createConversation(simulationID _: Int, request _: ChatCreateConversationRequest) async throws -> ChatConversation { throw StubError.sentinel }
    func getConversation(simulationID _: Int, conversationUUID _: String) async throws -> ChatConversation { throw StubError.sentinel }
    func listMessages(simulationID _: Int, conversationID _: Int?, cursor _: String?, order _: String, limit _: Int) async throws -> PaginatedResponse<ChatMessage> { throw StubError.sentinel }
    func createMessage(simulationID _: Int, request _: ChatCreateMessageRequest) async throws -> ChatMessage { throw StubError.sentinel }
    func retryMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage { throw StubError.sentinel }
    func getMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage { throw StubError.sentinel }
    func markMessageRead(simulationID _: Int, messageID _: Int) async throws -> ChatMessage { throw StubError.sentinel }
    func listEvents(simulationID _: Int, lastEventID _: String?, limit _: Int) async throws -> ChatEventReplayResponse { throw StubError.sentinel }
    func listTools(simulationID _: Int, names _: [String]?) async throws -> ChatToolListResponse { throw StubError.sentinel }
    func getTool(simulationID _: Int, toolName _: String) async throws -> ChatToolState { throw StubError.sentinel }
    func signOrders(simulationID _: Int, request _: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse { throw StubError.sentinel }
    func submitLabOrders(simulationID _: Int, request _: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse { throw StubError.sentinel }
    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO { throw StubError.sentinel }
    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO { throw StubError.sentinel }
    func listModifierGroups(groups _: [String]?) async throws -> [ModifierGroup] { throw StubError.sentinel }
}

@MainActor
final class ChatLabHomeStoreTests: XCTestCase {
    func testRefresh_fetchesAndStoresSimulations() async {
        let service = StubChatLabService()
        let sim = makeSimulation(id: 1)
        service.listSimulationsResult = .success(PaginatedResponse(items: [sim], nextCursor: nil, hasMore: false))
        let store = ChatLabHomeStore(service: service)

        await store.refresh()

        XCTAssertEqual(store.simulations.count, 1)
        XCTAssertEqual(store.simulations.first?.id, 1)
        XCTAssertEqual(service.listSimulationsCallCount, 1)
    }

    func testRefresh_replacesExistingSimulations() async {
        let service = StubChatLabService()
        let old = makeSimulation(id: 10)
        let new = makeSimulation(id: 20)

        service.listSimulationsResult = .success(PaginatedResponse(items: [old], nextCursor: nil, hasMore: false))
        let store = ChatLabHomeStore(service: service)
        await store.loadInitial()
        XCTAssertEqual(store.simulations.first?.id, 10)

        service.listSimulationsResult = .success(PaginatedResponse(items: [new], nextCursor: nil, hasMore: false))
        await store.refresh()

        XCTAssertEqual(store.simulations.count, 1)
        XCTAssertEqual(store.simulations.first?.id, 20)
    }

    func testRefresh_setsErrorOnFailure() async {
        let service = StubChatLabService()
        service.listSimulationsResult = .failure(NSError(domain: "test", code: 99))
        let store = ChatLabHomeStore(service: service)

        await store.refresh()

        XCTAssertNotNil(store.presentableError)
    }

    func testRefresh_skipsWhenInitialLoadInProgress() async {
        let service = StubChatLabService()
        // Make loadInitial() block long enough for the concurrent refresh() to be skipped.
        service.listSimulationsDelay = 200_000_000 // 200ms
        service.listSimulationsResult = .success(PaginatedResponse(items: [], nextCursor: nil, hasMore: false))
        let store = ChatLabHomeStore(service: service)

        let loadTask = Task { await store.loadInitial() }
        // Yield so loadInitial sets isLoading = true before refresh() runs.
        await Task.yield()
        await store.refresh()
        await loadTask.value

        // Only one service call: the initial load. refresh() bailed early.
        XCTAssertEqual(service.listSimulationsCallCount, 1)
    }

    func testLoadInitialAndRefresh_useSameServiceMethod() async {
        let service = StubChatLabService()
        service.listSimulationsResult = .success(PaginatedResponse(items: [], nextCursor: nil, hasMore: false))
        let store = ChatLabHomeStore(service: service)

        await store.loadInitial()
        await store.refresh()

        XCTAssertEqual(service.listSimulationsCallCount, 2)
    }
}

private func makeSimulation(id: Int) -> ChatSimulation {
    ChatSimulation(
        id: id,
        userID: 7,
        startTimestamp: Date(),
        endTimestamp: nil,
        timeLimitSeconds: 600,
        diagnosis: "Test",
        chiefComplaint: "Pain",
        patientDisplayName: "Test Patient",
        patientInitials: "TP",
        status: .inProgress,
        terminalReasonCode: "",
        terminalReasonText: "",
        terminalAt: nil,
        retryable: nil,
        latestEventID: nil,
    )
}
