import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadFanWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadFanWidget",
            intent: HomesteadFanWidgetConfigurationIntent.self,
            provider: HomesteadFanTimelineProvider()
        ) { entry in
            HomesteadFanWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Fan")
        .description("Control a Home Assistant fan from your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadFanWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Fan"
    static var description = IntentDescription("Choose a Home Assistant fan.")

    @Parameter(title: "Fan")
    var selectedFan: HomesteadFanEntity?
}

struct ToggleHomesteadFanIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Fan"
    static var description = IntentDescription("Turns a Home Assistant fan on or off.")

    @Parameter(title: "Entity ID")
    var entityID: String

    @Parameter(title: "Turn On")
    var turnOn: Bool

    init() {}

    init(entityID: String, turnOn: Bool) {
        self.entityID = entityID
        self.turnOn = turnOn
    }

    func perform() async throws -> some IntentResult {
        let previousIsOn = HomesteadWidgetSharedStore.fanSnapshot(entityID: entityID)?.isOn
        HomesteadWidgetSharedStore.updateFanSnapshot(entityID: entityID, isOn: turnOn)
        WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadFanWidget")

        do {
            try await HAWidgetActionClient().setFan(entityID: entityID, isOn: turnOn)
        } catch {
            if let previousIsOn {
                HomesteadWidgetSharedStore.updateFanSnapshot(entityID: entityID, isOn: previousIsOn)
                WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadFanWidget")
            }

            throw error
        }

        return .result()
    }
}

struct HomesteadFanEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Fan")
    static var defaultQuery = HomesteadFanEntityQuery()

    let id: String
    let displayName: String
    let isOn: Bool
    let statusText: String
    let isAvailable: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct HomesteadFanEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadFanEntity.ID]) async throws -> [HomesteadFanEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadFanEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadFanEntity? {
        allEntities().first
    }

    private func allEntities() -> [HomesteadFanEntity] {
        HomesteadWidgetSharedStore.fanSnapshots.map(Self.entity)
    }

    private static func entity(from snapshot: WidgetFanSnapshot) -> HomesteadFanEntity {
        HomesteadFanEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            isOn: snapshot.isOn,
            statusText: snapshot.statusText,
            isAvailable: snapshot.isAvailable
        )
    }
}

struct HomesteadFanEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let isOn: Bool
    let statusText: String
    let isAvailable: Bool
    let isConfigured: Bool
}

struct HomesteadFanTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadFanEntry {
        HomesteadFanEntry(
            date: Date(),
            entityID: "fan.bedroom",
            displayName: "Bedroom Fan",
            isOn: true,
            statusText: "On • 50%",
            isAvailable: true,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadFanWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadFanEntry {
        await entry(for: configuration).entry
    }

    func timeline(
        for configuration: HomesteadFanWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadFanEntry> {
        let result = await entry(for: configuration)
        let refreshInterval: TimeInterval = result.usedOptimisticState ? 30 : 15 * 60

        return Timeline(
            entries: [result.entry],
            policy: .after(Date().addingTimeInterval(refreshInterval))
        )
    }

    private func entry(for configuration: HomesteadFanWidgetConfigurationIntent) async -> TimelineResult {
        let configuredFan = configuration.selectedFan
        let latestConfiguredSnapshot = configuredFan.flatMap { fan in
            HomesteadWidgetSharedStore.fanSnapshot(entityID: fan.id)
        }
        let selectedFan = latestConfiguredSnapshot.map(Self.entity)
            ?? configuredFan
            ?? HomesteadWidgetSharedStore.fanSnapshots.first.map(Self.entity)

        guard let selectedFan else {
            return TimelineResult(
                entry: HomesteadFanEntry(
                    date: Date(),
                    entityID: nil,
                    displayName: "Choose a Fan",
                    isOn: false,
                    statusText: "Open Homestead first",
                    isAvailable: false,
                    isConfigured: false
                ),
                usedOptimisticState: false
            )
        }

        if let isOn = HomesteadWidgetSharedStore.optimisticFanState(entityID: selectedFan.id) {
            return TimelineResult(
                entry: HomesteadFanEntry(
                    date: Date(),
                    entityID: selectedFan.id,
                    displayName: selectedFan.displayName,
                    isOn: isOn,
                    statusText: isOn ? "On" : "Off",
                    isAvailable: selectedFan.isAvailable,
                    isConfigured: true
                ),
                usedOptimisticState: true
            )
        }

        do {
            let state = try await HAWidgetActionClient().fetchFanState(entityID: selectedFan.id)

            return TimelineResult(
                entry: HomesteadFanEntry(
                    date: Date(),
                    entityID: state.entityID,
                    displayName: state.displayName,
                    isOn: state.isOn,
                    statusText: state.statusText,
                    isAvailable: state.isAvailable,
                    isConfigured: true
                ),
                usedOptimisticState: false
            )
        } catch {
            return TimelineResult(
                entry: HomesteadFanEntry(
                    date: Date(),
                    entityID: selectedFan.id,
                    displayName: selectedFan.displayName,
                    isOn: selectedFan.isOn,
                    statusText: "Needs connection",
                    isAvailable: selectedFan.isAvailable,
                    isConfigured: true
                ),
                usedOptimisticState: false
            )
        }
    }

    private static func entity(from snapshot: WidgetFanSnapshot) -> HomesteadFanEntity {
        HomesteadFanEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            isOn: snapshot.isOn,
            statusText: snapshot.statusText,
            isAvailable: snapshot.isAvailable
        )
    }

    private struct TimelineResult {
        let entry: HomesteadFanEntry
        let usedOptimisticState: Bool
    }
}

struct HomesteadFanWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadFanEntry

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
            widgetButton

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(entry.isOn ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessoryCircular: some View {
        widgetButton
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "fan.fill")
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var widgetButton: some View {
        if let entityID = entry.entityID, entry.isConfigured, entry.isAvailable {
            Button(intent: ToggleHomesteadFanIntent(entityID: entityID, turnOn: !entry.isOn)) {
                fanIcon
            }
            .buttonStyle(.plain)
        } else {
            fanIcon
        }
    }

    private var fanIcon: some View {
        Image(systemName: "fan.fill")
            .font(.title2.weight(.semibold))
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var iconColor: Color {
        guard entry.isAvailable else {
            return .secondary
        }

        return entry.isOn ? .teal : .secondary
    }
}

#Preview(as: .systemSmall) {
    HomesteadFanWidget()
} timeline: {
    HomesteadFanEntry(
        date: .now,
        entityID: "fan.bedroom",
        displayName: "Bedroom Fan",
        isOn: true,
        statusText: "On • 50%",
        isAvailable: true,
        isConfigured: true
    )
    HomesteadFanEntry(
        date: .now,
        entityID: "fan.office",
        displayName: "Office Fan",
        isOn: false,
        statusText: "Off",
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadFanWidget()
} timeline: {
    HomesteadFanEntry(
        date: .now,
        entityID: "fan.bedroom",
        displayName: "Bedroom Fan",
        isOn: true,
        statusText: "On • 50%",
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryCircular) {
    HomesteadFanWidget()
} timeline: {
    HomesteadFanEntry(
        date: .now,
        entityID: "fan.bedroom",
        displayName: "Bedroom Fan",
        isOn: true,
        statusText: "On • 50%",
        isAvailable: true,
        isConfigured: true
    )
}
