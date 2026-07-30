import SwiftUI

struct LogbookSettingsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HAStateStore.self) private var stateStore

    @State private var rangePreset: LogbookDateRangePreset = .last24Hours
    @State private var startDate = Date().addingTimeInterval(-86_400)
    @State private var endDate = Date()
    @State private var selectedDomain: EntityDomain?
    @State private var selectedEntityID: String?
    @State private var searchText = ""
    @State private var rows: [HAActivityRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastLoadedAt: Date?

    var body: some View {
        let presentation = HALogbookPresentation.make(
            rows: rows,
            searchText: searchText,
            selectedDomain: selectedDomain
        )

        List {
            rangeSection
            filtersSection

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)

                    Button {
                        Task { await refreshLogbook(updatesPresetRange: false) }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                }
            }

            if isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            } else if rows.isEmpty {
                Section {
                    ContentUnavailableView("No Activity", systemImage: "list.bullet.clipboard")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            } else if presentation.sections.isEmpty {
                Section {
                    ContentUnavailableView.search(text: searchText)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            } else {
                statusSection(visibleRowCount: presentation.visibleRowCount)

                ForEach(presentation.sections) { section in
                    Section(section.title) {
                        ForEach(section.rows) { row in
                            HAActivityRowView(row: row)
                        }
                    }
                }
            }
        }
        .navigationTitle("Logbook")
        .toolbarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .refreshable {
            await refreshLogbook(updatesPresetRange: true)
        }
        .task(id: queryTaskID) {
            await refreshLogbook(updatesPresetRange: false)
        }
        .onChange(of: rangePreset) { _, newValue in
            applyPreset(newValue)
        }
        .onChange(of: selectedDomain) { _, newValue in
            guard let selectedEntityID, let newValue else {
                return
            }

            if EntityDomain(entityID: selectedEntityID) != newValue {
                self.selectedEntityID = nil
            }
        }
    }

    private var rangeSection: some View {
        Section("Range") {
            Picker("Range", selection: $rangePreset) {
                ForEach(LogbookDateRangePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)

            if rangePreset == .custom {
                DatePicker("From", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                DatePicker("To", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
            } else {
                LabeledContent("From") {
                    Text(startDate.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                LabeledContent("To") {
                    Text(endDate.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var filtersSection: some View {
        Section("Filters") {
            Picker("Domain", selection: $selectedDomain) {
                Text("All Domains").tag(Optional<EntityDomain>.none)
                ForEach(availableDomains, id: \.self) { domain in
                    Label(domain.displayName, systemImage: domain.systemImage)
                        .tag(Optional(domain))
                }
            }
            .pickerStyle(.menu)

            NavigationLink {
                LogbookEntityPickerView(
                    selectedEntityID: $selectedEntityID,
                    selectedDomain: selectedDomain
                )
            } label: {
                LabeledContent("Entity", value: selectedEntityTitle)
            }
        }
    }

    private func statusSection(visibleRowCount: Int) -> some View {
        Section {
            LabeledContent("Events", value: String(visibleRowCount))

            if let lastLoadedAt {
                LabeledContent("Updated") {
                    Text(lastLoadedAt.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var availableDomains: [EntityDomain] {
        let entityDomains = stateStore.allEntities.map(\.domain)
        let rowDomains = rows.compactMap(\.entityDomain)
        return Array(Set(entityDomains + rowDomains))
            .sorted { lhs, rhs in
                if lhs.dashboardPriority != rhs.dashboardPriority {
                    return lhs.dashboardPriority < rhs.dashboardPriority
                }

                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private var selectedEntityTitle: String {
        guard let selectedEntityID else {
            return "All Entities"
        }

        return stateStore.entity(for: selectedEntityID)?.displayName ?? selectedEntityID
    }

    private var queryTaskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            String(startDate.timeIntervalSince1970),
            String(endDate.timeIntervalSince1970),
            selectedEntityID ?? "all"
        ].joined(separator: "|")
    }

    private func refreshLogbook(updatesPresetRange: Bool) async {
        if updatesPresetRange {
            applyPreset(rangePreset)
        }

        guard endDate > startDate else {
            errorMessage = "Choose an end date after the start date."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = HALogbookRequest(
                startDate: startDate,
                endDate: endDate,
                entityID: selectedEntityID
            )
            rows = try await homeAssistantService.fetchLogbook(
                settings: connectionSettings,
                request: request
            )
            lastLoadedAt = Date()
        } catch {
            errorMessage = HAConnectionIssuePresentation.message(for: error)
        }
    }

    private func applyPreset(_ preset: LogbookDateRangePreset) {
        guard preset != .custom else {
            return
        }

        let range = preset.range(now: Date(), calendar: .current)
        startDate = range.start
        endDate = range.end
    }
}

struct HAActivityRowView: View {
    let row: HAActivityRow
    var showsDetailText = true
    var showsRelativeTime = false

    var body: some View {
        Label {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(row.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(row.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if showsDetailText {
                        Text(row.detailText)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: AppSpacing.medium)

                VStack(alignment: .trailing, spacing: AppSpacing.xSmall) {
                    Text(row.occurredAt.formatted(date: .omitted, time: .shortened))

                    if showsRelativeTime {
                        Text(row.occurredAt, style: .relative)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            HomesteadIconView(icon: row.resolvedIcon, pointSize: 18)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }
}

private struct LogbookEntityPickerView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Binding var selectedEntityID: String?
    let selectedDomain: EntityDomain?
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                Button {
                    selectedEntityID = nil
                } label: {
                    LogbookEntityPickerRow(
                        title: "All Entities",
                        subtitle: selectedDomain?.displayName,
                        systemImage: "square.grid.2x2",
                        isSelected: selectedEntityID == nil
                    )
                }
                .foregroundStyle(.primary)
            }

            Section {
                ForEach(filteredEntities) { entity in
                    Button {
                        selectedEntityID = entity.entityID
                    } label: {
                        LogbookEntityPickerRow(
                            title: entity.displayName,
                            subtitle: entity.entityID,
                            systemImage: entity.domain.systemImage,
                            isSelected: selectedEntityID == entity.entityID
                        )
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .overlay {
            if filteredEntities.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .navigationTitle("Entity")
        .toolbarTitleDisplayMode(.inline)
    }

    private var filteredEntities: [HomeEntity] {
        stateStore.allEntities
            .filter { entity in
                selectedDomain == nil || entity.domain == selectedDomain
            }
            .filter { entity in
                let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedSearchText.isEmpty else {
                    return true
                }

                return "\(entity.displayName) \(entity.entityID) \(entity.domain.displayName)"
                    .localizedCaseInsensitiveContains(trimmedSearchText)
            }
    }
}

private struct LogbookEntityPickerRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        Label {
            HStack(spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(title)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }
}

private enum LogbookDateRangePreset: CaseIterable, Identifiable, Equatable {
    case last24Hours
    case today
    case yesterday
    case last7Days
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .last24Hours:
            "Last 24 Hours"
        case .today:
            "Today"
        case .yesterday:
            "Yesterday"
        case .last7Days:
            "Last 7 Days"
        case .custom:
            "Custom"
        }
    }

    func range(now: Date, calendar: Calendar) -> (start: Date, end: Date) {
        switch self {
        case .last24Hours:
            return (now.addingTimeInterval(-86_400), now)
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .yesterday:
            let todayStart = calendar.startOfDay(for: now)
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? now.addingTimeInterval(-86_400)
            return (yesterdayStart, todayStart)
        case .last7Days:
            return (calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-604_800), now)
        case .custom:
            return (now.addingTimeInterval(-86_400), now)
        }
    }
}

#if DEBUG
#Preview("Logbook Settings") {
    NavigationStack {
        LogbookSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
