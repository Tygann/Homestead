import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadActionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: HomesteadWidgetKind.action.rawValue,
            intent: HomesteadActionWidgetConfigurationIntent.self,
            provider: HomesteadActionTimelineProvider()
        ) { entry in
            HomesteadActionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(SharedFeatureCatalog.widgetDescriptor(for: .action)!.displayName)
        .description(SharedFeatureCatalog.widgetDescriptor(for: .action)!.description)
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadActionWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Action"
    static var description = IntentDescription("Choose a Home Assistant scene, script, or button.")

    @Parameter(title: "Action")
    var action: HomesteadActionEntity?
}

struct RunHomesteadActionIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Action"
    static var description = IntentDescription("Runs a Home Assistant scene, script, or button.")

    @Parameter(title: "Entity ID")
    var entityID: String

    @Parameter(title: "Domain")
    var domain: String

    init() {}

    init(entityID: String, domain: String) {
        self.entityID = entityID
        self.domain = domain
    }

    func perform() async throws -> some IntentResult {
        guard let reference = HomesteadWidgetSharedStore.reference(for: entityID) else {
            throw HAWidgetActionError.missingCredentials
        }
        guard HomesteadWidgetSharedStore.isServerAvailable(profileID: reference.profileID) else {
            throw HAWidgetActionError.serverRemoved
        }
        let client = HAWidgetActionClient(profileID: reference.profileID)
        let semantic = try await client.fetchSemanticPresentation(
            entityID: reference.entityID,
            domain: domain
        )
        guard semantic.isAvailable else {
            throw HAWidgetActionError.entityUnavailable
        }
        try await client.triggerAction(domain: domain, entityID: reference.entityID)
        WidgetCenter.shared.reloadTimelines(ofKind: HomesteadWidgetKind.action.rawValue)
        return .result()
    }
}

