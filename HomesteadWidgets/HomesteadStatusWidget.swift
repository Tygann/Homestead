import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadStatusWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadStatusWidget",
            intent: HomesteadStatusWidgetConfigurationIntent.self,
            provider: HomesteadStatusTimelineProvider()
        ) { entry in
            HomesteadStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Status")
        .description("Show a Home Assistant sensor or person status.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadStatusWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Status"
    static var description = IntentDescription("Choose a Home Assistant status entity.")

    @Parameter(title: "Entity")
    var entity: HomesteadStatusEntity?
}

struct HomesteadStatusEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Status")
    static var defaultQuery = HomesteadStatusEntityQuery()

    let id: String
    let domain: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let isHighlighted: Bool
    let isAlerting: Bool
    let isAvailable: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(domain) • \(id)")
    }
}

struct HomesteadStatusEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadStatusEntity.ID]) async throws -> [HomesteadStatusEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadStatusEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadStatusEntity? {
        nil
    }

    private func allEntities() -> [HomesteadStatusEntity] {
        HomesteadStatusSnapshotBuilder.entities()
    }
}

struct HomesteadStatusEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let domain: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let isHighlighted: Bool
    let isAlerting: Bool
    let isAvailable: Bool
    let isConfigured: Bool
}

struct HomesteadStatusTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadStatusEntry {
        HomesteadStatusEntry(
            date: Date(),
            entityID: "sensor.living_room_temperature",
            domain: "sensor",
            displayName: "Living Room",
            valueText: "72°F",
            subtitle: "Temperature",
            systemImage: "thermometer.medium",
            isHighlighted: false,
            isAlerting: false,
            isAvailable: true,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadStatusWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadStatusEntry {
        if context.isPreview, configuration.entity == nil {
            return placeholder(in: context)
        }

        return await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadStatusWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadStatusEntry> {
        if context.isPreview, configuration.entity == nil {
            return Timeline(
                entries: [placeholder(in: context)],
                policy: .after(Date().addingTimeInterval(15 * 60))
            )
        }

        return Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(15 * 60))
        )
    }

    private func entry(for configuration: HomesteadStatusWidgetConfigurationIntent) async -> HomesteadStatusEntry {
        let configuredEntity = configuration.entity
        let latestConfiguredEntity = configuredEntity.flatMap { entity in
            HomesteadStatusSnapshotBuilder.entity(entityID: entity.id)
        }
        let selectedEntity = latestConfiguredEntity
            ?? configuredEntity

        guard let selectedEntity else {
            return HomesteadStatusEntry(
                date: Date(),
                entityID: nil,
                domain: "status",
                displayName: "Choose a Status",
                valueText: "--",
                subtitle: "Open Homestead first",
                systemImage: "gauge.medium",
                isHighlighted: false,
                isAlerting: false,
                isAvailable: false,
                isConfigured: false
            )
        }

        do {
            return try await liveEntry(for: selectedEntity)
        } catch {
            return HomesteadStatusEntry(
                date: Date(),
                entityID: selectedEntity.id,
                domain: selectedEntity.domain,
                displayName: selectedEntity.displayName,
                valueText: selectedEntity.valueText,
                subtitle: "Needs connection",
                systemImage: selectedEntity.systemImage,
                isHighlighted: selectedEntity.isHighlighted,
                isAlerting: selectedEntity.isAlerting,
                isAvailable: selectedEntity.isAvailable,
                isConfigured: true
            )
        }
    }

    private func liveEntry(for entity: HomesteadStatusEntity) async throws -> HomesteadStatusEntry {
        switch entity.domain {
        case "sensor":
            let state = try await HAWidgetActionClient().fetchSensorState(entityID: entity.id)
            return HomesteadStatusEntry(
                date: Date(),
                entityID: state.entityID,
                domain: entity.domain,
                displayName: state.displayName,
                valueText: state.valueText,
                subtitle: state.subtitle,
                systemImage: state.systemImage,
                isHighlighted: false,
                isAlerting: state.isAlerting,
                isAvailable: state.isAvailable,
                isConfigured: true
            )
        case "person":
            let state = try await HAWidgetActionClient().fetchPresenceState(entityID: entity.id)
            return HomesteadStatusEntry(
                date: Date(),
                entityID: state.entityID,
                domain: entity.domain,
                displayName: state.displayName,
                valueText: state.statusText,
                subtitle: "Presence",
                systemImage: state.systemImage,
                isHighlighted: state.isHome,
                isAlerting: false,
                isAvailable: state.isAvailable,
                isConfigured: true
            )
        default:
            throw HAWidgetActionError.unexpectedResponse
        }
    }
}

