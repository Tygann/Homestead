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
                Text("Registry views use Home Assistant data already available to Homestead. Unsupported management categories are placeholders until official API support is added.")
            }
        }
        .navigationTitle("Devices & Services")
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(for section: DevicesAndServicesSection) -> some View {
        switch section {
        case .integrations:
            SettingsManagementPlaceholderView(
                title: section.title,
                systemImage: section.systemImage,
                message: "Native integration details are not available in Homestead yet."
            )
        case .devices:
            DeviceRegistryManagementList()
        case .entities:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Entities",
                emptySystemImage: section.systemImage
            )
        case .helpers:
            SettingsManagementPlaceholderView(
                title: section.title,
                systemImage: section.systemImage,
                message: "Native helper management will be added after Homestead supports the right Home Assistant APIs."
            )
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
            "Installed integrations and setup details"
        case .devices:
            "Registered hardware, bridges, and entity counts"
        case .entities:
            "Entity registry, status, area, and device details"
        case .helpers:
            "Home Assistant helper management"
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

private struct DeviceRegistryManagementList: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var searchText = ""
    @State private var grouping: DeviceManagementGrouping = .name

    var body: some View {
        let devices = stateStore.deviceManagementSummaries()
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
            if devices.isEmpty {
                ContentUnavailableView("No Devices", systemImage: "laptopcomputer.and.iphone")
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
            Label {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(device.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(device.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(entityCountText(for: device.entityCount))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, AppSpacing.xSmall)
            } icon: {
                Image(systemName: "laptopcomputer.and.iphone")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var groupingMenu: some View {
        Menu {
            ForEach(DeviceManagementGrouping.allCases) { option in
                Button {
                    grouping = option
                } label: {
                    Label(option.title, systemImage: grouping == option ? "checkmark" : option.systemImage)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Group devices")
    }

    private func entityCountText(for count: Int) -> String {
        count == 1 ? "1 entity" : "\(count) entities"
    }
}

private enum DeviceManagementGrouping: CaseIterable, Identifiable {
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
                    key: { $0.areaName ?? "No Area" },
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
                    id: title == "No Area" || title == "Unknown Manufacturer" ? fallbackID : title,
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
                Text("Automations, scenes, and scripts use entity data already available to Homestead. Blueprint browsing is a placeholder until official API support is added.")
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
                allowedDomains: [.automation]
            )
        case .scenes:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Scenes",
                emptySystemImage: section.systemImage,
                allowedDomains: [.scene]
            )
        case .scripts:
            EntityRegistryManagementBrowser(
                title: section.title,
                emptyTitle: "No Scripts",
                emptySystemImage: section.systemImage,
                allowedDomains: [.script]
            )
        case .blueprints:
            SettingsManagementPlaceholderView(
                title: section.title,
                systemImage: section.systemImage,
                message: "Native blueprint browsing will be added after Homestead supports an official Home Assistant API for it."
            )
        }
    }
}

private enum AutomationsAndScenesSection: CaseIterable, Identifiable {
    case automations
    case scenes
    case scripts
    case blueprints

    var id: Self { self }

    var title: String {
        switch self {
        case .automations:
            "Automations"
        case .scenes:
            "Scenes"
        case .scripts:
            "Scripts"
        case .blueprints:
            "Blueprints"
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
        case .blueprints:
            "Reusable automation and script templates"
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
        case .blueprints:
            "doc.badge.gearshape"
        }
    }
}

private struct EntityRegistryManagementBrowser: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var selectedEntity: SettingsSelectedEntity?

    let title: String
    let emptyTitle: String
    let emptySystemImage: String
    var allowedDomains: Set<EntityDomain>?

    var body: some View {
        EntityBrowserList(
            hiddenEntityIDs: [],
            emptyTitle: emptyTitle,
            emptySystemImage: emptySystemImage,
            includesUnavailableByDefault: true,
            showsGroupingMenu: allowedDomains == nil,
            showsSingleGroupHeaders: false,
            allowedDomains: allowedDomains,
            initialGrouping: allowedDomains == nil ? .device : .type,
            rowAction: { entityBox in
                selectedEntity = SettingsSelectedEntity(entityID: entityBox.entityID)
            },
            allowsDashboardMembershipEditing: false,
            rowDetail: { entityBox in
                stateStore.entityRegistryAdminDetail(for: entityBox.entityID)
            },
            accessory: { entityBox in
                EntityRegistryStatusAccessory(entityBox: entityBox)
            }
        )
        .sheet(item: $selectedEntity) { selectedEntity in
            if let entityBox = stateStore.entityBox(for: selectedEntity.entityID) {
                NavigationStack {
                    EntityDiagnosticsView(entityBox: entityBox)
                }
            }
        }
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct EntityRegistryStatusAccessory: View {
    let entityBox: HAEntityState

    var body: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(entityBox.homeEntity.isAvailable ? .secondary : Color.red)
            .lineLimit(1)
            .frame(width: 88, alignment: .trailing)
    }

    private var statusText: String {
        guard entityBox.homeEntity.isAvailable else {
            return "Unavailable"
        }

        return entityBox.homeEntity.domain.displayName
    }
}

private struct SettingsSelectedEntity: Identifiable {
    let entityID: String

    var id: String { entityID }
}
