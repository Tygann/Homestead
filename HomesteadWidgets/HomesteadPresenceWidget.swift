import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadPresenceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadPresenceWidget",
            intent: HomesteadPresenceWidgetConfigurationIntent.self,
            provider: HomesteadPresenceTimelineProvider()
        ) { entry in
            HomesteadPresenceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Presence")
        .description("Show a Home Assistant person status on your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadPresenceWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Presence"
    static var description = IntentDescription("Choose a Home Assistant person.")

    @Parameter(title: "Person")
    var person: HomesteadPresenceEntity?
}

struct HomesteadPresenceEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Person")
    static var defaultQuery = HomesteadPresenceEntityQuery()

    let id: String
    let displayName: String
    let statusText: String
    let isHome: Bool
    let systemImage: String
    let isAvailable: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct HomesteadPresenceEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadPresenceEntity.ID]) async throws -> [HomesteadPresenceEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadPresenceEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadPresenceEntity? {
        allEntities().first
    }

    private func allEntities() -> [HomesteadPresenceEntity] {
        HomesteadWidgetSharedStore.presenceSnapshots.map { snapshot in
            HomesteadPresenceEntity(
                id: snapshot.entityID,
                displayName: snapshot.displayName,
                statusText: snapshot.statusText,
                isHome: snapshot.isHome,
                systemImage: snapshot.systemImage,
                isAvailable: snapshot.isAvailable
            )
        }
    }
}

struct HomesteadPresenceEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let statusText: String
    let isHome: Bool
    let systemImage: String
    let isAvailable: Bool
    let isConfigured: Bool
}

struct HomesteadPresenceTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadPresenceEntry {
        HomesteadPresenceEntry(
            date: Date(),
            entityID: "person.tyler",
            displayName: "Tyler",
            statusText: "Home",
            isHome: true,
            systemImage: "person.fill",
            isAvailable: true,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadPresenceWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadPresenceEntry {
        await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadPresenceWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadPresenceEntry> {
        Timeline(
            entries: [await entry(for: configuration)],
            policy: .after(Date().addingTimeInterval(15 * 60))
        )
    }

    private func entry(for configuration: HomesteadPresenceWidgetConfigurationIntent) async -> HomesteadPresenceEntry {
        let configuredPerson = configuration.person
        let latestConfiguredSnapshot = configuredPerson.flatMap { person in
            HomesteadWidgetSharedStore.presenceSnapshot(entityID: person.id)
        }
        let selectedPerson = latestConfiguredSnapshot.map(Self.entity) ?? configuredPerson
            ?? HomesteadWidgetSharedStore.presenceSnapshots.first.map(Self.entity)

        guard let selectedPerson else {
            return HomesteadPresenceEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose a Person",
                statusText: "Open Homestead first",
                isHome: false,
                systemImage: "person",
                isAvailable: false,
                isConfigured: false
            )
        }

        do {
            let state = try await HAWidgetActionClient().fetchPresenceState(entityID: selectedPerson.id)
            return HomesteadPresenceEntry(
                date: Date(),
                entityID: state.entityID,
                displayName: state.displayName,
                statusText: state.statusText,
                isHome: state.isHome,
                systemImage: state.systemImage,
                isAvailable: state.isAvailable,
                isConfigured: true
            )
        } catch {
            return HomesteadPresenceEntry(
                date: Date(),
                entityID: selectedPerson.id,
                displayName: selectedPerson.displayName,
                statusText: "Needs connection",
                isHome: selectedPerson.isHome,
                systemImage: selectedPerson.systemImage,
                isAvailable: selectedPerson.isAvailable,
                isConfigured: true
            )
        }
    }

    private static func entity(from snapshot: WidgetPresenceSnapshot) -> HomesteadPresenceEntity {
        HomesteadPresenceEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            statusText: snapshot.statusText,
            isHome: snapshot.isHome,
            systemImage: snapshot.systemImage,
            isAvailable: snapshot.isAvailable
        )
    }
}

struct HomesteadPresenceWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadPresenceEntry

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
            presenceIcon

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Text(entry.statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accessoryCircular: some View {
        presenceIcon
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.systemImage)
                .foregroundStyle(statusColor)

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

    private var presenceIcon: some View {
        Image(systemName: entry.systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(statusColor)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusColor: Color {
        if !entry.isAvailable {
            return .secondary
        }

        return entry.isHome ? .green : .blue
    }
}

#Preview(as: .systemSmall) {
    HomesteadPresenceWidget()
} timeline: {
    HomesteadPresenceEntry(
        date: .now,
        entityID: "person.tyler",
        displayName: "Tyler",
        statusText: "Home",
        isHome: true,
        systemImage: "person.fill",
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadPresenceWidget()
} timeline: {
    HomesteadPresenceEntry(
        date: .now,
        entityID: "person.tyler",
        displayName: "Tyler",
        statusText: "Away",
        isHome: false,
        systemImage: "person",
        isAvailable: true,
        isConfigured: true
    )
}
