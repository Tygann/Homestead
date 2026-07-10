import SwiftUI

// MARK: - Devices and Services Management
struct DevicesAndServicesManagementView: View {
    var body: some View {
        Form {
            Section {
                ForEach(DevicesAndServicesSection.allCases) { section in
                    NavigationLink {
                        destination(for: section)
                    } label: {
                        SettingsManagementOverviewRow(
                            title: section.title,
                            subtitle: section.subtitle,
                            systemImage: section.systemImage
                        )
                    }
                }
            } footer: {
                Text("Homestead shows the devices, services, and helpers already available from Home Assistant. Setup and configuration changes stay in Home Assistant.")
            }
        }
        .navigationTitle("Devices & Services")
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(for section: DevicesAndServicesSection) -> some View {
        switch section {
        case .integrations:
            IntegrationRegistryManagementList()
        case .devices:
            DeviceRegistryManagementList()
        case .entities:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Entities",
                emptySystemImage: section.systemImage,
                groupingPersistenceKey: "homestead.management.entities.grouping"
            )
        case .helpers:
            HelperRegistryManagementList()
        }
    }
}

private enum DevicesAndServicesSection: CaseIterable, Identifiable {
    case integrations
    case devices
    case entities
    case helpers

    var id: Self { self }

    var title: String {
        switch self {
        case .integrations:
            "Integrations"
        case .devices:
            "Devices"
        case .entities:
            "Entities"
        case .helpers:
            "Helpers"
        }
    }

    var subtitle: String {
        switch self {
        case .integrations:
            "Connected services with their devices and entities"
        case .devices:
            "Registered hardware, bridges, and entity counts"
        case .entities:
            "Status, area, and device details"
        case .helpers:
            "Helper entities available from Home Assistant"
        }
    }

    var systemImage: String {
        switch self {
        case .integrations:
            "puzzlepiece.extension"
        case .devices:
            "laptopcomputer.and.iphone"
        case .entities:
            "square.grid.2x2"
        case .helpers:
            "wrench.and.screwdriver"
        }
    }
}

