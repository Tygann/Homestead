#if DEBUG
import SwiftUI

@MainActor
struct PreviewDependencies {
    let stateStore: HAStateStore
    let connectionSettings: HAConnectionSettings
    let homeAssistantService: HomeAssistantService
    let dashboardConfiguration: DashboardConfiguration

    static var sample: PreviewDependencies {
        let previewDefaults = UserDefaults.samplePreview
        let stateStore = HAStateStore()
        stateStore.applyInitialStates(PreviewData.entities)
        let dashboardConfiguration = DashboardConfiguration(defaults: previewDefaults)
        dashboardConfiguration.reset(using: stateStore.allEntities)

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

        let service = HomeAssistantService(
            stateStore: stateStore,
            connectionStatus: .connected,
            authState: .signedIn(HAAuthSessionSummary(credential: credential)),
            mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
            authManager: HAOAuthManager(tokenStore: tokenStore)
        )

        return PreviewDependencies(
            stateStore: stateStore,
            connectionSettings: settings,
            homeAssistantService: service,
            dashboardConfiguration: dashboardConfiguration
        )
    }

    static var liveHomeAssistant: PreviewDependencies? {
        let previewDefaults = UserDefaults.livePreview
        let stateStore = HAStateStore()
        let dashboardConfiguration = DashboardConfiguration(defaults: previewDefaults)

        if let credential = PreviewCredentialProvider.liveCredential() {
            let tokenStore = InMemoryHAOAuthTokenStore(credential: credential)
            let settings = HAConnectionSettings(
                baseURL: credential.baseURLString,
                defaults: previewDefaults,
                tokenStore: tokenStore
            )
            let service = HomeAssistantService(
                stateStore: stateStore,
                authState: .signedIn(HAAuthSessionSummary(credential: credential)),
                mobileAppRegistrationStore: InMemoryHAMobileAppRegistrationStore(),
                authManager: HAOAuthManager(tokenStore: tokenStore)
            )

            return PreviewDependencies(
                stateStore: stateStore,
                connectionSettings: settings,
                homeAssistantService: service,
                dashboardConfiguration: dashboardConfiguration
            )
        }

        let settings = HAConnectionSettings(defaults: previewDefaults)

        guard settings.hasServerURL else {
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
            Text("Add PreviewCredentials.json or save Home Assistant sign-in data in the app Settings screen before using the live preview.")
        }
        .padding()
    }
}

private enum PreviewCredentialProvider {
    private static let bundledCredentialsResource = "PreviewCredentials"

    static func liveCredential() -> HAOAuthCredential? {
        bundledCredential()
    }

    private static func bundledCredential() -> HAOAuthCredential? {
        guard let url = Bundle.main.url(forResource: bundledCredentialsResource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let credentials = try? JSONDecoder().decode(PreviewCredentialsFile.self, from: data) else {
            return nil
        }

        let baseURL = credentials.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = credentials.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty, !accessToken.isEmpty else {
            return nil
        }

        return sampleCredential(baseURL: baseURL, accessToken: accessToken)
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
        let baseURL: String
        let accessToken: String
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
