import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadLightWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadLightWidget",
            intent: HomesteadLightWidgetConfigurationIntent.self,
            provider: HomesteadLightTimelineProvider()
        ) { entry in
            HomesteadLightWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Light")
        .description("Control a Home Assistant light from your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadLightWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Light"
    static var description = IntentDescription("Choose a Home Assistant light.")

    @Parameter(title: "Light")
    var light: HomesteadLightEntity?
}

struct ToggleHomesteadLightIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Light"
    static var description = IntentDescription("Turns a Home Assistant light on or off.")

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
        let previousIsOn = HomesteadWidgetSharedStore.lightSnapshot(entityID: entityID)?.isOn
        HomesteadWidgetSharedStore.updateLightSnapshot(entityID: entityID, isOn: turnOn)
        WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadLightWidget")

        do {
            try await HAWidgetActionClient().setLight(entityID: entityID, isOn: turnOn)
        } catch {
            if let previousIsOn {
                HomesteadWidgetSharedStore.updateLightSnapshot(entityID: entityID, isOn: previousIsOn)
                WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadLightWidget")
            }

            throw error
        }

        return .result()
    }
}

struct HomesteadLightEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Light")
    static var defaultQuery = HomesteadLightEntityQuery()

    let id: String
    let displayName: String
    let isOn: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct HomesteadLightEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadLightEntity.ID]) async throws -> [HomesteadLightEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadLightEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadLightEntity? {
        allEntities().first
    }

    private func allEntities() -> [HomesteadLightEntity] {
        HomesteadWidgetSharedStore.lightSnapshots.map { snapshot in
            HomesteadLightEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: snapshot.isOn
            )
        }
    }
}

struct HomesteadLightEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let isOn: Bool
    let statusText: String
    let isConfigured: Bool
}

struct HomesteadLightTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadLightEntry {
        HomesteadLightEntry(
            date: Date(),
            entityID: "light.lamp",
            displayName: "Lamp",
            isOn: true,
            statusText: "On",
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadLightWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadLightEntry {
        await entry(for: configuration).entry
    }

    func timeline(
        for configuration: HomesteadLightWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadLightEntry> {
        let result = await entry(for: configuration)
        let refreshInterval: TimeInterval = result.usedOptimisticState ? 30 : 15 * 60

        return Timeline(
            entries: [result.entry],
            policy: .after(Date().addingTimeInterval(refreshInterval))
        )
    }

    private func entry(for configuration: HomesteadLightWidgetConfigurationIntent) async -> TimelineResult {
        let configuredLight = configuration.light
        let latestConfiguredSnapshot = configuredLight.flatMap { light in
            HomesteadWidgetSharedStore.lightSnapshot(entityID: light.id)
        }
        let selectedLight = latestConfiguredSnapshot.map { snapshot in
            HomesteadLightEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: snapshot.isOn
            )
        } ?? configuredLight ?? HomesteadWidgetSharedStore.lightSnapshots.first.map { snapshot in
            HomesteadLightEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: snapshot.isOn
            )
        }

        guard let selectedLight else {
            return TimelineResult(
                entry: HomesteadLightEntry(
                    date: Date(),
                    entityID: nil,
                    displayName: "Choose a Light",
                    isOn: false,
                    statusText: "Open Homestead first",
                    isConfigured: false
                ),
                usedOptimisticState: false
            )
        }

        if let isOn = HomesteadWidgetSharedStore.optimisticLightState(entityID: selectedLight.id) {
            return TimelineResult(
                entry: HomesteadLightEntry(
                    date: Date(),
                    entityID: selectedLight.id,
                    displayName: selectedLight.displayName,
                    isOn: isOn,
                    statusText: isOn ? "On" : "Off",
                    isConfigured: true
                ),
                usedOptimisticState: true
            )
        }

        do {
            let state = try await HAWidgetActionClient().fetchLightState(entityID: selectedLight.id)

            return TimelineResult(
                entry: HomesteadLightEntry(
                    date: Date(),
                    entityID: state.entityID,
                    displayName: state.displayName,
                    isOn: state.isOn,
                    statusText: state.isOn ? "On" : "Off",
                    isConfigured: true
                ),
                usedOptimisticState: false
            )
        } catch {
            return TimelineResult(
                entry: HomesteadLightEntry(
                    date: Date(),
                    entityID: selectedLight.id,
                    displayName: selectedLight.displayName,
                    isOn: selectedLight.isOn,
                    statusText: "Needs connection",
                    isConfigured: true
                ),
                usedOptimisticState: false
            )
        }
    }

    private struct TimelineResult {
        let entry: HomesteadLightEntry
        let usedOptimisticState: Bool
    }
}

struct HomesteadLightWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadLightEntry

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
            Image(systemName: entry.isOn ? "lightbulb.fill" : "lightbulb")
                .foregroundStyle(entry.isOn ? .yellow : .secondary)

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
        if let entityID = entry.entityID, entry.isConfigured {
            Button(intent: ToggleHomesteadLightIntent(entityID: entityID, turnOn: !entry.isOn)) {
                lightIcon
            }
            .buttonStyle(.plain)
        } else {
            lightIcon
        }
    }

    private var lightIcon: some View {
        Image(systemName: entry.isOn ? "lightbulb.fill" : "lightbulb")
            .font(.title2.weight(.semibold))
            .foregroundStyle(entry.isOn ? .yellow : .secondary)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

@main
struct HomesteadWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HomesteadLightWidget()
        HomesteadSwitchWidget()
    }
}

#Preview(as: .systemSmall) {
    HomesteadLightWidget()
} timeline: {
    HomesteadLightEntry(
        date: .now,
        entityID: "light.bed_lamp",
        displayName: "Bed Lamp",
        isOn: true,
        statusText: "On",
        isConfigured: true
    )
    HomesteadLightEntry(
        date: .now,
        entityID: "light.back_yard",
        displayName: "Back Yard Lights",
        isOn: false,
        statusText: "Off",
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadLightWidget()
} timeline: {
    HomesteadLightEntry(
        date: .now,
        entityID: "light.bed_lamp",
        displayName: "Bed Lamp",
        isOn: true,
        statusText: "On",
        isConfigured: true
    )
}

#Preview(as: .accessoryCircular) {
    HomesteadLightWidget()
} timeline: {
    HomesteadLightEntry(
        date: .now,
        entityID: "light.bed_lamp",
        displayName: "Bed Lamp",
        isOn: true,
        statusText: "On",
        isConfigured: true
    )
}
