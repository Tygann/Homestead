import SwiftUI
import UIKit

struct PeopleSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var searchText = ""
    @State private var filter: HAPresenceFilter = .all
    @State private var grouping: HAPresenceGrouping = .kind

    var body: some View {
        let records = stateStore.presenceRecords()
        let presentation = HAPresencePresentation.make(
            records: records,
            searchText: searchText,
            filter: filter,
            grouping: grouping
        )

        List {
            if !records.isEmpty {
                controlsSection(summary: presentation.summary, visibleCount: presentation.visibleCount)
            }

            ForEach(presentation.sections) { section in
                Section(section.title) {
                    ForEach(section.records) { record in
                        NavigationLink {
                            PeoplePresenceDetailSettingsView(entityID: record.entityID)
                        } label: {
                            PeoplePresenceRow(record: record)
                        }
                    }
                }
            }
        }
        .overlay {
            if records.isEmpty {
                ContentUnavailableView("No People", systemImage: "person.2")
            } else if presentation.sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .navigationTitle("People")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    groupingMenu
                }
            }
        }
    }

    private func controlsSection(summary: HAPresenceSummary, visibleCount: Int) -> some View {
        Section {
            Picker("Filter", selection: $filter) {
                ForEach(HAPresenceFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)

            LabeledContent("Showing", value: "\(visibleCount) of \(summary.totalCount)")

            if summary.peopleCount > 0 {
                LabeledContent("People", value: String(summary.peopleCount))
            }

            if summary.trackerCount > 0 {
                LabeledContent("Trackers", value: String(summary.trackerCount))
            }

            if summary.homeCount > 0 {
                LabeledContent("Home", value: String(summary.homeCount))
            }

            if summary.awayCount > 0 {
                LabeledContent("Away", value: String(summary.awayCount))
            }

            if summary.zoneCount > 0 {
                LabeledContent("Zones", value: String(summary.zoneCount))
            }

            if summary.unavailableCount > 0 {
                LabeledContent("Unavailable", value: String(summary.unavailableCount))
            }
        }
    }

    private var groupingMenu: some View {
        Menu {
            ForEach(HAPresenceGrouping.allCases) { option in
                Button {
                    grouping = option
                } label: {
                    Label(option.title, systemImage: grouping == option ? "checkmark" : option.systemImage)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Group people")
    }
}

private struct PeoplePresenceRow: View {
    let record: HAPresenceRecord

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            PeoplePresenceImageView(record: record, size: 40)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(record.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(record.rowSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(record.contextSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.medium)

            PeoplePresenceStatusBadge(status: record.status)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}

private struct PeoplePresenceDetailSettingsView: View {
    @Environment(HAStateStore.self) private var stateStore

    let entityID: String

    var body: some View {
        Group {
            if let record {
                Form {
                    headerSection(record)
                    presenceSection(record)
                    relationshipsSection(record)
                    contextSection(record)
                    activitySection(record)
                    homeAssistantSection(record)
                }
            } else {
                ContentUnavailableView("Presence Missing", systemImage: "person.2")
                    .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(record?.displayName ?? "Presence")
        .toolbarTitleDisplayMode(.inline)
    }

    private var record: HAPresenceRecord? {
        stateStore.presenceRecord(for: entityID)
    }

    private func headerSection(_ record: HAPresenceRecord) -> some View {
        Section {
            HStack(spacing: AppSpacing.medium) {
                PeoplePresenceImageView(record: record, size: 56)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(record.displayName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    Text(record.status.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(record.status.tint)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.medium)
            }
            .padding(.vertical, AppSpacing.xSmall)
        }
    }

    private func presenceSection(_ record: HAPresenceRecord) -> some View {
        Section("Presence") {
            Label {
                Text(record.status.title)
            } icon: {
                Image(systemName: record.status.systemImage)
                    .foregroundStyle(record.status.tint)
            }

            LabeledContent("Kind", value: record.domain == .person ? "Person" : "Tracker")
            LabeledContent("State", value: record.rawState)

            if let sourceTypeTitle = record.sourceTypeTitle {
                LabeledContent("Source", value: sourceTypeTitle)
            }

            if let batteryText = record.batteryText {
                LabeledContent("Battery", value: batteryText)
            }

            if let gpsAccuracyText = record.gpsAccuracyText {
                LabeledContent("Accuracy", value: gpsAccuracyText)
            }

            if let lastChanged = record.lastChanged {
                LabeledContent("Changed") {
                    Text(lastChanged.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }

            if let lastUpdated = record.lastUpdated, record.lastUpdated != record.lastChanged {
                LabeledContent("Updated") {
                    Text(lastUpdated.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func relationshipsSection(_ record: HAPresenceRecord) -> some View {
        if record.isPerson {
            Section("Trackers") {
                if record.linkedTrackers.isEmpty {
                    Label("No linked trackers", systemImage: "location.slash")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(record.linkedTrackers) { tracker in
                        Label {
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text(tracker.displayName)
                                Text(tracker.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        } icon: {
                            Image(systemName: tracker.status.systemImage)
                                .foregroundStyle(tracker.status.tint)
                        }
                    }
                }
            }
        } else if let linkedPersonName = record.linkedPersonName {
            Section("Person") {
                Label(linkedPersonName, systemImage: "person.fill")
            }
        }
    }

    private func contextSection(_ record: HAPresenceRecord) -> some View {
        Section("Context") {
            if let areaName = record.context.areaName {
                LabeledContent("Area", value: areaName)
            }

            if let floorName = record.context.floorName {
                LabeledContent("Floor", value: floorName)
            }

            if let deviceName = record.context.deviceName {
                LabeledContent("Device", value: deviceName)
            }

            if record.context.areaName == nil,
               record.context.floorName == nil,
               record.context.deviceName == nil {
                Text("No area or device context")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func activitySection(_ record: HAPresenceRecord) -> some View {
        Section {
            NavigationLink {
                PeoplePresenceActivitySettingsView(record: record)
            } label: {
                Label("Recent Activity", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    private func homeAssistantSection(_ record: HAPresenceRecord) -> some View {
        Section("Home Assistant") {
            LabeledContent("Entity", value: record.entityID)
            LabeledContent("Domain", value: record.domain.displayName)

            if let sourceEntityID = record.sourceEntityID {
                LabeledContent("Tracker", value: sourceEntityID)
            }
        }
    }
}

private struct PeoplePresenceActivitySettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService

    @State private var selectedHistoryRange: HAHistoryRangePreset = .day
    @State private var timelinePhase: EntityHistoryTimelinePhase = .idle

    let record: HAPresenceRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                EntityHistoryTimelinePanel(
                    selectedRange: $selectedHistoryRange,
                    phase: timelinePhase,
                    tint: record.status.tint
                ) {
                    Task { await refreshTimeline() }
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Recent Activity")
        .toolbarTitleDisplayMode(.inline)
        .task(id: timelineTaskID) {
            await refreshTimeline()
        }
    }

    private var timelineTaskID: String {
        "\(record.entityID)-\(selectedHistoryRange.rawValue)"
    }

    @MainActor
    private func refreshTimeline() async {
        timelinePhase = .loading
        let interval = selectedHistoryRange.interval()
        let request = HAHistoryRequest(
            startDate: interval.start,
            endDate: interval.end,
            entityID: record.entityID
        )

        do {
            timelinePhase = .loaded(
                try await homeAssistantService.fetchTimeline(
                    settings: connectionSettings,
                    request: request,
                    range: selectedHistoryRange
                )
            )
        } catch {
            timelinePhase = .failed
        }
    }
}

private struct PeoplePresenceImageView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var image: Image?

    let record: HAPresenceRecord
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: record.iconSystemName)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(record.status.tint)
                    .frame(width: size, height: size)
                    .background(record.status.tint.opacity(0.12), in: Circle())
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: taskID) {
            await loadImage()
        }
        .accessibilityHidden(true)
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            record.entityPicturePath ?? "no-picture"
        ].joined(separator: "|")
    }

    private func loadImage() async {
        guard let entityPicturePath = record.entityPicturePath,
              let request = await homeAssistantService.homeAssistantImageRequest(
                settings: connectionSettings,
                pathOrURL: entityPicturePath
              ) else {
            image = nil
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let uiImage = UIImage(data: data) else {
                image = nil
                return
            }
            image = Image(uiImage: uiImage)
        } catch {
            image = nil
        }
    }
}

private struct PeoplePresenceStatusBadge: View {
    let status: HAPresenceStatus

    var body: some View {
        Text(status.shortTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.tint.opacity(0.12), in: Capsule())
    }
}

private extension HAPresenceStatus {
    var tint: Color {
        switch self {
        case .home:
            return .green
        case .zone:
            return .accentColor
        case .away:
            return .secondary
        case .unknown:
            return .orange
        case .unavailable:
            return .red
        }
    }
}

#if DEBUG
#Preview("People Settings") {
    NavigationStack {
        PeopleSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
