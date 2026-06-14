import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadCoverWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadCoverWidget",
            intent: HomesteadCoverWidgetConfigurationIntent.self,
            provider: HomesteadCoverTimelineProvider()
        ) { entry in
            HomesteadCoverWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Cover")
        .description("Control a Home Assistant cover from your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadCoverWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Cover"
    static var description = IntentDescription("Choose a Home Assistant cover.")

    @Parameter(title: "Cover")
    var selectedCover: HomesteadCoverEntity?
}

struct RunHomesteadCoverIntent: AppIntent {
    static var title: LocalizedStringResource = "Control Cover"
    static var description = IntentDescription("Opens, closes, or stops a Home Assistant cover.")

    @Parameter(title: "Entity ID")
    var entityID: String

    @Parameter(title: "Service")
    var service: String

    init() {}

    init(entityID: String, service: String) {
        self.entityID = entityID
        self.service = service
    }

    func perform() async throws -> some IntentResult {
        try await HAWidgetActionClient().runCoverService(entityID: entityID, service: service)
        WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadCoverWidget")
        return .result()
    }
}

struct HomesteadCoverEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cover")
    static var defaultQuery = HomesteadCoverEntityQuery()

    let id: String
    let displayName: String
    let state: String
    let statusText: String
    let systemImage: String
    let isOpen: Bool
    let isClosed: Bool
    let isMoving: Bool
    let isAvailable: Bool
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct HomesteadCoverEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadCoverEntity.ID]) async throws -> [HomesteadCoverEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadCoverEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadCoverEntity? {
        allEntities().first
    }

    private func allEntities() -> [HomesteadCoverEntity] {
        HomesteadWidgetSharedStore.coverSnapshots.map(Self.entity)
    }

    private static func entity(from snapshot: WidgetCoverSnapshot) -> HomesteadCoverEntity {
        HomesteadCoverEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            state: snapshot.state,
            statusText: snapshot.statusText,
            systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
            isOpen: snapshot.isOpen,
            isClosed: snapshot.isClosed,
            isMoving: snapshot.isMoving,
            isAvailable: snapshot.isAvailable,
            icon: snapshot.resolvedIcon
        )
    }
}

struct HomesteadCoverEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let state: String
    let statusText: String
    let systemImage: String
    let isOpen: Bool
    let isClosed: Bool
    let isMoving: Bool
    let isAvailable: Bool
    let isConfigured: Bool
    var icon: ResolvedIcon? = nil

    var resolvedIcon: ResolvedIcon {
        icon ?? .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
    }
}

struct HomesteadCoverTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadCoverEntry {
        HomesteadCoverEntry(
            date: Date(),
            entityID: "cover.garage_door",
            displayName: "Garage Door",
            state: "closed",
            statusText: "Closed",
            systemImage: "door.garage.closed",
            isOpen: false,
            isClosed: true,
            isMoving: false,
            isAvailable: true,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadCoverWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadCoverEntry {
        await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadCoverWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadCoverEntry> {
        let entry = await entry(for: configuration)

        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(15 * 60))
        )
    }

    private func entry(for configuration: HomesteadCoverWidgetConfigurationIntent) async -> HomesteadCoverEntry {
        let configuredCover = configuration.selectedCover
        let latestConfiguredSnapshot = configuredCover.flatMap { cover in
            HomesteadWidgetSharedStore.coverSnapshot(entityID: cover.id)
        }
        let selectedCover = latestConfiguredSnapshot.map(Self.entity)
            ?? configuredCover
            ?? HomesteadWidgetSharedStore.coverSnapshots.first.map(Self.entity)

        guard let selectedCover else {
            return HomesteadCoverEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose a Cover",
                state: "unknown",
                statusText: "Open Homestead first",
                systemImage: "blinds.horizontal.closed",
                isOpen: false,
                isClosed: false,
                isMoving: false,
                isAvailable: false,
                isConfigured: false
            )
        }

