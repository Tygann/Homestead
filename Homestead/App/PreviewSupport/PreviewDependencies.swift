#if DEBUG
import CryptoKit
import SwiftUI

@MainActor
struct PreviewDependencies {
    let stateStore: HAStateStore
    let connectionSettings: HAConnectionSettings
    let homeAssistantService: HomeAssistantService
    let nativeNotificationService: NativeNotificationService
    let nativePermissionService: NativePermissionService
    let dashboardConfiguration: DashboardConfiguration
    let actionConfirmationSettings: ActionConfirmationSettings
    let appearanceSettings: HomesteadAppearanceSettings
    let tabSettings: HomesteadTabSettings
    let iCloudSyncService: HomesteadICloudSyncService

    static var sample: PreviewDependencies {
        makeSample()
    }

    static func settingsSample(_ scenario: PreviewSettingsScenario) -> PreviewDependencies {
        let isDegraded = scenario == .degraded
        let base = makeSample(
            dataFreshness: isDegraded
                ? .cached(Date(timeIntervalSince1970: 1_753_200_000))
                : .live(Date(timeIntervalSince1970: 1_753_286_400)),
            connectionStatus: isDegraded
                ? .failed("Preview connection failure")
                : .connected
        )

        base.connectionSettings.internalURL = "http://homeassistant.local:8123"
        base.connectionSettings.externalURL = "https://ha.example.com"
        if isDegraded {
            base.connectionSettings.baseURL = "https://configured.example.com"
        }

        let config = HAConfigDTO(
            version: "2026.7.3",
            locationName: "Lake House",
            timeZone: "America/Chicago",
            internalURL: "http://homeassistant.local:8123",
            externalURL: "https://ha.example.com",
            state: "RUNNING",
            configSource: "storage",
            unitSystem: nil
        )
        let serverConfiguration = HAServerConfigurationSnapshot(
            dto: config,
            loadedAt: Date(timeIntervalSince1970: 1_753_286_400)
        )
        let serverEnvironment = HAServerEnvironmentSnapshot(
            config: config,
            supervisorInfo: HASupervisorInfoDTO(version: "2026.07.3"),
            operatingSystemInfo: HAOperatingSystemInfoDTO(version: "18.1")
        )
        let registrationInfo = HAMobileAppRegistrationInfo(
            serverIdentifier: "preview",
            deviceID: "preview-device",
            appVersion: "1.0",
            deviceName: "Homestead • iPhone",
            webhookID: "preview-webhook",
            supportsCloudPushNotifications: true,
            registeredAt: Date(timeIntervalSince1970: 1_752_600_000)
        )
        base.homeAssistantService.applySettingsPreviewState(
            currentUserDisplayName: "Taylor",
            isNetworkAvailable: !isDegraded,
            mobileAppRegistrationState: isDegraded
                ? .failed("Registration needs to be restored.")
                : .registered(HAMobileAppRegistrationSummary(info: registrationInfo)),
            serverConfiguration: serverConfiguration,
            serverEnvironment: serverEnvironment,
            stateCacheMetadata: HAStateCacheMetadata(
                scopeIdentifier: "preview-settings",
                savedAt: Date(timeIntervalSince1970: 1_753_286_400),
                entityCount: 1_093,
                entityRegistryCount: 1_204,
                deviceRegistryCount: 214,
                areaRegistryCount: 18,
                floorRegistryCount: 3
            ),
            activeRouteSummary: HAConnectionRouteSummary(
                route: .externalURL,
                baseURLString: "https://ha.example.com"
            )
        )

        let permissionStatus: NativePermissionStatusSnapshot = switch scenario {
        case .healthy, .degraded, .permissionsAllowed:
            .previewAllowed
        case .permissionsNotRequested:
            NativePermissionStatusSnapshot(
                camera: .notDetermined,
                location: .notDetermined,
                localNetwork: .managedBySystem
            )
        case .permissionsDenied:
            NativePermissionStatusSnapshot(
                camera: .denied,
                location: .denied,
                localNetwork: .managedBySystem
            )
        }
        let nativePermissionService = NativePermissionService(
            client: PreviewNativePermissionClient(status: permissionStatus)
        )

        return PreviewDependencies(
            stateStore: base.stateStore,
            connectionSettings: base.connectionSettings,
            homeAssistantService: base.homeAssistantService,
            nativeNotificationService: base.nativeNotificationService,
            nativePermissionService: nativePermissionService,
            dashboardConfiguration: base.dashboardConfiguration,
            actionConfirmationSettings: base.actionConfirmationSettings,
            appearanceSettings: base.appearanceSettings,
            tabSettings: base.tabSettings,
            iCloudSyncService: base.iCloudSyncService
        )
    }

