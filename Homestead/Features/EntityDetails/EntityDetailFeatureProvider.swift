import Foundation

nonisolated enum EntityDetailFeature: Hashable, Sendable {
    case numericHistory
    case recentActivity
    case nativeEditor
    case media
    case domainInsights
    case forecast
}

nonisolated enum EntityDetailActivitySource: Equatable, Sendable {
    case stateHistory
    case automationTraces
}

nonisolated struct EntityDetailFeatureSet: Equatable, Sendable {
    let supportedFeatures: Set<EntityDetailFeature>
    let activitySource: EntityDetailActivitySource?

    func supports(_ feature: EntityDetailFeature) -> Bool {
        supportedFeatures.contains(feature)
    }
}

@MainActor
enum EntityDetailFeatureProvider {
    static func features(for entityBox: HAEntityState) -> EntityDetailFeatureSet {
        let profile = EntityCapabilityRegistry.profile(for: entityBox.domain)
        var features: Set<EntityDetailFeature> = []
        let activitySource = resolvedActivitySource(
            for: entityBox.domain,
            profile: profile
        )

        if profile.supports(.showHistory), supportsNumericHistory(entityBox) {
            features.insert(.numericHistory)
        }
        if activitySource != nil {
            features.insert(.recentActivity)
        }
        if profile.supports(.editValue), supportsNativeEditor(entityBox) {
            features.insert(.nativeEditor)
        }
        if supportsMedia(entityBox) {
            features.insert(.media)
        }
        if supportsDomainInsights(entityBox) {
            features.insert(.domainInsights)
        }
        if supportsForecast(entityBox) {
            features.insert(.forecast)
        }

        return EntityDetailFeatureSet(
            supportedFeatures: features,
            activitySource: activitySource
        )
    }

    private static func supportsNumericHistory(_ entityBox: HAEntityState) -> Bool {
        switch entityBox.domain {
        case .sensor:
            entityBox.sensorEntity?.numericValue != nil
        case .number:
            entityBox.numberEntity?.value != nil
        default:
            false
        }
    }

    private static func resolvedActivitySource(
        for domain: EntityDomain,
        profile: EntityCapabilityProfile
    ) -> EntityDetailActivitySource? {
        guard profile.supports(.showActivity) else { return nil }

        return domain == .automation ? .automationTraces : .stateHistory
    }

    private static func supportsNativeEditor(_ entityBox: HAEntityState) -> Bool {
        switch entityBox.domain {
        case .number:
            entityBox.numberEntity != nil
        case .select:
            entityBox.selectEntity != nil
        case .text:
            entityBox.textEntity != nil
        case .date, .time, .datetime:
            entityBox.temporalEntity != nil
        default:
            false
        }
    }

    private static func supportsMedia(_ entityBox: HAEntityState) -> Bool {
        entityBox.domain == .camera || entityBox.mediaPlayerEntity != nil
    }

    private static func supportsDomainInsights(_ entityBox: HAEntityState) -> Bool {
        switch entityBox.domain {
        case .automation, .script, .climate, .weather:
            true
        default:
            false
        }
    }

    private static func supportsForecast(_ entityBox: HAEntityState) -> Bool {
        entityBox.weatherEntity?.supportedForecastTypes.isEmpty == false
    }
}
