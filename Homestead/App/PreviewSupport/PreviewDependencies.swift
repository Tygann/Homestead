#if DEBUG
import SwiftUI

@MainActor
struct PreviewDependencies {
    let stateStore: HAStateStore
    let connectionSettings: HAConnectionSettings
    let homeAssistantService: HomeAssistantService
    let dashboardConfiguration: DashboardConfiguration

    static var sample: PreviewDependencies {
        let stateStore = HAStateStore()
        stateStore.applyInitialStates(PreviewData.entities)
        let dashboardConfiguration = DashboardConfiguration(defaults: .samplePreview)
        dashboardConfiguration.reset(using: stateStore.allEntities)

        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            accessToken: "preview-token",
            defaults: .samplePreview,
            credentialStore: InMemoryHACredentialStore()
        )

        let service = HomeAssistantService(
            stateStore: stateStore,
            connectionStatus: .connected
        )

        return PreviewDependencies(
            stateStore: stateStore,
            connectionSettings: settings,
            homeAssistantService: service,
            dashboardConfiguration: dashboardConfiguration
        )
    }

    static var liveHomeAssistant: PreviewDependencies? {
        let stateStore = HAStateStore()
        let dashboardConfiguration = DashboardConfiguration(defaults: .livePreview)

        let settings = PreviewCredentialProvider.environmentSettings ??
            HAConnectionSettings(defaults: .standard)

        guard settings.hasCredentials else {
            return nil
        }

        let service = HomeAssistantService(stateStore: stateStore)

        return PreviewDependencies(
            stateStore: stateStore,
            connectionSettings: settings,
            homeAssistantService: service,
            dashboardConfiguration: dashboardConfiguration
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
                "friendly_name": .string("Downstairs")
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
        return defaults
    }

    static var livePreview: UserDefaults {
        UserDefaults(suiteName: "com.tyler.Homestead.preview.live") ?? .standard
    }
}
#endif