    static func entityDetailSample(
        entityOverrides: [HAEntityDTO] = [],
        dataFreshness: HADataFreshness = .live(Date()),
        connectionStatus: HAConnectionStatus = .connected,
        serviceFeedback: HAServiceFeedback? = nil,
        pendingCommand: HAEntityPendingCommand? = nil,
        contentState: PreviewEntityDetailContentState = .loaded
    ) -> PreviewDependencies {
        makeSample(
            entityOverrides: entityOverrides,
            dataFreshness: dataFreshness,
            connectionStatus: connectionStatus,
            serviceFeedback: serviceFeedback,
            pendingCommand: pendingCommand,
            httpClient: PreviewEntityDetailHTTPClient(state: contentState)
        )
    }

    private static func makeSample(
        entityOverrides: [HAEntityDTO] = [],
        dataFreshness: HADataFreshness = .live(Date()),
        connectionStatus: HAConnectionStatus = .connected,
        serviceFeedback: HAServiceFeedback? = nil,
        pendingCommand: HAEntityPendingCommand? = nil,
        httpClient: (any HAHTTPClientProtocol)? = nil
    ) -> PreviewDependencies {
        let previewDefaults = UserDefaults.samplePreview
        let stateStore = HAStateStore()
        let overridesByID = Dictionary(uniqueKeysWithValues: entityOverrides.map { ($0.entityID, $0) })
        let baseEntities = PreviewData.entities.map { overridesByID[$0.entityID] ?? $0 }
        let baseEntityIDs = Set(baseEntities.map(\.entityID))
        let appendedOverrides = entityOverrides.filter { !baseEntityIDs.contains($0.entityID) }
        let entities = baseEntities + appendedOverrides
        stateStore.applyInitialStates(entities)
        if let pendingCommand {
            stateStore.setPendingCommand(pendingCommand)
        }
        let dashboardConfiguration = DashboardConfiguration(defaults: previewDefaults)
        let actionConfirmationSettings = ActionConfirmationSettings(defaults: previewDefaults)
        let tabSettings = HomesteadTabSettings(defaults: previewDefaults)
        let iCloudSyncService = HomesteadICloudSyncService(defaults: previewDefaults)
        _ = dashboardConfiguration.applySuggestedSetup(using: stateStore.dashboardSuggestionCandidates())

        let credential = PreviewCredentialProvider.sampleCredential(
            baseURL: "http://homeassistant.local:8123",
            accessToken: "preview-token"
        )
        let tokenStore = InMemoryHAOAuthTokenStore(credential: credential)
        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            defaults: previewDefaults,
            tokenStore: tokenStore
        )
        let appearanceSettings = HomesteadAppearanceSettings(
            profileID: settings.activeProfileID,
            defaults: previewDefaults
        )

        let nativeNotificationService = NativeNotificationService(
            client: PreviewNativeNotificationPermissionClient(status: .previewAuthorized)
        )
        let nativePermissionService = NativePermissionService(
            client: PreviewNativePermissionClient(status: .previewAllowed)
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            connectionStatus: connectionStatus,
            dataFreshness: dataFreshness,
            serviceFeedback: serviceFeedback,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            httpClient: httpClient,
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            pushRelayTokenStore: InMemoryPushRelayTokenStore(),
            nativeNotificationService: nativeNotificationService,
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        return PreviewDependencies(
            stateStore: stateStore,
            connectionSettings: settings,
            homeAssistantService: service,
            nativeNotificationService: nativeNotificationService,
            nativePermissionService: nativePermissionService,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings,
            tabSettings: tabSettings,
            iCloudSyncService: iCloudSyncService
        )
    }

