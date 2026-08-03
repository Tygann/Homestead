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

    @Parameter(title: "Control")
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
        guard let reference = HomesteadWidgetSharedStore.reference(for: entityID),
              HomesteadWidgetSharedStore.isServerAvailable(profileID: reference.profileID) else {
            throw HAWidgetActionError.missingCredentials
        }
        let client = HAWidgetActionClient(profileID: reference.profileID)

        switch (domain, action) {
        case ("light", "toggle"):
            let state = try await client.fetchLightState(entityID: reference.entityID)
            guard state.isAvailable else { throw HAWidgetActionError.serviceCallFailed }
            try await runOptimisticToggle(
                currentState: state.isOn,
                turnOn: !state.isOn,
                update: { HomesteadWidgetSharedStore.updateLightSnapshot(entityID: entityID, isOn: $0) },
                serviceCall: { try await client.setLight(entityID: reference.entityID, isOn: $0) }
            )
        case ("switch", "toggle"):
            let state = try await client.fetchSwitchState(entityID: reference.entityID)
            guard EntityAvailability.resolve(state: state.state).isAvailable else {
                throw HAWidgetActionError.serviceCallFailed
            }
            try await runOptimisticToggle(
                currentState: state.isOn,
                turnOn: !state.isOn,
                update: { HomesteadWidgetSharedStore.updateSwitchSnapshot(entityID: entityID, isOn: $0) },
                serviceCall: { try await client.setSwitch(entityID: reference.entityID, isOn: $0) }
            )
        case ("fan", "toggle"):
            let state = try await client.fetchFanState(entityID: reference.entityID)
            guard state.isAvailable else { throw HAWidgetActionError.serviceCallFailed }
            try await runOptimisticToggle(
                currentState: state.isOn,
                turnOn: !state.isOn,
                update: { HomesteadWidgetSharedStore.updateFanSnapshot(entityID: entityID, isOn: $0) },
                serviceCall: { try await client.setFan(entityID: reference.entityID, isOn: $0) }
            )
        case ("cover", "resolve_cover"):
            let state = try await client.fetchCoverState(entityID: reference.entityID)
            guard state.isAvailable else { throw HAWidgetActionError.serviceCallFailed }
            let service = state.isMoving ? "stop_cover" : state.isOpen ? "close_cover" : "open_cover"
            try await client.runCoverService(entityID: reference.entityID, service: service)
            WidgetCenter.shared.reloadTimelines(ofKind: HomesteadWidgetKind.control.rawValue)
        case ("lock", "lock"):
            let state = try await client.fetchLockState(entityID: reference.entityID)
            guard state.isAvailable else { throw HAWidgetActionError.serviceCallFailed }
            if !state.isLocked {
                try await client.lock(entityID: reference.entityID)
            }
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
    var serverName: String = "Home Assistant"
    var isServerAvailable: Bool = true
    var hasMultipleServers: Bool = false
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
            subtitle: "\(pickerSubtitle)",
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
        HomesteadWidgetEntityPickerText.serverScopedGroupName(
            serverName: serverName,
            hasMultipleServers: hasMultipleServers,
            areaName: areaName,
            deviceName: deviceName,
            fallback: HomesteadWidgetEntityPickerText.pluralDisplayName(forDomain: domain)
        )
    }

    var pickerSubtitle: String {
        isServerAvailable
            ? HomesteadWidgetEntityPickerText.contextDescription(
                serverName: serverName,
                hasMultipleServers: hasMultipleServers,
                areaName: areaName,
                deviceName: deviceName
            )
            : "Server Removed"
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
                serverName,
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
        WidgetControlActionResolver.action(
            domain: domain,
            isConfigured: isConfigured,
            isAvailable: isAvailable,
            isActive: isActive
        )?.rawValue
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
                    statusText: WidgetStateText.openHomestead,
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
                    statusText: WidgetStateText.needsConnection,
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
        guard let reference = HomesteadWidgetSharedStore.reference(for: entity.id),
              HomesteadWidgetSharedStore.isServerAvailable(profileID: reference.profileID) else {
            throw HAWidgetActionError.missingCredentials
        }
        let client = HAWidgetActionClient(profileID: reference.profileID)

        switch entity.domain {
        case "light":
            let state = try await client.fetchLightState(entityID: reference.entityID)
            return HomesteadControlEntry(
                date: Date(),
                entityID: entity.id,
                domain: entity.domain,
                displayName: state.displayName,
                statusText: lightStatusText(isOn: state.isOn, brightnessPercentage: state.brightnessPercentage),
                systemImage: "lightbulb.fill",
                isActive: state.isOn,
                isMoving: false,
                isAvailable: state.isAvailable,
                isConfigured: true,
                icon: preferredLiveIcon(state.icon, cached: entity.resolvedIcon)
            )
        case "switch":
            let state = try await client.fetchSwitchState(entityID: reference.entityID)
            return HomesteadControlEntry(
                date: Date(),
                entityID: entity.id,
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
            let state = try await client.fetchCoverState(entityID: reference.entityID)
            return HomesteadControlEntry(
                date: Date(),
                entityID: entity.id,
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
            let state = try await client.fetchFanState(entityID: reference.entityID)
            return HomesteadControlEntry(
                date: Date(),
                entityID: entity.id,
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
            let state = try await client.fetchLockState(entityID: reference.entityID)
            return HomesteadControlEntry(
                date: Date(),
                entityID: entity.id,
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
        HomesteadWidgetSharedStore.scopedLightSnapshots.map { scoped in
            let snapshot = scoped.value
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: scoped.reference.encodedID,
                domain: "light",
                displayName: presentation.title,
                statusText: presentation.subtitle ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                serverName: scoped.serverName,
                isServerAvailable: scoped.isServerAvailable,
                hasMultipleServers: scoped.hasMultipleServers,
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
            )
        }
    }

    private static func switchEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.scopedSwitchSnapshots.map { scoped in
            let snapshot = scoped.value
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: scoped.reference.encodedID,
                domain: "switch",
                displayName: presentation.title,
                statusText: presentation.statusText ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                serverName: scoped.serverName,
                isServerAvailable: scoped.isServerAvailable,
                hasMultipleServers: scoped.hasMultipleServers,
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
            )
        }
    }

    private static func fanEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.scopedFanSnapshots.map { scoped in
            let snapshot = scoped.value
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: scoped.reference.encodedID,
                domain: "fan",
                displayName: presentation.title,
                statusText: presentation.statusText ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                serverName: scoped.serverName,
                isServerAvailable: scoped.isServerAvailable,
                hasMultipleServers: scoped.hasMultipleServers,
                isActive: snapshot.isOn,
                isMoving: false,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
            )
        }
    }

    private static func coverEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.scopedCoverSnapshots.map { scoped in
            let snapshot = scoped.value
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: scoped.reference.encodedID,
                domain: "cover",
                displayName: presentation.title,
                statusText: presentation.statusText ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                serverName: scoped.serverName,
                isServerAvailable: scoped.isServerAvailable,
                hasMultipleServers: scoped.hasMultipleServers,
                isActive: snapshot.isOpen,
                isMoving: snapshot.isMoving,
                isAvailable: presentation.isAvailable,
                icon: presentation.icon
            )
        }
    }

    private static func lockEntities() -> [HomesteadControlEntity] {
        HomesteadWidgetSharedStore.scopedLockSnapshots.map { scoped in
            let snapshot = scoped.value
            let presentation = snapshot.sharedPresentation
            return HomesteadControlEntity(
                id: scoped.reference.encodedID,
                domain: "lock",
                displayName: presentation.title,
                statusText: presentation.statusText ?? "",
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                serverName: scoped.serverName,
                isServerAvailable: scoped.isServerAvailable,
                hasMultipleServers: scoped.hasMultipleServers,
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
        HomesteadWidgetSingleItemFace(
            family: faceFamily,
            title: entry.displayName,
            value: entry.statusText,
            valueColor: entry.isActive || entry.isMoving ? .primary : .secondary
        ) {
            if family == .accessoryRectangular {
                HomesteadIconView(icon: displayedIcon, pointSize: 16)
                    .foregroundStyle(iconColor)
            } else {
                widgetButton
            }
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

    private var faceFamily: HomesteadWidgetFaceFamily {
        switch family {
        case .accessoryCircular: .accessoryCircular
        case .accessoryRectangular: .accessoryRectangular
        default: .systemSmall
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
