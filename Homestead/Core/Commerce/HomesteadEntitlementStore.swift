import Foundation
import Observation
import OSLog
import StoreKit
import WidgetKit

nonisolated enum HomesteadPlusPlan: String, Equatable, Sendable {
    case free
    case trial
    case monthly
    case annual
    case lifetime

    var displayName: String {
        switch self {
        case .free: "Free"
        case .trial: "Trial"
        case .monthly: "Monthly"
        case .annual: "Annual"
        case .lifetime: "Lifetime"
        }
    }

    var hasPlus: Bool { self != .free }
}

nonisolated enum HomesteadPurchaseState: Equatable, Sendable {
    case loading
    case available
    case purchasing
    case pending
    case restoring
    case unavailable(String)
    case failed(String)
}

nonisolated enum HomesteadPlusProduct: String, CaseIterable, Sendable {
    case monthly = "com.tyler.Homestead.plus.monthly"
    case annual = "com.tyler.Homestead.plus.annual"
    case lifetime = "com.tyler.Homestead.plus.lifetime"

    static let allIDs = Set(allCases.map(\.rawValue))
}

nonisolated struct HomesteadVerifiedEntitlement: Equatable, Sendable {
    let productID: String
    let purchaseDate: Date
    let expirationDate: Date?
    let revocationDate: Date?
    let isIntroductoryOffer: Bool
    let subscriptionStatusGrantsAccess: Bool?

    var isActive: Bool {
        guard revocationDate == nil else { return false }
        if let subscriptionStatusGrantsAccess {
            return subscriptionStatusGrantsAccess
        }
        return expirationDate.map { $0 > .now } != false
    }

    init(
        productID: String,
        purchaseDate: Date = .distantPast,
        expirationDate: Date?,
        revocationDate: Date?,
        isIntroductoryOffer: Bool,
        subscriptionStatusGrantsAccess: Bool? = nil
    ) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isIntroductoryOffer = isIntroductoryOffer
        self.subscriptionStatusGrantsAccess = subscriptionStatusGrantsAccess
    }
}

nonisolated enum HomesteadEntitlementResolver {
    static func plan(from entitlements: [HomesteadVerifiedEntitlement]) -> HomesteadPlusPlan {
        let active = entitlements.filter(\.isActive)
        if active.contains(where: { $0.productID == HomesteadPlusProduct.lifetime.rawValue }) {
            return .lifetime
        }
        return subscriptionPlan(from: active) ?? .free
    }

    static func subscriptionPlan(
        from entitlements: [HomesteadVerifiedEntitlement]
    ) -> HomesteadPlusPlan? {
        let subscription = entitlements
            .filter {
                $0.isActive && (
                    $0.productID == HomesteadPlusProduct.annual.rawValue
                        || $0.productID == HomesteadPlusProduct.monthly.rawValue
                )
            }
            .max {
                if $0.purchaseDate != $1.purchaseDate {
                    return $0.purchaseDate < $1.purchaseDate
                }
                return ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture)
            }

        switch subscription?.productID {
        case HomesteadPlusProduct.annual.rawValue:
            return subscription?.isIntroductoryOffer == true ? .trial : .annual
        case HomesteadPlusProduct.monthly.rawValue:
            return .monthly
        default:
            return nil
        }
    }
}

nonisolated enum HomesteadEntitlementMergePolicy {
    static func merge(
        _ candidate: HomesteadVerifiedEntitlement,
        into entitlements: inout [String: HomesteadVerifiedEntitlement]
    ) {
        guard let existing = entitlements[candidate.productID] else {
            entitlements[candidate.productID] = candidate
            return
        }

        // StoreKit can return more than one status for a subscription group.
        // Never let an older inactive status replace verified active access.
        if candidate.isActive || !existing.isActive {
            entitlements[candidate.productID] = candidate
        }
    }
}

nonisolated enum HomesteadStoreKitDiagnostics {
    static func userFacingMessage(_ message: String, error: any Error) -> String {
        let nsError = error as NSError
        return "\(message) (\(nsError.domain) \(nsError.code))"
    }
}

nonisolated enum HomesteadPlusCapabilityPolicy {
    static func canCreateDashboard(hasPlus: Bool, existingDashboardCount: Int) -> Bool {
        hasPlus || existingDashboardCount == 0
    }

    static func canAddServer(hasPlus: Bool, configuredServerCount: Int) -> Bool {
        hasPlus || configuredServerCount == 0
    }
}

nonisolated enum HomesteadPlusContinuationPolicy {
    static func consume<Action>(_ pendingAction: inout Action?, hasPlus: Bool) -> Action? {
        let action = pendingAction
        pendingAction = nil
        return hasPlus ? action : nil
    }
}