    static var liveHomeAssistant: PreviewDependencies? {
        let previewDefaults = UserDefaults.livePreview
        let dashboardDefaults = LivePreviewDashboardPersistence.dashboardDefaults(fallback: previewDefaults)
        let stateStore = HAStateStore()
        let actionConfirmationSettings = ActionConfirmationSettings(defaults: previewDefaults)
        let tabSettings = HomesteadTabSettings(defaults: previewDefaults)
        let iCloudSyncService = HomesteadICloudSyncService(defaults: previewDefaults)

        let previewCredentials = PreviewCredentialProvider.liveCredentials()
        if !previewCredentials.isEmpty {
            let profiles = previewCredentials.map(\.profile)
            let profileStore = HAConnectionProfileStore(
                defaults: previewDefaults,
                legacyBaseURL: profiles[0].baseURL
            )
            profileStore.replaceForPreview(profiles)
            LivePreviewDashboardPersistence.prepare(
                legacyDefaults: previewDefaults,
                dashboardDefaults: dashboardDefaults,
                profileIDs: profiles.map { Optional($0.id) },
                backupData: LivePreviewDashboardPersistence.bundledBackupData()
            )
            let tokenStores = Dictionary(uniqueKeysWithValues: previewCredentials.map {
                ($0.profile.id, InMemoryHAOAuthTokenStore(credential: $0.credential))
            })
            let settings = HAConnectionSettings(
                defaults: previewDefaults,
                tokenStore: tokenStores[profileStore.activeProfileID],
                profileStore: profileStore
            )
            let dashboardConfiguration = DashboardConfiguration(
                defaults: dashboardDefaults,
                profileID: profileStore.activeProfileID
            )
            let appearanceSettings = HomesteadAppearanceSettings(
                profileID: profileStore.activeProfileID,
                defaults: previewDefaults
            )
            let activeCredential = previewCredentials.first {
                $0.profile.id == profileStore.activeProfileID
            }?.credential ?? previewCredentials[0].credential
            let nativeNotificationService = NativeNotificationService(
                client: PreviewNativeNotificationPermissionClient(status: .previewAuthorized)
            )
            let nativePermissionService = NativePermissionService(
                client: PreviewNativePermissionClient(status: .previewAllowed)
            )
            let service = HomeAssistantService(
                stateStore: stateStore,
                authState: .signedIn(HAAuthSessionSummary(credential: activeCredential)),
                mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
                mobileAppDeviceIDStore: InMemoryHAMobileAppDeviceIDStore(),
                pushRelayTokenStore: InMemoryPushRelayTokenStore(),
                nativeNotificationService: nativeNotificationService,
                authManager: HAOAuthManager(
                    tokenStore: tokenStores[profileStore.activeProfileID],
                    profileID: profileStore.activeProfileID
                ),
                authManagerProvider: { profileID in
                    HAOAuthManager(tokenStore: tokenStores[profileID], profileID: profileID)
                },
                automaticallyRegistersMobileApp: false
            )

            return PreviewDependencies(
                stateStore: stateStore,
                connectionSettings: settings,
                homeAssistantService: service,
                nativeNotificationService: nativeNotificationService,
                nativePermissionService: nativePermissionService,
                dashboardConfiguration: dashboardConfiguration,
                actionConfirmationSettings: actionConfirmationSettings,
                appearanceSettings: appearanceSettings,
                tabSettings: tabSettings,
                iCloudSyncService: iCloudSyncService
            )
        }

        LivePreviewDashboardPersistence.prepare(
            legacyDefaults: previewDefaults,
            dashboardDefaults: dashboardDefaults,
            profileIDs: [nil],
            backupData: LivePreviewDashboardPersistence.bundledBackupData()
        )
        let dashboardConfiguration = DashboardConfiguration(defaults: dashboardDefaults)
        let settings = HAConnectionSettings(defaults: previewDefaults)
        let appearanceSettings = HomesteadAppearanceSettings(
            profileID: settings.activeProfileID,
            defaults: previewDefaults
        )

        guard settings.hasServerURL else {
            return nil
        }

        let nativeNotificationService = NativeNotificationService(
            client: PreviewNativeNotificationPermissionClient(status: .previewNotDetermined)
        )
        let nativePermissionService = NativePermissionService(
            client: PreviewNativePermissionClient(status: .previewMixed)
        )
        let service = HomeAssistantService(
            stateStore: stateStore,
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            mobileAppDeviceIDStore: InMemoryHAMobileAppDeviceIDStore(),
            pushRelayTokenStore: InMemoryPushRelayTokenStore(),
            nativeNotificationService: nativeNotificationService,
            automaticallyRegistersMobileApp: false
        )

        return PreviewDependencies(
            stateStore: stateStore,
            connectionSettings: settings,
            homeAssistantService: service,
            nativeNotificationService: nativeNotificationService,
            nativePermissionService: nativePermissionService,
            dashboardConfiguration: dashboardConfiguration,
            actionConfirmationSettings: actionConfirmationSettings,
            appearanceSettings: appearanceSettings,
            tabSettings: tabSettings,
            iCloudSyncService: iCloudSyncService
        )
    }
}

