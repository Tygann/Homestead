import SwiftUI

nonisolated enum EntityDetailEntryContext: Equatable, Hashable, Sendable {
    case overview
    case history(initialRange: HAHistoryRangePreset)
}

struct EntityDetailSheet: View {
    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet
    var automaticallyLoadsWeatherForecast = true
    var entryContext: EntityDetailEntryContext = .overview

    var body: some View {
        let route = EntityCapabilityRegistry.profile(for: entityBox.domain).detailRoute

        switch route {
            case .light:
                LightDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .cover:
                CoverDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .climate:
                ClimateDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .fan:
                FanDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .lock:
                LockDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .toggle:
                ToggleEntityDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .action:
                ActionEntityDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .automation:
                AutomationDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .sensor:
                SensorDetailView(
                    entityBox: entityBox,
                    presentationStyle: presentationStyle,
                    entryContext: entryContext
                )
            case .mediaPlayer:
                MediaPlayerDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .camera:
                CameraDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .vacuum:
                VacuumDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .weather:
                WeatherDetailView(
                    entityBox: entityBox,
                    presentationStyle: presentationStyle,
                    automaticallyLoadsForecast: automaticallyLoadsWeatherForecast
                )
            case .alarmControlPanel:
                AlarmControlPanelDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .button:
                ButtonDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .select:
                SelectDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .number:
                NumberDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .text:
                TextDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .temporal:
                TemporalDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .presence:
                PresenceDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .generic:
                GenericEntityDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        }
    }
}