private enum HomesteadStatusSnapshotBuilder {
    static func entities() -> [HomesteadStatusEntity] {
        sensorEntities() + presenceEntities()
    }

    static func entity(entityID: String) -> HomesteadStatusEntity? {
        entities().first { $0.id == entityID }
    }

    private static func sensorEntities() -> [HomesteadStatusEntity] {
        HomesteadWidgetSharedStore.sensorSnapshots.map { snapshot in
            HomesteadStatusEntity(
                id: snapshot.entityID,
                domain: "sensor",
                displayName: snapshot.displayName,
                valueText: snapshot.valueText,
                subtitle: snapshot.subtitle,
                systemImage: snapshot.systemImage,
                isHighlighted: false,
                isAlerting: snapshot.isAlerting,
                isAvailable: snapshot.isAvailable
            )
        }
    }

    private static func presenceEntities() -> [HomesteadStatusEntity] {
        HomesteadWidgetSharedStore.presenceSnapshots.map { snapshot in
            HomesteadStatusEntity(
                id: snapshot.entityID,
                domain: "person",
                displayName: snapshot.displayName,
                valueText: snapshot.statusText,
                subtitle: "Presence",
                systemImage: snapshot.systemImage,
                isHighlighted: snapshot.isHome,
                isAlerting: false,
                isAvailable: snapshot.isAvailable
            )
        }
    }
}

struct HomesteadStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadStatusEntry

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
            statusIcon

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.valueText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(entry.domain == "person" ? iconColor : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let supportingText {
                    Text(supportingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessoryCircular: some View {
        statusIcon
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.systemImage)
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

    private var statusIcon: some View {
        Image(systemName: entry.systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var iconColor: Color {
        guard entry.isAvailable else {
            return .secondary
        }

        if entry.isAlerting {
            return .red
        }

        if entry.domain == "person" {
            return entry.isHighlighted ? .green : .secondary
        }

        return .accentColor
    }

    private var supportingText: String? {
        guard entry.isConfigured else {
            return entry.subtitle
        }

        guard entry.isAvailable else {
            return "Unavailable"
        }

        guard entry.domain == "sensor" else {
            return nil
        }

        let trimmedSubtitle = entry.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubtitle.isEmpty, trimmedSubtitle != entry.valueText else {
            return nil
        }

        if entry.isAlerting {
            return trimmedSubtitle
        }

        let lowercaseSubtitle = trimmedSubtitle.localizedLowercase
        if lowercaseSubtitle.contains("connection") || lowercaseSubtitle.contains("unavailable") {
            return trimmedSubtitle
        }

        return nil
    }
}

#Preview(as: .systemSmall) {
    HomesteadStatusWidget()
} timeline: {
    HomesteadStatusEntry(
        date: .now,
        entityID: "sensor.living_room_temperature",
        domain: "sensor",
        displayName: "Living Room",
        valueText: "72°F",
        subtitle: "Temperature",
        systemImage: "thermometer.medium",
        isHighlighted: false,
        isAlerting: false,
        isAvailable: true,
        isConfigured: true
    )
    HomesteadStatusEntry(
        date: .now,
        entityID: "person.tyler",
        domain: "person",
        displayName: "Tyler",
        valueText: "Home",
        subtitle: "Presence",
        systemImage: "person.fill",
        isHighlighted: true,
        isAlerting: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadStatusWidget()
} timeline: {
    HomesteadStatusEntry(
        date: .now,
        entityID: "person.tyler",
        domain: "person",
        displayName: "Tyler",
        valueText: "Home",
        subtitle: "Presence",
        systemImage: "person.fill",
        isHighlighted: true,
        isAlerting: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryCircular) {
    HomesteadStatusWidget()
} timeline: {
    HomesteadStatusEntry(
        date: .now,
        entityID: "sensor.battery",
        domain: "sensor",
        displayName: "Battery",
        valueText: "18%",
        subtitle: "Low Battery",
        systemImage: "battery.75percent",
        isHighlighted: false,
        isAlerting: true,
        isAvailable: true,
        isConfigured: true
    )
}
