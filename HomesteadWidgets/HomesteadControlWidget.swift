import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadControlWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadControlWidget",
            intent: HomesteadControlWidgetConfigurationIntent.self,
            provider: HomesteadControlTimelineProvider()
        ) { entry in
            HomesteadControlWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Control")
        .description("Control a Home Assistant light, switch, fan, cover, or lock.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadControlWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Control"
    static var description = IntentDescription("Choose a controllable Home Assistant entity.")

    @Parameter(title: "Entity")
    var entity: HomesteadControlEntity?
}

struct RunHomesteadControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Control Entity"
    static var description = IntentDescription("Runs a Home Assistant control action.")

    @Parameter(title: "Entity ID")
    var entityID: String

    @Parameter(title: "Domain")
    var domain: String

    @Parameter(title: "Action")
    var action: String

    init() {}

    init(entityID: String, domain: String, action: String) {
        self.entityID = entityID
        self.domain = domain
        self.action = action
    }

    func perform() async throws -> some IntentResult {
        switch (domain, action) {
        case ("light", "turn_on"), ("light", "turn_off"):
            try await runOptimisticToggle(
                currentState: HomesteadWidgetSharedStore.lightSnapshot(entityID: entityID)?.isOn,
                turnOn: action == "turn_on",
                update: { HomesteadWidgetSharedStore.updateLightSnapshot(entityID: entityID, isOn: $0) },
                serviceCall: { try await HAWidgetActionClient().setLight(entityID: entityID, isOn: $0) }
            )
        case ("switch", "turn_on"), ("switch", "turn_off"):
            try await runOptimisticToggle(
                currentState: HomesteadWidgetSharedStore.switchSnapshot(entityID: entityID)?.isOn,
                turnOn: action == "turn_on",
                update: { HomesteadWidgetSharedStore.updateSwitchSnapshot(entityID: entityID, isOn: $0) },
                serviceCall: { try await HAWidgetActionClient().setSwitch(entityID: entityID, isOn: $0) }
            )
        case ("fan", "turn_on"), ("fan", "turn_off"):
            try await runOptimisticToggle(
                currentState: HomesteadWidgetSharedStore.fanSnapshot(entityID: entityID)?.isOn,
                turnOn: action == "turn_on",
                update: { HomesteadWidgetSharedStore.updateFanSnapshot(entityID: entityID, isOn: $0) },
                serviceCall: { try await HAWidgetActionClient().setFan(entityID: entityID, isOn: $0) }
            )
        case ("cover", "open_cover"), ("cover", "close_cover"), ("cover", "stop_cover"):
            try await HAWidgetActionClient().runCoverService(entityID: entityID, service: action)
            WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadControlWidget")
        case ("lock", "lock"):
            try await HAWidgetActionClient().lock(entityID: entityID)
            WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadControlWidget")
        default:
            throw HAWidgetActionError.serviceCallFailed
        }

        return .result()
    }

    private func runOptimisticToggle(
        currentState: Bool?,
        turnOn: Bool,
        update: (Bool) -> Void,
        serviceCall: (Bool) async throws -> Void
    ) async throws {
        update(turnOn)
        WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadControlWidget")

        do {
            try await serviceCall(turnOn)
        } catch {
            if let currentState {
                update(currentState)
                WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadControlWidget")
            }

            throw error
        }
    }
}

struct HomesteadControlEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Control")
    static var defaultQuery = HomesteadControlEntityQuery()

    let id: String
    let domain: String
    let displayName: String
    let statusText: String
    let systemImage: String
    let isActive: Bool
    let isMoving: Bool
    let isAvailable: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(domain) • \(id)")
    }
}

struct HomesteadControlEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadControlEntity.ID]) async throws -> [HomesteadControlEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadControlEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadControlEntity? {
        nil
    }

    private func allEntities() -> [HomesteadControlEntity] {
        HomesteadControlSnapshotBuilder.entities()
    }
}

