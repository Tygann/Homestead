import Foundation

nonisolated enum HomesteadPlusEntitlementCache {
    static let appGroupID = "group.com.tyler.Homestead"
    static let maximumExtensionCacheAge: TimeInterval = 48 * 60 * 60

    private static let hasPlusKey = "homestead.plus.hasVerifiedAccess.v1"
    private static let verificationDateKey = "homestead.plus.verificationDate.v1"

    static func save(hasPlus: Bool, verifiedAt: Date = .now, defaults: UserDefaults? = nil) {
        let defaults = defaults ?? UserDefaults(suiteName: appGroupID)
        defaults?.set(hasPlus, forKey: hasPlusKey)
        defaults?.set(verifiedAt, forKey: verificationDateKey)
    }

    static func snapshot(defaults: UserDefaults? = nil) -> HomesteadPlusCachedEntitlement {
        let defaults = defaults ?? UserDefaults(suiteName: appGroupID)
        return HomesteadPlusCachedEntitlement(
            hasPlus: defaults?.bool(forKey: hasPlusKey) ?? false,
            verifiedAt: defaults?.object(forKey: verificationDateKey) as? Date
        )
    }
}

nonisolated struct HomesteadPlusCachedEntitlement: Equatable, Sendable {
    let hasPlus: Bool
    let verifiedAt: Date?

    func grantsExtensionAccess(
        now: Date = .now,
        maximumAge: TimeInterval = HomesteadPlusEntitlementCache.maximumExtensionCacheAge
    ) -> Bool {
        guard hasPlus, let verifiedAt else { return false }
        let age = now.timeIntervalSince(verifiedAt)
        return age >= 0 && age <= maximumAge
    }
}
