import SwiftUI

struct SensorDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let entityBox: HAEntityState

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    statusCard
                    detailMetrics
                    contextDetails
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            DashboardEntityStatusCard(
                iconName: presentation.iconName,
                title: presentation.title,
                badge: statusBadgeText,
                summary: presentation.subtitle,
                iconColor: iconColor,
                badgeColor: statusColor,
                iconBackground: iconBackground,
                badgeBackground: statusBackground
            )

            DashboardControlPanel(title: "Current Reading", systemImage: "gauge.medium") {
                Text(primaryValue)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var detailMetrics: some View {
        DashboardEntityContextPanel(
            title: "Reading",
            systemImage: "waveform.path.ecg",
            rows: readingRows
        )
    }

    private var readingRows: [DashboardEntityDetailRow] {
        var rows = [DashboardEntityDetailRow(title: "State", value: primaryValue)]

        if let sensor = entityBox.sensorEntity {
            if let valueText = nonEmpty(sensor.valueText), valueText != sensor.formattedValue {
                rows.append(DashboardEntityDetailRow(title: "Value", value: valueText))
            }

            if let unit = sensor.unitText {
                rows.append(DashboardEntityDetailRow(title: "Unit", value: unit))
            }

            if let deviceClass = sensor.formattedDeviceClass {
                rows.append(DashboardEntityDetailRow(title: "Type", value: deviceClass))
            }
        } else if entity.domain == .binarySensor {
            rows.append(DashboardEntityDetailRow(title: "Type", value: "Binary Sensor"))
        }

        return rows
    }

    private var contextDetails: some View {
        DashboardEntityContextPanel(
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: contextRows
        )
    }

    private var contextRows: [DashboardEntityDetailRow] {
        var rows = [
            DashboardEntityDetailRow(title: "Entity ID", value: entity.entityID),
            DashboardEntityDetailRow(title: "Domain", value: entity.domain.displayName)
        ]

        if let lastUpdated = entity.lastUpdated {
            rows.append(DashboardEntityDetailRow(title: "Last Updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened)))
        }

        return rows
    }

    private var navigationTitle: String {
        switch entity.domain {
        case .binarySensor:
            "Binary Sensor"
        case .sensor:
            "Sensor"
        case .light, .climate, .cover, .switch, .fan, .lock, .mediaPlayer, .camera, .vacuum, .scene, .script, .other:
            "Entity"
        }
    }

    private var primaryValue: String {
        if let sensor = entityBox.sensorEntity {
            return sensor.formattedValue
        }

        return binarySensorStateText
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

    private var statusBackground: Color {
        guard entity.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

#if DEBUG
#Preview("Sensor") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "sensor.hallway_temperature") {
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
