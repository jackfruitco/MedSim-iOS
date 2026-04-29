@testable import ChatLabiOS
import Networking
import SharedModels
import XCTest

private enum StubError: Error { case sentinel }

private final class StubChatLabService: ChatLabServiceProtocol, @unchecked Sendable {
    var listSimulationsResult: Result<PaginatedResponse<ChatSimulation>, Error> = .success(
        PaginatedResponse(items: [], nextCursor: nil, hasMore: false),
    )
    var listSimulationsCallCount = 0
    var listSimulationsDelay: UInt64 = 0
    var quickCreateResult: Result<ChatSimulation, Error> = .failure(StubError.sentinel)
    var quickCreateRequests: [ChatQuickCreateRequest] = []
    var listModifierGroupsResult: Result<[ModifierGroup], Error> = .failure(StubError.sentinel)
    var listModifierGroupsCallCount = 0
    var listModifierGroupsDelay: UInt64 = 0
    var requestedLabTypes: [String] = []

    func listSimulations(limit _: Int, cursor _: String?, status _: String?, query _: String?, searchMessages _: Bool) async throws -> PaginatedResponse<ChatSimulation> {
        listSimulationsCallCount += 1
        if listSimulationsDelay > 0 {
            try? await Task.sleep(nanoseconds: listSimulationsDelay)
        }
        return try listSimulationsResult.get()
    }

    func quickCreateSimulation(request: ChatQuickCreateRequest) async throws -> ChatSimulation {
        quickCreateRequests.append(request)
        return try quickCreateResult.get()
    }

    func getSimulation(simulationID _: Int) async throws -> ChatSimulation {
        throw StubError.sentinel
    }

    func endSimulation(simulationID _: Int) async throws -> ChatSimulation {
        throw StubError.sentinel
    }

    func retryInitial(simulationID _: Int) async throws -> ChatSimulation {
        throw StubError.sentinel
    }

    func retryFeedback(simulationID _: Int) async throws -> ChatSimulation {
        throw StubError.sentinel
    }

    func listConversations(simulationID _: Int) async throws -> ChatConversationListResponse {
        throw StubError.sentinel
    }

    func createConversation(simulationID _: Int, request _: ChatCreateConversationRequest) async throws -> ChatConversation {
        throw StubError.sentinel
    }

    func getConversation(simulationID _: Int, conversationUUID _: String) async throws -> ChatConversation {
        throw StubError.sentinel
    }

    func listMessages(simulationID _: Int, conversationID _: Int?, cursor _: String?, order _: String, limit _: Int) async throws -> PaginatedResponse<ChatMessage> {
        throw StubError.sentinel
    }

    func createMessage(simulationID _: Int, request _: ChatCreateMessageRequest) async throws -> ChatMessage {
        throw StubError.sentinel
    }

