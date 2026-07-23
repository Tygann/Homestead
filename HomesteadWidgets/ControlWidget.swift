import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadControlWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: HomesteadWidgetKind.control.rawValue,
            intent: HomesteadControlWidgetConfigurationIntent.self,
            provider: HomesteadControlTimelineProvider()
        ) { entry in
            HomesteadControlWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(SharedFeatureCatalog.widgetDescriptor(for: .control)!.displayName)
        .description(SharedFeatureCatalog.widgetDescriptor(for: .control)!.description)
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
            WidgetCenter.shared.reloadTimelines(ofKind: HomesteadWidgetKind.control.rawValue)
        case ("lock", "lock"):
            try await HAWidgetActionClient().lock(entityID: entityID)
            WidgetCenter.shared.reloadTimelines(ofKind: HomesteadWidgetKind.control.rawValue)
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
        WidgetCenter.shared.reloadTimelines(ofKind: HomesteadWidgetKind.control.rawValue)

        do {
            try await serviceCall(turnOn)
        } catch {
            if let currentState {
                update(currentState)
                WidgetCenter.shared.reloadTimelines(ofKind: HomesteadWidgetKind.control.rawValue)
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
    let areaName: String?
    let deviceName: String?
    let isActive: Bool
    let isMoving: Bool
    let isAvailable: Bool
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(pickerDisplayName)",
            image: DisplayRepresentation.Image(systemName: systemImage)
        )
    }

    var pickerDisplayName: String {
        HomesteadWidgetEntityPickerText.contextualDisplayName(
            displayName,
            areaName: areaName,
            deviceName: deviceName
        )
    }

    var pickerGroupTitle: String {
        HomesteadWidgetEntityPickerText.groupName(
            areaName: areaName,
            deviceName: deviceName,
            fallback: HomesteadWidgetEntityPickerText.pluralDisplayName(forDomain: domain)
        )
    }

    func matches(_ query: String) -> Bool {
        HomesteadWidgetEntityPickerText.matches(
            query: query,
            values: [
                displayName,
                pickerDisplayName,
                statusText,
                domain,
                HomesteadWidgetEntityPickerText.displayName(forDomain: domain),
                areaName,
                deviceName,
                id
            ]
        )
    }
}

struct HomesteadControlEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    typealias Result = IntentItemCollection<HomesteadControlEntity>

    func entities(for identifiers: [HomesteadControlEntity.ID]) async throws -> [HomesteadControlEntity] {
        flatEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HomesteadControlEntity> {
        collection(from: flatEntities().filter { $0.matches(string) })
    }

    func allEntities() async throws -> IntentItemCollection<HomesteadControlEntity> {
        collection(from: flatEntities())
    }

    func suggestedEntities() async throws -> IntentItemCollection<HomesteadControlEntity> {
        try await allEntities()
    }

    func defaultResult() async -> HomesteadControlEntity? {
        nil
    }

    private func flatEntities() -> [HomesteadControlEntity] {
        HomesteadControlSnapshotBuilder.entities()
    }

    private func collection(from entities: [HomesteadControlEntity]) -> IntentItemCollection<HomesteadControlEntity> {
        HomesteadWidgetEntityPickerText.collection(
            from: entities,
            groupedBy: \.pickerGroupTitle,
            sortedBy: \.pickerDisplayName
        )
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
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

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
            entityID: nil,
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
                    displayName: "Choose Control",
                    statusText: "Open Homestead",
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
                    isConfigured: true,
                    icon: selectedEntity.resolvedIcon
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
            systemImage: entity.systemImage,
            isActive: isActive,
            isMoving: false,
            isAvailable: entity.isAvailable,
            isConfigured: true,
            icon: entity.resolvedIcon
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
                isConfigured: true,
                icon: preferredLiveIcon(state.icon, cached: entity.resolvedIcon)
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
                isConfigured: true,
                icon: preferredLiveIcon(state.icon, cached: entity.resolvedIcon)
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
                isConfigured: true,
                icon: preferredLiveIcon(state.icon, cached: entity.resolvedIcon)
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
                isConfigured: true,
                icon: preferredLiveIcon(state.icon, cached: entity.resolvedIcon)
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
                isConfigured: true,
                icon: preferredLiveIcon(state.icon, cached: entity.resolvedIcon)
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

    private func preferredLiveIcon(_ liveIcon: ResolvedIcon, cached: ResolvedIcon) -> ResolvedIcon {
        cached.provenance == .haRegistryIcon ? cached : liveIcon
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
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "light",
                displayName: presentation.title,
                statusText: presentation.subtitle ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
            )
        }
    }

    private static func switchEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.switchSnapshots.map { snapshot in
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "switch",
                displayName: presentation.title,
                statusText: presentation.statusText ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
            )
        }
    }

    private static func fanEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.fanSnapshots.map { snapshot in
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "fan",
                displayName: presentation.title,
                statusText: presentation.statusText ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
            )
        }
    }

    private static func coverEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.coverSnapshots.map { snapshot in
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "cover",
                displayName: presentation.title,
                statusText: presentation.statusText ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                isActive: snapshot.isOpen,
                isMoving: snapshot.isMoving,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
            )
        }
    }

    private static func lockEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.lockSnapshots.map { snapshot in
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: snapshot.entityID,
                domain: "lock",
                displayName: presentation.title,
                statusText: presentation.statusText ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                isActive: snapshot.isLocked,
                isMoving: false,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
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
        deepLinkedContent {
            familyContent
        }
    }

    @ViewBuilder
    private var familyContent: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        default:
            systemSmall
        }
    }

    @ViewBuilder
    private func deepLinkedContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let entityID = entry.entityID {
            content()
                .widgetURL(HomesteadWidgetDeepLink.entityURL(entityID: entityID))
        } else {
            content()
        }
    }

    private var systemSmall: some View {
        HomesteadWidgetSmallTile(
            title: entry.displayName,
            value: entry.statusText,
            valueColor: entry.isActive || entry.isMoving ? .primary : .secondary
        ) {
            widgetButton
        }
    }

    private var accessoryCircular: some View {
        widgetButton
    }

    private var accessoryRectangular: some View {
        HomesteadWidgetRectangularTile(
            title: entry.displayName,
            value: entry.statusText
        ) {
            HomesteadIconView(icon: displayedIcon, pointSize: 16)
                .foregroundStyle(iconColor)
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
        HomesteadWidgetIconBadge(content: .resolved(displayedIcon), color: iconColor)
    }

    private var displayedIcon: ResolvedIcon {
        entry.isMoving
            ? .sfSymbol("stop.fill", provenance: .homesteadSemanticMapping)
            : entry.resolvedIcon
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
