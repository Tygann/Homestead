import Foundation
import XCTest
@testable import Homestead

final class HomesteadPlusTests: XCTestCase {
    func testEntitlementResolverPrefersLifetime() {
        let plan = HomesteadEntitlementResolver.plan(from: [
            activeEntitlement(.monthly),
            activeEntitlement(.lifetime)
        ])

        XCTAssertEqual(plan, .lifetime)
    }

    func testEntitlementResolverRecognizesAnnualTrial() {
        let plan = HomesteadEntitlementResolver.plan(from: [
            activeEntitlement(.annual, isIntroductoryOffer: true)
        ])

        XCTAssertEqual(plan, .trial)
    }

    func testEntitlementResolverRejectsExpiredAndRevokedTransactions() {
        let plan = HomesteadEntitlementResolver.plan(from: [
            HomesteadVerifiedEntitlement(
                productID: HomesteadPlusProduct.annual.rawValue,
                expirationDate: .now.addingTimeInterval(-60),
                revocationDate: nil,
                isIntroductoryOffer: false
            ),
            HomesteadVerifiedEntitlement(
                productID: HomesteadPlusProduct.lifetime.rawValue,
                expirationDate: nil,
                revocationDate: .now,
                isIntroductoryOffer: false
            )
        ])

        XCTAssertEqual(plan, .free)
    }

    func testEntitlementResolverHonorsGracePeriodAndBillingRetryState() {
        let gracePlan = HomesteadEntitlementResolver.plan(from: [
            HomesteadVerifiedEntitlement(
                productID: HomesteadPlusProduct.annual.rawValue,
                expirationDate: .now.addingTimeInterval(-60),
                revocationDate: nil,
                isIntroductoryOffer: false,
                subscriptionStatusGrantsAccess: true
            )
        ])
        let billingRetryPlan = HomesteadEntitlementResolver.plan(from: [
            HomesteadVerifiedEntitlement(
                productID: HomesteadPlusProduct.annual.rawValue,
                expirationDate: .now.addingTimeInterval(60),
                revocationDate: nil,
                isIntroductoryOffer: false,
                subscriptionStatusGrantsAccess: false
            )
        ])

        XCTAssertEqual(gracePlan, .annual)
        XCTAssertEqual(billingRetryPlan, .free)
    }

    func testDashboardPolicyGrandfathersExistingDashboardsWithoutAllowingCreation() {
        XCTAssertFalse(HomesteadPlusCapabilityPolicy.canCreateDashboard(
            hasPlus: false,
            existingDashboardCount: 1
        ))
        XCTAssertFalse(HomesteadPlusCapabilityPolicy.canCreateDashboard(
            hasPlus: false,
            existingDashboardCount: 3
        ))
        XCTAssertTrue(HomesteadPlusCapabilityPolicy.canCreateDashboard(
            hasPlus: true,
            existingDashboardCount: 3
        ))
    }

    func testServerPolicyAllowsFirstServerButRequiresPlusForAnother() {
        XCTAssertTrue(HomesteadPlusCapabilityPolicy.canAddServer(
            hasPlus: false,
            configuredServerCount: 0
        ))
        XCTAssertFalse(HomesteadPlusCapabilityPolicy.canAddServer(
            hasPlus: false,
            configuredServerCount: 1
        ))
        XCTAssertTrue(HomesteadPlusCapabilityPolicy.canAddServer(
            hasPlus: true,
            configuredServerCount: 1
        ))
    }

    func testExtensionCacheRequiresFreshVerifiedPlusAccess() throws {
        let suiteName = "HomesteadPlusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date()

        HomesteadPlusEntitlementCache.save(hasPlus: true, verifiedAt: now, defaults: defaults)
        XCTAssertTrue(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(now: now))
        XCTAssertFalse(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(
            now: now.addingTimeInterval(HomesteadPlusEntitlementCache.maximumExtensionCacheAge + 1)
        ))

        HomesteadPlusEntitlementCache.save(hasPlus: false, verifiedAt: now, defaults: defaults)
        XCTAssertFalse(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(now: now))
    }

    @MainActor
    func testICloudPausesWithoutClearingEnabledIntentAndResumes() throws {
        let suiteName = "HomesteadPlusICloudTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = PlusTestICloudStore()
        let service = HomesteadICloudSyncService(defaults: defaults, store: store, hasPlusAccess: true)
        let dependencies = PlusTestSyncDependencies(defaults: defaults)

        service.bootstrap(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )
        _ = service.requestEnable(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )
        XCTAssertTrue(service.isEnabled)
        let writesBeforePause = store.setCount
        let updateBeforePause = service.makePayload(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        ).actionConfirmations.updatedAt

        service.setPlusAccess(false)
        dependencies.actionConfirmationSettings.mode = .off
        service.noteLocalChange(
            .actionConfirmations,
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )
        service.syncNow(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )
        XCTAssertTrue(service.isEnabled)
        XCTAssertEqual(service.status, .requiresPlus)
        XCTAssertEqual(store.setCount, writesBeforePause)
        let pausedPayload = service.makePayload(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )
        XCTAssertEqual(pausedPayload.actionConfirmations.value.mode, .off)
        XCTAssertGreaterThan(pausedPayload.actionConfirmations.updatedAt, updateBeforePause)

        service.setPlusAccess(true)
        service.syncNow(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )
        XCTAssertGreaterThan(store.setCount, writesBeforePause)
    }

    func testPlusWidgetDeepLinkRoundTrips() {
        XCTAssertTrue(HomesteadWidgetDeepLink.isPlusURL(HomesteadWidgetDeepLink.plusURL))
        XCTAssertNil(HomesteadWidgetDeepLink.entityID(from: HomesteadWidgetDeepLink.plusURL))
    }

    private func activeEntitlement(
        _ product: HomesteadPlusProduct,
        isIntroductoryOffer: Bool = false
    ) -> HomesteadVerifiedEntitlement {
        HomesteadVerifiedEntitlement(
            productID: product.rawValue,
            expirationDate: product == .lifetime ? nil : .now.addingTimeInterval(3_600),
            revocationDate: nil,
            isIntroductoryOffer: isIntroductoryOffer
        )
    }
}

@MainActor
private struct PlusTestSyncDependencies {
    let connectionSettings: HAConnectionSettings
    let dashboardConfiguration: DashboardConfiguration
    let actionConfirmationSettings: ActionConfirmationSettings
    let appearanceSettings: HomesteadAppearanceSettings

    init(defaults: UserDefaults) {
        connectionSettings = HAConnectionSettings(defaults: defaults)
        dashboardConfiguration = DashboardConfiguration(defaults: defaults)
        actionConfirmationSettings = ActionConfirmationSettings(defaults: defaults)
        appearanceSettings = HomesteadAppearanceSettings(
            profileID: connectionSettings.activeProfileID,
            defaults: defaults
        )
    }
}

private final class PlusTestICloudStore: HomesteadICloudKeyValueStore {
    private var values: [String: Data] = [:]
    private(set) var setCount = 0

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func set(_ value: Data?, forKey key: String) {
        values[key] = value
        setCount += 1
    }

    func synchronize() -> Bool {
        true
    }
}
