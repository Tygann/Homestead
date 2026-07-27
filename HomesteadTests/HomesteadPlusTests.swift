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

    func testEntitlementResolverRecognizesPaidSubscriptionsAndIgnoresUnknownProducts() {
        XCTAssertEqual(
            HomesteadEntitlementResolver.plan(from: [activeEntitlement(.monthly)]),
            .monthly
        )
        XCTAssertEqual(
            HomesteadEntitlementResolver.plan(from: [
                activeEntitlement(.monthly),
                activeEntitlement(.annual)
            ]),
            .annual
        )
        XCTAssertEqual(
            HomesteadEntitlementResolver.plan(from: [
                HomesteadVerifiedEntitlement(
                    productID: "com.tyler.Homestead.plus.unknown",
                    expirationDate: nil,
                    revocationDate: nil,
                    isIntroductoryOffer: false
                )
            ]),
            .free
        )
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
        XCTAssertTrue(HomesteadPlusCapabilityPolicy.canCreateDashboard(
            hasPlus: false,
            existingDashboardCount: 0
        ))
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

    func testContinuationPolicyResumesAndConsumesActionAfterPlusUnlocks() {
        var pendingAction: String? = "create-dashboard"

        let action = HomesteadPlusContinuationPolicy.consume(&pendingAction, hasPlus: true)

        XCTAssertEqual(action, "create-dashboard")
        XCTAssertNil(pendingAction)
    }

    func testContinuationPolicyClearsActionWhenPurchaseSheetClosesWithoutPlus() {
        var pendingAction: String? = "enable-icloud"

        let action = HomesteadPlusContinuationPolicy.consume(&pendingAction, hasPlus: false)

        XCTAssertNil(action)
        XCTAssertNil(pendingAction)
    }

    func testExtensionCacheRequiresFreshVerifiedPlusAccess() throws {
        let suiteName = "HomesteadPlusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date()

        XCTAssertFalse(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(now: now))

        HomesteadPlusEntitlementCache.save(hasPlus: true, verifiedAt: now, defaults: defaults)
        XCTAssertTrue(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(now: now))
        XCTAssertTrue(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(
            now: now.addingTimeInterval(HomesteadPlusEntitlementCache.maximumExtensionCacheAge)
        ))
        XCTAssertFalse(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(
            now: now.addingTimeInterval(HomesteadPlusEntitlementCache.maximumExtensionCacheAge + 1)
        ))
        XCTAssertFalse(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(
            now: now.addingTimeInterval(-1)
        ))

        HomesteadPlusEntitlementCache.save(hasPlus: false, verifiedAt: now, defaults: defaults)
        XCTAssertFalse(HomesteadPlusEntitlementCache.snapshot(defaults: defaults).grantsExtensionAccess(now: now))
    }

    func testWidgetPolicyKeepsReadingFreeAndRequiresPlusForAdvancedSensorsAndBoards() {
        XCTAssertTrue(HomesteadWidgetPlusPolicy.allowsSensorDisplay(.reading, hasPlus: false))
        for display in [
            HomesteadSensorWidgetDisplay.chart,
            .circularGauge,
            .segmentedGauge,
            .barGauge
        ] {
            XCTAssertFalse(HomesteadWidgetPlusPolicy.allowsSensorDisplay(display, hasPlus: false))
            XCTAssertTrue(HomesteadWidgetPlusPolicy.allowsSensorDisplay(display, hasPlus: true))
        }
        XCTAssertFalse(HomesteadWidgetPlusPolicy.allowsSensorBoard(hasPlus: false))
        XCTAssertTrue(HomesteadWidgetPlusPolicy.allowsSensorBoard(hasPlus: true))
    }

    @MainActor
    func testICloudColdLaunchPreservesEnabledIntentWithoutContactingStoreWhenPlusIsMissing() throws {
        let suiteName = "HomesteadPlusICloudColdLaunchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let setupStore = PlusTestICloudStore()
        let dependencies = PlusTestSyncDependencies(defaults: defaults)
        let setupService = HomesteadICloudSyncService(
            defaults: defaults,
            store: setupStore,
            hasPlusAccess: true
        )

        setupService.bootstrap(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )
        _ = setupService.requestEnable(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )
        XCTAssertTrue(setupService.isEnabled)

        let lockedStore = PlusTestICloudStore()
        let lockedService = HomesteadICloudSyncService(
            defaults: defaults,
            store: lockedStore,
            hasPlusAccess: false
        )
        lockedService.bootstrap(
            connectionSettings: dependencies.connectionSettings,
            dashboardConfiguration: dependencies.dashboardConfiguration,
            actionConfirmationSettings: dependencies.actionConfirmationSettings,
            appearanceSettings: dependencies.appearanceSettings
        )

        XCTAssertTrue(lockedService.isEnabled)
        XCTAssertEqual(lockedService.bootstrapState, .complete)
        XCTAssertEqual(lockedService.status, .requiresPlus)
        XCTAssertEqual(lockedStore.synchronizeCount, 0)
        XCTAssertEqual(lockedStore.setCount, 0)
        XCTAssertEqual(
            lockedService.requestEnable(
                connectionSettings: dependencies.connectionSettings,
                dashboardConfiguration: dependencies.dashboardConfiguration,
                actionConfirmationSettings: dependencies.actionConfirmationSettings,
                appearanceSettings: dependencies.appearanceSettings
            ),
            .unavailable("Homestead+ is required to sync preferences with iCloud.")
        )
    }

    @MainActor
    func testICloudBootstrapPolicyRechecksCleanDeviceAfterDelayedEntitlementGrant() {
        XCTAssertTrue(HomesteadPlusICloudBootstrapPolicy.shouldRecheckRemoteSetup(
            didGainPlusAccess: true,
            isSyncEnabled: false,
            bootstrapState: .complete
        ))
        XCTAssertFalse(HomesteadPlusICloudBootstrapPolicy.shouldRecheckRemoteSetup(
            didGainPlusAccess: false,
            isSyncEnabled: false,
            bootstrapState: .complete
        ))
        XCTAssertFalse(HomesteadPlusICloudBootstrapPolicy.shouldRecheckRemoteSetup(
            didGainPlusAccess: true,
            isSyncEnabled: true,
            bootstrapState: .complete
        ))
        XCTAssertFalse(HomesteadPlusICloudBootstrapPolicy.shouldRecheckRemoteSetup(
            didGainPlusAccess: true,
            isSyncEnabled: false,
            bootstrapState: .checking
        ))
    }

    @MainActor
    func testDelayedEntitlementGrantRechecksRemoteICloudSetup() throws {
        let producerSuite = "HomesteadPlusICloudProducerTests.\(UUID().uuidString)"
        let consumerSuite = "HomesteadPlusICloudConsumerTests.\(UUID().uuidString)"
        let producerDefaults = try XCTUnwrap(UserDefaults(suiteName: producerSuite))
        let consumerDefaults = try XCTUnwrap(UserDefaults(suiteName: consumerSuite))
        defer {
            producerDefaults.removePersistentDomain(forName: producerSuite)
            consumerDefaults.removePersistentDomain(forName: consumerSuite)
        }
        let store = PlusTestICloudStore()
        let producerDependencies = PlusTestSyncDependencies(defaults: producerDefaults)
        producerDependencies.actionConfirmationSettings.mode = .off
        let producer = HomesteadICloudSyncService(
            defaults: producerDefaults,
            store: store,
            hasPlusAccess: true
        )
        producer.bootstrap(
            connectionSettings: producerDependencies.connectionSettings,
            dashboardConfiguration: producerDependencies.dashboardConfiguration,
            actionConfirmationSettings: producerDependencies.actionConfirmationSettings,
            appearanceSettings: producerDependencies.appearanceSettings
        )
        _ = producer.requestEnable(
            connectionSettings: producerDependencies.connectionSettings,
            dashboardConfiguration: producerDependencies.dashboardConfiguration,
            actionConfirmationSettings: producerDependencies.actionConfirmationSettings,
            appearanceSettings: producerDependencies.appearanceSettings
        )
        XCTAssertGreaterThan(store.setCount, 0)

        let consumerDependencies = PlusTestSyncDependencies(defaults: consumerDefaults)
        let consumer = HomesteadICloudSyncService(
            defaults: consumerDefaults,
            store: store,
            hasPlusAccess: false
        )
        let synchronizationsBeforeLockedBootstrap = store.synchronizeCount
        consumer.bootstrap(
            connectionSettings: consumerDependencies.connectionSettings,
            dashboardConfiguration: consumerDependencies.dashboardConfiguration,
            actionConfirmationSettings: consumerDependencies.actionConfirmationSettings,
            appearanceSettings: consumerDependencies.appearanceSettings
        )
        XCTAssertEqual(consumer.bootstrapState, .complete)
        XCTAssertEqual(store.synchronizeCount, synchronizationsBeforeLockedBootstrap)

        consumer.setPlusAccess(true)
        XCTAssertTrue(HomesteadPlusICloudBootstrapPolicy.shouldRecheckRemoteSetup(
            didGainPlusAccess: true,
            isSyncEnabled: consumer.isEnabled,
            bootstrapState: consumer.bootstrapState
        ))
        consumer.bootstrap(
            connectionSettings: consumerDependencies.connectionSettings,
            dashboardConfiguration: consumerDependencies.dashboardConfiguration,
            actionConfirmationSettings: consumerDependencies.actionConfirmationSettings,
            appearanceSettings: consumerDependencies.appearanceSettings
        )

        guard case .restoreAvailable = consumer.bootstrapState else {
            return XCTFail("Expected remote setup to be offered after Plus access was verified.")
        }
        XCTAssertEqual(consumer.status, .restoreAvailable)
        XCTAssertEqual(consumerDependencies.actionConfirmationSettings.mode, .smart)
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

    func testCheckedInStoreKitConfigurationMatchesDocumentedProductsAndTrial() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configurationURL = repositoryRoot
            .appendingPathComponent("Homestead/Resources/Homestead.storekit")
        let configuration = try JSONDecoder().decode(
            PlusStoreKitConfiguration.self,
            from: Data(contentsOf: configurationURL)
        )

        XCTAssertEqual(
            Set(configuration.products.map(\.productID)),
            [HomesteadPlusProduct.lifetime.rawValue]
        )
        let lifetime = try XCTUnwrap(configuration.products.first)
        XCTAssertEqual(lifetime.type, "NonConsumable")
        XCTAssertEqual(lifetime.displayPrice, "69.99")
        XCTAssertTrue(lifetime.familyShareable)

        let group = try XCTUnwrap(configuration.subscriptionGroups.first)
        XCTAssertEqual(configuration.subscriptionGroups.count, 1)
        XCTAssertEqual(group.name, "Homestead+")
        XCTAssertEqual(
            Set(group.subscriptions.map(\.productID)),
            [
                HomesteadPlusProduct.annual.rawValue,
                HomesteadPlusProduct.monthly.rawValue
            ]
        )

        let annual = try XCTUnwrap(
            group.subscriptions.first { $0.productID == HomesteadPlusProduct.annual.rawValue }
        )
        XCTAssertEqual(annual.displayPrice, "24.99")
        XCTAssertEqual(annual.recurringSubscriptionPeriod, "P1Y")
        XCTAssertEqual(annual.introductoryOffer?.paymentMode, "free")
        XCTAssertEqual(annual.introductoryOffer?.subscriptionPeriod, "P2W")
        XCTAssertTrue(annual.familyShareable)
        XCTAssertTrue(annual.codeOffers.contains {
            $0.referenceName == "Homestead+ Annual Test Code"
                && $0.paymentMode == "free"
        })

        let monthly = try XCTUnwrap(
            group.subscriptions.first { $0.productID == HomesteadPlusProduct.monthly.rawValue }
        )
        XCTAssertEqual(monthly.displayPrice, "4.99")
        XCTAssertEqual(monthly.recurringSubscriptionPeriod, "P1M")
        XCTAssertNil(monthly.introductoryOffer)
        XCTAssertTrue(monthly.familyShareable)
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
        connectionSettings = HAConnectionSettings(
            baseURL: "",
            defaults: defaults,
            tokenStore: InMemoryHAOAuthTokenStore()
        )
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
    private(set) var synchronizeCount = 0

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func set(_ value: Data?, forKey key: String) {
        values[key] = value
        setCount += 1
    }

    func synchronize() -> Bool {
        synchronizeCount += 1
        return true
    }
}

private struct PlusStoreKitConfiguration: Decodable {
    let products: [Product]
    let subscriptionGroups: [SubscriptionGroup]

    struct Product: Decodable {
        let displayPrice: String
        let familyShareable: Bool
        let productID: String
        let type: String
    }

    struct SubscriptionGroup: Decodable {
        let name: String
        let subscriptions: [Subscription]
    }

    struct Subscription: Decodable {
        let codeOffers: [Offer]
        let displayPrice: String
        let familyShareable: Bool
        let introductoryOffer: Offer?
        let productID: String
        let recurringSubscriptionPeriod: String
    }

    struct Offer: Decodable {
        let paymentMode: String
        let referenceName: String?
        let subscriptionPeriod: String
    }
}
