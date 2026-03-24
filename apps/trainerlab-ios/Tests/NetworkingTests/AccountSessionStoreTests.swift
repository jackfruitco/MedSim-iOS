import Foundation
@testable import Networking
import SharedModels
import XCTest

private final class MockAccountAPIClient: APIClientProtocol, @unchecked Sendable {
    var accounts: [AccountOut]
    var accessSnapshotsByAccountUUID: [String: AccessSnapshotOut]
    var accessErrorByAccountUUID: [String: Error] = [:]
    var selectedAccountUUID: String?
    private(set) var selectCalls: [String] = []
    private(set) var billingSyncCalls: [AppleBillingSyncRequest] = []

    init(accounts: [AccountOut], accessSnapshotsByAccountUUID: [String: AccessSnapshotOut], selectedAccountUUID: String? = nil) {
        self.accounts = accounts
        self.accessSnapshotsByAccountUUID = accessSnapshotsByAccountUUID
        self.selectedAccountUUID = selectedAccountUUID ?? accounts.first(where: \.isActiveContext)?.uuid
    }

    private func typedResponse<T>(_ value: some Sendable, as _: T.Type = T.self) throws -> T {
        guard let typed = value as? T else {
            throw APIClientError.decoding("Unexpected mock response type for \(T.self)")
        }
        return typed
    }

    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as _: T.Type) async throws -> T {
        switch endpoint.path {
        case "/api/v1/accounts/":
            return try typedResponse(accounts)
        case "/api/v1/accounts/select/":
            let body = try XCTUnwrap(endpoint.body)
            let payload = try JSONDecoder().decode(AccountSelectionPayload.self, from: body)
            selectedAccountUUID = payload.accountUUID
            selectCalls.append(payload.accountUUID)
            accounts = accounts.map { account in
                AccountOut(
                    uuid: account.uuid,
                    name: account.name,
                    slug: account.slug,
                    accountType: account.accountType,
                    isActive: account.isActive,
                    requiresJoinApproval: account.requiresJoinApproval,
                    parentAccountUUID: account.parentAccountUUID,
                    membershipRole: account.membershipRole,
                    membershipStatus: account.membershipStatus,
                    isActiveContext: account.uuid == payload.accountUUID,
                )
            }
            return try typedResponse(EmptyResponse())
        case "/api/v1/accounts/me/access/":
            if let selectedAccountUUID,
               let error = accessErrorByAccountUUID[selectedAccountUUID]
            {
                throw error
            }
            guard let selectedAccountUUID,
                  let snapshot = accessSnapshotsByAccountUUID[selectedAccountUUID]
            else {
                throw APIClientError.http(statusCode: 404, detail: "Missing access snapshot", correlationID: nil)
            }
            return try typedResponse(snapshot)
        case "/api/v1/billing/apple/sync/":
            let body = try XCTUnwrap(endpoint.body)
            try billingSyncCalls.append(JSONDecoder().decode(AppleBillingSyncRequest.self, from: body))
            return try typedResponse(EmptyResponse())
        default:
            throw APIClientError.http(statusCode: 500, detail: "Unhandled path \(endpoint.path)", correlationID: nil)
        }
    }

    func requestData(_ endpoint: Endpoint) async throws -> Data {
        let _: EmptyResponse = try await request(endpoint, as: EmptyResponse.self)
        return Data()
    }

    func baseURL() async -> URL {
        URL(string: "https://example.com")!
    }
}

