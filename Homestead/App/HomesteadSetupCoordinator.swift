import Foundation
import Observation

enum HomesteadSetupPhase: Equatable {
    case checkingICloud
    case setup
    case ready
}

@MainActor
@Observable
final class HomesteadSetupCoordinator {
    private(set) var phase: HomesteadSetupPhase
    let discoveryService = HomeAssistantDiscoveryService()
    @ObservationIgnored private var hasStartedServices = false

    init(initialPhase: HomesteadSetupPhase = .checkingICloud) {
        phase = initialPhase
    }

    func start(
        iCloud: HomesteadICloudSyncService,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings,
        homeAssistantService: HomeAssistantService
    ) async {
        guard phase == .checkingICloud else { return }
        iCloud.startObserving(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
        iCloud.bootstrap(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
        guard case .restoreAvailable = iCloud.bootstrapState else {
            await startServices(homeAssistantService, settings: connectionSettings)
            return
        }
    }

    func restoreAndSignIn(
        iCloud: HomesteadICloudSyncService,
        connectionSettings: HAConnectionSettings,
        dashboardConfiguration: DashboardConfiguration,
        actionConfirmationSettings: ActionConfirmationSettings,
        appearanceSettings: HomesteadAppearanceSettings,
        homeAssistantService: HomeAssistantService
    ) async {
        iCloud.acceptBootstrapRestore(
            connectionSettings: connectionSettings,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings
        )
        await startServices(homeAssistantService, settings: connectionSettings)
        if connectionSettings.hasServerURL {
            await homeAssistantService.signInWithHomeAssistant(settings: connectionSettings)
        }
    }

    func setUpAnotherHome(
        iCloud: HomesteadICloudSyncService,
        connectionSettings: HAConnectionSettings,
        homeAssistantService: HomeAssistantService
    ) async {
        iCloud.declineBootstrapRestore()
        await startServices(homeAssistantService, settings: connectionSettings)
    }

    func select(_ instance: HomeAssistantDiscoveredInstance, settings: HAConnectionSettings) {
        settings.baseURL = instance.signInURL
        settings.internalURL = instance.internalURL ?? ""
        settings.externalURL = instance.externalURL ?? ""
        discoveryService.stop()
    }

    private func startServices(_ service: HomeAssistantService, settings: HAConnectionSettings) async {
        guard !hasStartedServices else { return }
        hasStartedServices = true
        phase = .setup
        service.startNetworkMonitoring(settings: settings)
        await service.refreshAuthState()
        service.refreshMobileAppRegistrationState(settings: settings)
        await service.loadCachedStatesIfPossible(settings: settings)
        await service.connectIfPossible(settings: settings)
        phase = .ready
    }
}
