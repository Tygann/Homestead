import Foundation
import Observation
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
        expirationDate: Date?,
        revocationDate: Date?,
        isIntroductoryOffer: Bool,
        subscriptionStatusGrantsAccess: Bool? = nil
    ) {
        self.productID = productID
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
        if let annual = active.first(where: { $0.productID == HomesteadPlusProduct.annual.rawValue }) {
            return annual.isIntroductoryOffer ? .trial : .annual
        }
        if active.contains(where: { $0.productID == HomesteadPlusProduct.monthly.rawValue }) {
            return .monthly
        }
        return .free
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

@MainActor
@Observable
final class HomesteadEntitlementStore {
    private(set) var plan: HomesteadPlusPlan
    private(set) var purchaseState: HomesteadPurchaseState
    private(set) var availableProducts: [Product]
    private(set) var isEligibleForAnnualTrial: Bool?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let usesStoreKit: Bool

    var hasPlus: Bool { plan.hasPlus }
    var statusTitle: String { plan.displayName }

    init(
        previewPlan: HomesteadPlusPlan? = nil,
        previewAnnualTrialEligibility: Bool? = nil,
        purchaseState: HomesteadPurchaseState = .loading
    ) {
        plan = previewPlan ?? .free
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
                    if case .verified(let transaction) = result {
                        await self.refreshEntitlements()
                        await transaction.finish()
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

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  HomesteadPlusProduct.allIDs.contains(transaction.productID) else {
                continue
            }
            verifiedByProductID[transaction.productID] = HomesteadVerifiedEntitlement(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                revocationDate: transaction.revocationDate,
                isIntroductoryOffer: transaction.offer?.type == .introductory
            )
        }

        // Subscription status carries grace-period state that cannot be inferred
        // reliably from a transaction's expiration date alone.
        for product in availableProducts {
            guard let subscription = product.subscription,
                  let statuses = try? await subscription.status else {
                continue
            }
            for status in statuses {
                guard case .verified(let transaction) = status.transaction,
                      HomesteadPlusProduct.allIDs.contains(transaction.productID) else {
                    continue
                }
                let grantsAccess = switch status.state {
                case .subscribed, .inGracePeriod: true
                case .expired, .inBillingRetryPeriod, .revoked: false
                default: false
                }
                verifiedByProductID[transaction.productID] = HomesteadVerifiedEntitlement(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    revocationDate: transaction.revocationDate,
                    isIntroductoryOffer: transaction.offer?.type == .introductory,
                    subscriptionStatusGrantsAccess: grantsAccess
                )
            }
        }

        plan = HomesteadEntitlementResolver.plan(from: Array(verifiedByProductID.values))
        publishExtensionEntitlement()
    }

    func purchase(_ product: Product) async {
        guard usesStoreKit else { return }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    purchaseState = .failed("The App Store could not verify this purchase.")
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
                purchaseState = .available
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .available
            @unknown default:
                purchaseState = .failed("The App Store returned an unknown purchase result.")
            }
        } catch {
            purchaseState = .failed("The purchase could not be completed. Please try again.")
        }
    }

    func restorePurchases() async {
        guard usesStoreKit else { return }
        purchaseState = .restoring
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = .available
        } catch {
            purchaseState = .failed("Purchases could not be restored. Please try again.")
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
