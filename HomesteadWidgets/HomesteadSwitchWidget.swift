import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadSwitchWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadSwitchWidget",
            intent: HomesteadSwitchWidgetConfigurationIntent.self,
            provider: HomesteadSwitchTimelineProvider()
        ) { entry in
            HomesteadSwitchWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Switch")
        .description("Control a Home Assistant switch from your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadSwitchWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Switch"
    static var description = IntentDescription("Choose a Home Assistant switch.")

    @Parameter(title: "Switch")
    var selectedSwitch: HomesteadSwitchEntity?
}

struct ToggleHomesteadSwitchIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Switch"
    static var description = IntentDescription("Turns a Home Assistant switch on or off.")

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
        let previousIsOn = HomesteadWidgetSharedStore.switchSnapshot(entityID: entityID)?.isOn
        HomesteadWidgetSharedStore.updateSwitchSnapshot(entityID: entityID, isOn: turnOn)
        WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadSwitchWidget")

        do {
            try await HAWidgetActionClient().setSwitch(entityID: entityID, isOn: turnOn)
        } catch {
            if let previousIsOn {
                HomesteadWidgetSharedStore.updateSwitchSnapshot(entityID: entityID, isOn: previousIsOn)
                WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadSwitchWidget")
            }

            throw error
        }

        return .result()
    }
}

struct HomesteadSwitchEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Switch")
    static var defaultQuery = HomesteadSwitchEntityQuery()

    let id: String
    let displayName: String
    let isOn: Bool
    let systemImage: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct HomesteadSwitchEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadSwitchEntity.ID]) async throws -> [HomesteadSwitchEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadSwitchEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadSwitchEntity? {
        allEntities().first
    }

    private func allEntities() -> [HomesteadSwitchEntity] {
        HomesteadWidgetSharedStore.switchSnapshots.map { snapshot in
            HomesteadSwitchEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: snapshot.isOn,
                systemImage: snapshot.systemImage
            )
        }
    }
}

struct HomesteadSwitchEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let isOn: Bool
    let statusText: String
    let systemImage: String
    let isConfigured: Bool
}

struct HomesteadSwitchTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadSwitchEntry {
        HomesteadSwitchEntry(
            date: Date(),
            entityID: "switch.coffee",
            displayName: "Coffee",
            isOn: true,
            statusText: "On",
            systemImage: "lightswitch.on.fill",
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadSwitchWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadSwitchEntry {
        await entry(for: configuration).entry
    }

    func timeline(
        for configuration: HomesteadSwitchWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadSwitchEntry> {
        let result = await entry(for: configuration)
        let refreshInterval: TimeInterval = result.usedOptimisticState ? 30 : 15 * 60

        return Timeline(
            entries: [result.entry],
            policy: .after(Date().addingTimeInterval(refreshInterval))
        )
    }

    private func entry(for configuration: HomesteadSwitchWidgetConfigurationIntent) async -> TimelineResult {
        let configuredSwitch = configuration.selectedSwitch
        let latestConfiguredSnapshot = configuredSwitch.flatMap { selectedSwitch in
            HomesteadWidgetSharedStore.switchSnapshot(entityID: selectedSwitch.id)
        }
        let selectedSwitch = latestConfiguredSnapshot.map { snapshot in
            HomesteadSwitchEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: snapshot.isOn,
                systemImage: snapshot.systemImage
            )
        } ?? configuredSwitch ?? HomesteadWidgetSharedStore.switchSnapshots.first.map { snapshot in
            HomesteadSwitchEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                isOn: snapshot.isOn,
                systemImage: snapshot.systemImage
            )
        }

        guard let selectedSwitch else {
            return TimelineResult(
                entry: HomesteadSwitchEntry(
                    date: Date(),
                    entityID: nil,
                    displayName: "Choose a Switch",
                    isOn: false,
                    statusText: "Open Homestead first",
                    systemImage: "lightswitch.off.fill",
                    isConfigured: false
                ),
                usedOptimisticState: false
            )
        }

        if let isOn = HomesteadWidgetSharedStore.optimisticSwitchState(entityID: selectedSwitch.id) {
            return TimelineResult(
                entry: HomesteadSwitchEntry(
                    date: Date(),
                    entityID: selectedSwitch.id,
                    displayName: selectedSwitch.displayName,
                    isOn: isOn,
                    statusText: isOn ? "On" : "Off",
                    systemImage: switchSystemImage(isOn: isOn, fallback: selectedSwitch.systemImage),
                    isConfigured: true
                ),
                usedOptimisticState: true
            )
        }

        do {
            let state = try await HAWidgetActionClient().fetchSwitchState(entityID: selectedSwitch.id)

            return TimelineResult(
                entry: HomesteadSwitchEntry(
                    date: Date(),
                    entityID: state.entityID,
                    displayName: state.displayName,
                    isOn: state.isOn,
                    statusText: statusText(for: state.state),
                    systemImage: state.systemImage,
                    isConfigured: true
                ),
                usedOptimisticState: false
            )
        } catch {
            return TimelineResult(
                entry: HomesteadSwitchEntry(
                    date: Date(),
                    entityID: selectedSwitch.id,
                    displayName: selectedSwitch.displayName,
                    isOn: selectedSwitch.isOn,
                    statusText: "Needs connection",
                    systemImage: selectedSwitch.systemImage,
                    isConfigured: true
                ),
                usedOptimisticState: false
            )
        }
    }