private struct IntegrationRegistryManagementList: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var searchText = ""

    var body: some View {
        let summaries = stateStore.integrationManagementSummaries()
        let visibleSummaries = summaries.filter { $0.matches(query: searchText) }

        List {
            Section {
                ForEach(visibleSummaries) { summary in
                    NavigationLink {
                        IntegrationRegistryDetailView(summary: summary)
                    } label: {
                        IntegrationManagementRow(summary: summary)
                    }
                }
            }
        }
        .overlay {
            if summaries.isEmpty {
                ContentUnavailableView("No Integrations", systemImage: "puzzlepiece.extension")
            } else if visibleSummaries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .navigationTitle("Integrations")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct IntegrationManagementRow: View {
    let summary: HAIntegrationManagementSummary

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            IntegrationBrandImageView(platform: summary.platform, size: 36, fallbackSystemImage: "puzzlepiece.extension")

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(summary.title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(summary.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, AppSpacing.xSmall)
        }
    }
}

private struct IntegrationRegistryDetailView: View {
    @Environment(HAStateStore.self) private var stateStore

    let summary: HAIntegrationManagementSummary

    var body: some View {
        List {
            Section {
                HStack(spacing: AppSpacing.medium) {
                    IntegrationBrandImageView(platform: summary.platform, size: 52, fallbackSystemImage: "puzzlepiece.extension")

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(summary.title)
                            .font(.headline)
                        Text(summary.detailSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, AppSpacing.small)
            }

            Section {
                LabeledContent("Entities", value: "\(summary.entityCount)")
                LabeledContent("Devices", value: "\(summary.deviceCount)")

                if summary.unavailableEntityCount > 0 {
                    LabeledContent("Unavailable", value: "\(summary.unavailableEntityCount)")
                }
                if summary.configEntityCount > 0 {
                    LabeledContent("Config Entities", value: "\(summary.configEntityCount)")
                }
                if summary.diagnosticEntityCount > 0 {
                    LabeledContent("Diagnostic Entities", value: "\(summary.diagnosticEntityCount)")
                }
                if summary.hiddenEntityCount > 0 {
                    LabeledContent("Hidden", value: "\(summary.hiddenEntityCount)")
                }
            }

            if !summary.devices.isEmpty {
                Section("Devices") {
                    ForEach(summary.devices) { device in
                        NavigationLink {
                            DeviceRegistryDetailView(device: device)
                        } label: {
                            HStack(spacing: AppSpacing.medium) {
                                DeviceManagementIconView(device: device, size: 36)

                                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                    Text(device.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text(device.rowSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, AppSpacing.xSmall)
                            }
                        }
                    }
                }
            }

            if !summary.unassignedEntityIDs.isEmpty {
                Section(summary.devices.isEmpty ? "Entities" : "Entities Without a Device") {
                    ForEach(summary.unassignedEntityIDs, id: \.self) { entityID in
                        if let entityBox = stateStore.entityBox(for: entityID) {
                            NavigationLink {
                                EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation)
                            } label: {
                                EntityBrowserRow(
                                    entityBox: entityBox,
                                    displayNameOverride: nil,
                                    detailText: stateStore.entityRegistryAdminDetail(for: entityID),
                                    accessory: EntityRegistryStatusAccessory(entityBox: entityBox, showsDomain: true)
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(summary.title)
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct IntegrationBrandImageView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.colorScheme) private var colorScheme

    let platform: String
    let size: CGFloat
    var fallbackSystemImage = "puzzlepiece.extension"

    var body: some View {
        HomeAssistantAsyncImage(
            id: taskID,
            request: {
                let imageName = colorScheme == .dark ? "dark_icon@2x.png" : "icon@2x.png"
                let path = "/api/brands/integration/\(platform)/\(imageName)"
                return await homeAssistantService.homeAssistantImageRequest(
                    settings: connectionSettings,
                    pathOrURL: path
                )
            }
        ) { image in
            if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.06)
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: size, height: size)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: min(10, size * 0.22), style: .continuous)
                    )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var taskID: String {
        [
            connectionSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            homeAssistantService.authState.title,
            homeAssistantService.connectionStatus.title,
            platform,
            colorScheme == .dark ? "dark" : "light"
        ].joined(separator: "|")
    }

}

private struct HelperRegistryManagementList: View {
    @Environment(HAStateStore.self) private var stateStore

    var body: some View {
        let summaries = stateStore.helperManagementSummaries()
        let helperEntityIDs = stateStore.helperEntityIDs()

        EntityBrowserList(
            hiddenEntityIDs: [],
            emptyTitle: "No Helpers",
            emptySystemImage: "wrench.and.screwdriver",
            showsFilters: true,
            includesUnavailableByDefault: true,
            groupingPersistenceKey: "homestead.management.helpers.grouping",
            allowedGroupings: [.name, .type, .area, .category],
            showsGroupingMenu: true,
            showsSingleGroupHeaders: summaries.count > 1,
            allowedEntityIDs: helperEntityIDs,
            organizationScope: .helper,
            showsLabelFilter: true,
            initialGrouping: .name,
            rowAction: { entityBox in
                _ = entityBox
            },
            rowDetail: { entityBox in
                stateStore.managementOrganizationDetail(for: entityBox.entityID, scope: .helper)
                    ?? helperDetail(for: entityBox.entityID)
            },
            typeGroup: { entityBox in
                helperGroup(for: entityBox.entityID)
            },
            rowDestination: { entityBox in
                AnyView(EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation))
            },
            accessory: { entityBox in
                EntityRegistryStatusAccessory(entityBox: entityBox, showsDomain: false)
            }
        )
        .navigationTitle("Helpers")
        .toolbarTitleDisplayMode(.inline)
    }

    private func helperDetail(for entityID: String) -> String? {
        HAHelperDomain(entityID: entityID)?.displayName
    }

    private func helperGroup(for entityID: String) -> EntityBrowserGroup? {
        guard let domain = HAHelperDomain(entityID: entityID) else {
            return nil
        }

        return EntityBrowserGroup(
            id: "helper-\(domain.rawValue)",
            title: domain.displayName,
            systemImage: domain.systemImage,
            entityIDs: []
        )
    }
}

private struct DeviceRegistryManagementList: View {
    @Environment(HAStateStore.self) private var stateStore
    @AppStorage("homestead.management.devices.grouping") private var groupingRawValue = DeviceManagementGrouping.name.rawValue
    @State private var searchText = ""
    @State private var selectedLabel: String?

    var body: some View {
        let grouping = currentGrouping
        let allDevices = stateStore.deviceManagementSummaries()
        let devices = allDevices.filter { device in
            guard let selectedLabel else { return true }
            return device.labels.contains(selectedLabel)
        }
        let presentation = DeviceManagementPresentation.make(
            devices: devices,
            searchText: searchText,
            grouping: grouping
        )

        List {
            ForEach(presentation.groups) { group in
                if grouping == .name || presentation.groups.count == 1 {
                    Section {
                        deviceRows(group.devices)
                    }
                } else {
                    Section(group.title) {
                        deviceRows(group.devices)
                    }
                }
            }
        }
        .overlay {
            if allDevices.isEmpty {
                ContentUnavailableView("No Devices", systemImage: "laptopcomputer.and.iphone")
            } else if devices.isEmpty, let selectedLabel {
                ContentUnavailableView("No Devices with \(selectedLabel)", systemImage: "tag")
            } else if presentation.groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .navigationTitle("Devices")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !devices.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    groupingMenu
                }
            }
        }
    }

    @ViewBuilder
    private func deviceRows(_ devices: [HADeviceManagementSummary]) -> some View {
        ForEach(devices) { device in
            NavigationLink {
                DeviceRegistryDetailView(device: device)
            } label: {
                HStack(spacing: AppSpacing.medium) {
                    DeviceManagementIconView(device: device, size: 36)

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(device.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(device.rowSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, AppSpacing.xSmall)
                }
            }
        }
    }

    private var groupingMenu: some View {
        Menu {
            Section("Group By") {
                ForEach(DeviceManagementGrouping.allCases) { option in
                    Button {
                        groupingRawValue = option.rawValue
                    } label: {
                        Label(option.title, systemImage: currentGrouping == option ? "checkmark" : option.systemImage)
                    }
                }
            }

            if !availableLabels.isEmpty {
                Section("Label") {
                    Button {
                        selectedLabel = nil
                    } label: {
                        Label("All Labels", systemImage: selectedLabel == nil ? "checkmark" : "tag")
                    }
                    ForEach(availableLabels, id: \.self) { label in
                        Button {
                            selectedLabel = label
                        } label: {
                            Label(label, systemImage: selectedLabel == label ? "checkmark" : "tag")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Group devices")
    }

    private var availableLabels: [String] {
        Set(stateStore.deviceManagementSummaries().flatMap(\.labels)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private var currentGrouping: DeviceManagementGrouping {
        DeviceManagementGrouping(rawValue: groupingRawValue) ?? .name
    }
}

private struct DeviceManagementIconView: View {
    let device: HADeviceManagementSummary
    let size: CGFloat

    var body: some View {
        if let platform = device.platform {
            IntegrationBrandImageView(platform: platform, size: size, fallbackSystemImage: "laptopcomputer.and.iphone")
        } else {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: size, height: size)
                .background(
                    Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: min(10, size * 0.22), style: .continuous)
                )
                .accessibilityHidden(true)
        }
    }
}

private struct DeviceRegistryDetailView: View {
    @Environment(HAStateStore.self) private var stateStore

    let device: HADeviceManagementSummary

    var body: some View {
        List {
            Section {
                HStack(spacing: AppSpacing.medium) {
                    DeviceManagementIconView(device: device, size: 52)

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(device.title)
                            .font(.headline)
                            .lineLimit(2)

                        Text(device.detailSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, AppSpacing.small)
            }

            Section {
                LabeledContent("Entities", value: device.entityCountText)

                if let areaName = device.areaName {
                    LabeledContent("Area", value: areaName)
                }

                if let manufacturer = device.manufacturer {
                    LabeledContent("Manufacturer", value: manufacturer)
                }

                if let model = device.model {
                    LabeledContent("Model", value: model)
                }

                if device.unavailableEntityCount > 0 {
                    LabeledContent("Unavailable", value: "\(device.unavailableEntityCount)")
                }
            }

            if !device.entityIDs.isEmpty {
                Section("Entities") {
                    ForEach(device.entityIDs, id: \.self) { entityID in
                        if let entityBox = stateStore.entityBox(for: entityID) {
                            NavigationLink {
                                EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation)
                            } label: {
                                EntityBrowserRow(
                                    entityBox: entityBox,
                                    displayNameOverride: nil,
                                    detailText: stateStore.entityRegistryAdminDetail(for: entityID),
                                    accessory: EntityRegistryStatusAccessory(entityBox: entityBox, showsDomain: true)
                                )
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(device.title)
        .toolbarTitleDisplayMode(.inline)
    }
}

private enum DeviceManagementGrouping: String, CaseIterable, Identifiable {
    case name
    case area
    case manufacturer

    var id: Self { self }

    var title: String {
        switch self {
        case .name:
            "Name"
        case .area:
            "Area"
        case .manufacturer:
            "Manufacturer"
        }
    }

    var systemImage: String {
        switch self {
        case .name:
            "textformat"
        case .area:
            "square.grid.3x3"
        case .manufacturer:
            "building.2"
        }
    }
}

private struct DeviceManagementPresentation {
    struct Group: Identifiable {
        let id: String
        let title: String
        let devices: [HADeviceManagementSummary]
    }

    let groups: [Group]

    static func make(
        devices: [HADeviceManagementSummary],
        searchText: String,
        grouping: DeviceManagementGrouping
    ) -> DeviceManagementPresentation {
        let matchingDevices = devices.filter { $0.matches(query: searchText) }

        switch grouping {
        case .name:
            return DeviceManagementPresentation(groups: [
                Group(id: "name", title: "Devices", devices: matchingDevices)
            ].filter { !$0.devices.isEmpty })
        case .area:
            return DeviceManagementPresentation(
                groups: groupedDevices(
                    matchingDevices,
                    key: { $0.areaName ?? DashboardAreaBuilder.unassignedAreaName },
                    fallbackID: "no-area"
                )
            )
        case .manufacturer:
            return DeviceManagementPresentation(
                groups: groupedDevices(
                    matchingDevices,
                    key: { $0.manufacturer ?? "Unknown Manufacturer" },
                    fallbackID: "unknown-manufacturer"
                )
            )
        }
    }

    private static func groupedDevices(
        _ devices: [HADeviceManagementSummary],
        key: (HADeviceManagementSummary) -> String,
        fallbackID: String
    ) -> [Group] {
        Dictionary(grouping: devices, by: key)
            .map { title, devices in
                Group(
                    id: title == DashboardAreaBuilder.unassignedAreaName || title == "Unknown Manufacturer" ? fallbackID : title,
                    title: title,
                    devices: devices.sortedByDeviceTitle
                )
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }
}

private extension Array where Element == HADeviceManagementSummary {
    var sortedByDeviceTitle: [HADeviceManagementSummary] {
        sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

// MARK: - Automations and Scenes Management
struct AutomationsAndScenesManagementView: View {
    var body: some View {
        Form {
            Section {
                ForEach(AutomationsAndScenesSection.allCases) { section in
                    NavigationLink {
                        destination(for: section)
                    } label: {
                        SettingsManagementOverviewRow(
                            title: section.title,
                            subtitle: section.subtitle,
                            systemImage: section.systemImage
                        )
                    }
                }
            } footer: {
                Text("Homestead shows automations, scenes, and scripts already available from Home Assistant. Advanced editing stays in Home Assistant.")
            }
        }
        .navigationTitle("Automations & Scenes")
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(for section: AutomationsAndScenesSection) -> some View {
        switch section {
        case .automations:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Automations",
                emptySystemImage: section.systemImage,
                allowedDomains: [.automation],
                groupingPersistenceKey: "homestead.management.automations.grouping",
                organizationScope: .automation,
                allowedGroupings: [.name, .area, .category, .recent]
            )
        case .scenes:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Scenes",
                emptySystemImage: section.systemImage,
                allowedDomains: [.scene],
                groupingPersistenceKey: "homestead.management.scenes.grouping",
                organizationScope: .scene,
                allowedGroupings: [.name, .area, .category, .recent]
            )
        case .scripts:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Scripts",
                emptySystemImage: section.systemImage,
                allowedDomains: [.script],
                groupingPersistenceKey: "homestead.management.scripts.grouping",
                organizationScope: .script,
                allowedGroupings: [.name, .area, .category, .recent]
            )
        }
    }
}

private enum AutomationsAndScenesSection: CaseIterable, Identifiable {
    case automations
    case scenes
    case scripts

    var id: Self { self }

    var title: String {
        switch self {
        case .automations:
            "Automations"
        case .scenes:
            "Scenes"
        case .scripts:
            "Scripts"
        }
    }

    var subtitle: String {
        switch self {
        case .automations:
            "Rules and triggers exposed as Home Assistant entities"
        case .scenes:
            "Scene entities available for native activation"
        case .scripts:
            "Script entities available for native runs"
        }
    }

    var systemImage: String {
        switch self {
        case .automations:
            EntityDomain.automation.systemImage
        case .scenes:
            EntityDomain.scene.systemImage
        case .scripts:
            EntityDomain.script.systemImage
        }
    }
}

private struct EntityRegistryManagementBrowser: View {
    @Environment(HAStateStore.self) private var stateStore

    let title: String
    let emptyTitle: String
    let emptySystemImage: String
    var allowedDomains: Set<EntityDomain>?
    var groupingPersistenceKey: String?
    var organizationScope: HAOrganizationScope?
    var allowedGroupings: [EntityBrowserGrouping]?

    var body: some View {
        EntityBrowserList(
            hiddenEntityIDs: [],
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            showsFilters: true,
            includesUnavailableByDefault: true,
            groupingPersistenceKey: groupingPersistenceKey,
            allowedGroupings: allowedGroupings ?? (allowedDomains == nil ? [.name, .device, .type, .area] : [.name]),
            showsGroupingMenu: true,
            showsSingleGroupHeaders: false,
            allowedDomains: allowedDomains,
            organizationScope: organizationScope,
            showsLabelFilter: true,
            showsAutomationStateFilter: organizationScope == .automation,
            initialGrouping: .name,
            rowAction: { entityBox in
                _ = entityBox
            },
            rowDetail: { entityBox in
                managementRowDetail(for: entityBox)
            },
            rowDestination: { entityBox in
                AnyView(EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation))
            },
            accessory: { entityBox in
                EntityRegistryStatusAccessory(entityBox: entityBox, showsDomain: allowedDomains == nil)
            }
        )
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }

    private func managementRowDetail(for entityBox: HAEntityState) -> String? {
        let organizationDetail = stateStore.managementOrganizationDetail(for: entityBox.entityID, scope: organizationScope)
        guard allowedGroupings?.contains(.recent) == true,
              let date = stateStore.managementActivityDate(for: entityBox.entityID) else {
            return organizationDetail
        }

        let verb: String
        switch entityBox.homeEntity.domain {
        case .automation: verb = "Triggered"
        case .scene: verb = "Activated"
        case .script: verb = "Run"
        default: verb = "Used"
        }
        let activity = "\(verb) \(date.formatted(.relative(presentation: .named)))"
        return [organizationDetail, activity]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " • ")
    }
}

private struct EntityRegistryStatusAccessory: View {
    @Environment(HAStateStore.self) private var stateStore

    let entityBox: HAEntityState
    var showsDomain = true

    var body: some View {
        if !entityBox.homeEntity.isAvailable {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.red)
                .accessibilityLabel("Unavailable")
        } else if stateStore.entityRegistryMetadata(for: entityBox.entityID)?.hiddenBy == true {
            Image(systemName: "eye.slash.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Hidden")
        } else if entityBox.homeEntity.domain == .automation {
            Image(systemName: entityBox.homeEntity.state == "on" ? "checkmark.circle.fill" : "pause.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(entityBox.homeEntity.state == "on" ? Color.accentColor : Color.secondary)
                .accessibilityLabel(entityBox.homeEntity.state == "on" ? "Enabled" : "Disabled")
        }
    }
}