struct HomesteadActionEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
    static var defaultQuery = HomesteadActionEntityQuery()

    let id: String
    let displayName: String
    let domain: String
    let systemImage: String
    let areaName: String?
    let deviceName: String?
    var serverName: String = "Home Assistant"
    var isServerAvailable: Bool = true
    var hasMultipleServers: Bool = false
    var isAvailable: Bool = true

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
            fallback: fallbackGroupTitle
        )
    }

    var pickerSubtitle: String {
        guard isServerAvailable else { return "Server Removed" }
        guard isAvailable else { return "Unavailable" }
        return HomesteadWidgetEntityPickerText.contextDescription(
            serverName: serverName,
            hasMultipleServers: hasMultipleServers,
            areaName: areaName,
            deviceName: deviceName
        )
    }

    private var fallbackGroupTitle: String {
        switch domain {
        case "script": "Scripts"
        case "button": "Buttons"
        default: "Scenes"
        }
    }

    func matches(_ query: String) -> Bool {
        HomesteadWidgetEntityPickerText.matches(
            query: query,
            values: [
                displayName,
                pickerDisplayName,
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

struct HomesteadActionEntityQuery: EntityQuery, EntityStringQuery, EnumerableEntityQuery {
    typealias Result = IntentItemCollection<HomesteadActionEntity>

    func entities(for identifiers: [HomesteadActionEntity.ID]) async throws -> [HomesteadActionEntity] {
        flatEntities().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HomesteadActionEntity> {
        collection(from: flatEntities().filter { $0.matches(string) })
    }

    func allEntities() async throws -> IntentItemCollection<HomesteadActionEntity> {
        collection(from: flatEntities())
    }

    func suggestedEntities() async throws -> IntentItemCollection<HomesteadActionEntity> {
        try await allEntities()
    }

    func defaultResult() async -> HomesteadActionEntity? {
        nil
    }

    private func flatEntities() -> [HomesteadActionEntity] {
        HomesteadActionSnapshotBuilder.entities()
    }

    private func collection(from entities: [HomesteadActionEntity]) -> IntentItemCollection<HomesteadActionEntity> {
        HomesteadWidgetEntityPickerText.collection(
            from: entities,
            groupedBy: \.pickerGroupTitle,
            sortedBy: \.pickerDisplayName
        )
    }
}

struct HomesteadActionEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let domain: String
    let systemImage: String
    let isConfigured: Bool
    var isAvailable: Bool = true
    var statusText: String? = nil
}

struct HomesteadActionTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadActionEntry {
        HomesteadActionEntry(
            date: Date(),
            entityID: nil,
            displayName: "Movie Time",
            domain: "scene",
            systemImage: "sparkles",
            isConfigured: true,
            isAvailable: true,
            statusText: nil
        )
    }

    func snapshot(
        for configuration: HomesteadActionWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadActionEntry {
        if context.isPreview, configuration.action == nil {
            return placeholder(in: context)
        }

        return await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadActionWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadActionEntry> {
        if context.isPreview, configuration.action == nil {
            return Timeline(
                entries: [placeholder(in: context)],
                policy: .after(Date().addingTimeInterval(60 * 60))
            )
        }

        return Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(60 * 60))
        )
    }

    private func entry(for configuration: HomesteadActionWidgetConfigurationIntent) async -> HomesteadActionEntry {
        let configuredAction = configuration.action
        let selectedAction = configuredAction.flatMap {
            HomesteadActionSnapshotBuilder.entity(identifier: $0.id)
        } ?? configuredAction

        guard let selectedAction else {
            return HomesteadActionEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose Action",
                domain: "scene",
                systemImage: "sparkles",
                isConfigured: false,
                isAvailable: false,
                statusText: "Choose Action"
            )
        }

        guard let reference = HomesteadWidgetSharedStore.reference(for: selectedAction.id),
              HomesteadWidgetSharedStore.isServerAvailable(profileID: reference.profileID) else {
            return HomesteadActionEntry(
                date: Date(),
                entityID: selectedAction.id,
                displayName: selectedAction.displayName,
                domain: selectedAction.domain,
                systemImage: selectedAction.systemImage,
                isConfigured: true,
                isAvailable: false,
                statusText: "Server Removed"
            )
        }

        let livePresentation = try? await HAWidgetActionClient(profileID: reference.profileID)
            .fetchSemanticPresentation(entityID: reference.entityID, domain: selectedAction.domain)
        let isAvailable = livePresentation?.isAvailable ?? selectedAction.isAvailable
        return HomesteadActionEntry(
            date: Date(),
            entityID: selectedAction.id,
            displayName: selectedAction.displayName,
            domain: selectedAction.domain,
            systemImage: selectedAction.systemImage,
            isConfigured: true,
            isAvailable: isAvailable,
            statusText: isAvailable ? nil : "Unavailable"
        )
    }

}

private enum HomesteadActionSnapshotBuilder {
    static func entities() -> [HomesteadActionEntity] {
        HomesteadWidgetSharedStore.scopedActionSnapshots.map { scoped in
            let snapshot = scoped.value
            let presentation = snapshot.sharedPresentation
            return HomesteadActionEntity(
                id: scoped.reference.encodedID,
                displayName: presentation.title,
                domain: snapshot.domain,
                systemImage: presentation.icon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName,
                serverName: scoped.serverName,
                isServerAvailable: scoped.isServerAvailable,
                hasMultipleServers: scoped.hasMultipleServers,
                isAvailable: presentation.isAvailable
            )
        }
    }

    static func entity(identifier: String) -> HomesteadActionEntity? {
        entities().first { $0.id == identifier }
    }
}

struct HomesteadActionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadActionEntry

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
            supportingText: supportingText,
            titleLineLimit: entry.isConfigured ? 3 : 2
        ) {
            actionButton
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
    private var actionButton: some View {
        if let entityID = entry.entityID, entry.isConfigured, entry.isAvailable {
            Button(intent: RunHomesteadActionIntent(entityID: entityID, domain: entry.domain)) {
                actionIcon
            }
            .buttonStyle(.plain)
        } else {
            actionIcon
        }
    }

    private var actionIcon: some View {
        HomesteadWidgetIconBadge(
            content: .symbol(entry.isConfigured ? "play.circle.fill" : entry.systemImage),
            color: entry.isConfigured ? .purple : .secondary
        )
    }

    private var supportingText: String? {
        guard entry.isConfigured else {
            return WidgetStateText.openHomestead
        }

        return entry.statusText
    }
}

#Preview(as: .systemSmall) {
    HomesteadActionWidget()
} timeline: {
    HomesteadActionEntry(
        date: .now,
        entityID: "scene.movie_time",
        displayName: "Movie Time",
        domain: "scene",
        systemImage: "sparkles",
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadActionWidget()
} timeline: {
    HomesteadActionEntry(
        date: .now,
        entityID: "script.good_night",
        displayName: "Good Night",
        domain: "script",
        systemImage: "play.circle",
        isConfigured: true
    )
}
