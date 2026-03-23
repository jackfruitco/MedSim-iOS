import Foundation
import Networking
import SharedModels
import XCTest

private final class MockAccountAPIClient: APIClientProtocol, @unchecked Sendable {
    var accounts: [AccountOut]
    var accessSnapshotsByAccountUUID: [String: AccessSnapshotOut]
    var selectedAccountUUID: String?
    private(set) var selectCalls: [String] = []

    init(accounts: [AccountOut], accessSnapshotsByAccountUUID: [String: AccessSnapshotOut], selectedAccountUUID: String? = nil) {
        self.accounts = accounts
        self.accessSnapshotsByAccountUUID = accessSnapshotsByAccountUUID
        self.selectedAccountUUID = selectedAccountUUID ?? accounts.first(where: \.isActiveContext)?.uuid
    }

    func request<T: Decodable & Sendable>(_ endpoint: Endpoint, as _: T.Type) async throws -> T {
        switch endpoint.path {
        case "/api/v1/accounts/":
            return accounts as! T
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
            return EmptyResponse() as! T
        case "/api/v1/accounts/me/access/":
            guard let selectedAccountUUID,
                  let snapshot = accessSnapshotsByAccountUUID[selectedAccountUUID]
            else {
                throw APIClientError.http(statusCode: 404, detail: "Missing access snapshot", correlationID: nil)
            }
            return snapshot as! T
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

private struct AccountSelectionPayload: Decodable {
    let accountUUID: String

    enum CodingKeys: String, CodingKey {
        case accountUUID = "account_uuid"
    }
}

@MainActor
final class AccountSessionStoreTests: XCTestCase {
    func testBootstrapUsesPersistedSelectionAndRefreshesAccessSnapshot() async throws {
        let suiteName = "AccountSessionStoreTests.bootstrap.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
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
        let userDefaults = UserDefaults(suiteName: suiteName)!
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
}
