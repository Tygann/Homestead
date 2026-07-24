import SwiftUI

struct EntityDiagnosticsView: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(HAStateStore.self) private var stateStore
    @State private var frontendDestination: HomeAssistantFrontendEntityDestination?
    @State private var isResolvingFrontendDestination = false
    @State private var showsFrontendDestinationError = false

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .navigationStack
    var surfaceContext: EntityDetailSurfaceContext = .standard

    var body: some View {
        let entity = entityBox.homeEntity
        let rawEntity = stateStore.rawEntity(for: entity.entityID)
        let registry = stateStore.entityRegistryMetadata(for: entity.entityID)
        let device = stateStore.deviceRegistryMetadata(forEntityID: entity.entityID)

        List {
            Section {
                EntitySummaryHeader(entityBox: entityBox)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                EntityDetailRow(title: "Entity ID", value: entity.entityID)
                EntityDetailRow(title: "Domain", value: entity.domain.displayName)
                EntityDetailRow(title: "State", value: displayState(for: entityBox))

                if let lastUpdated = rawEntity?.lastUpdated ?? entity.lastUpdated {
                    EntityDetailRow(title: "Last Updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened))
                }

                if let lastChanged = rawEntity?.lastChanged {
                    EntityDetailRow(title: "Last Changed", value: lastChanged.formatted(date: .abbreviated, time: .shortened))
                }
            } header: {
                HomesteadListSectionHeader("State")
            }
            .homesteadListRowSurface()

            Section {
                Button {
                    openInHomeAssistant(entityID: entity.entityID)
                } label: {
                    Label(frontendActionTitle(for: entity), systemImage: "safari")
                }
                .disabled(isResolvingFrontendDestination)
            } footer: {
                Text("Uses Home Assistant’s web session. You may be asked to sign in.")
            }
            .homesteadListRowSurface()

            if let device {
                Section {
                    EntityDetailRow(title: "Name", value: device.displayName)

                    if let manufacturer = device.manufacturer?.nonEmptyValue {
                        EntityDetailRow(title: "Manufacturer", value: manufacturer)
                    }

                    if let model = device.model?.nonEmptyValue {
                        EntityDetailRow(title: "Model", value: model)
                    }

                    EntityDetailRow(title: "Device ID", value: device.id)
                } header: {
                    HomesteadListSectionHeader("Device")
                }
                .homesteadListRowSurface()
            }

            if let registry {
                Section {
                    if let name = registry.name?.nonEmptyValue {
                        EntityDetailRow(title: "Name", value: name)
                    }

                    if let originalName = registry.originalName?.nonEmptyValue {
                        EntityDetailRow(title: "Original Name", value: originalName)
                    }

                    if let deviceID = registry.deviceID?.nonEmptyValue {
                        EntityDetailRow(title: "Device ID", value: deviceID)
                    }

                    if let hiddenBy = registry.hiddenBy {
                        EntityDetailRow(title: "Hidden", value: hiddenBy ? "Yes" : "No")
                    }
                } header: {
                    HomesteadListSectionHeader("Registry")
                }
                .homesteadListRowSurface()
            }

            if let attributes = rawEntity?.attributes, !attributes.isEmpty {
                Section {
                    ForEach(attributes.sortedByKey, id: \.key) { key, value in
                        EntityDetailRow(title: key.humanizedAttributeName, value: value.detailDisplayValue)
                    }
                } header: {
                    HomesteadListSectionHeader("Attributes")
                }
                .homesteadListRowSurface()
            }
        }
        .scrollContentBackground(.hidden)
        .homesteadWallpaperBackground(allowsWallpaper: surfaceContext == .home)
        .environment(\.homesteadEntityDetailSurfaceContext, surfaceContext)
        .entityDetailPresentation(title: "Entity Details", style: presentationStyle)
        .fullScreenCover(item: $frontendDestination) { destination in
            HomeAssistantSafariView(url: destination.url)
                .ignoresSafeArea()
        }
        .alert("Unable to Open Home Assistant", isPresented: $showsFrontendDestinationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Homestead could not form a supported destination for this entity and connection.")
        }
    }

    private func frontendActionTitle(for entity: HomeEntity) -> String {
        let rawEntity = stateStore.rawEntity(for: entity.entityID)
        let isPersonEditable = rawEntity?.attributes["editable"]?.boolValue
            ?? (rawEntity?.attributes["editable"]?.stringValue?.lowercased() != "false")

        return HomeAssistantFrontendEntityDestinationResolver.destination(
            baseURLString: connectionSettings.baseURL,
            entityID: entity.entityID,
            configurationID: rawEntity?.attributes["id"]?.stringValue,
            registryUniqueID: stateStore.entityRegistryUniqueID(for: entity.entityID),
            isPersonEditable: isPersonEditable
        )?.action.title ?? "Open in Home Assistant"
    }

    private func openInHomeAssistant(entityID: String) {
        guard !isResolvingFrontendDestination else { return }
        isResolvingFrontendDestination = true

        Task {
            let destination = await homeAssistantService.homeAssistantFrontendDestination(
                settings: connectionSettings,
                entityID: entityID
            )
            frontendDestination = destination
            showsFrontendDestinationError = destination == nil
            isResolvingFrontendDestination = false
        }
    }

    private func displayState(for entityBox: HAEntityState) -> String {
        if let sensor = entityBox.sensorEntity {
            return sensor.formattedValue
        }

        if let light = entityBox.lightEntity {
            guard light.isOn else { return "Off" }
            guard let brightnessPercentage = light.brightnessPercentage else { return "On" }

            return "On, \(brightnessPercentage)%"
        }

        if let cover = entityBox.coverEntity {
            return cover.displaySubtitle
        }

        if let climate = entityBox.climateEntity {
            return climate.displaySubtitle
        }

        return entityBox.homeEntity.state.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct EntitySummaryHeader: View {
    let entityBox: HAEntityState

    var body: some View {
        let entity = entityBox.homeEntity

        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                CardIconView(icon: entity.resolvedIcon, isActive: isActive)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(entity.displayName)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)

                    Text(entity.entityID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Text(summaryText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(summaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isActive: Bool {
        if let light = entityBox.lightEntity {
            return light.isOn
        }

        let state = entityBox.homeEntity.state
        return state == "on" || state == "open" || state == "home" || state == "playing" || state == "cleaning" || state == "unlocked"
    }

    private var summaryText: String {
        if let sensor = entityBox.sensorEntity {
            return sensor.formattedValue
        }

        if let light = entityBox.lightEntity {
            guard light.isOn else { return "Off" }
            guard let brightnessPercentage = light.brightnessPercentage else { return "On" }

            return "\(brightnessPercentage)%"
        }

        if let cover = entityBox.coverEntity {
            return cover.positionPercentage.map { "\($0)%" } ?? cover.displayState
        }

        if let climate = entityBox.climateEntity {
            return climate.targetTemperatureText ?? climate.currentTemperatureText ?? climate.displayState
        }

        return entityBox.homeEntity.state.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var summaryColor: Color {
        guard entityBox.homeEntity.isAvailable else { return .red }
        return isActive ? .accentColor : .primary
    }
}

private struct EntityDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xSmall)
    }
}

private extension HADeviceRegistryDTO {
    var displayName: String {
        nameByUser?.nonEmptyValue ?? name?.nonEmptyValue ?? manufacturer?.nonEmptyValue ?? "Unknown Device"
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    var sortedByKey: [(key: String, value: JSONValue)] {
        sorted { lhs, rhs in
            lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }
    }
}

private extension JSONValue {
    var detailDisplayValue: String {
        switch self {
        case .string(let value):
            return value.replacingOccurrences(of: "_", with: " ").capitalized
        case .number(let value):
            return Self.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        case .bool(let value):
            return value ? "Yes" : "No"
        case .object(let value):
            guard !value.isEmpty else { return "{}" }
            return value.sortedByKey
                .map { "\($0.key): \($0.value.detailDisplayValue)" }
                .joined(separator: "\n")
        case .array(let value):
            guard !value.isEmpty else { return "[]" }
            return value.map(\.detailDisplayValue).joined(separator: ", ")
        case .null:
            return "None"
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        return formatter
    }()
}

private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    var humanizedAttributeName: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }
}

#if DEBUG
#Preview {
    EntityDiagnosticsView(
        entityBox: HAEntityState(
            homeEntity: HomeEntity(
                entityID: "sensor.hallway_temperature",
                domain: .sensor,
                displayName: "Hallway Temperature",
                state: "72.4",
                iconName: "thermometer.medium",
                isAvailable: true,
                lastUpdated: .now
            ),
            sensorEntity: SensorEntity(
                entityID: "sensor.hallway_temperature",
                displayName: "Hallway Temperature",
                value: "72.4",
                unit: "F",
                deviceClass: "temperature",
                lastUpdated: .now
            )
        )
    )
    .withPreviewEnvironment()
}
#endif
