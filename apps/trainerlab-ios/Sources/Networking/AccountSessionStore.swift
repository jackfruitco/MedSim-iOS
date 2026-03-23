import Combine
import Foundation
import SharedModels

public protocol AuthSessionBootstrapper: Sendable {
    func bootstrapSession() async throws
    func clearSession() async
}

public actor SelectedAccountContext: AccountContextProvider {
    private var accountUUID: String?

    public init(accountUUID: String? = nil) {
        self.accountUUID = accountUUID
    }

    public func selectedAccountUUID() async -> String? {
        accountUUID
    }

    public func setSelectedAccountUUID(_ accountUUID: String?) {
        self.accountUUID = accountUUID
    }
}

private struct AccountSelectionRequest: Codable, Sendable {
    let accountUUID: String

    enum CodingKeys: String, CodingKey {
        case accountUUID = "account_uuid"
    }
}

@MainActor
public final class AccountSessionStore: ObservableObject, AuthSessionBootstrapper {
    @Published public private(set) var availableAccounts: [AccountOut] = []
    @Published public private(set) var accessSnapshot: AccessSnapshotOut?
    @Published public private(set) var selectedAccountUUID: String?
    @Published public private(set) var isBootstrapping = false
    @Published public private(set) var isSwitching = false
    @Published public private(set) var errorMessage: String?

    private let apiClient: APIClientProtocol
    private let baseURLProvider: () -> URL
    private let accountContext: SelectedAccountContext
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder

