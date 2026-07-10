import SwiftUI

struct EntityDetailSheet: View {
    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    var body: some View {
        if entityBox.domain == .automation {
            AutomationDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        } else {
            let detailKind = DashboardEntityPresentation(entityBox: entityBox).detailKind

            switch detailKind {
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
            case .sensor:
                SensorDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .mediaPlayer:
                MediaPlayerDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .camera:
                CameraDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .vacuum:
                VacuumDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .weather:
                WeatherDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .alarmControlPanel:
                AlarmControlPanelDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .button:
                ButtonDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .select:
                SelectDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .number:
                NumberDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            case .entity:
                GenericEntityDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
            }
        }
    }
}