struct HomesteadControlEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let domain: String
    let displayName: String
    let statusText: String
    let systemImage: String
    let isActive: Bool
    let isMoving: Bool
    let isAvailable: Bool
    let isConfigured: Bool

    var action: String? {
        guard isConfigured, isAvailable else {
            return nil
        }

        switch domain {
        case "light", "switch", "fan":
            return isActive ? "turn_off" : "turn_on"
        case "cover":
            if isMoving {
                return "stop_cover"
            }

            return isActive ? "close_cover" : "open_cover"
        case "lock":
            return isActive ? nil : "lock"
        default:
            return nil
        }
    }
}

struct HomesteadControlTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadControlEntry {
        HomesteadControlEntry(
            date: Date(),
            entityID: "light.bed_lamp",
            domain: "light",
            displayName: "Bed Lamp",
            statusText: "On • 50%",
            systemImage: "lightbulb.fill",
            isActive: true,
            isMoving: false,
            isAvailable: true,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadControlWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadControlEntry {
        if context.isPreview, configuration.entity == nil {
            return placeholder(in: context)
        }

        return await entry(for: configuration).entry
    }

    func timeline(
        for configuration: HomesteadControlWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadControlEntry> {
        if context.isPreview, configuration.entity == nil {
            return Timeline(
                entries: [placeholder(in: context)],
                policy: .after(Date().addingTimeInterval(15 * 60))
            )
        }

        let result = await entry(for: configuration)
        let refreshInterval: TimeInterval = result.usedOptimisticState ? 30 : 15 * 60

        return Timeline(
            entries: [result.entry],
            policy: .after(Date().addingTimeInterval(refreshInterval))
        )
    }

    private func entry(for configuration: HomesteadControlWidgetConfigurationIntent) async -> TimelineResult {
        let configuredEntity = configuration.entity
        let latestConfiguredEntity = configuredEntity.flatMap { entity in
            HomesteadControlSnapshotBuilder.entity(entityID: entity.id)
        }
        let selectedEntity = latestConfiguredEntity
            ?? configuredEntity

        guard let selectedEntity else {
            return TimelineResult(
                entry: HomesteadControlEntry(
                    date: Date(),
                    entityID: nil,
                    domain: "control",
                    displayName: "Choose a Control",
                    statusText: "Open Homestead first",
                    systemImage: "switch.2",
                    isActive: false,
                    isMoving: false,
                    isAvailable: false,
                    isConfigured: false
                ),
                usedOptimisticState: false
            )
        }

        if let optimisticEntry = optimisticEntry(for: selectedEntity) {
            return TimelineResult(entry: optimisticEntry, usedOptimisticState: true)
        }

        do {
            return TimelineResult(
                entry: try await liveEntry(for: selectedEntity),
                usedOptimisticState: false
            )
        } catch {
            return TimelineResult(
                entry: HomesteadControlEntry(
                    date: Date(),
                    entityID: selectedEntity.id,
                    domain: selectedEntity.domain,
                    displayName: selectedEntity.displayName,
                    statusText: "Needs connection",
                    systemImage: selectedEntity.systemImage,
                    isActive: selectedEntity.isActive,
                    isMoving: selectedEntity.isMoving,
                    isAvailable: selectedEntity.isAvailable,
                    isConfigured: true
                ),
                usedOptimisticState: false
            )
        }
    }

    private func optimisticEntry(for entity: HomesteadControlEntity) -> HomesteadControlEntry? {
        let isActive: Bool?

        switch entity.domain {
        case "light":
            isActive = HomesteadWidgetSharedStore.optimisticLightState(entityID: entity.id)
        case "switch":
            isActive = HomesteadWidgetSharedStore.optimisticSwitchState(entityID: entity.id)
        case "fan":
            isActive = HomesteadWidgetSharedStore.optimisticFanState(entityID: entity.id)
        default:
            isActive = nil
        }

        guard let isActive else {
            return nil
        }

        return HomesteadControlEntry(
            date: Date(),
            entityID: entity.id,
            domain: entity.domain,
            displayName: entity.displayName,
            statusText: isActive ? "On" : "Off",
            systemImage: systemImage(domain: entity.domain, isActive: isActive, fallback: entity.systemImage),
            isActive: isActive,
            isMoving: false,
            isAvailable: entity.isAvailable,
            isConfigured: true
        )
    }

    private func liveEntry(for entity: HomesteadControlEntity) async throws -> HomesteadControlEntry {
        switch entity.domain {
        case "light":
            let state = try await HAWidgetActionClient().fetchLightState(entityID: entity.id)
            return HomesteadControlEntry(
                date: Date(),
                entityID: state.entityID,
                domain: entity.domain,
                displayName: state.displayName,
                statusText: lightStatusText(isOn: state.isOn, brightnessPercentage: state.brightnessPercentage),
                systemImage: "lightbulb.fill",
                isActive: state.isOn,
                isMoving: false,
                isAvailable: true,
                isConfigured: true
            )
        case "switch":
            let state = try await HAWidgetActionClient().fetchSwitchState(entityID: entity.id)
            return HomesteadControlEntry(
                date: Date(),
                entityID: state.entityID,
                domain: entity.domain,
                displayName: state.displayName,
                statusText: statusText(for: state.state),
                systemImage: state.systemImage,
                isActive: state.isOn,
                isMoving: false,
                isAvailable: !["unknown", "unavailable"].contains(state.state),
                isConfigured: true
            )
        case "cover":
            let state = try await HAWidgetActionClient().fetchCoverState(entityID: entity.id)
            return HomesteadControlEntry(
                date: Date(),
                entityID: state.entityID,
                domain: entity.domain,
                displayName: state.displayName,
                statusText: state.statusText,
                systemImage: state.systemImage,
                isActive: state.isOpen,
                isMoving: state.isMoving,
                isAvailable: state.isAvailable,
                isConfigured: true
            )
        case "fan":
            let state = try await HAWidgetActionClient().fetchFanState(entityID: entity.id)
            return HomesteadControlEntry(
                date: Date(),
                entityID: state.entityID,
                domain: entity.domain,
                displayName: state.displayName,
                statusText: state.statusText,
                systemImage: "fan.fill",
                isActive: state.isOn,
                isMoving: false,
                isAvailable: state.isAvailable,
                isConfigured: true
            )
        case "lock":
            let state = try await HAWidgetActionClient().fetchLockState(entityID: entity.id)
            return HomesteadControlEntry(
                date: Date(),
                entityID: state.entityID,
                domain: entity.domain,
                displayName: state.displayName,
                statusText: state.statusText,
                systemImage: state.systemImage,
                isActive: state.isLocked,
                isMoving: false,
                isAvailable: state.isAvailable,
                isConfigured: true
            )
        default:
            throw HAWidgetActionError.unexpectedResponse
        }
    }

    private func lightStatusText(isOn: Bool, brightnessPercentage: Int?) -> String {
        guard isOn else {
            return "Off"
        }

        guard let brightnessPercentage else {
            return "On"
        }

        return "On • \(brightnessPercentage)%"
    }

    private func statusText(for state: String) -> String {
        switch state {
        case "on":
            "On"
        case "off":
            "Off"
        case "unknown":
            "Unknown"
        case "unavailable":
            "Unavailable"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func systemImage(domain: String, isActive: Bool, fallback: String) -> String {
        switch domain {
        case "light":
            "lightbulb.fill"
        case "fan":
            "fan.fill"
        case "switch" where fallback == "lightswitch.on.fill" || fallback == "lightswitch.off.fill":
            isActive ? "lightswitch.on.fill" : "lightswitch.off.fill"
        default:
            fallback
        }
    }

    private struct TimelineResult {
        let entry: HomesteadControlEntry
        let usedOptimisticState: Bool
    }
}

private enum HomesteadControlSnapshotBuilder {
    static func entities() -> [HomesteadControlEntity] {
        lightEntities()
            + switchEntities()
            + fanEntities()
            + coverEntities()
            + lockEntities()
    }

    static func entity(entityID: String) -> HomesteadControlEntity? {
        entities().first { $0.id == entityID }
    }

    private static func lightEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.lightSnapshots.map { snapshot in
            HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "light",
                displayName: snapshot.displayName,
                statusText: lightStatusText(isOn: snapshot.isOn, brightnessPercentage: snapshot.brightnessPercentage),
                systemImage: "lightbulb.fill",
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: true
            )
        }
    }

    private static func switchEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.switchSnapshots.map { snapshot in
            HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "switch",
                displayName: snapshot.displayName,
                statusText: snapshot.isOn ? "On" : "Off",
                systemImage: snapshot.systemImage,
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: true
            )
        }
    }

