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
    @State private var isShowingActivityFilters = false
    @State private var selectedEntityDestination: EntityDetailDestination?

    // MARK: - Body

    var body: some View {
        let presentation = HALogbookPresentation.make(
            rows: rows,
            searchText: searchText,
            selectedDomain: selectedDomain
        )

        List {
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isLoading, !rows.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing activity")
                }

                Button {
                    isShowingActivityFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(hasActiveFilter ? Color.accentColor : Color.primary)
                }
                .accessibilityLabel("Filter Activity")
                .accessibilityValue(filterAccessibilityValue)
            }
        }
        .refreshable {
            await refreshLogbook(updatesPresetRange: true)
        }
        .task(id: queryTaskID) {
            await refreshLogbook(updatesPresetRange: false)
        }
        .sheet(isPresented: $isShowingActivityFilters) {
            ActivityFilterSheet(
                rangePreset: $rangePreset,
                startDate: $startDate,
                endDate: $endDate,
                selectedDomain: $selectedDomain,
                selectedEntityID: $selectedEntityID,
                availableDomains: availableDomains
            )
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
                            hasPrevious: index > 0,
                            hasNext: index < section.rows.count - 1
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
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
    private func activityRow(_ row: HAActivityRow, hasPrevious: Bool, hasNext: Bool) -> some View {
        let subtitle = activitySubtitle(for: row)

        if let entityID = row.entityID, stateStore.entityBox(for: entityID) != nil {
            Button {
                selectedEntityDestination = EntityDetailDestination(entityID: entityID)
            } label: {
                HAActivityTimelineRow(
                    row: row,
                    subtitle: subtitle,
                    hasPrevious: hasPrevious,
                    hasNext: hasNext
                )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(row.title) details")
        } else {
            HAActivityTimelineRow(
                row: row,
                subtitle: subtitle,
                hasPrevious: hasPrevious,
                hasNext: hasNext
            )
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

    private var filterAccessibilityValue: String {
        let target = selectedEntityID.flatMap { stateStore.entity(for: $0)?.displayName } ??
            selectedDomain?.displayName
        return [rangePreset.title, target].compactMap { $0 }.joined(separator: ", ")
    }

    private func activitySubtitle(for row: HAActivityRow) -> String? {
        if let sourceName = normalizedActivityText(row.sourceName), sourceName != row.title {
            return sourceName
        }

        guard let entityID = row.entityID else {
            return nil
        }

        let areaName = normalizedActivityText(stateStore.areaName(for: entityID))
        let deviceID = normalizedActivityText(stateStore.entityRegistryMetadata(for: entityID)?.deviceID)
        let deviceName = normalizedActivityText(deviceID.flatMap { stateStore.deviceName(forDeviceID: $0) })
        let parts = [areaName, deviceName]
            .compactMap { $0 }
            .filter { $0 != row.title }
        let uniqueParts = parts.reduce(into: [String]()) { result, part in
            if !result.contains(part) {
                result.append(part)
            }
        }

        return uniqueParts.isEmpty ? nil : uniqueParts.joined(separator: " › ")
    }

    private func normalizedActivityText(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedValue.isEmpty ? nil : trimmedValue
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
    let subtitle: String?
    let hasPrevious: Bool
    let hasNext: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                if hasPrevious {
                    Rectangle()
                        .fill(railColor)
                        .frame(width: 2, height: Self.iconTopY)
                        .position(x: Self.iconCenterX, y: Self.iconTopY / 2)
                }

                if hasNext {
                    let railHeight = max(0, geometry.size.height - Self.iconBottomY)
                    Rectangle()
                        .fill(railColor)
                        .frame(width: 2, height: railHeight)
                        .position(
                            x: Self.iconCenterX,
                            y: Self.iconBottomY + railHeight / 2
                        )
                }
            }
            .allowsHitTesting(false)

            HomesteadIconView(icon: row.resolvedIcon, pointSize: 13, weight: .bold)
                .foregroundStyle(toneColor)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .background(toneColor.opacity(0.14), in: Circle())
                .offset(x: Self.horizontalPadding, y: Self.verticalPadding)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    Text(row.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(titleLineLimit)

                    Spacer(minLength: AppSpacing.small)

                    Text(row.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    if let subtitle {
                        Text(subtitle)
                            .lineLimit(1)
                    }

                    Spacer(minLength: AppSpacing.small)

                    Text(row.occurredAt.formatted(date: .omitted, time: .standard))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let tertiaryText {
                    Text(tertiaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, Self.contentLeadingPadding)
            .padding(.trailing, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
        }
        .frame(minHeight: 58)
        .overlay(alignment: .bottomTrailing) {
            if hasNext {
                Divider()
                    .padding(.leading, Self.contentLeadingPadding)
                    .padding(.trailing, Self.horizontalPadding)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private static let horizontalPadding: CGFloat = AppSpacing.large
    private static let verticalPadding: CGFloat = AppSpacing.medium
    private static let iconSize: CGFloat = 30
    private static let iconCenterX = horizontalPadding + iconSize / 2
    private static let iconTopY = verticalPadding
    private static let iconBottomY = verticalPadding + iconSize
    private static let contentLeadingPadding = horizontalPadding + iconSize + AppSpacing.medium

    private var railColor: Color {
        Color(.tertiaryLabel).opacity(0.35)
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

    private var tertiaryText: String? {
        attributionText
    }

    private var titleLineLimit: Int {
        subtitle == nil && tertiaryText == nil ? 2 : 1
    }

    private var attributionText: String? {
        let userAttribution = row.attributionName.map { "By \($0)" }
        let text = [row.triggerText, userAttribution].compactMap { $0 }.joined(separator: " • ")
        return text.isEmpty ? nil : text
    }

    private var accessibilityLabel: String {
        [
            row.title,
            row.statusText,
            subtitle,
            row.occurredAt.formatted(date: .omitted, time: .standard),
            attributionText
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

// MARK: - Control Sheets

private struct ActivityFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Binding var rangePreset: LogbookDateRangePreset
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var selectedDomain: EntityDomain?
    @Binding var selectedEntityID: String?
    let availableDomains: [EntityDomain]

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    Picker("Range", selection: $rangePreset) {
                        ForEach(LogbookDateRangePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    if rangePreset == .custom {
                        DatePicker("From", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Targets") {
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
            .onChange(of: rangePreset) { _, preset in
                guard preset != .custom else {
                    return
                }

                let range = preset.range(now: Date(), calendar: .current)
                startDate = range.start
                endDate = range.end
            }
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
struct ActivityTimelinePreviewScreen: View {
    private let rows = HAActivityRow.makeRows(
        from: [
            HALogbookEntryDTO(
                when: Date(timeIntervalSince1970: 1_775_000_745),
                name: "Office Ceiling Light",
                state: "off",
                domain: "light",
                entityID: "light.office_ceiling",
                contextName: "Office • Light • Presence",
                contextDomain: "automation"
            ),
            HALogbookEntryDTO(
                when: Date(timeIntervalSince1970: 1_775_000_710),
                name: "Ashton Bedroom Apple TV",
                state: "playing",
                domain: "media_player",
                entityID: "media_player.ashton_bedroom_apple_tv"
            ),
            HALogbookEntryDTO(
                when: Date(timeIntervalSince1970: 1_775_000_680),
                name: "Front Porch Camera Snapshot",
                state: "unavailable",
                domain: "camera",
                entityID: "camera.front_porch_snapshot"
            ),
            HALogbookEntryDTO(
                when: Date(timeIntervalSince1970: 1_775_000_640),
                name: "Date & Time",
                state: "2026-07-30, 16:02",
                domain: "sensor",
                entityID: "sensor.date_time"
            )
        ],
        entityDisplayName: { _ in nil }
    )

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HAActivityTimelineRow(
                            row: row,
                            subtitle: subtitle(for: row.entityID),
                            hasPrevious: index > 0,
                            hasNext: index < rows.count - 1
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Activity")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
    }

    private func subtitle(for entityID: String?) -> String? {
        switch entityID {
        case "light.office_ceiling":
            "Office › Office Ceiling Fan"
        case "media_player.ashton_bedroom_apple_tv":
            "Ashton Bedroom"
        default:
            nil
        }
    }
}
#endif

#if DEBUG
#Preview("Activity Settings") {
    NavigationStack {
        LogbookSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
