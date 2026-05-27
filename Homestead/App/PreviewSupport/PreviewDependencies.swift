#if DEBUG
import SwiftUI

@MainActor
struct PreviewDependencies {
    let stateStore: HAStateStore
    let connectionSettings: HAConnectionSettings
    let homeAssistantService: HomeAssistantService
    let dashboardConfiguration: DashboardConfiguration
    let dashboardPreferences: DashboardPreferences
    let pinnedEntityStore: PinnedEntityStore

    static var sample: PreviewDependencies {
        let previewDefaults = UserDefaults.samplePreview
        let stateStore = HAStateStore()
        stateStore.applyInitialStates(PreviewData.entities)
        let dashboardConfiguration = DashboardConfiguration(defaults: previewDefaults)
        dashboardConfiguration.reset(using: stateStore.allEntities)
        let dashboardPreferences = DashboardPreferences(defaults: previewDefaults)
        let pinnedEntityStore = PinnedEntityStore(defaults: previewDefaults)
        pinnedEntityStore.toggle("light.living_room_lamps")
        pinnedEntityStore.toggle("climate.downstairs")

        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            accessToken: "preview-token",
            defaults: previewDefaults,
            credentialStore: InMemoryHACredentialStore()
        )

        let service = HomeAssistantService(
            stateStore: stateStore,
            connectionStatus: .connected,
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore()
        )

        return PreviewDependencies(
            stateStore: stateStore,
            connectionSettings: settings,
            homeAssistantService: service,
            dashboardConfiguration: dashboardConfiguration,
            dashboardPreferences: dashboardPreferences,
            pinnedEntityStore: pinnedEntityStore
        )
    }

    static var liveHomeAssistant: PreviewDependencies? {
        let previewDefaults = UserDefaults.livePreview
        let stateStore = HAStateStore()
        let dashboardConfiguration = DashboardConfiguration(defaults: previewDefaults)
        let dashboardPreferences = DashboardPreferences(defaults: previewDefaults)
        let pinnedEntityStore = PinnedEntityStore(defaults: previewDefaults)

        let settings = PreviewCredentialProvider.environmentSettings ??
            HAConnectionSettings(defaults: previewDefaults)

        guard settings.hasCredentials else {
            return nil
        }

        let service = HomeAssistantService(
            stateStore: stateStore,
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore()
        )

        return PreviewDependencies(
            stateStore: stateStore,
            connectionSettings: settings,
            homeAssistantService: service,
            dashboardConfiguration: dashboardConfiguration,
            dashboardPreferences: dashboardPreferences,
            pinnedEntityStore: pinnedEntityStore
        )
    }
}

extension View {
    @MainActor
    func withPreviewEnvironment() -> some View {
        withPreviewEnvironment(.sample)
    }

    @MainActor
    func withPreviewEnvironment(_ dependencies: PreviewDependencies) -> some View {
        environment(dependencies.stateStore)
            .environment(dependencies.connectionSettings)
            .environment(dependencies.homeAssistantService)
            .environment(dependencies.dashboardConfiguration)
            .environment(dependencies.dashboardPreferences)
            .environment(dependencies.pinnedEntityStore)
    }
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
                "friendly_name": .string("Living Room TV")
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
                ])
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
        )
    ]
}

struct MissingLivePreviewCredentialsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Preview Credentials Missing", systemImage: "key.slash")
        } description: {
            Text("Save credentials in the app Settings screen, or set HOMESTEAD_PREVIEW_HA_BASE_URL and HOMESTEAD_PREVIEW_HA_TOKEN in your local Xcode environment.")
        }
        .padding()
    }
}

private enum PreviewCredentialProvider {
    private static let baseURLKey = "HOMESTEAD_PREVIEW_HA_BASE_URL"
    private static let tokenKey = "HOMESTEAD_PREVIEW_HA_TOKEN"

    @MainActor
    static var environmentSettings: HAConnectionSettings? {
        let environment = ProcessInfo.processInfo.environment

        guard let baseURL = environment[baseURLKey], !baseURL.isEmpty,
              let token = environment[tokenKey], !token.isEmpty else {
            return nil
        }

        return HAConnectionSettings(
            baseURL: baseURL,
            accessToken: token,
            defaults: .livePreview,
            credentialStore: InMemoryHACredentialStore()
        )
    }
}

private extension UserDefaults {
    static var samplePreview: UserDefaults {
        let defaults = UserDefaults(suiteName: "com.tyler.Homestead.preview.sample") ?? .standard
        defaults.removeObject(forKey: "homeAssistantBaseURL")
        defaults.removeObject(forKey: "dashboardItems")
        defaults.removeObject(forKey: "dashboardEntityIDs")
        defaults.removeObject(forKey: "dashboardCardSizes")
        defaults.removeObject(forKey: "dashboard.density")
        defaults.removeObject(forKey: "dashboard.showsOnlyActiveDevices")
        defaults.removeObject(forKey: "dashboard.pinnedEntityIDs")
        return defaults
    }

    static var livePreview: UserDefaults {
        UserDefaults(suiteName: "com.tyler.Homestead.preview.live") ?? .standard
    }
}
#endif