    private static func fanEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.fanSnapshots.map { snapshot in
            HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "fan",
                displayName: snapshot.displayName,
                statusText: snapshot.statusText,
                systemImage: "fan.fill",
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: snapshot.isAvailable
            )
        }
    }

    private static func coverEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.coverSnapshots.map { snapshot in
            HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "cover",
                displayName: snapshot.displayName,
                statusText: snapshot.statusText,
                systemImage: snapshot.systemImage,
                isActive: snapshot.isOpen,
                isMoving: snapshot.isMoving,
                isAvailable: snapshot.isAvailable
            )
        }
    }

    private static func lockEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.lockSnapshots.map { snapshot in
            HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "lock",
                displayName: snapshot.displayName,
                statusText: snapshot.statusText,
                systemImage: snapshot.systemImage,
                isActive: snapshot.isLocked,
                isMoving: false,
                isAvailable: snapshot.isAvailable
            )
        }
    }

    private static func lightStatusText(isOn: Bool, brightnessPercentage: Int?) -> String {
        guard isOn else {
            return "Off"
        }

        guard let brightnessPercentage else {
            return "On"
        }

        return "On • \(brightnessPercentage)%"
    }
}

struct HomesteadControlWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadControlEntry

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
                    .foregroundStyle(entry.isActive || entry.isMoving ? .primary : .secondary)
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
            Image(systemName: iconName)
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
        if let entityID = entry.entityID, let action = entry.action {
            Button(intent: RunHomesteadControlIntent(entityID: entityID, domain: entry.domain, action: action)) {
                controlIcon
            }
            .buttonStyle(.plain)
        } else {
            controlIcon
        }
    }

    private var controlIcon: some View {
        Image(systemName: iconName)
            .font(.title2.weight(.semibold))
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var iconName: String {
        entry.isMoving ? "stop.fill" : entry.systemImage
    }

    private var iconColor: Color {
        guard entry.isAvailable else {
            return .secondary
        }

        switch entry.domain {
        case "light":
            return entry.isActive ? .yellow : .secondary
        case "switch":
            return entry.isActive ? .green : .secondary
        case "fan":
            return entry.isActive ? .teal : .secondary
        case "cover":
            return entry.isActive || entry.isMoving ? .blue : .secondary
        case "lock":
            return entry.isActive ? .green : .orange
        default:
            return entry.isActive ? .accentColor : .secondary
        }
    }
}

