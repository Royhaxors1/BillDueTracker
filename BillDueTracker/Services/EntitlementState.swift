import Foundation
import StoreKit

@MainActor
final class EntitlementState: ObservableObject {
    @Published private(set) var tier: SubscriptionTier = .free
    @Published private(set) var renewalDate: Date?
    @Published private(set) var lastUpdatedAt: Date = .now
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var hasLoadedProducts = false
    @Published private(set) var lastErrorMessage: String?

    private var productsByPlan: [SubscriptionPlan: Product] = [:]

    private let defaults: UserDefaults
    private var transactionUpdatesTask: Task<Void, Never>?

    private enum Keys {
        static let tier = "subscription.tier"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadPersistedTier()
        startTransactionListener()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var isPro: Bool {
        tier == .pro
    }

    var hasAnyAvailablePlan: Bool {
        if isUITestMode {
            return true
        }
        return !productsByPlan.isEmpty
    }

    func refresh() async {
        if isUITestMode {
            applyUITestOverrides()
            hasLoadedProducts = true
            lastUpdatedAt = .now
            return
        }

        await loadProductsIfNeeded()
        await syncTierFromTransactions()
        lastUpdatedAt = .now
    }

    func hasAccess(to feature: BillFeature) -> Bool {
        UsageLimitService.canUse(feature, tier: tier)
    }

    func priceLabel(for plan: SubscriptionPlan) -> String {
        if let product = productsByPlan[plan] {
            return "\(product.displayPrice) / \(plan == .annualPro ? "year" : "month")"
        }
        return plan.fallbackPriceLabel
    }

    func isPlanAvailable(_ plan: SubscriptionPlan) -> Bool {
        if isUITestMode {
            return true
        }
        return productsByPlan[plan] != nil
    }

    func purchase(plan: SubscriptionPlan) async throws {
        if isUITestMode {
            setTier(.pro, persist: false)
            return
        }

        if productsByPlan[plan] == nil {
            await loadProductsIfNeeded(force: true)
        }

        guard let product = productsByPlan[plan] else {
            throw EntitlementError.productUnavailable(lastErrorMessage)
        }

        let purchaseResult = try await product.purchase()
        switch purchaseResult {
        case let .success(verification):
            let transaction = try verifiedTransaction(verification)
            await transaction.finish()
            await syncTierFromTransactions()
        case .pending:
            throw EntitlementError.pending
        case .userCancelled:
            throw EntitlementError.userCancelled
        @unknown default:
            throw EntitlementError.unknown
        }
    }

    func restorePurchases() async throws {
        if isUITestMode {
            applyUITestOverrides()
            return
        }

        do {
            try await AppStore.sync()
            await syncTierFromTransactions()
            if !isPro {
                throw EntitlementError.noActiveSubscription
            }
        } catch let entitlementError as EntitlementError {
            throw entitlementError
        } catch {
            throw EntitlementError.restoreFailed(error.localizedDescription)
        }
    }

    private func startTransactionListener() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task {
            guard !Task.isCancelled else { return }
            for await update in Transaction.updates {
                do {
                    let transaction = try verifiedTransaction(update)
                    await transaction.finish()
                    await syncTierFromTransactions()
                } catch {
                    if let entitlementError = error as? EntitlementError,
                       entitlementError == .userCancelled {
                        continue
                    }
                    lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadProductsIfNeeded(force: Bool = false) async {
        guard force || productsByPlan.isEmpty else { return }

        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            hasLoadedProducts = true
        }

        let expectedPlans = SubscriptionPlan.allCases
        let expectedProductIDs = expectedPlans.map(\.productID)

        do {
            let products = try await Product.products(for: expectedProductIDs)

            var mapped: [SubscriptionPlan: Product] = [:]
            for plan in expectedPlans {
                if let product = products.first(where: { $0.id == plan.productID }) {
                    mapped[plan] = product
                }
            }

            productsByPlan = mapped
            let missingIDs = expectedPlans
                .filter { mapped[$0] == nil }
                .map(\.productID)

            if missingIDs.isEmpty {
                lastErrorMessage = nil
            } else {
                let missingList = missingIDs.joined(separator: ", ")
                lastErrorMessage = "Subscription products are unavailable for this build. Confirm these product IDs are configured for this app in App Store Connect: \(missingList)."
            }
        } catch {
            productsByPlan = [:]
            lastErrorMessage = "Unable to load subscription products. Check network connection and App Store Connect product setup."
        }
    }

    private func syncTierFromTransactions() async {
        var hasActivePro = false
        var resolvedRenewalDate: Date?

        for await result in Transaction.currentEntitlements {
            guard subscriptionPlan(for: result) != nil else { continue }

            let transaction: Transaction
            switch result {
            case let .verified(value):
                transaction = value
            case .unverified:
                continue
            }

            if transaction.revocationDate != nil {
                continue
            }

            if let expirationDate = transaction.expirationDate,
               expirationDate <= .now {
                continue
            }

            hasActivePro = true
            if let expirationDate = transaction.expirationDate {
                if let existing = resolvedRenewalDate {
                    resolvedRenewalDate = max(existing, expirationDate)
                } else {
                    resolvedRenewalDate = expirationDate
                }
            }
        }

        renewalDate = resolvedRenewalDate
        setTier(hasActivePro ? .pro : .free)
        lastErrorMessage = nil
    }

    private func subscriptionPlan(for result: VerificationResult<Transaction>) -> SubscriptionPlan? {
        switch result {
        case let .verified(transaction):
            return SubscriptionPlan.allCases.first(where: { $0.productID == transaction.productID })
        case .unverified:
            return nil
        }
    }

    private func verifiedTransaction(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case let .verified(transaction):
            return transaction
        case .unverified:
            throw EntitlementError.verificationFailed
        }
    }

    private func loadPersistedTier() {
        let environment = ProcessInfo.processInfo.environment
        if environment["UITEST_RESET"] == "1" {
            defaults.removeObject(forKey: Keys.tier)
        }

        if environment["UITEST_FORCE_PRO"] == "1" {
            setTier(.pro, persist: false)
            return
        }

        if let rawTier = defaults.string(forKey: Keys.tier),
           let resolvedTier = SubscriptionTier(rawValue: rawTier) {
            tier = resolvedTier
        } else {
            tier = .free
        }
    }

    private func applyUITestOverrides() {
        if ProcessInfo.processInfo.environment["UITEST_FORCE_PRO"] == "1" {
            setTier(.pro, persist: false)
        } else {
            setTier(.free, persist: false)
        }
        renewalDate = nil
        hasLoadedProducts = true
        lastErrorMessage = nil
    }

    private func setTier(_ newTier: SubscriptionTier, persist: Bool = true) {
        tier = newTier
        if persist {
            defaults.set(newTier.rawValue, forKey: Keys.tier)
        }
        lastUpdatedAt = .now
    }

    private var isUITestMode: Bool {
        ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
    }
}

enum EntitlementError: LocalizedError, Equatable {
    case productUnavailable(String?)
    case pending
    case userCancelled
    case noActiveSubscription
    case verificationFailed
    case restoreFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case let .productUnavailable(detail):
            return detail ?? "Subscription product is unavailable right now."
        case .pending:
            return "Purchase is pending approval."
        case .userCancelled:
            return "Purchase was cancelled."
        case .noActiveSubscription:
            return "No active Pro subscription was found to restore for this Apple Account."
        case .verificationFailed:
            return "Unable to verify purchase transaction."
        case let .restoreFailed(message):
            return "Restore failed: \(message)"
        case .unknown:
            return "Unknown purchase result."
        }
    }
}
