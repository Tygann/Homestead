import SwiftUI

struct EntityDetailDestinationView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var activeEntityID: String

    let destination: EntityDetailDestination
    var presentationStyle: EntityDetailPresentationStyle = .navigation

    init(
        destination: EntityDetailDestination,
        presentationStyle: EntityDetailPresentationStyle = .navigation
    ) {
        self.destination = destination
        self.presentationStyle = presentationStyle
        _activeEntityID = State(initialValue: destination.entityID)
    }

    var body: some View {
        if let entityBox = stateStore.entityBox(for: activeEntityID) {
            EntityDetailSheet(
                entityBox: entityBox,
                presentationStyle: presentationStyle,
                initialSection: destination.initialSection,
                dashboardItemReference: destination.dashboardItemReference,
                onCardEntityChange: { activeEntityID = $0 }
            )
        } else {
            ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                .navigationTitle("Entity")
        }
    }
}

struct EntityDetailSheet: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var editingCardReference: DashboardItemReference?

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet
    var automaticallyLoadsWeatherForecast = true
    var initialSection: EntityDetailInitialSection = .overview
    var dashboardItemReference: DashboardItemReference?
    var onCardEntityChange: ((String) -> Void)?

    var body: some View {
        let route = EntityCapabilityRegistry.profile(for: entityBox.domain).detailRoute

        Group {
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
                    initialSection: initialSection
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
        // Reset entity-specific routed state without tearing down the
        // contextual card editor that owns the replacement flow.
        .id(entityBox.entityID)
        .toolbar {
            if let dashboardItemReference {
                ToolbarItem(placement: .topBarTrailing) {
                    if dashboardConfiguration.item(for: dashboardItemReference) != nil {
                        Button {
                            editingCardReference = dashboardItemReference
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel("Edit Card")
                    }
                }
            }
        }
        .sheet(item: $editingCardReference) { reference in
            DashboardCardEditorView(
                reference: reference,
                onEntityReplaced: onCardEntityChange
            )
        }
    }
}
