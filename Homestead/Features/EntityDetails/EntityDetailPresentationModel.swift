import SwiftUI

/// Canonical presentation facts shared by entity-detail families.
///
/// This model intentionally excludes dashboard overrides, card layout, and
/// card-specific configuration so every entry point describes the same Home
/// Assistant entity.
struct EntityDetailPresentationModel {
    let title: String
    let subtitle: String
    let icon: ResolvedIcon
    let isActive: Bool
    let isAvailable: Bool
    let accentColor: Color

    init(entityBox: HAEntityState) {
        let entity = entityBox.homeEntity
        let effectiveState = entityBox.pendingCommand?.expectedState ?? entity.state

        title = Self.title(for: entityBox)
        subtitle = Self.subtitle(for: entityBox, effectiveState: effectiveState)
        icon = entity.resolvedIcon
        isActive = Self.isActive(entityBox, effectiveState: effectiveState)
        isAvailable = entity.isAvailable
        accentColor = Self.accentColor(for: entityBox, isActive: isActive)
    }

    private static func title(for entityBox: HAEntityState) -> String {
        if let sensor = entityBox.sensorEntity { return sensor.displayName }
        if let binarySensor = entityBox.binarySensorEntity { return binarySensor.displayName }
        if let mediaPlayer = entityBox.mediaPlayerEntity { return mediaPlayer.displayName }
        if let weather = entityBox.weatherEntity { return weather.displayName }
        if let select = entityBox.selectEntity { return select.displayName }
        if let number = entityBox.numberEntity { return number.displayName }
        if let text = entityBox.textEntity { return text.displayName }
        if let temporal = entityBox.temporalEntity { return temporal.displayName }
        return entityBox.homeEntity.displayName
    }

    private static func subtitle(for entityBox: HAEntityState, effectiveState: String) -> String {
        if let sensor = entityBox.sensorEntity { return sensor.displaySubtitle }
        if let binarySensor = entityBox.binarySensorEntity { return binarySensor.displaySubtitle }
        if let cover = entityBox.coverEntity { return cover.displaySubtitle }
        if let climate = entityBox.climateEntity { return climate.displaySubtitle }
        if let fan = entityBox.fanEntity { return fan.displaySubtitle }
        if let mediaPlayer = entityBox.mediaPlayerEntity { return mediaPlayer.displaySubtitle }
        if let weather = entityBox.weatherEntity { return weather.displaySubtitle }
        return effectiveState.displayStateText
    }

    private static func isActive(_ entityBox: HAEntityState, effectiveState: String) -> Bool {
        if let light = entityBox.lightEntity {
            return entityBox.pendingCommand?.expectedState == nil ? light.isOn : effectiveState == "on"
        }
        if let binarySensor = entityBox.binarySensorEntity { return binarySensor.isActive }
        if let cover = entityBox.coverEntity { return cover.isOpen }
        if let climate = entityBox.climateEntity { return climate.isActive }
        if let fan = entityBox.fanEntity {
            return entityBox.pendingCommand?.expectedState == nil ? fan.isOn : effectiveState == "on"
        }
        if let mediaPlayer = entityBox.mediaPlayerEntity { return mediaPlayer.isPlaying }
        if let sensor = entityBox.sensorEntity { return sensor.isAlerting }

        switch effectiveState {
        case "on", "open", "opening", "unlocked", "unlocking", "playing", "cleaning", "active":
            return true
        default:
            return false
        }
    }

    private static func accentColor(for entityBox: HAEntityState, isActive: Bool) -> Color {
        guard entityBox.homeEntity.isAvailable else { return .secondary }

        if let status = entityBox.sensorEntity?.gaugePresentation?.status {
            return gaugeVisualStatusColor(for: status.visualStatus)
        }
        if let sensor = entityBox.sensorEntity {
            return EntitySemanticAccentColor.sensor(sensor)
        }
        if let climate = entityBox.climateEntity {
            return EntitySemanticAccentColor.climate(climate)
        }
        if let weather = entityBox.weatherEntity {
            return EntitySemanticAccentColor.weather(weather)
        }

        switch entityBox.domain {
        case .camera:
            return .blue
        case .scene:
            return .purple
        case .mediaPlayer where isActive, .vacuum where isActive:
            return .green
        default:
            return .accentColor
        }
    }
}