private actor BootstrapBarrier {
    private var didStart = false
    private var shouldResume = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    func markStarted() {
        didStart = true
        startContinuation?.resume()
        startContinuation = nil
    }

    func waitUntilStarted() async {
        if didStart { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func waitForResume() async {
        if shouldResume {
            shouldResume = false
            return
        }
        await withCheckedContinuation { continuation in
            resumeContinuation = continuation
        }
    }

    func resume() {
        if let resumeContinuation {
            resumeContinuation.resume()
            self.resumeContinuation = nil
        } else {
            shouldResume = true
        }
    }
}

private final class BlockingBootstrapAPIClient: APIClientProtocol, @unchecked Sendable {
    private let accounts: [AccountOut]
    private let snapshot: AccessSnapshotOut
    private let barrier = BootstrapBarrier()

    init(accounts: [AccountOut], snapshot: AccessSnapshotOut) {
        self.accounts = accounts
        self.snapshot = snapshot
    }

    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as _: T.Type) async throws -> T {
        switch endpoint.path {
        case "/api/v1/accounts/":
            await barrier.markStarted()
            await barrier.waitForResume()
            return try cast(accounts, as: T.self)
        case "/api/v1/accounts/me/access/":
            return try cast(snapshot, as: T.self)
        default:
            throw APIClientError.http(statusCode: 500, detail: "Unhandled path \(endpoint.path)", correlationID: nil)
        }
    }

    func requestData(_ endpoint: Endpoint) async throws -> Data {
        let _: EmptyResponse = try await request(endpoint, as: EmptyResponse.self)
        return Data()
    }

    func baseURL() async -> URL {
        URL(string: "https://example.com")!
    }

    func waitUntilBootstrapStarts() async {
        await barrier.waitUntilStarted()
    }

    func resumeBootstrap() async {
        await barrier.resume()
    }

    private func cast<T>(_ value: some Sendable, as _: T.Type) throws -> T {
        guard let typed = value as? T else {
            throw APIClientError.decoding("Unexpected mock response type for \(T.self)")
        }
        return typed
    }
}

private struct AccountSelectionPayload: Decodable {
    let accountUUID: String

    enum CodingKeys: String, CodingKey {
        case accountUUID = "account_uuid"
    }
}

@MainActor
final class AccountSessionStoreTests: XCTestCase {
    private func makeStore(
        products: [String: ProductAccessOut],
        accountUUID: String = "acct-a",
        accountName: String = "Alpha",
    ) -> AccountSessionStore {
        let accounts = [
            AccountOut(
                uuid: accountUUID,
                name: accountName,
                slug: accountName.lowercased(),
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "owner",
                membershipStatus: "active",
                isActiveContext: true,
            ),
        ]
        let snapshots = [
            accountUUID: AccessSnapshotOut(
                accountUUID: accountUUID,
                accountName: accountName,
                accountType: "personal",
                membershipRole: "owner",
                products: products,
            ),
        ]
        let apiClient = MockAccountAPIClient(accounts: accounts, accessSnapshotsByAccountUUID: snapshots)

        return AccountSessionStore(
            apiClient: apiClient,
            baseURLProvider: { URL(string: "https://example.com")! },
            accountContext: SelectedAccountContext(accountUUID: accountUUID),
            userDefaults: UserDefaults(suiteName: "AccountSessionStoreTests.\(UUID().uuidString)")!,
        )
    }

    func testBootstrapUsesPersistedSelectionAndRefreshesAccessSnapshot() async throws {
        let suiteName = "AccountSessionStoreTests.bootstrap.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set("acct-b", forKey: "medsim.selected-account.example.com.default")

        let accounts = [
            AccountOut(
                uuid: "acct-a",
                name: "Alpha",
                slug: "alpha",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "owner",
                membershipStatus: "active",
                isActiveContext: true,
            ),
            AccountOut(
                uuid: "acct-b",
                name: "Bravo",
                slug: "bravo",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "member",
                membershipStatus: "active",
                isActiveContext: false,
            ),
        ]

        let snapshots = [
            "acct-a": AccessSnapshotOut(
                accountUUID: "acct-a",
                accountName: "Alpha",
                accountType: "personal",
                membershipRole: "owner",
                products: [:],
            ),
            "acct-b": AccessSnapshotOut(
                accountUUID: "acct-b",
                accountName: "Bravo",
                accountType: "personal",
                membershipRole: "member",
                products: [
                    "chatlab": ProductAccessOut(
                        enabled: true,
                        features: ["advanced_search": .bool(true)],
                        limits: ["seat_count": .number(5)],
                    ),
                ],
            ),
        ]

        let apiClient = MockAccountAPIClient(accounts: accounts, accessSnapshotsByAccountUUID: snapshots)
        let accountContext = SelectedAccountContext()
        let store = AccountSessionStore(
            apiClient: apiClient,
            baseURLProvider: { URL(string: "https://example.com")! },
            accountContext: accountContext,
            userDefaults: userDefaults,
        )

        try await store.bootstrapSession()

        XCTAssertEqual(apiClient.selectCalls, ["acct-b"])
        XCTAssertEqual(store.selectedAccountUUID, "acct-b")
        XCTAssertEqual(store.currentAccount?.name, "Bravo")
        XCTAssertEqual(store.productAccess(code: "chatlab")?.enabled, true)
        XCTAssertTrue(store.hasFeature("advanced_search", in: "chatlab"))
        XCTAssertEqual(store.limit("seat_count", in: "chatlab"), .number(5))
        let selectedFromContext = await accountContext.selectedAccountUUID()
        XCTAssertEqual(selectedFromContext, "acct-b")
    }

    func testSwitchAccountUpdatesActiveContextAndPersistsSelection() async throws {
        let suiteName = "AccountSessionStoreTests.switch.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let accounts = [
            AccountOut(
                uuid: "acct-a",
                name: "Alpha",
                slug: "alpha",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "owner",
                membershipStatus: "active",
                isActiveContext: true,
            ),
            AccountOut(
                uuid: "acct-b",
                name: "Bravo",
                slug: "bravo",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "member",
                membershipStatus: "active",
                isActiveContext: false,
            ),
        ]

        let snapshots = [
            "acct-a": AccessSnapshotOut(
                accountUUID: "acct-a",
                accountName: "Alpha",
                accountType: "personal",
                membershipRole: "owner",
                products: [:],
            ),
            "acct-b": AccessSnapshotOut(
                accountUUID: "acct-b",
                accountName: "Bravo",
                accountType: "personal",
                membershipRole: "member",
                products: ["trainerlab": ProductAccessOut(enabled: true)],
            ),
        ]

        let apiClient = MockAccountAPIClient(accounts: accounts, accessSnapshotsByAccountUUID: snapshots)
        let accountContext = SelectedAccountContext(accountUUID: "acct-a")
        let store = AccountSessionStore(
            apiClient: apiClient,
            baseURLProvider: { URL(string: "https://example.com")! },
            accountContext: accountContext,
            userDefaults: userDefaults,
        )

        try await store.bootstrapSession()
        try await store.switchAccount(to: "acct-b")

        XCTAssertEqual(store.currentAccount?.uuid, "acct-b")
        XCTAssertEqual(userDefaults.string(forKey: "medsim.selected-account.example.com.default"), "acct-b")
        XCTAssertEqual(store.productAccess(code: "trainerlab")?.enabled, true)
    }

    func testSwitchAccountClearsStaleAccessSnapshotWhenRefreshFails() async throws {
        let suiteName = "AccountSessionStoreTests.switch-error.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let accounts = [
            AccountOut(
                uuid: "acct-a",
                name: "Alpha",
                slug: "alpha",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "owner",
                membershipStatus: "active",
                isActiveContext: true,
            ),
            AccountOut(
                uuid: "acct-b",
                name: "Bravo",
                slug: "bravo",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "member",
                membershipStatus: "active",
                isActiveContext: false,
            ),
        ]

        let snapshots = [
            "acct-a": AccessSnapshotOut(
                accountUUID: "acct-a",
                accountName: "Alpha",
                accountType: "personal",
                membershipRole: "owner",
                products: ["chatlab": ProductAccessOut(enabled: true)],
            ),
        ]

        let apiClient = MockAccountAPIClient(accounts: accounts, accessSnapshotsByAccountUUID: snapshots)
        apiClient.accessErrorByAccountUUID["acct-b"] = APIClientError.http(
            statusCode: 503,
            detail: "Temporary outage",
            correlationID: nil,
        )
        let accountContext = SelectedAccountContext(accountUUID: "acct-a")
        let store = AccountSessionStore(
            apiClient: apiClient,
            baseURLProvider: { URL(string: "https://example.com")! },
            accountContext: accountContext,
            userDefaults: userDefaults,
        )

        try await store.bootstrapSession()

        do {
            try await store.switchAccount(to: "acct-b")
            XCTFail("Expected switchAccount to surface the access snapshot failure")
        } catch {}

        XCTAssertEqual(store.selectedAccountUUID, "acct-b")
        XCTAssertEqual(store.currentAccount?.uuid, "acct-b")
        XCTAssertNil(store.accessSnapshot)
        XCTAssertNil(store.productAccess(code: "chatlab"))
        let selectedFromContext = await accountContext.selectedAccountUUID()
        XCTAssertEqual(selectedFromContext, "acct-b")
    }

    func testRetryPendingSyncRequiresOriginalAccountContext() async throws {
        let suiteName = "AccountSessionStoreTests.billing-retry.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let accounts = [
            AccountOut(
                uuid: "acct-a",
                name: "Alpha",
                slug: "alpha",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "owner",
                membershipStatus: "active",
                isActiveContext: true,
            ),
            AccountOut(
                uuid: "acct-b",
                name: "Bravo",
                slug: "bravo",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "member",
                membershipStatus: "active",
                isActiveContext: false,
            ),
        ]

        let snapshots = [
            "acct-a": AccessSnapshotOut(
                accountUUID: "acct-a",
                accountName: "Alpha",
                accountType: "personal",
                membershipRole: "owner",
                products: [:],
            ),
            "acct-b": AccessSnapshotOut(
                accountUUID: "acct-b",
                accountName: "Bravo",
                accountType: "personal",
                membershipRole: "member",
                products: [:],
            ),
        ]

        let apiClient = MockAccountAPIClient(accounts: accounts, accessSnapshotsByAccountUUID: snapshots)
        let accountContext = SelectedAccountContext(accountUUID: "acct-a")
        let store = AccountSessionStore(
            apiClient: apiClient,
            baseURLProvider: { URL(string: "https://example.com")! },
            accountContext: accountContext,
            userDefaults: userDefaults,
        )
        let billingService = AppleBillingService(
            apiClient: apiClient,
            accountSessionStore: store,
        )

        try await store.bootstrapSession()
        billingService.storePendingSyncRetry(
            [
                AppleBillingSyncRequest(
                    transactionID: "tx-1",
                    originalTransactionID: "orig-1",
                    productID: "com.jackfruitco.medsim.one.monthly",
                    status: "active",
                    purchaseDate: Date(timeIntervalSince1970: 1_710_000_000),
                    expiresDate: nil,
                    endedAt: nil,
                    metadata: [:],
                ),
            ],
            accountUUID: "acct-a",
        )

        try await store.switchAccount(to: "acct-b")
        await billingService.retryPendingSync()

        XCTAssertTrue(apiClient.billingSyncCalls.isEmpty)
        XCTAssertTrue(billingService.hasPendingSyncRetry)
        XCTAssertEqual(
            billingService.syncErrorMessage,
            "Switch back to Alpha before retrying App Store sync.",
        )
    }

    func testAppleBillingSyncRequestEncodesExpectedKeys() throws {
        let request = AppleBillingSyncRequest(
            transactionID: "tx-1",
            originalTransactionID: "orig-1",
            productID: "com.jackfruitco.medsim.one.monthly",
            status: "active",
            purchaseDate: Date(timeIntervalSince1970: 1_710_000_000),
            expiresDate: Date(timeIntervalSince1970: 1_712_592_000),
            endedAt: nil,
            metadata: ["source": .string("ios_storekit2")],
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(payload?["transaction_id"] as? String, "tx-1")
        XCTAssertEqual(payload?["original_transaction_id"] as? String, "orig-1")
        XCTAssertEqual(payload?["product_id"] as? String, "com.jackfruitco.medsim.one.monthly")
        XCTAssertEqual(payload?["status"] as? String, "active")
        XCTAssertNotNil(payload?["purchase_date"])
        XCTAssertNotNil(payload?["expires_date"])
        XCTAssertNil(payload?["ended_at"])
    }

    func testCanonicalTrainerAndChatLabProductsEnableExpectedLabs() async throws {
        let cases: [(LabProductAccess, String)] = [
            (.trainerLab, "trainerlab_go"),
            (.trainerLab, "trainerlab_plus"),
            (.chatLab, "chatlab_go"),
            (.chatLab, "chatlab_plus"),
        ]

        for (lab, productCode) in cases {
            let store = makeStore(products: [productCode: ProductAccessOut(enabled: true)])

            try await store.bootstrapSession()

            XCTAssertTrue(store.isLabEnabled(lab), "Expected \(productCode) to enable \(lab)")
        }
    }

    func testMedsimProductsEnableBothLabs() async throws {
        let productCodes = ["medsim_one", "medsim_one_plus"]

        for productCode in productCodes {
            let store = makeStore(products: [productCode: ProductAccessOut(enabled: true)])

            try await store.bootstrapSession()

            XCTAssertTrue(store.isLabEnabled(.trainerLab), "Expected \(productCode) to enable TrainerLab")
            XCTAssertTrue(store.isLabEnabled(.chatLab), "Expected \(productCode) to enable ChatLab")
        }
    }

    func testLabAccessMessageReturnsExpectedStates() async throws {
        let loadingAccounts = [
            AccountOut(
                uuid: "acct-a",
                name: "Alpha",
                slug: "alpha",
                accountType: "personal",
                isActive: true,
                requiresJoinApproval: false,
                parentAccountUUID: nil,
                membershipRole: "owner",
                membershipStatus: "active",
                isActiveContext: true,
            ),
        ]
        let loadingSnapshot = AccessSnapshotOut(
            accountUUID: "acct-a",
            accountName: "Alpha",
            accountType: "personal",
            membershipRole: "owner",
            products: [:],
        )
        let loadingAPIClient = BlockingBootstrapAPIClient(accounts: loadingAccounts, snapshot: loadingSnapshot)
        let loadingStore = AccountSessionStore(
            apiClient: loadingAPIClient,
            baseURLProvider: { URL(string: "https://example.com")! },
            accountContext: SelectedAccountContext(accountUUID: "acct-a"),
            userDefaults: UserDefaults(suiteName: "AccountSessionStoreTests.loading.\(UUID().uuidString)")!,
        )
        let bootstrapTask = Task {
            try await loadingStore.bootstrapSession()
        }

        await loadingAPIClient.waitUntilBootstrapStarts()
        XCTAssertEqual(loadingStore.labAccessMessage(.trainerLab), "Loading account access...")
        await loadingAPIClient.resumeBootstrap()
        try await bootstrapTask.value

        let noAccountStore = makeStore(products: [:])
        XCTAssertEqual(noAccountStore.labAccessMessage(.trainerLab), "Select an account to continue.")

        let unavailableStore = makeStore(products: [:])
        try await unavailableStore.bootstrapSession()
        XCTAssertEqual(unavailableStore.labAccessMessage(.trainerLab), "Unavailable for Alpha.")

        let disabledStore = makeStore(products: ["trainerlab_go": ProductAccessOut(enabled: false)])
        try await disabledStore.bootstrapSession()
        XCTAssertEqual(disabledStore.labAccessMessage(.trainerLab), "Not included for Alpha.")

        let enabledStore = makeStore(products: ["trainerlab_plus": ProductAccessOut(enabled: true)])
        try await enabledStore.bootstrapSession()
        XCTAssertNil(enabledStore.labAccessMessage(.trainerLab))
    }

    func testLegacyLabCodesDoNotEnableLabAccess() async throws {
        let store = makeStore(
            products: [
                "trainerlab": ProductAccessOut(enabled: true),
                "chatlab": ProductAccessOut(enabled: true),
            ],
        )

        try await store.bootstrapSession()

        XCTAssertFalse(store.isLabEnabled(.trainerLab))
        XCTAssertFalse(store.isLabEnabled(.chatLab))
        XCTAssertEqual(store.labAccessMessage(.trainerLab), "Unavailable for Alpha.")
        XCTAssertEqual(store.labAccessMessage(.chatLab), "Unavailable for Alpha.")
    }
}
