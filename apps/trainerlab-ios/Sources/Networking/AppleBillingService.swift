import Foundation
import SharedModels
import StoreKit

public enum BillingProductGroup: String, CaseIterable, Identifiable, Sendable {
    case chatLab
    case trainerLab
    case medsimOne

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .chatLab:
            "ChatLab"
        case .trainerLab:
            "TrainerLab"
        case .medsimOne:
            "MedSim One"
        }
    }
}

public struct BillingCatalogEntry: Identifiable, Equatable, Sendable {
    public let productID: String
    public let group: BillingProductGroup
    public let title: String
    public let subtitle: String
    public let price: String
    public let isAvailable: Bool

    public var id: String {
        productID
    }
}

private struct BillingCatalogDescriptor: Sendable {
    let productID: String
    let group: BillingProductGroup
    let fallbackTitle: String
    let fallbackSubtitle: String
}

@MainActor
public final class AppleBillingService: ObservableObject {
    @Published public private(set) var catalogEntries: [BillingCatalogEntry]
    @Published public private(set) var isLoadingProducts = false
    @Published public private(set) var isProcessing = false
    @Published public private(set) var catalogErrorMessage: String?
    @Published public private(set) var syncErrorMessage: String?
    @Published public private(set) var hasPendingSyncRetry = false

    private let apiClient: APIClientProtocol
    private let accountSessionStore: AccountSessionStore
    private let catalog: [BillingCatalogDescriptor]
    private let encoder: JSONEncoder
    private var productsByID: [String: Product] = [:]
    private var pendingSyncRequests: [AppleBillingSyncRequest] = []