@MainActor
@Observable
final class HomesteadEntitlementStore {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.tyler.Homestead",
        category: "StoreKit"
    )

    private(set) var plan: HomesteadPlusPlan
    private(set) var activeSubscriptionPlan: HomesteadPlusPlan?
    private(set) var purchaseState: HomesteadPurchaseState
    private(set) var availableProducts: [Product]
    private(set) var isEligibleForAnnualTrial: Bool?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let usesStoreKit: Bool

    var hasPlus: Bool { plan.hasPlus }
    var statusTitle: String { plan.displayName }

    init(
        previewPlan: HomesteadPlusPlan? = nil,
        previewActiveSubscriptionPlan: HomesteadPlusPlan? = nil,
        previewAnnualTrialEligibility: Bool? = nil,
        purchaseState: HomesteadPurchaseState = .loading
    ) {
        plan = previewPlan ?? .free
        activeSubscriptionPlan = previewActiveSubscriptionPlan ?? previewPlan?.subscriptionPlan
        self.purchaseState = if previewPlan != nil, purchaseState == .loading {
            .available
        } else {
            purchaseState
        }
        availableProducts = []
        isEligibleForAnnualTrial = previewPlan == nil ? nil : (previewAnnualTrialEligibility ?? true)
        usesStoreKit = previewPlan == nil

        if usesStoreKit {
            updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    switch result {
                    case .verified(let transaction):
                        await self.refreshEntitlements()
                        await transaction.finish()
                    case .unverified(_, let error):
                        Self.logger.error(
                            "Transaction update verification failed: \(String(describing: error), privacy: .public)"
                        )
                        self.purchaseState = .failed(
                            HomesteadStoreKitDiagnostics.userFacingMessage(
                                "The App Store returned a purchase that could not be verified.",
                                error: error
                            )
                        )
                    }
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func prepare() async {
        guard usesStoreKit else { return }
        purchaseState = .loading
        do {
            let products = try await Product.products(for: HomesteadPlusProduct.allIDs)
            availableProducts = products.sorted(by: Self.productSort)
            if let annual = product(.annual), let subscription = annual.subscription {
                isEligibleForAnnualTrial = await subscription.isEligibleForIntroOffer
            } else {
                isEligibleForAnnualTrial = nil
            }
            await refreshEntitlements()
            purchaseState = products.isEmpty
                ? .unavailable("Homestead+ is not available from the App Store right now.")
                : .available
        } catch {
            isEligibleForAnnualTrial = nil
            await refreshEntitlements()
            purchaseState = .unavailable("The App Store could not load Homestead+. Please try again.")
        }
    }

    func refreshEntitlements() async {
        guard usesStoreKit else { return }
        var verifiedByProductID: [String: HomesteadVerifiedEntitlement] = [:]
        var activeSubscriptionStatusesByProductID: [String: HomesteadVerifiedEntitlement] = [:]

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard HomesteadPlusProduct.allIDs.contains(transaction.productID) else {
                    continue
                }
                HomesteadEntitlementMergePolicy.merge(
                    HomesteadVerifiedEntitlement(
                        productID: transaction.productID,
                        purchaseDate: transaction.purchaseDate,
                        expirationDate: transaction.expirationDate,
                        revocationDate: transaction.revocationDate,
                        isIntroductoryOffer: transaction.offer?.type == .introductory
                    ),
                    into: &verifiedByProductID
                )
            case .unverified(let transaction, let error):
                guard HomesteadPlusProduct.allIDs.contains(transaction.productID) else {
                    continue
                }
                Self.logger.error(
                    "Current entitlement verification failed for \(transaction.productID, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }

        // Subscription status carries grace-period state that cannot be inferred
        // reliably from a transaction's expiration date alone.
        for product in availableProducts {
            guard let subscription = product.subscription else {
                continue
            }

            do {
                for status in try await subscription.status {
                    switch status.transaction {
                    case .verified(let transaction):
                        guard HomesteadPlusProduct.allIDs.contains(transaction.productID) else {
                            continue
                        }
                        let grantsAccess = switch status.state {
                        case .subscribed, .inGracePeriod: true
                        case .expired, .inBillingRetryPeriod, .revoked: false
                        default: false
                        }
                        let entitlement = HomesteadVerifiedEntitlement(
                            productID: transaction.productID,
                            purchaseDate: transaction.purchaseDate,
                            expirationDate: transaction.expirationDate,
                            revocationDate: transaction.revocationDate,
                            isIntroductoryOffer: transaction.offer?.type == .introductory,
                            subscriptionStatusGrantsAccess: grantsAccess
                        )
                        HomesteadEntitlementMergePolicy.merge(
                            entitlement,
                            into: &verifiedByProductID
                        )
                        if grantsAccess {
                            HomesteadEntitlementMergePolicy.merge(
                                entitlement,
                                into: &activeSubscriptionStatusesByProductID
                            )
                        }
                    case .unverified(let transaction, let error):
                        Self.logger.error(
                            "Subscription status verification failed for \(transaction.productID, privacy: .public): \(String(describing: error), privacy: .public)"
                        )
                    }
                }
            } catch {
                Self.logger.error(
                    "Subscription status request failed for \(product.id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }

        let entitlements = Array(verifiedByProductID.values)
        let subscriptionEntitlements = activeSubscriptionStatusesByProductID.isEmpty
            ? entitlements
            : Array(activeSubscriptionStatusesByProductID.values)
        activeSubscriptionPlan = HomesteadEntitlementResolver.subscriptionPlan(
            from: subscriptionEntitlements
        )
        plan = entitlements.contains {
            $0.productID == HomesteadPlusProduct.lifetime.rawValue && $0.isActive
        } ? .lifetime : (activeSubscriptionPlan ?? .free)
        publishExtensionEntitlement()
    }

    func purchase(_ product: Product) async {
        guard usesStoreKit else { return }
        purchaseState = .purchasing
        do {
            await handlePurchaseResult(.success(try await product.purchase()))
        } catch {
            await handlePurchaseResult(.failure(error))
        }
    }

    func handlePurchaseResult(_ result: Result<Product.PurchaseResult, any Error>) async {
        guard usesStoreKit else { return }

        switch result {
        case .success(.success(let verificationResult)):
            switch verificationResult {
            case .verified(let transaction):
                let purchasedEntitlement = HomesteadVerifiedEntitlement(
                    productID: transaction.productID,
                    purchaseDate: transaction.purchaseDate,
                    expirationDate: transaction.expirationDate,
                    revocationDate: transaction.revocationDate,
                    isIntroductoryOffer: transaction.offer?.type == .introductory
                )
                await transaction.finish()
                await refreshEntitlements()
                if !hasPlus, purchasedEntitlement.isActive {
                    // The verified purchase itself is authoritative even if the
                    // current-entitlements sequence has not caught up yet.
                    plan = HomesteadEntitlementResolver.plan(from: [purchasedEntitlement])
                    activeSubscriptionPlan = HomesteadEntitlementResolver.subscriptionPlan(
                        from: [purchasedEntitlement]
                    )
                    publishExtensionEntitlement()
                }
                purchaseState = hasPlus
                    ? .available
                    : .failed("The purchase completed, but Homestead+ access was not returned by the App Store.")
            case .unverified(_, let error):
                Self.logger.error(
                    "Purchase verification failed: \(String(describing: error), privacy: .public)"
                )
                purchaseState = .failed(
                    HomesteadStoreKitDiagnostics.userFacingMessage(
                        "The App Store could not verify this purchase.",
                        error: error
                    )
                )
            }
        case .success(.pending):
            purchaseState = .pending
        case .success(.userCancelled):
            purchaseState = .available
        case .success:
            purchaseState = .failed("The App Store returned an unknown purchase result.")
        case .failure(let error):
            Self.logger.error(
                "Purchase request failed: \(String(describing: error), privacy: .public)"
            )
            purchaseState = .failed(
                HomesteadStoreKitDiagnostics.userFacingMessage(
                    "The purchase could not be completed.",
                    error: error
                )
            )
        }
    }

    func restorePurchases() async {
        guard usesStoreKit else { return }
        purchaseState = .restoring
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = hasPlus
                ? .available
                : .failed("No active Homestead+ purchase was found for this App Store account.")
        } catch {
            Self.logger.error(
                "App Store sync failed: \(String(describing: error), privacy: .public)"
            )

            // The receipt can already contain a valid entitlement even when the
            // explicit App Store synchronization request fails.
            await refreshEntitlements()
            purchaseState = hasPlus
                ? .available
                : .failed(
                    HomesteadStoreKitDiagnostics.userFacingMessage(
                        "Purchases could not be synchronized.",
                        error: error
                    )
                )
        }
    }

    func clearError() {
        if case .failed = purchaseState {
            purchaseState = availableProducts.isEmpty ? .loading : .available
        }
    }

    func product(_ product: HomesteadPlusProduct) -> Product? {
        availableProducts.first { $0.id == product.rawValue }
    }

    private func publishExtensionEntitlement() {
        HomesteadPlusEntitlementCache.save(hasPlus: hasPlus)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func productSort(_ lhs: Product, _ rhs: Product) -> Bool {
        let order = [
            HomesteadPlusProduct.annual.rawValue,
            HomesteadPlusProduct.monthly.rawValue,
            HomesteadPlusProduct.lifetime.rawValue
        ]
        return (order.firstIndex(of: lhs.id) ?? .max) < (order.firstIndex(of: rhs.id) ?? .max)
    }
}

private extension HomesteadPlusPlan {
    var subscriptionPlan: HomesteadPlusPlan? {
        switch self {
        case .trial, .monthly, .annual:
            self
        case .free, .lifetime:
            nil
        }
    }
}