enum PreviewSettingsScenario: Equatable, Sendable {
    case healthy
    case degraded
    case permissionsNotRequested
    case permissionsAllowed
    case permissionsDenied
}

// MARK: - Entity Detail Fixtures

enum PreviewEntityDetailContentState: Sendable {
    case loaded
    case loading
    case empty
    case failed
}

private actor PreviewEntityDetailHTTPClient: HAHTTPClientProtocol {
    let state: PreviewEntityDetailContentState

    init(state: PreviewEntityDetailContentState) {
        self.state = state
    }

    func fetchCameraSnapshot(configuration: HAConnectionConfiguration, entityID: String) async throws -> Data {
        throw HAWebSocketError.missingResult
    }

    func fetchLogbook(
        configuration: HAConnectionConfiguration,
        request: HALogbookRequest
    ) async throws -> [HALogbookEntryDTO] {
        []
    }

    func fetchHistory(
        configuration: HAConnectionConfiguration,
        request: HAHistoryRequest
    ) async throws -> HAHistoryResponseDTO {
        switch state {
        case .loaded:
            return loadedResponse(for: request)
        case .loading:
            try await Task.sleep(for: .seconds(60))
            throw CancellationError()
        case .empty:
            return HAHistoryResponseDTO(series: [])
        case .failed:
            throw HAWebSocketError.requestFailed("Deterministic preview failure")
        }
    }

    private func loadedResponse(for request: HAHistoryRequest) -> HAHistoryResponseDTO {
        let states: [String]
        switch EntityDomain(entityID: request.entityID) {
        case .cover:
            states = [
                "closed", "opening", "open", "closing",
                "closed", "opening", "open", "closing",
                "closed", "opening", "open", "closing"
            ]
        case .person, .deviceTracker:
            states = ["not_home", "home"]
        case .sensor, .number:
            states = request.entityID == "sensor.living_room_temperature"
                ? ["72.2", "71.6", "72.8", "73.4", "72.9", "73.4"]
                : ["12", "18", "15"]
        default:
            states = ["off", "on"]
        }

        let duration = request.endDate.timeIntervalSince(request.startDate)
        let rows = states.enumerated().map { index, state in
            HAHistoryStateDTO(
                entityID: request.entityID,
                state: state,
                lastChanged: request.startDate.addingTimeInterval(
                    duration * Double(index + 1) / Double(states.count + 1)
                )
            )
        }
        return HAHistoryResponseDTO(series: [rows])
    }
}

extension View {
    @MainActor
    func withPreviewAccentColor() -> some View {
        withPreviewAccentColor(HomesteadAppearanceSettings(
            profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            defaults: .samplePreview
        ))
    }

