import SwiftUI

struct SensorCard: View {
    let entityBox: HAEntityState

    var body: some View {
        if let sensor = entityBox.sensorEntity {
            CardContainer {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    HStack(alignment: .top) {
                        SensorIconBadge(sensor: sensor)

                        Spacer()

                        if !sensor.isAvailable {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.red)
                                .accessibilityHidden(true)
                        }
                    }

                    Spacer(minLength: AppSpacing.small)

                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(sensor.displayName)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xSmall) {
                            Text(sensor.valueText)
                                .font(.title2.bold())
                                .foregroundStyle(sensor.isAvailable ? Color.primary : Color.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            if let unit = sensor.unitText {
                                Text(unit)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Text(sensor.displaySubtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(sensor.isAvailable ? .secondary : Color.red)
                            .lineLimit(1)
                    }
                }
            }
            .accessibilityLabel(sensor.displayName)
            .accessibilityValue(sensor.formattedValue)
        }
    }
}

private struct SensorIconBadge: View {
    let sensor: SensorEntity

    var body: some View {
        Image(systemName: sensor.iconName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(accentColor)
            .frame(width: 44, height: 44)
            .background(accentColor.opacity(sensor.isAvailable ? 0.13 : 0.08), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
            .accessibilityHidden(true)
    }

    private var accentColor: Color {
        guard sensor.isAvailable else { return .secondary }

        switch sensor.displayKind {
        case .temperature:
            return .orange
        case .humidity, .water:
            return .cyan
        case .battery:
            return .green
        case .energy, .power, .voltage, .current, .illuminance:
            return .yellow
        case .pressure:
            return .purple
        case .signal:
            return .blue
        case .gas:
            return .orange
        case .problem:
            return .red
        case .generic:
            return .accentColor
        }
    }
}

#if DEBUG
#Preview {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "sensor.hallway_temperature") {
        SensorCard(entityBox: entityBox)
            .padding()
            .background(Color(.systemGroupedBackground))
            .withPreviewEnvironment()
    }
}
#endif
