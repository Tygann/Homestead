import SwiftUI

struct SensorDetailView: View {
    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet
    var entryContext: EntityDetailEntryContext = .overview

    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var historySelection: EntityHistorySelection?

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }
    private var features: EntityDetailFeatureSet {
        EntityDetailFeatureProvider.features(for: entityBox)
    }

    @MainActor
    private var heroPresentation: SensorDetailHeroPresentation? {
        entityBox.sensorEntity.map(SensorDetailHeroPresentation.init)
    }

    var body: some View {
        EntityDetailScaffold(title: navigationTitle, presentationStyle: presentationStyle) {
            if entity.domain == .sensor {
                if isHistoryFocused {
                    historyHero
                } else {
                    sensorHero
                }
            } else {
                header
                currentReading
            }
            if supportsHistory {
                EntityNumericHistoryPanel(
                    entityBox: entityBox,
                    displayName: entityBox.sensorEntity?.displayName ?? entity.displayName,
                    unit: entityBox.sensorEntity?.unitText,
                    displayPrecision: entityBox.sensorEntity?.resolvedDisplayPrecision,
                    accentColor: presentation.accentColor,
                    preferredRange: isHistoryFocused
                        ? nil
                        : entityBox.sensorEntity?.gaugePresentation?.range,
                    initialRange: initialHistoryRange,
                    layout: isHistoryFocused ? .expanded : .compact,
                    interpolationStyle: entityBox.sensorEntity?.dashboardHistoryInterpolationStyle ?? .linear,
                    onSelectionChange: { historySelection = $0 }
                )
            }
            if let source = features.activitySource {
                EntityActivityPanel(
                    entityID: entity.entityID,
                    source: source,
                    tint: presentation.accentColor
                )
            }
            if entity.domain != .sensor {
                detailMetrics
            }
            contextDetails
        }
    }

    private var header: some View {
        EntityDetailHeader(
            entityBox: entityBox,
            icon: presentation.icon,
            category: EntityCapabilityRegistry.profile(for: entity.domain).categoryTitle,
            summary: nil,
            status: binarySensorStatus,
            iconColor: iconColor,
            iconBackground: iconBackground
        )
    }

    private var currentReading: some View {
        EntityControlPanel(title: "Current Reading", systemImage: "gauge.medium") {
            if let gauge = entityBox.sensorEntity?.gaugePresentation {
                GaugePresentationView(
                    presentation: gauge,
                    style: .detail,
                    tint: presentation.accentColor
                )
            } else {
                Text(primaryValue)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var sensorHero: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: heroPresentation?.category ?? "Sensor",
            subtitle: sensorFreshnessText,
            status: heroPresentation?.statusText,
            iconColor: sensorHeroColor,
            statusColor: .orange,
            statusBackground: Color.orange.opacity(0.12),
            statePresentation: detailState
        ) {
            if let gauge = entityBox.sensorEntity?.gaugePresentation {
                GaugePresentationView(
                    presentation: gauge,
                    style: .detail,
                    tint: presentation.accentColor,
                    icon: presentation.icon
                )
            } else {
                Text(primaryValue)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var historyHero: some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: heroPresentation?.category ?? "Sensor",
            subtitle: historyHeroSubtitle,
            status: heroPresentation?.statusText,
            iconColor: sensorHeroColor,
            statusColor: .orange,
            statusBackground: Color.orange.opacity(0.12),
            statePresentation: detailState
        ) {
            Text(historySelection?.formattedValue ?? primaryValue)
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var historyHeroSubtitle: Text? {
        guard let selection = historySelection else {
            return sensorFreshnessText
        }
        return Text(selection.occurredAt.formatted(date: .abbreviated, time: .shortened))
    }

    private var isHistoryFocused: Bool {
        if case .history = entryContext { return true }
        return false
    }

    private var initialHistoryRange: HAHistoryRangePreset {
        if case .history(let range) = entryContext { return range }
        return .day
    }

    private var sensorFreshnessText: Text? {
        EntityDetailHeroSubtitle.updated(entity)
    }

    private var binarySensorStatus: EntityDetailStatusPresentation? {
        guard entityBox.binarySensorEntity?.isActive == true else { return nil }
        return EntityDetailStatusPresentation(text: statusBadgeText, tone: .warning)
    }

    private var detailMetrics: some View {
        DashboardEntityContextPanel(
            title: "Reading",
            systemImage: "waveform.path.ecg",
            rows: readingRows
        )
    }

    private var readingRows: [EntityMetadataRow] {
        var rows = [EntityMetadataRow(title: "State", value: primaryValue)]

        if let sensor = entityBox.sensorEntity {
            if let valueText = nonEmpty(sensor.valueText), valueText != sensor.formattedValue {
                rows.append(EntityMetadataRow(title: "Value", value: valueText))
            }

            if let unit = sensor.unitText {
                rows.append(EntityMetadataRow(title: "Unit", value: unit))
            }

            if let deviceClass = sensor.formattedDeviceClass {
                rows.append(EntityMetadataRow(title: "Type", value: deviceClass))
            }
        } else if entity.domain == .binarySensor {
            rows.append(EntityMetadataRow(title: "Type", value: "Binary Sensor"))
        }

        return rows
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: contextRows
        )
    }

    private var contextRows: [EntityMetadataRow] {
        var rows = [
            EntityMetadataRow(title: "Entity ID", value: entity.entityID),
            EntityMetadataRow(title: "Domain", value: entity.domain.displayName)
        ]

        if let lastUpdated = entity.lastUpdated {
            rows.append(EntityMetadataRow(title: "Last Updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened)))
        }

        return rows
    }

    private var navigationTitle: String {
        presentation.title
    }

    private var primaryValue: String {
        if let sensor = entityBox.sensorEntity {
            return sensor.formattedValue
        }

        return binarySensorStateText
    }

    private var supportsHistory: Bool {
        // A configured Chart card remains a history surface even while the current
        // Home Assistant state is temporarily nonnumeric (for example, unavailable).
        isHistoryFocused || features.supports(.numericHistory)
    }

    private var statusBadgeText: String {
        guard entity.isAvailable else { return "Unavailable" }

        if let sensor = entityBox.sensorEntity, sensor.isAlerting {
            return "Alert"
        }

        if entity.domain == .binarySensor {
            return entity.state == "on" ? "Detected" : "Clear"
        }

        return "Live"
    }

    private var sensorHeroColor: Color {
        guard entity.isAvailable else { return .red }
        guard let status = entityBox.sensorEntity?.gaugePresentation?.status else {
            return presentation.accentColor
        }
        return gaugeVisualStatusColor(for: status.visualStatus)
    }

    private var binarySensorStateText: String {
        guard entity.isAvailable else { return entity.state.displayStateText }

        switch entity.state {
        case "on":
            return "Detected"
        case "off":
            return "Clear"
        default:
            return entity.state.displayStateText
        }
    }

    private var iconColor: Color {
        guard entity.isAvailable else { return .secondary }
        return presentation.isActive ? presentation.accentColor : .secondary
    }

    private var statusColor: Color {
        guard entity.isAvailable else { return .red }
        return presentation.isActive ? presentation.accentColor : .primary
    }

    private var iconBackground: Color {
        guard entity.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

}

struct SensorDetailHeroPresentation: Equatable, Sendable {
    let category: String
    let statusText: String?

    init(sensor: SensorEntity) {
        category = sensor.formattedDeviceClass ?? "Sensor"

        guard sensor.isAvailable else {
            statusText = "Unavailable"
            return
        }

        if let gauge = sensor.gaugePresentation, gauge.status != .nominal {
            statusText = gauge.statusDisplayText
        } else if sensor.isAlerting {
            statusText = "Alert"
        } else {
            statusText = nil
        }
    }
}

#if DEBUG
#Preview("Sensor") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "sensor.hallway_temperature") {
        SensorDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}

#Preview("Gauge Sensor") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "sensor.front_door_battery") {
        SensorDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}

#Preview("Binary Sensor") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "binary_sensor.front_door") {
        SensorDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
