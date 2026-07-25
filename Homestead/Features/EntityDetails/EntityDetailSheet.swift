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
            .homesteadWallpaperBackground(
                allowsWallpaper: destination.surfaceContext == .home
            )
            .environment(
                \.homesteadEntityDetailSurfaceContext,
                destination.surfaceContext
            )
        } else {
            ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                .navigationTitle("Entity")
                .homesteadWallpaperBackground(
                    allowsWallpaper: destination.surfaceContext == .home
                )
                .environment(
                    \.homesteadEntityDetailSurfaceContext,
                    destination.surfaceContext
                )
        }
    }
}

struct EntityDetailSheet: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HAStateStore.self) private var stateStore
    @State private var editingCardReference: DashboardItemReference?
    @State private var frontendDestination: HomeAssistantFrontendEntityDestination?
    @State private var isResolvingFrontendDestination = false
    @State private var showsFrontendDestinationError = false

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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let dashboardItemReference,
                       let dashboardItem = dashboardConfiguration.item(for: dashboardItemReference) {
                        Button {
                            editingCardReference = dashboardItemReference
                        } label: {
                            Label(
                                dashboardItem.role == .chip ? "Edit Chip" : "Edit Card",
                                systemImage: "slider.horizontal.3"
                            )
                        }

                        Divider()
                    }

                    Button {
                        openInHomeAssistant()
                    } label: {
                        Label(frontendActionTitle, systemImage: "safari")
                    }
                    .disabled(isResolvingFrontendDestination)
                } label: {
                    Image(systemName: "ellipsis")
                        .bold()
                }
                .accessibilityLabel("Entity options")
            }
        }
        .sheet(item: $editingCardReference) { reference in
            DashboardItemEditorView(
                reference: reference,
                onEntityReplaced: onCardEntityChange
            )
        }
        .fullScreenCover(item: $frontendDestination) { destination in
            HomeAssistantSafariView(url: destination.url)
                .ignoresSafeArea()
        }
        .alert("Unable to Open Home Assistant", isPresented: $showsFrontendDestinationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Homestead could not form a supported destination for this entity and connection.")
        }
    }

    private var frontendActionTitle: String {
        frontendDestinationPreview?.action.title ?? "Open in Home Assistant"
    }

    private var frontendDestinationPreview: HomeAssistantFrontendEntityDestination? {
        let rawEntity = stateStore.rawEntity(for: entityBox.entityID)
        let isPersonEditable = rawEntity?.attributes["editable"]?.boolValue
            ?? (rawEntity?.attributes["editable"]?.stringValue?.lowercased() != "false")

        return HomeAssistantFrontendEntityDestinationResolver.destination(
            baseURLString: connectionSettings.baseURL,
            entityID: entityBox.entityID,
            configurationID: rawEntity?.attributes["id"]?.stringValue,
            registryUniqueID: stateStore.entityRegistryUniqueID(for: entityBox.entityID),
            isPersonEditable: isPersonEditable
        )
    }

    private func openInHomeAssistant() {
        guard !isResolvingFrontendDestination else { return }
        isResolvingFrontendDestination = true

        Task {
            let destination = await homeAssistantService.homeAssistantFrontendDestination(
                settings: connectionSettings,
                entityID: entityBox.entityID
            )
            frontendDestination = destination
            showsFrontendDestinationError = destination == nil
            isResolvingFrontendDestination = false
        }
    }
}
