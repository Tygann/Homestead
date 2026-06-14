import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadActionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadActionWidget",
            intent: HomesteadActionWidgetConfigurationIntent.self,
            provider: HomesteadActionTimelineProvider()
        ) { entry in
            HomesteadActionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Action")
        .description("Run a Home Assistant scene or script from your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadActionWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Action"
    static var description = IntentDescription("Choose a Home Assistant scene or script.")

    @Parameter(title: "Action")
    var action: HomesteadActionEntity?
}

struct RunHomesteadActionIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Action"
    static var description = IntentDescription("Runs a Home Assistant scene or script.")

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
        try await HAWidgetActionClient().triggerAction(domain: domain, entityID: entityID)
        WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadActionWidget")
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
            fallback: domain == "script" ? "Scripts" : "Scenes"
        )
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
        HomesteadWidgetSharedStore.actionSnapshots.map { snapshot in
            HomesteadActionEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                domain: snapshot.domain,
                systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
                areaName: snapshot.areaName,
                deviceName: snapshot.deviceName
            )
        }
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
}

struct HomesteadActionTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadActionEntry {
        HomesteadActionEntry(
            date: Date(),
            entityID: nil,
            displayName: "Movie Time",
            domain: "scene",
            systemImage: "sparkles",
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadActionWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadActionEntry {
        if context.isPreview, configuration.action == nil {
            return placeholder(in: context)
        }

        return entry(for: configuration)
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
            entries: [entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(60 * 60))
        )
    }

    private func entry(for configuration: HomesteadActionWidgetConfigurationIntent) -> HomesteadActionEntry {
        let configuredAction = configuration.action
        let latestConfiguredSnapshot = configuredAction.flatMap { action in
            HomesteadWidgetSharedStore.actionSnapshot(entityID: action.id)
        }
        let selectedAction = latestConfiguredSnapshot.map(Self.entity) ?? configuredAction

        guard let selectedAction else {
            return HomesteadActionEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose Action",
                domain: "scene",
                systemImage: "sparkles",
                isConfigured: false
            )
        }

        return HomesteadActionEntry(
            date: Date(),
            entityID: selectedAction.id,
            displayName: selectedAction.displayName,
            domain: selectedAction.domain,
            systemImage: selectedAction.systemImage,
            isConfigured: true
        )
    }

    private static func entity(from snapshot: WidgetActionSnapshot) -> HomesteadActionEntity {
        HomesteadActionEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            domain: snapshot.domain,
            systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
            areaName: snapshot.areaName,
            deviceName: snapshot.deviceName
        )
    }
}

struct HomesteadActionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadActionEntry

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
            actionButton

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(entry.isConfigured ? 3 : 2)
                    .minimumScaleFactor(0.86)

                if let supportingText {
                    Text(supportingText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessoryCircular: some View {
        actionButton
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            actionButton

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if let supportingText {
                    Text(supportingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let entityID = entry.entityID, entry.isConfigured {
            Button(intent: RunHomesteadActionIntent(entityID: entityID, domain: entry.domain)) {
                actionIcon
            }
            .buttonStyle(.plain)
        } else {
            actionIcon
        }
    }

    private var actionIcon: some View {
        Image(systemName: entry.isConfigured ? "play.circle.fill" : entry.systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(entry.isConfigured ? .purple : .secondary)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var supportingText: String? {
        guard entry.isConfigured else {
            return "Open Homestead"
        }

        return nil
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