        do {
            let state = try await HAWidgetActionClient().fetchCoverState(entityID: selectedCover.id)

            return HomesteadCoverEntry(
                date: Date(),
                entityID: state.entityID,
                displayName: state.displayName,
                state: state.state,
                statusText: state.statusText,
                systemImage: state.systemImage,
                isOpen: state.isOpen,
                isClosed: state.isClosed,
                isMoving: state.isMoving,
                isAvailable: state.isAvailable,
                isConfigured: true,
                icon: state.icon
            )
        } catch {
            return HomesteadCoverEntry(
                date: Date(),
                entityID: selectedCover.id,
                displayName: selectedCover.displayName,
                state: selectedCover.state,
                statusText: "Needs connection",
                systemImage: selectedCover.systemImage,
                isOpen: selectedCover.isOpen,
                isClosed: selectedCover.isClosed,
                isMoving: selectedCover.isMoving,
                isAvailable: selectedCover.isAvailable,
                isConfigured: true,
                icon: selectedCover.icon
            )
        }
    }

    private static func entity(from snapshot: WidgetCoverSnapshot) -> HomesteadCoverEntity {
        HomesteadCoverEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            state: snapshot.state,
            statusText: snapshot.statusText,
            systemImage: snapshot.resolvedIcon.fallbackSFSymbol,
            isOpen: snapshot.isOpen,
            isClosed: snapshot.isClosed,
            isMoving: snapshot.isMoving,
            isAvailable: snapshot.isAvailable,
            icon: snapshot.resolvedIcon
        )
    }
}

struct HomesteadCoverWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadCoverEntry

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
                    .foregroundStyle(entry.isOpen || entry.isMoving ? .primary : .secondary)
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
            HomesteadIconView(icon: entry.resolvedIcon, pointSize: 16)
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
            Button(intent: RunHomesteadCoverIntent(entityID: entityID, service: nextService)) {
                coverIcon
            }
            .buttonStyle(.plain)
        } else {
            coverIcon
        }
    }

    @ViewBuilder
    private var coverIcon: some View {
        if entry.isMoving {
            Image(systemName: "stop.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            HomesteadIconView(icon: entry.resolvedIcon, pointSize: 22)
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var nextService: String {
        if entry.isMoving {
            return "stop_cover"
        }

        return entry.isOpen ? "close_cover" : "open_cover"
    }

    private var iconColor: Color {
        guard entry.isAvailable else {
            return .secondary
        }

        return entry.isOpen || entry.isMoving ? .blue : .secondary
    }
}

#Preview(as: .systemSmall) {
    HomesteadCoverWidget()
} timeline: {
    HomesteadCoverEntry(
        date: .now,
        entityID: "cover.garage_door",
        displayName: "Garage Door",
        state: "closed",
        statusText: "Closed",
        systemImage: "door.garage.closed",
        isOpen: false,
        isClosed: true,
        isMoving: false,
        isAvailable: true,
        isConfigured: true
    )
    HomesteadCoverEntry(
        date: .now,
        entityID: "cover.living_room_shades",
        displayName: "Living Room Shades",
        state: "open",
        statusText: "Open • 70%",
        systemImage: "window.shade.open",
        isOpen: true,
        isClosed: false,
        isMoving: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadCoverWidget()
} timeline: {
    HomesteadCoverEntry(
        date: .now,
        entityID: "cover.living_room_shades",
        displayName: "Living Room Shades",
        state: "open",
        statusText: "Open • 70%",
        systemImage: "window.shade.open",
        isOpen: true,
        isClosed: false,
        isMoving: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryCircular) {
    HomesteadCoverWidget()
} timeline: {
    HomesteadCoverEntry(
        date: .now,
        entityID: "cover.garage_door",
        displayName: "Garage Door",
        state: "closed",
        statusText: "Closed",
        systemImage: "door.garage.closed",
        isOpen: false,
        isClosed: true,
        isMoving: false,
        isAvailable: true,
        isConfigured: true
    )
}
