import AppIntents
import SwiftUI
import WidgetKit

struct HomesteadLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "HomesteadLockWidget",
            intent: HomesteadLockWidgetConfigurationIntent.self,
            provider: HomesteadLockTimelineProvider()
        ) { entry in
            HomesteadLockWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Homestead Lock")
        .description("View and lock a Home Assistant lock from your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct HomesteadLockWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Homestead Lock"
    static var description = IntentDescription("Choose a Home Assistant lock.")

    @Parameter(title: "Lock")
    var selectedLock: HomesteadLockEntity?
}

struct LockHomesteadLockIntent: AppIntent {
    static var title: LocalizedStringResource = "Lock"
    static var description = IntentDescription("Locks a Home Assistant lock.")

    @Parameter(title: "Entity ID")
    var entityID: String

    init() {}

    init(entityID: String) {
        self.entityID = entityID
    }

    func perform() async throws -> some IntentResult {
        try await HAWidgetActionClient().lock(entityID: entityID)
        WidgetCenter.shared.reloadTimelines(ofKind: "HomesteadLockWidget")
        return .result()
    }
}

struct HomesteadLockEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Lock")
    static var defaultQuery = HomesteadLockEntityQuery()

    let id: String
    let displayName: String
    let state: String
    let statusText: String
    let systemImage: String
    let isLocked: Bool
    let isAvailable: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct HomesteadLockEntityQuery: EntityQuery {
    func entities(for identifiers: [HomesteadLockEntity.ID]) async throws -> [HomesteadLockEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HomesteadLockEntity] {
        allEntities()
    }

    func defaultResult() async -> HomesteadLockEntity? {
        allEntities().first
    }

    private func allEntities() -> [HomesteadLockEntity] {
        HomesteadWidgetSharedStore.lockSnapshots.map(Self.entity)
    }

    private static func entity(from snapshot: WidgetLockSnapshot) -> HomesteadLockEntity {
        HomesteadLockEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            state: snapshot.state,
            statusText: snapshot.statusText,
            systemImage: snapshot.systemImage,
            isLocked: snapshot.isLocked,
            isAvailable: snapshot.isAvailable
        )
    }
}

struct HomesteadLockEntry: TimelineEntry {
    let date: Date
    let entityID: String?
    let displayName: String
    let state: String
    let statusText: String
    let systemImage: String
    let isLocked: Bool
    let isAvailable: Bool
    let isConfigured: Bool

    var canLock: Bool {
        isConfigured && isAvailable && (state == "unlocked" || state == "unlocking")
    }
}

struct HomesteadLockTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomesteadLockEntry {
        HomesteadLockEntry(
            date: Date(),
            entityID: "lock.front_door",
            displayName: "Front Door",
            state: "locked",
            statusText: "Locked",
            systemImage: "lock.fill",
            isLocked: true,
            isAvailable: true,
            isConfigured: true
        )
    }

    func snapshot(
        for configuration: HomesteadLockWidgetConfigurationIntent,
        in context: Context
    ) async -> HomesteadLockEntry {
        await entry(for: configuration)
    }

    func timeline(
        for configuration: HomesteadLockWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<HomesteadLockEntry> {
        let entry = await entry(for: configuration)

        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(15 * 60))
        )
    }

    private func entry(for configuration: HomesteadLockWidgetConfigurationIntent) async -> HomesteadLockEntry {
        let configuredLock = configuration.selectedLock
        let latestConfiguredSnapshot = configuredLock.flatMap { lock in
            HomesteadWidgetSharedStore.lockSnapshot(entityID: lock.id)
        }
        let selectedLock = latestConfiguredSnapshot.map(Self.entity)
            ?? configuredLock
            ?? HomesteadWidgetSharedStore.lockSnapshots.first.map(Self.entity)

        guard let selectedLock else {
            return HomesteadLockEntry(
                date: Date(),
                entityID: nil,
                displayName: "Choose a Lock",
                state: "unknown",
                statusText: "Open Homestead first",
                systemImage: "lock.fill",
                isLocked: false,
                isAvailable: false,
                isConfigured: false
            )
        }

        do {
            let state = try await HAWidgetActionClient().fetchLockState(entityID: selectedLock.id)

            return HomesteadLockEntry(
                date: Date(),
                entityID: state.entityID,
                displayName: state.displayName,
                state: state.state,
                statusText: state.statusText,
                systemImage: state.systemImage,
                isLocked: state.isLocked,
                isAvailable: state.isAvailable,
                isConfigured: true
            )
        } catch {
            return HomesteadLockEntry(
                date: Date(),
                entityID: selectedLock.id,
                displayName: selectedLock.displayName,
                state: selectedLock.state,
                statusText: "Needs connection",
                systemImage: selectedLock.systemImage,
                isLocked: selectedLock.isLocked,
                isAvailable: selectedLock.isAvailable,
                isConfigured: true
            )
        }
    }

    private static func entity(from snapshot: WidgetLockSnapshot) -> HomesteadLockEntity {
        HomesteadLockEntity(
            id: snapshot.entityID,
            displayName: snapshot.displayName,
            state: snapshot.state,
            statusText: snapshot.statusText,
            systemImage: snapshot.systemImage,
            isLocked: snapshot.isLocked,
            isAvailable: snapshot.isAvailable
        )
    }
}

struct HomesteadLockWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HomesteadLockEntry

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
                    .foregroundStyle(entry.isLocked ? .secondary : .primary)
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
        if let entityID = entry.entityID, entry.canLock {
            Button(intent: LockHomesteadLockIntent(entityID: entityID)) {
                lockIcon
            }
            .buttonStyle(.plain)
        } else {
            lockIcon
        }
    }

    private var lockIcon: some View {
        Image(systemName: entry.systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var iconColor: Color {
        guard entry.isAvailable else {
            return .secondary
        }

        switch entry.state {
        case "locked", "locking":
            return .green
        case "jammed":
            return .red
        default:
            return .orange
        }
    }
}

#Preview(as: .systemSmall) {
    HomesteadLockWidget()
} timeline: {
    HomesteadLockEntry(
        date: .now,
        entityID: "lock.front_door",
        displayName: "Front Door",
        state: "locked",
        statusText: "Locked",
        systemImage: "lock.fill",
        isLocked: true,
        isAvailable: true,
        isConfigured: true
    )
    HomesteadLockEntry(
        date: .now,
        entityID: "lock.garage",
        displayName: "Garage Entry",
        state: "unlocked",
        statusText: "Unlocked",
        systemImage: "lock.open.fill",
        isLocked: false,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryRectangular) {
    HomesteadLockWidget()
} timeline: {
    HomesteadLockEntry(
        date: .now,
        entityID: "lock.front_door",
        displayName: "Front Door",
        state: "locked",
        statusText: "Locked",
        systemImage: "lock.fill",
        isLocked: true,
        isAvailable: true,
        isConfigured: true
    )
}

#Preview(as: .accessoryCircular) {
    HomesteadLockWidget()
} timeline: {
    HomesteadLockEntry(
        date: .now,
        entityID: "lock.garage",
        displayName: "Garage Entry",
        state: "unlocked",
        statusText: "Unlocked",
        systemImage: "lock.open.fill",
        isLocked: false,
        isAvailable: true,
        isConfigured: true
    )
}
