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
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                Image(systemName: presentation.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 64, height: 64)
                    .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                Spacer()

                Text(statusBadgeText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(statusBackground, in: Capsule())
            }

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(presentation.subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(primaryValue)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var detailMetrics: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Reading", systemImage: "waveform.path.ecg")
                .font(.headline)

            SensorDetailRow(title: "State", value: primaryValue)

            if let sensor = entityBox.sensorEntity {
                if let valueText = nonEmpty(sensor.valueText), valueText != sensor.formattedValue {
                    SensorDetailRow(title: "Value", value: valueText)
                }

                if let unit = sensor.unitText {
                    SensorDetailRow(title: "Unit", value: unit)
                }

                if let deviceClass = sensor.formattedDeviceClass {
                    SensorDetailRow(title: "Type", value: deviceClass)
                }
            } else if entity.domain == .binarySensor {
                SensorDetailRow(title: "Type", value: "Binary Sensor")
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var contextDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Home Assistant", systemImage: "house.and.flag")
                .font(.headline)

            SensorDetailRow(title: "Entity ID", value: entity.entityID)
            SensorDetailRow(title: "Domain", value: entity.domain.displayName)

            if let lastUpdated = entity.lastUpdated {
                SensorDetailRow(title: "Last Updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
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

private struct SensorDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.medium)

            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xSmall)
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