    public init(
        apiClient: APIClientProtocol,
        accountSessionStore: AccountSessionStore,
    ) {
        self.apiClient = apiClient
        self.accountSessionStore = accountSessionStore
        let descriptors = Self.defaultCatalog
        self.catalog = descriptors
        self.catalogEntries = Self.makeFallbackEntries(from: descriptors)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func entries(for group: BillingProductGroup) -> [BillingCatalogEntry] {
        catalogEntries.filter { $0.group == group }
    }

    public func loadProductsIfNeeded() async {
        guard productsByID.isEmpty else { return }
        await reloadProducts()
    }

    public func reloadProducts() async {
        isLoadingProducts = true
        catalogErrorMessage = nil
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: catalog.map(\.productID))
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            catalogEntries = catalog.map { descriptor in
                if let product = productsByID[descriptor.productID] {
                    return BillingCatalogEntry(
                        productID: descriptor.productID,
                        group: descriptor.group,
                        title: product.displayName,
                        subtitle: product.description,
                        price: product.displayPrice,
                        isAvailable: true,
                    )
                }
                return BillingCatalogEntry(
                    productID: descriptor.productID,
                    group: descriptor.group,
                    title: descriptor.fallbackTitle,
                    subtitle: descriptor.fallbackSubtitle,
                    price: "Unavailable",
                    isAvailable: false,
                )
            }
        } catch {
            catalogErrorMessage = error.localizedDescription
            catalogEntries = Self.makeFallbackEntries(from: catalog)
        }
    }

    public func purchase(productID: String) async {
        guard let product = productsByID[productID] else {
            syncErrorMessage = "This App Store product is not available yet."
            return
        }

        isProcessing = true
        syncErrorMessage = nil
        defer { isProcessing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                let transaction = try requireVerified(verification)
                let request = makeSyncRequest(from: transaction)
                let syncError = await syncRequestsHandlingError([request])
                await transaction.finish()
                if let syncError {
                    pendingSyncRequests = [request]
                    hasPendingSyncRetry = true
                    syncErrorMessage = syncError.localizedDescription
                    return
                }
                pendingSyncRequests = []
                hasPendingSyncRetry = false
                try await accountSessionStore.refreshAfterBillingSync()
            case .pending:
                syncErrorMessage = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                syncErrorMessage = "The App Store returned an unsupported purchase result."
            }
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }

    public func restorePurchases() async {
        isProcessing = true
        syncErrorMessage = nil
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
            let transactions = try await currentVerifiedEntitlements()
            guard !transactions.isEmpty else {
                hasPendingSyncRetry = false
                pendingSyncRequests = []
                syncErrorMessage = "No active App Store purchases were found to restore."
                return
            }

            let requests = transactions.map(makeSyncRequest(from:))
            let syncError = await syncRequestsHandlingError(requests)
            for transaction in transactions {
                await transaction.finish()
            }

            if let syncError {
                pendingSyncRequests = requests
                hasPendingSyncRetry = true
                syncErrorMessage = syncError.localizedDescription
                return
            }

            pendingSyncRequests = []
            hasPendingSyncRetry = false
            try await accountSessionStore.refreshAfterBillingSync()
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }

    public func retryPendingSync() async {
        guard !pendingSyncRequests.isEmpty else { return }

        isProcessing = true
        syncErrorMessage = nil
        defer { isProcessing = false }

        if let syncError = await syncRequestsHandlingError(pendingSyncRequests) {
            syncErrorMessage = syncError.localizedDescription
            hasPendingSyncRetry = true
            return
        }

        pendingSyncRequests = []
        hasPendingSyncRetry = false

        do {
            try await accountSessionStore.refreshAfterBillingSync()
        } catch {
            syncErrorMessage = error.localizedDescription
        }
    }

    private func syncRequestsHandlingError(_ requests: [AppleBillingSyncRequest]) async -> Error? {
        do {
            try await syncRequests(requests)
            return nil
        } catch {
            return error
        }
    }

    private func syncRequests(_ requests: [AppleBillingSyncRequest]) async throws {
        for request in requests {
            let body = try encoder.encode(request)
            let _: EmptyResponse = try await apiClient.request(
                BillingAPI.appleSync(body: body),
                as: EmptyResponse.self,
            )
        }
    }

    private func currentVerifiedEntitlements() async throws -> [Transaction] {
        var transactions: [Transaction] = []
        for await verification in Transaction.currentEntitlements {
            let transaction = try requireVerified(verification)
            transactions.append(transaction)
        }
        return transactions
    }

    private func requireVerified<T>(_ verification: VerificationResult<T>) throws -> T {
        switch verification {
        case let .verified(value):
            value
        case .unverified(_, _):
            throw APIClientError.decoding("StoreKit transaction verification failed.")
        }
    }

    private func makeSyncRequest(from transaction: Transaction) -> AppleBillingSyncRequest {
        let expirationDate = transaction.expirationDate
        let revokedAt = transaction.revocationDate
        let now = Date()
        let status: String
        if revokedAt != nil {
            status = "revoked"
        } else if let expirationDate, expirationDate < now {
            status = "expired"
        } else {
            status = "active"
        }

        let group = catalog.first(where: { $0.productID == transaction.productID })?.group

        return AppleBillingSyncRequest(
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            productID: transaction.productID,
            status: status,
            purchaseDate: transaction.purchaseDate,
            expiresDate: expirationDate,
            endedAt: revokedAt ?? (status == "expired" ? expirationDate : nil),
            metadata: [
                "source": .string("ios_storekit2"),
                "product_group": .string(group?.rawValue ?? "unknown"),
                "environment": .string(String(describing: transaction.environment)),
                "ownership_type": .string(String(describing: transaction.ownershipType)),
            ],
        )
    }

    private static func makeFallbackEntries(from catalog: [BillingCatalogDescriptor]) -> [BillingCatalogEntry] {
        catalog.map { descriptor in
            BillingCatalogEntry(
                productID: descriptor.productID,
                group: descriptor.group,
                title: descriptor.fallbackTitle,
                subtitle: descriptor.fallbackSubtitle,
                price: "Unavailable",
                isAvailable: false,
            )
        }
    }

    private static let defaultCatalog: [BillingCatalogDescriptor] = [
        BillingCatalogDescriptor(
            productID: "com.jackfruitco.medsim.chatlab.go.monthly",
            group: .chatLab,
            fallbackTitle: "ChatLab Go Monthly",
            fallbackSubtitle: "Monthly ChatLab Go subscription",
        ),
        BillingCatalogDescriptor(
            productID: "com.jackfruitco.medsim.chatlab.plus.monthly",
            group: .chatLab,
            fallbackTitle: "ChatLab Plus Monthly",
            fallbackSubtitle: "Monthly ChatLab Plus subscription",
        ),
        BillingCatalogDescriptor(
            productID: "com.jackfruitco.medsim.trainerlab.go.monthly",
            group: .trainerLab,
            fallbackTitle: "TrainerLab Go Monthly",
            fallbackSubtitle: "Monthly TrainerLab Go subscription",
        ),
        BillingCatalogDescriptor(
            productID: "com.jackfruitco.medsim.trainerlab.plus.monthly",
            group: .trainerLab,
            fallbackTitle: "TrainerLab Plus Monthly",
            fallbackSubtitle: "Monthly TrainerLab Plus subscription",
        ),
        BillingCatalogDescriptor(
            productID: "com.jackfruitco.medsim.one.monthly",
            group: .medsimOne,
            fallbackTitle: "MedSim One Monthly",
            fallbackSubtitle: "Monthly MedSim One subscription",
        ),
        BillingCatalogDescriptor(
            productID: "com.jackfruitco.medsim.one.plus.monthly",
            group: .medsimOne,
            fallbackTitle: "MedSim One Plus Monthly",
            fallbackSubtitle: "Monthly MedSim One Plus subscription",
        ),
    ]
}
