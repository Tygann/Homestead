import SwiftUI

struct LogbookSettingsView: View {
    // MARK: - Properties

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
    @State private var presentedControls: ActivityControlsDestination?
    @State private var selectedEntityDestination: EntityDetailDestination?

    // MARK: - Body

    var body: some View {
        let presentation = HALogbookPresentation.make(
            rows: rows,
            searchText: searchText,
            selectedDomain: selectedDomain
        )

        List {
            controlsSection

            if let errorMessage, !rows.isEmpty {
                Section {
                    Label("Showing saved activity. Pull to refresh.", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityHint(errorMessage)
                }
            }

            activityContent(presentation)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Activity")
        .toolbarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .toolbar {
            if isLoading, !rows.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing activity")
                }
            }
        }
        .refreshable {
            await refreshLogbook(updatesPresetRange: true)
        }
        .task(id: queryTaskID) {
            await refreshLogbook(updatesPresetRange: false)
        }
        .sheet(item: $presentedControls) { destination in
            switch destination {
            case .range:
                ActivityRangeSheet(
                    rangePreset: $rangePreset,
                    startDate: $startDate,
                    endDate: $endDate
                )
            case .filters:
                ActivityFilterSheet(
                    selectedDomain: $selectedDomain,
                    selectedEntityID: $selectedEntityID,
                    availableDomains: availableDomains
                )
            }
        }
        .navigationDestination(item: $selectedEntityDestination) { destination in
            EntityDetailDestinationView(destination: destination)
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

    // MARK: - Sections

    private var controlsSection: some View {
        Section {
            HStack(spacing: AppSpacing.small) {
                Button {
                    presentedControls = .range
                } label: {
                    Label(rangePreset.title, systemImage: "calendar")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    presentedControls = .filters
                } label: {
                    HStack(spacing: AppSpacing.xSmall) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(filterButtonTitle)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .listRowInsets(EdgeInsets(
                top: AppSpacing.small,
                leading: AppSpacing.large,
                bottom: AppSpacing.small,
                trailing: AppSpacing.large
            ))

            if hasActiveFilter {
                Button {
                    presentedControls = .filters
                } label: {
                    Label(activeFilterTitle, systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func activityContent(_ presentation: HALogbookPresentation) -> some View {
        if isLoading, rows.isEmpty {
            Section {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
            .listRowBackground(Color.clear)
        } else if let errorMessage, rows.isEmpty {
            Section {
                ContentUnavailableView(
                    "Activity Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )

                Button("Try Again") {
                    Task { await refreshLogbook(updatesPresetRange: false) }
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        } else if rows.isEmpty {
            Section {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "clock",
                    description: Text("Home Assistant activity in this range will appear here.")
                )
            }
            .listRowBackground(Color.clear)
        } else if presentation.sections.isEmpty {
            Section {
                ContentUnavailableView.search(text: searchText)
            }
            .listRowBackground(Color.clear)
        } else {
            ForEach(presentation.sections) { section in
                Section {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        activityRow(
                            row,
                            showsConnector: index < section.rows.count - 1
                        )
                    }
                } header: {
                    Text(section.title)
                } footer: {
                    if section.id == presentation.sections.last?.id {
                        Text("\(presentation.visibleRowCount) \(presentation.visibleRowCount == 1 ? "event" : "events")")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func activityRow(_ row: HAActivityRow, showsConnector: Bool) -> some View {
        if let entityID = row.entityID, stateStore.entityBox(for: entityID) != nil {
            Button {
                selectedEntityDestination = EntityDetailDestination(entityID: entityID)
            } label: {
                HAActivityTimelineRow(row: row, showsConnector: showsConnector)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(row.title) details")
        } else {
            HAActivityTimelineRow(row: row, showsConnector: showsConnector)
        }
    }

    // MARK: - Helpers

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

    private var hasActiveFilter: Bool {
        selectedDomain != nil || selectedEntityID != nil
    }

    private var filterButtonTitle: String {
        hasActiveFilter ? "Filter \(selectedFilterCount)" : "Filter"
    }

    private var selectedFilterCount: Int {
        [selectedDomain != nil, selectedEntityID != nil].count(where: { $0 })
    }

    private var activeFilterTitle: String {
        if let selectedEntityID {
            return stateStore.entity(for: selectedEntityID)?.displayName ?? selectedEntityID
        }
        return selectedDomain?.displayName ?? "All Activity"
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

    // MARK: - Actions

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

// MARK: - Timeline

struct HAActivityTimelineRow: View {
    let row: HAActivityRow
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(spacing: 0) {
                HomesteadIconView(icon: row.resolvedIcon, pointSize: 13, weight: .bold)
                    .foregroundStyle(toneColor)
                    .frame(width: 30, height: 30)
                    .background(toneColor.opacity(0.14), in: Circle())

                if showsConnector {
                    Rectangle()
                        .fill(Color(.tertiaryLabel).opacity(0.35))
                        .frame(width: 2)
                        .frame(minHeight: 42)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    Text(row.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: AppSpacing.small)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    if let contextText {
                        Text(contextText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: AppSpacing.small)

                    Text(row.occurredAt.formatted(date: .omitted, time: .standard))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let attributionText {
                    Text(attributionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, showsConnector ? AppSpacing.small : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var toneColor: Color {
        switch row.timelineTone {
        case .active:
            .accentColor
        case .inactive:
            .secondary
        case .unavailable:
            .red
        }
    }

    private var contextText: String? {
        guard let sourceName = row.sourceName, sourceName != row.title else {
            return nil
        }
        return sourceName
    }

    private var statusText: String {
        let prefixes = ["changed to ", "turned ", "was ", "is ", "became "]
        for prefix in prefixes where row.message.hasPrefix(prefix) {
            let value = row.message.dropFirst(prefix.count)
            return value.prefix(1).uppercased() + value.dropFirst()
        }
        return row.message.prefix(1).uppercased() + row.message.dropFirst()
    }

    private var attributionText: String? {
        let parts = [row.triggerText, row.attributionName.map { "by \($0)" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var accessibilityLabel: String {
        [
            row.title,
            statusText,
            contextText,
            row.occurredAt.formatted(date: .omitted, time: .standard),
            attributionText
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

// MARK: - Control Sheets

private struct ActivityRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var rangePreset: LogbookDateRangePreset
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(LogbookDateRangePreset.allCases) { preset in
                        Button {
                            rangePreset = preset
                            if preset != .custom {
                                let range = preset.range(now: Date(), calendar: .current)
                                startDate = range.start
                                endDate = range.end
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(preset.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if rangePreset == preset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                if rangePreset == .custom {
                    Section("Custom Range") {
                        DatePicker("From", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Date Range")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ActivityFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Binding var selectedDomain: EntityDomain?
    @Binding var selectedEntityID: String?
    let availableDomains: [EntityDomain]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Domain", selection: $selectedDomain) {
                        Text("All Domains").tag(Optional<EntityDomain>.none)
                        ForEach(availableDomains, id: \.self) { domain in
                            Label(domain.displayName, systemImage: domain.systemImage)
                                .tag(Optional(domain))
                        }
                    }

                    NavigationLink {
                        LogbookEntityPickerView(
                            selectedEntityID: $selectedEntityID,
                            selectedDomain: selectedDomain
                        )
                    } label: {
                        LabeledContent("Entity", value: selectedEntityID.map(entityDisplayName) ?? "All Entities")
                    }
                }

                if selectedDomain != nil || selectedEntityID != nil {
                    Section {
                        Button("Reset Filters", role: .destructive) {
                            selectedDomain = nil
                            selectedEntityID = nil
                        }
                    }
                }
            }
            .navigationTitle("Filter Activity")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func entityDisplayName(_ entityID: String) -> String {
        stateStore.entity(for: entityID)?.displayName ?? entityID
            .split(separator: ".")
            .last
            .map { String($0).replacingOccurrences(of: "_", with: " ").capitalized } ?? entityID
    }
}

private struct LogbookEntityPickerView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Binding var selectedEntityID: String?
    let selectedDomain: EntityDomain?
    @State private var searchText = ""

    var body: some View {
        List {
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

private enum ActivityControlsDestination: String, Identifiable {
    case range
    case filters

    var id: String { rawValue }
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
        case .last24Hours: "Last 24 Hours"
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .last7Days: "Last 7 Days"
        case .custom: "Custom"
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
#Preview("Activity Settings") {
    NavigationStack {
        LogbookSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