    public init(
        apiClient: APIClientProtocol,
        baseURLProvider: @escaping () -> URL,
        accountContext: SelectedAccountContext,
        userDefaults: UserDefaults = .standard,
    ) {
        self.apiClient = apiClient
        self.baseURLProvider = baseURLProvider
        self.accountContext = accountContext
        self.userDefaults = userDefaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public var currentAccount: AccountOut? {
        let resolvedUUID = accessSnapshot?.accountUUID ?? selectedAccountUUID
        guard let resolvedUUID else { return nil }
        return availableAccounts.first(where: { $0.uuid == resolvedUUID })
    }

    public var isCurrentAccountPersonal: Bool {
        (currentAccount?.accountType ?? accessSnapshot?.accountType ?? "").caseInsensitiveCompare("personal") == .orderedSame
    }

    public func productAccess(code: String) -> ProductAccessOut? {
        accessSnapshot?.products[code]
    }

    public func isProductEnabled(_ code: String) -> Bool {
        productAccess(code: code)?.enabled == true
    }

    public func hasFeature(_ feature: String, in productCode: String) -> Bool {
        guard let value = productAccess(code: productCode)?.features[feature] else {
            return false
        }
        switch value {
        case let .bool(enabled):
            enabled
        case let .number(number):
            number != 0
        case let .string(raw):
            ["1", "true", "yes", "enabled"].contains(raw.lowercased())
        default:
            false
        }
    }

    public func limit(_ key: String, in productCode: String) -> JSONValue? {
        productAccess(code: productCode)?.limits[key]
    }

    // Account-scoped backend checklist: bootstrap accounts, persist selection,
    // and refresh access after account switch or billing sync.
    public func bootstrapSession() async throws {
        isBootstrapping = true
        errorMessage = nil
        defer { isBootstrapping = false }

        do {
            try await reloadAccountsAndAccess(
                preferredAccountUUID: persistedSelectedAccountUUID(),
                alignBackendSelection: true,
            )
        } catch {
            clearLoadedState()
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func switchAccount(to accountUUID: String) async throws {
        guard accountUUID != selectedAccountUUID else { return }

        isSwitching = true
        errorMessage = nil
        defer { isSwitching = false }

        do {
            try await postAccountSelection(accountUUID: accountUUID)
            try await reloadAccountsAndAccess(
                preferredAccountUUID: accountUUID,
                alignBackendSelection: false,
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func refreshAccountsAndAccess() async throws {
        errorMessage = nil
        do {
            try await reloadAccountsAndAccess(
                preferredAccountUUID: selectedAccountUUID ?? persistedSelectedAccountUUID(),
                alignBackendSelection: false,
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func refreshAfterBillingSync() async throws {
        try await refreshAccountsAndAccess()
    }

    public func clearSession() async {
        clearLoadedState()
        clearPersistedSelection()
        await accountContext.setSelectedAccountUUID(nil)
    }

    private func reloadAccountsAndAccess(
        preferredAccountUUID: String?,
        alignBackendSelection: Bool,
    ) async throws {
        availableAccounts = try await fetchAccounts()

        guard !availableAccounts.isEmpty else {
            clearLoadedState()
            clearPersistedSelection()
            await accountContext.setSelectedAccountUUID(nil)
            return
        }

        guard let resolvedUUID = resolveSelectedAccountUUID(
            preferredAccountUUID: preferredAccountUUID,
            accounts: availableAccounts,
        ) else {
            clearLoadedState()
            clearPersistedSelection()
            await accountContext.setSelectedAccountUUID(nil)
            return
        }

        let backendActiveUUID = availableAccounts.first(where: \.isActiveContext)?.uuid
        if alignBackendSelection, backendActiveUUID != resolvedUUID {
            try await postAccountSelection(accountUUID: resolvedUUID)
            availableAccounts = try await fetchAccounts()
        }

        let effectiveUUID = availableAccounts.first(where: \.isActiveContext)?.uuid ?? resolvedUUID
        selectedAccountUUID = effectiveUUID
        persistSelectedAccountUUID(effectiveUUID)
        await accountContext.setSelectedAccountUUID(effectiveUUID)

        accessSnapshot = try await apiClient.request(AccountsAPI.accessSnapshot(), as: AccessSnapshotOut.self)

        if let snapshotUUID = accessSnapshot?.accountUUID, snapshotUUID != effectiveUUID {
            selectedAccountUUID = snapshotUUID
            persistSelectedAccountUUID(snapshotUUID)
            await accountContext.setSelectedAccountUUID(snapshotUUID)
        }
    }

    private func fetchAccounts() async throws -> [AccountOut] {
        try await apiClient.request(AccountsAPI.listAccounts(), as: [AccountOut].self)
    }

    private func postAccountSelection(accountUUID: String) async throws {
        let body = try encoder.encode(AccountSelectionRequest(accountUUID: accountUUID))
        let _: EmptyResponse = try await apiClient.request(
            AccountsAPI.selectAccount(body: body),
            as: EmptyResponse.self,
        )
    }

    private func resolveSelectedAccountUUID(
        preferredAccountUUID: String?,
        accounts: [AccountOut],
    ) -> String? {
        if let preferredAccountUUID,
           let preferred = accounts.first(where: { $0.uuid == preferredAccountUUID }),
           preferred.isActive
        {
            return preferred.uuid
        }

        if let activeContext = accounts.first(where: \.isActiveContext)?.uuid {
            return activeContext
        }

        if let firstActive = accounts.first(where: \.isActive)?.uuid {
            return firstActive
        }

        return accounts.first?.uuid
    }

    private func clearLoadedState() {
        availableAccounts = []
        accessSnapshot = nil
        selectedAccountUUID = nil
        errorMessage = nil
    }

    private func persistSelectedAccountUUID(_ accountUUID: String) {
        userDefaults.set(accountUUID, forKey: persistedSelectionKey())
    }

    private func persistedSelectedAccountUUID() -> String? {
        userDefaults.string(forKey: persistedSelectionKey())
    }

    private func clearPersistedSelection() {
        userDefaults.removeObject(forKey: persistedSelectionKey())
    }

    private func persistedSelectionKey() -> String {
        let baseURL = baseURLProvider()
        let host = baseURL.host() ?? baseURL.host ?? "unknown"
        let port = baseURL.port.map(String.init) ?? "default"
        return "medsim.selected-account.\(host).\(port)"
    }
}
