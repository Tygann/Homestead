#if DEBUG
import SwiftUI

@MainActor
struct PreviewDependencies {
    let stateStore: HAStateStore
    let connectionSettings: HAConnectionSettings
    let homeAssistantService: HomeAssistantService

    static var sample: PreviewDependencies {
        let stateStore = HAStateStore()
        stateStore.applyInitialStates(PreviewData.entities)

        let settings = HAConnectionSettings(
            baseURL: "http://homeassistant.local:8123",
            accessToken: "preview-token",
            defaults: .preview,
            credentialStore: InMemoryHACredentialStore()
        )

        let service = HomeAssistantService(
            stateStore: stateStore,
            connectionStatus: .connected
        )

        return PreviewDependencies(
            stateStore: stateStore,
            connectionSettings: settings,
            homeAssistantService: service
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
        )
    ]
}

private extension UserDefaults {
    static var preview: UserDefaults {
        let defaults = UserDefaults(suiteName: "com.tyler.Homestead.preview") ?? .standard
        defaults.removeObject(forKey: "homeAssistantBaseURL")
        return defaults
    }
}
#endif