#Preview(as: .systemSmall) {
    HomesteadControlWidget()
} timeline: {
    HomesteadControlEntry(
        date: .now,
        entityID: "light.bed_lamp",
        domain: "light",
        displayName: "Bed Lamp",
        statusText: "On • 50%",
        systemImage: "lightbulb.fill",
        isActive: true,
        isMoving: false,
        isAvailable: true,
        isConfigured: true
    )
    HomesteadControlEntry(
        date: .now,
        entityID: "lock.front_door",
        domain: "lock",
        displayName: "Front Door",
        statusText: "Unlocked",
        systemImage: "lock.open.fill",
        isActive: false,
        isMoving: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadControlWidget()
} timeline: {
    HomesteadControlEntry(
        date: .now,
        entityID: "cover.living_room_shades",
        domain: "cover",
        displayName: "Living Room Shades",
        statusText: "Open • 70%",
        systemImage: "window.shade.open",
        isActive: true,
        isMoving: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryCircular) {
    HomesteadControlWidget()
} timeline: {
    HomesteadControlEntry(
        date: .now,
        entityID: "fan.bedroom",
        domain: "fan",
        displayName: "Bedroom Fan",
        statusText: "On • 50%",
        systemImage: "fan.fill",
        isActive: true,
        isMoving: false,
        isAvailable: true,
        isConfigured: true
    )
}
