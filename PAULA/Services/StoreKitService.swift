import Foundation
import StoreKit

// MARK: - Product IDs (must match App Store Connect)
enum PAULAProduct: String, CaseIterable {
    case proMonthly   = "com.paula.app.pro.monthly"
    case proAnnual    = "com.paula.app.pro.annual"
    case unlimited    = "com.paula.app.unlimited.annual"

    var displayName: String {
        switch self {
        case .proMonthly: return "Pro Monthly"
        case .proAnnual:  return "Pro Annual"
        case .unlimited:  return "Unlimited"
        }
    }
}

/// Subscription tier — determines feature access.
enum SubscriptionTier: Int, Comparable {
    case free    = 0
    case pro     = 1
    case unlimited = 2

    var monthlyMinutes: Int {
        switch self {
        case .free:      return 300
        case .pro:       return 1200
        case .unlimited: return Int.max
        }
    }

    var displayName: String {
        switch self {
        case .free:      return "Free"
        case .pro:       return "Pro"
        case .unlimited: return "Unlimited"
        }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - StoreKit Service

@MainActor
final class StoreKitService: ObservableObject {

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false

    private var updateListenerTask: Task<Void, Never>?

    var currentTier: SubscriptionTier {
        if purchasedProductIDs.contains(PAULAProduct.unlimited.rawValue) { return .unlimited }
        if purchasedProductIDs.contains(PAULAProduct.proAnnual.rawValue)  { return .pro }
        if purchasedProductIDs.contains(PAULAProduct.proMonthly.rawValue) { return .pro }
        return .free
    }

    init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshPurchasedProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load products

    func loadProducts() async {
        isLoading = true
        do {
            let ids = PAULAProduct.allCases.map(\.rawValue)
            products = try await Product.products(for: ids)
                .sorted { $0.price < $1.price }
        } catch {
            print("StoreKit: failed to load products — \(error)")
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
        } catch {
            print("StoreKit: restore failed — \(error)")
        }
        isLoading = false
    }

    // MARK: - Internal

    private func refreshPurchasedProducts() async {
        await updatePurchasedProducts()
    }

    private func updatePurchasedProducts() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        purchasedProductIDs = ids
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }
}
