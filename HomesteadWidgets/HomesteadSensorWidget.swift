import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadSensorWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadSensorWidget",
            intent: HomesteadSensorWidgetConfigurationIntent.self,
            provider: HomesteadSensorTimelineProvider()
        ) { entry in
            HomesteadSensorWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Sensor")
        .description("Show a Home Assistant sensor on your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadSensorWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Sensor"
    static var description = IntentDescription("Choose a Home Assistant sensor.")

    @Parameter(title: "Sensor")
    var sensor: HomesteadSensorEntity?
}

struct HomesteadSensorEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sensor")
    static var defaultQuery = HomesteadSensorEntityQuery()

    let id: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let unit: String?
    let isNumeric: Bool
    let isAlerting: Bool
    let isAvailable: Bool
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct HomesteadSensorEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadSensorEntity.ID]) async throws -> [HomesteadSensorEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadSensorEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadSensorEntity? {
        allEntities().first
    }

    private func allEntities() -> [HomesteadSensorEntity] {
        HomesteadWidgetSharedStore.sensorSnapshots.map { snapshot in
            HomesteadSensorEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                valueText: snapshot.valueText,
                subtitle: snapshot.subtitle,
                systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
                unit: snapshot.unit,
                isNumeric: snapshot.isNumeric == true,
                isAlerting: snapshot.isAlerting,
                isAvailable: snapshot.isAvailable,
                icon: snapshot.resolvedIcon
            )
        }
    }
}

struct HomesteadSensorEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let isAlerting: Bool
    let isAvailable: Bool
    let isConfigured: Bool
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }
}

struct HomesteadSensorTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadSensorEntry {
        HomesteadSensorEntry(
            date: Date(),
            entityID: "sensor.living_room_temperature",
            displayName: "Living Room",
            valueText: "72°F",
            subtitle: "Temperature",
            systemImage: "thermometer.medium",
            isAlerting: false,
            isAvailable: true,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadSensorWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadSensorEntry {
        await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadSensorWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadSensorEntry> {
        Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(15 * 60))
        )
    }

    private func entry(for configuration: HomesteadSensorWidgetConfigurationIntent) async -> HomesteadSensorEntry {
        let configuredSensor = configuration.sensor
        let latestConfiguredSnapshot = configuredSensor.flatMap { sensor in
            HomesteadWidgetSharedStore.sensorSnapshot(entityID: sensor.id)
        }
        let selectedSensor = latestConfiguredSnapshot.map(Self.entity) ?? configuredSensor
            ?? HomesteadWidgetSharedStore.sensorSnapshots.first.map(Self.entity)

        guard let selectedSensor else {
            return HomesteadSensorEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose a Sensor",
                valueText: "--",
                subtitle: "Open Homestead first",
                systemImage: "gauge.medium",
                isAlerting: false,
                isAvailable: false,
                isConfigured: false
            )
        }

        do {
            let state = try await HAWidgetActionClient().fetchSensorState(entityID: selectedSensor.id)
            return HomesteadSensorEntry(
                date: Date(),
                entityID: state.entityID,
                displayName: state.displayName,
                valueText: state.valueText,
                subtitle: state.subtitle,
                systemImage: state.systemImage,
                isAlerting: state.isAlerting,
                isAvailable: state.isAvailable,
                isConfigured: true,
                icon: state.icon
            )
        } catch {
            return HomesteadSensorEntry(
                date: Date(),
                entityID: selectedSensor.id,
                displayName: selectedSensor.displayName,
                valueText: selectedSensor.valueText,
                subtitle: "Needs connection",
                systemImage: selectedSensor.systemImage,
                isAlerting: selectedSensor.isAlerting,
                isAvailable: selectedSensor.isAvailable,
                isConfigured: true,
                icon: selectedSensor.icon
            )
        }
    }

    private static func entity(from snapshot: WidgetSensorSnapshot) -> HomesteadSensorEntity {
        HomesteadSensorEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            valueText: snapshot.valueText,
            subtitle: snapshot.subtitle,
            systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
            unit: snapshot.unit,
            isNumeric: snapshot.isNumeric == true,
            isAlerting: snapshot.isAlerting,
            isAvailable: snapshot.isAvailable,
            icon: snapshot.resolvedIcon
        )
    }
}

struct HomesteadSensorWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadSensorEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        default:
            systemSmall
        }
    }

    private var systemSmall: some View {
        VStack(alignment: .leading, spacing: 10) {
            sensorIcon

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.valueText)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessoryCircular: some View {
        sensorIcon
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            HomesteadIconView(icon: entry.resolvedIcon, pointSize: 16)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.valueText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var sensorIcon: some View {
        HomesteadIconView(icon: entry.resolvedIcon, pointSize: 22)
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var iconColor: Color {
        if entry.isAlerting {
            return .red
        }

        return entry.isAvailable ? .blue : .secondary
    }
}

#Preview(as: .systemSmall) {
    HomesteadSensorWidget()
} timeline: {
    HomesteadSensorEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "Temperature",
        systemImage: "thermometer.medium",
        isAlerting: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadSensorWidget()
} timeline: {
    HomesteadSensorEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "Temperature",
        systemImage: "thermometer.medium",
        isAlerting: false,
        isAvailable: true,
        isConfigured: true
    )
}