    private func statusText(for state: String) -> String {
        switch state {
        case "on":
            "On"
        case "off":
            "Off"
        case "unavailable":
            "Unavailable"
        case "unknown":
            "Unknown"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func switchSystemImage(isOn: Bool, fallback: String) -> String {
        guard fallback == "lightswitch.on.fill" || fallback == "lightswitch.off.fill" else {
            return fallback
        }

        return isOn ? "lightswitch.on.fill" : "lightswitch.off.fill"
    }

    private struct TimelineResult {
        let entry: HomesteadSwitchEntry
        let usedOptimisticState: Bool
    }
}

struct HomesteadSwitchWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadSwitchEntry

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
            Image(systemName: entry.systemImage)
                .foregroundStyle(entry.isOn ? .green : .secondary)

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
            Button(intent: ToggleHomesteadSwitchIntent(entityID: entityID, turnOn: !entry.isOn)) {
                switchIcon
            }
            .buttonStyle(.plain)
        } else {
            switchIcon
        }
    }

    private var switchIcon: some View {
        Image(systemName: entry.systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(entry.isOn ? .green : .secondary)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview(as: .systemSmall) {
    HomesteadSwitchWidget()
} timeline: {
    HomesteadSwitchEntry(
        date: .now,
        entityID: "switch.coffee",
        displayName: "Coffee",
        isOn: true,
        statusText: "On",
        systemImage: "lightswitch.on.fill",
        isConfigured: true
    )
    HomesteadSwitchEntry(
        date: .now,
        entityID: "switch.fan",
        displayName: "Fan",
        isOn: false,
        statusText: "Off",
        systemImage: "lightswitch.off.fill",
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadSwitchWidget()
} timeline: {
    HomesteadSwitchEntry(
        date: .now,
        entityID: "switch.coffee",
        displayName: "Coffee",
        isOn: true,
        statusText: "On",
        systemImage: "lightswitch.on.fill",
        isConfigured: true
    )
}

#Preview(as: .accessoryCircular) {
    HomesteadSwitchWidget()
} timeline: {
    HomesteadSwitchEntry(
        date: .now,
        entityID: "switch.coffee",
        displayName: "Coffee",
        isOn: true,
        statusText: "On",
        systemImage: "lightswitch.on.fill",
        isConfigured: true
    )
}