    func retryMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        throw StubError.sentinel
    }

    func getMessage(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        throw StubError.sentinel
    }

    func markMessageRead(simulationID _: Int, messageID _: Int) async throws -> ChatMessage {
        throw StubError.sentinel
    }

    func listEvents(simulationID _: Int, lastEventID _: String?, limit _: Int) async throws -> ChatEventReplayResponse {
        throw StubError.sentinel
    }

    func listTools(simulationID _: Int, names _: [String]?) async throws -> ChatToolListResponse {
        throw StubError.sentinel
    }

    func getTool(simulationID _: Int, toolName _: String) async throws -> ChatToolState {
        throw StubError.sentinel
    }

    func signOrders(simulationID _: Int, request _: ChatSignOrdersRequest) async throws -> ChatSignOrdersResponse {
        throw StubError.sentinel
    }

    func submitLabOrders(simulationID _: Int, request _: ChatSubmitLabOrdersRequest) async throws -> ChatLabOrdersResponse {
        throw StubError.sentinel
    }

    func getGuardState(simulationID _: Int) async throws -> GuardStateDTO {
        throw StubError.sentinel
    }

    func sendHeartbeat(simulationID _: Int) async throws -> GuardStateDTO {
        throw StubError.sentinel
    }

    func listModifierGroups(labType: String) async throws -> [ModifierGroup] {
        listModifierGroupsCallCount += 1
        requestedLabTypes.append(labType)
        if listModifierGroupsDelay > 0 {
            try? await Task.sleep(nanoseconds: listModifierGroupsDelay)
        }
        return try listModifierGroupsResult.get()
    }
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
        // Block loadInitial() long enough that the concurrent refresh() sees isLoading == true and bails.
        service.listSimulationsDelay = 200_000_000
        service.listSimulationsResult = .success(PaginatedResponse(items: [], nextCursor: nil, hasMore: false))
        let store = ChatLabHomeStore(service: service)

        let loadTask = Task { await store.loadInitial() }
        await Task.yield()
        await store.refresh()
        await loadTask.value

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

    func testLoadModifierGroups_fetchesChatLabCatalog() async {
        let service = StubChatLabService()
        service.listModifierGroupsResult = .success([makeModifierGroup()])
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()

        XCTAssertEqual(service.listModifierGroupsCallCount, 1)
        XCTAssertEqual(service.requestedLabTypes, ["chatlab"])
        XCTAssertEqual(store.modifierGroups.first?.key, "clinical_scenario")
        XCTAssertNil(store.modifierLoadError)
        XCTAssertTrue(store.hasLoadedModifierGroups)
        XCTAssertTrue(store.canCreateSimulation)
    }

    func testOptionalSingleSelectDefaultsToNoPreferenceAndFlattensNoKey() async {
        let service = StubChatLabService()
        let group = makeModifierGroup(required: false)
        service.listModifierGroupsResult = .success([group])
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()

        XCTAssertNil(store.singleSelection(in: group))
        XCTAssertEqual(store.flattenSelectedModifierKeys(), [])

        store.selectSingleModifier("musculoskeletal", in: group)
        XCTAssertEqual(store.flattenSelectedModifierKeys(), ["musculoskeletal"])

        store.selectSingleModifier(nil, in: group)
        XCTAssertEqual(store.flattenSelectedModifierKeys(), [])
    }

    func testRequiredSingleSelectValidationBlocksUntilSelected() async {
        let service = StubChatLabService()
        let group = makeModifierGroup(required: true)
        service.listModifierGroupsResult = .success([group])
        service.quickCreateResult = .success(makeSimulation(id: 41))
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()
        let blocked = await store.quickCreateSimulation()

        XCTAssertNil(blocked)
        XCTAssertEqual(store.modifierValidationErrors, ["Clinical Scenario is required."])
        XCTAssertEqual(service.quickCreateRequests.count, 0)

        store.selectSingleModifier("musculoskeletal", in: group)
        let created = await store.quickCreateSimulation()

        XCTAssertEqual(created?.id, 41)
        XCTAssertEqual(service.quickCreateRequests.first?.modifiers, ["musculoskeletal"])
    }

    func testMultipleSelectAllowsMultipleKeysAndValidatesRequiredGroup() async {
        let service = StubChatLabService()
        let group = makeModifierGroup(
            key: "injuries",
            label: "Injuries",
            mode: .multiple,
            required: true,
            modifiers: [
                ModifierOption(key: "hemorrhage", label: "Hemorrhage", description: "Bleeding"),
                ModifierOption(key: "fracture", label: "Fracture", description: "Broken bone"),
            ],
        )
        service.listModifierGroupsResult = .success([group])
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()
        XCTAssertEqual(store.validateModifierSelections(), ["Injuries requires at least one selection."])

        store.toggleMultipleModifier("hemorrhage", in: group)
        store.toggleMultipleModifier("fracture", in: group)

        XCTAssertEqual(store.validateModifierSelections(), [])
        XCTAssertEqual(store.flattenSelectedModifierKeys(), ["hemorrhage", "fracture"])
    }

    func testFlattenSelectedKeysUsesBackendGroupOrder() async {
        let service = StubChatLabService()
        let scenario = makeModifierGroup()
        let duration = makeModifierGroup(
            key: "clinical_duration",
            label: "Clinical Duration",
            modifiers: [
                ModifierOption(key: "acute", label: "Acute", description: "New concern"),
                ModifierOption(key: "chronic", label: "Chronic", description: "Long concern"),
            ],
        )
        service.listModifierGroupsResult = .success([scenario, duration])
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()
        store.selectSingleModifier("acute", in: duration)
        store.selectSingleModifier("musculoskeletal", in: scenario)

        XCTAssertEqual(store.flattenSelectedModifierKeys(), ["musculoskeletal", "acute"])
    }

    func testRefreshModifierGroupsDropsStaleSelectedKeys() async {
        let service = StubChatLabService()
        let original = makeModifierGroup()
        service.listModifierGroupsResult = .success([original])
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()
        store.selectSingleModifier("musculoskeletal", in: original)
        XCTAssertEqual(store.flattenSelectedModifierKeys(), ["musculoskeletal"])

        service.listModifierGroupsResult = .success([
            makeModifierGroup(
                modifiers: [ModifierOption(key: "respiratory", label: "Respiratory", description: "Respiratory issue")],
            ),
        ])
        await store.loadModifierGroups()

        XCTAssertEqual(store.flattenSelectedModifierKeys(), [])
    }

    func testModifierLoadFailureSetsRecoverableModifierErrorOnly() async {
        let service = StubChatLabService()
        service.listModifierGroupsResult = .failure(
            APIClientError.http(statusCode: 500, detail: "raw backend exception", correlationID: nil),
        )
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()

        XCTAssertNotNil(store.modifierLoadError)
        XCTAssertNil(store.presentableError)
        XCTAssertFalse(store.modifierLoadError?.message.contains("raw backend exception") ?? true)
    }

    func testQuickCreateMapsHTTP400ToGenericInvalidModifierMessage() async {
        let service = StubChatLabService()
        let group = makeModifierGroup()
        service.listModifierGroupsResult = .success([group])
        service.quickCreateResult = .failure(
            APIClientError.http(statusCode: 400, detail: "Unknown modifier key nonexistent", correlationID: nil),
        )
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()
        store.selectSingleModifier("musculoskeletal", in: group)
        let created = await store.quickCreateSimulation()

        XCTAssertNil(created)
        XCTAssertEqual(store.presentableError?.message, "Invalid modifier selection. Refresh and try again.")
        XCTAssertFalse(store.presentableError?.message.contains("nonexistent") ?? true)
    }

    func testQuickCreateBeforeModifierHydrationDoesNotCallService() async {
        let service = StubChatLabService()
        service.quickCreateResult = .success(makeSimulation(id: 77))
        let store = ChatLabHomeStore(service: service)

        let created = await store.quickCreateSimulation()

        XCTAssertNil(created)
        XCTAssertEqual(service.quickCreateRequests.count, 0)
        XCTAssertEqual(store.modifierValidationErrors, ["Modifiers are still loading."])
        XCTAssertFalse(store.canCreateSimulation)
    }

    func testQuickCreateWhileModifierGroupsAreLoadingDoesNotCallService() async {
        let service = StubChatLabService()
        service.listModifierGroupsDelay = 200_000_000
        service.listModifierGroupsResult = .success([makeModifierGroup()])
        service.quickCreateResult = .success(makeSimulation(id: 78))
        let store = ChatLabHomeStore(service: service)

        let loadTask = Task { await store.loadModifierGroups() }
        while store.isLoadingModifierGroups == false {
            await Task.yield()
        }

        let created = await store.quickCreateSimulation()
        await loadTask.value

        XCTAssertNil(created)
        XCTAssertEqual(service.quickCreateRequests.count, 0)
        XCTAssertEqual(store.modifierValidationErrors, ["Modifiers are still loading."])
    }

    func testQuickCreateAfterModifierLoadFailureDoesNotCallService() async {
        let service = StubChatLabService()
        service.listModifierGroupsResult = .failure(
            APIClientError.http(statusCode: 500, detail: "catalog invalid", correlationID: nil),
        )
        service.quickCreateResult = .success(makeSimulation(id: 79))
        let store = ChatLabHomeStore(service: service)

        await store.loadModifierGroups()
        let created = await store.quickCreateSimulation()

        XCTAssertNil(created)
        XCTAssertEqual(service.quickCreateRequests.count, 0)
        XCTAssertEqual(store.presentableError?.title, "Modifiers Unavailable")
        XCTAssertEqual(store.presentableError?.message, "Refresh modifiers and try again.")
        XCTAssertFalse(store.canCreateSimulation)
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

private func makeModifierGroup(
    key: String = "clinical_scenario",
    label: String = "Clinical Scenario",
    mode: ModifierSelectionMode = .single,
    required: Bool = false,
    modifiers: [ModifierOption] = [
        ModifierOption(
            key: "musculoskeletal",
            label: "Musculoskeletal",
            description: "Musculoskeletal injury or issue scenario",
        ),
        ModifierOption(
            key: "respiratory",
            label: "Respiratory",
            description: "Respiratory issue",
        ),
    ],
) -> ModifierGroup {
    ModifierGroup(
        key: key,
        label: label,
        description: "Type of clinical encounter",
        selection: ModifierSelectionConfig(mode: mode, required: required),
        modifiers: modifiers,
    )
}