    @MainActor
    func withPreviewAccentColor(_ appearanceSettings: HomesteadAppearanceSettings) -> some View {
        PreviewAccentColorView(content: self, appearanceSettings: appearanceSettings)
    }

    @MainActor
    func withPreviewEnvironment() -> some View {
        withPreviewEnvironment(.sample)
    }

    @MainActor
    func withPreviewEnvironment(_ dependencies: PreviewDependencies) -> some View {
        let setupCoordinator = HomesteadSetupCoordinator(initialPhase: .ready)
        return environment(dependencies.stateStore)
            .environment(dependencies.connectionSettings)
            .environment(dependencies.homeAssistantService)
            .environment(dependencies.nativeNotificationService)
            .environment(dependencies.nativePermissionService)
            .environment(dependencies.dashboardConfiguration)
            .environment(dependencies.actionConfirmationSettings)
            .environment(dependencies.tabSettings)
            .environment(dependencies.iCloudSyncService)
            .environment(setupCoordinator)
            .environment(setupCoordinator.discoveryService)
            .withPreviewAccentColor(dependencies.appearanceSettings)
    }
}

private struct PreviewAccentColorView<Content: View>: View {
    let content: Content
    let appearanceSettings: HomesteadAppearanceSettings

    var body: some View {
        content
            .environment(appearanceSettings)
            .accentColor(Color(appearanceSettings.appColor.uiColor))
    }
}

private struct PreviewNativeNotificationPermissionClient: NativeNotificationPermissionClient {
    var status: NativeNotificationStatusSnapshot

    func currentStatus() async throws -> NativeNotificationStatusSnapshot {
        status
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func presentNotification(_ request: NativeNotificationRequest) async throws {}
}

private struct PreviewNativePermissionClient: NativePermissionClient {
    var status: NativePermissionStatusSnapshot

    func currentStatus() async throws -> NativePermissionStatusSnapshot {
        status
    }

    func requestCameraAccess() async throws -> NativeCapabilityAuthorizationStatus {
        .allowed
    }

    func requestLocationAccess() async throws -> NativeCapabilityAuthorizationStatus {
        .allowed
    }
}

private extension NativeNotificationStatusSnapshot {
    static let previewAuthorized = NativeNotificationStatusSnapshot(
        authorizationStatus: .authorized,
        alertSetting: .enabled,
        soundSetting: .enabled,
        badgeSetting: .enabled
    )

    static let previewNotDetermined = NativeNotificationStatusSnapshot(
        authorizationStatus: .notDetermined,
        alertSetting: .unknown,
        soundSetting: .unknown,
        badgeSetting: .unknown
    )
}

private extension NativePermissionStatusSnapshot {
    static let previewAllowed = NativePermissionStatusSnapshot(
        camera: .allowed,
        location: .allowed,
        localNetwork: .managedBySystem
    )

    static let previewMixed = NativePermissionStatusSnapshot(
        camera: .notDetermined,
        location: .denied,
        localNetwork: .managedBySystem
    )
}

private enum PreviewData {
    static let entities: [HAEntityDTO] = [
        HAEntityDTO(
            entityID: "light.living_room_lamps",
            state: "on",
            attributes: [
                "friendly_name": .string("Living Room"),
                "brightness": .number(196)
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "light.kitchen_pendants",
            state: "off",
            attributes: [
                "friendly_name": .string("Kitchen")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "light.bedroom",
            state: "on",
            attributes: [
                "friendly_name": .string("Bedroom"),
                "brightness": .number(88)
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "sensor.hallway_temperature",
            state: "72",
            attributes: [
                "friendly_name": .string("Hallway"),
                "device_class": .string("temperature"),
                "unit_of_measurement": .string("F")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "sensor.living_room_humidity",
            state: "44",
            attributes: [
                "friendly_name": .string("Humidity"),
                "device_class": .string("humidity"),
                "unit_of_measurement": .string("%")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "sensor.front_door_battery",
            state: "18",
            attributes: [
                "friendly_name": .string("Front Door Battery"),
                "device_class": .string("battery"),
                "unit_of_measurement": .string("%")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "sensor.laundry_leak",
            state: "off",
            attributes: [
                "friendly_name": .string("Laundry Leak"),
                "device_class": .string("water")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "binary_sensor.front_door",
            state: "on",
            attributes: [
                "friendly_name": .string("Front Door"),
                "device_class": .string("door")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "media_player.living_room",
            state: "playing",
            attributes: [
                "friendly_name": .string("Living Room TV"),
                "volume_level": .number(0.42),
                "source": .string("Apple TV"),
                "source_list": .array([.string("Apple TV"), .string("Music"), .string("Game Console")]),
                "media_title": .string("Morning Mix"),
                "media_artist": .string("Homestead Radio")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "fan.bedroom",
            state: "on",
            attributes: [
                "friendly_name": .string("Bedroom Fan"),
                "percentage": .number(45),
                "percentage_step": .number(5),
                "preset_mode": .string("normal"),
                "preset_modes": .array([.string("sleep"), .string("normal"), .string("boost")])
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "lock.front_door",
            state: "locked",
            attributes: [
                "friendly_name": .string("Front Door")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "camera.driveway",
            state: "idle",
            attributes: [
                "friendly_name": .string("Driveway")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "vacuum.downstairs",
            state: "docked",
            attributes: [
                "friendly_name": .string("Downstairs Vacuum")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "cover.primary_shades",
            state: "open",
            attributes: [
                "friendly_name": .string("Primary Shades"),
                "current_position": .number(72)
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "climate.downstairs",
            state: "heat",
            attributes: [
                "friendly_name": .string("Downstairs"),
                "current_temperature": .number(68),
                "temperature": .number(70),
                "temperature_unit": .string("°F"),
                "min_temp": .number(50),
                "max_temp": .number(90),
                "target_temp_step": .number(1),
                "hvac_modes": .array([
                    .string("off"),
                    .string("heat"),
                    .string("cool"),
                    .string("heat_cool")
                ]),
                "fan_mode": .string("auto"),
                "fan_modes": .array([.string("auto"), .string("low"), .string("high")]),
                "preset_mode": .string("home"),
                "preset_modes": .array([.string("home"), .string("away"), .string("sleep")])
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "weather.home",
            state: "partlycloudy",
            attributes: [
                "friendly_name": .string("Home Weather"),
                "temperature": .number(73),
                "temperature_unit": .string("°F"),
                "humidity": .number(56),
                "wind_speed": .number(8),
                "wind_speed_unit": .string("mph"),
                "wind_bearing": .number(225),
                "supported_features": .number(3),
                "attribution": .string("Weather forecast from met.no, delivered by the Norwegian Meteorological Institute.")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "sun.sun",
            state: "above_horizon",
            attributes: [
                "friendly_name": .string("Sun"),
                "elevation": .number(24)
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "scene.movie_night",
            state: "scening",
            attributes: [
                "friendly_name": .string("Movie Night")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "script.good_morning",
            state: "off",
            attributes: [
                "friendly_name": .string("Good Morning")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "button.restart_router",
            state: "unknown",
            attributes: [
                "friendly_name": .string("Restart Router"),
                "device_class": .string("restart")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "select.house_mode",
            state: "Home",
            attributes: [
                "friendly_name": .string("House Mode"),
                "options": .array([.string("Home"), .string("Away"), .string("Sleep")])
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "number.target_humidity",
            state: "45",
            attributes: [
                "friendly_name": .string("Target Humidity"),
                "device_class": .string("humidity"),
                "unit_of_measurement": .string("%"),
                "min": .number(30),
                "max": .number(60),
                "step": .number(1)
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "input_text.guest_message",
            state: "Welcome home",
            attributes: [
                "friendly_name": .string("Guest Message"),
                "min": .number(0),
                "max": .number(64),
                "mode": .string("text")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "input_datetime.quiet_hours_start",
            state: "22:30:00",
            attributes: [
                "friendly_name": .string("Quiet Hours Start"),
                "has_date": .bool(false),
                "has_time": .bool(true)
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "alarm_control_panel.home",
            state: "armed_home",
            attributes: [
                "friendly_name": .string("Home Alarm")
            ],
            lastUpdated: .now
        ),
        HAEntityDTO(
            entityID: "person.tyler",
            state: "home",
            attributes: [
                "friendly_name": .string("Tyler"),
                "source": .string("device_tracker.tylers_iphone"),
                "entity_picture": .string("/api/image/preview-person")
            ],
            lastChanged: .now.addingTimeInterval(-1_200),
            lastUpdated: .now.addingTimeInterval(-180)
        ),
        HAEntityDTO(
            entityID: "device_tracker.tylers_iphone",
            state: "home",
            attributes: [
                "friendly_name": .string("Tyler's iPhone"),
                "source_type": .string("gps"),
                "tracking_type": .string("position"),
                "location_accuracy": .number(8)
            ],
            lastChanged: .now.addingTimeInterval(-1_200),
            lastUpdated: .now.addingTimeInterval(-180)
        )
    ]
}

struct MissingLivePreviewCredentialsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Preview Credentials Missing", systemImage: "key.slash")
        } description: {
            Text("Add PreviewCredentials.json or save Home Assistant sign-in data in the app Settings screen before using the live preview.")
        }
        .padding()
    }
}

private enum PreviewCredentialProvider {
    private static let bundledCredentialsResource = "PreviewCredentials"

    struct LiveCredential {
        let profile: HAConnectionProfile
        let credential: HAOAuthCredential
    }

    static func liveCredentials() -> [LiveCredential] {
        guard let url = Bundle.main.url(forResource: bundledCredentialsResource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoder = JSONDecoder()
        let entries = (try? decoder.decode(PreviewCredentialsCollection.self, from: data).servers)
            ?? (try? decoder.decode(PreviewCredentialsFile.self, from: data)).map { [$0] }
            ?? []

        return entries.compactMap { credentials in
            let baseURL = credentials.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let accessToken = credentials.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !baseURL.isEmpty, !accessToken.isEmpty else { return nil }
            let profileID = deterministicProfileID(for: baseURL)
            return LiveCredential(
                profile: HAConnectionProfile(
                    id: profileID,
                    serverName: credentials.name,
                    baseURL: baseURL
                ),
                credential: sampleCredential(baseURL: baseURL, accessToken: accessToken)
            )
        }
    }

    private static func deterministicProfileID(for baseURL: String) -> UUID {
        let digest = SHA256.hash(data: Data(baseURL.lowercased().utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    static func sampleCredential(baseURL: String, accessToken: String) -> HAOAuthCredential {
        HAOAuthCredential(
            baseURLString: baseURL,
            clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "preview-refresh-token",
            accessToken: accessToken,
            accessTokenExpiresAt: Date().addingTimeInterval(60 * 60 * 24 * 365),
            tokenType: "Bearer",
            updatedAt: Date()
        )
    }

    private struct PreviewCredentialsFile: Decodable {
        let name: String?
        let baseURL: String
        let accessToken: String
    }

    private struct PreviewCredentialsCollection: Decodable {
        let servers: [PreviewCredentialsFile]
    }
}

private extension UserDefaults {
    static var samplePreview: UserDefaults {
        let defaults = UserDefaults(suiteName: "com.tyler.Homestead.preview.sample") ?? .standard
        defaults.removeObject(forKey: "homeAssistantBaseURL")
        defaults.removeObject(forKey: "dashboardItems")
        defaults.removeObject(forKey: "dashboardEntityIDs")
        defaults.removeObject(forKey: "dashboardCardSizes")
        defaults.removeObject(forKey: "homestead.dashboard.configuration.v2")
        defaults.removeObject(forKey: "homestead.dashboard.selectedDashboardID.v2")
        defaults.removeObject(forKey: "homestead.dashboard.configuration.v3")
        defaults.removeObject(forKey: "homestead.dashboard.selectedDashboardID.v3")
        return defaults
    }

    static var livePreview: UserDefaults {
        UserDefaults(suiteName: "com.tyler.Homestead.preview.live") ?? .standard
    }
}
#endif
