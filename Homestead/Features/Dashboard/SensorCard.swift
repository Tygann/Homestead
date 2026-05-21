import SwiftUI

struct SensorCard: View {
    let entityBox: HAEntityState

    var body: some View {
        if let sensor = entityBox.sensorEntity {
            CardContainer {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    CardIconView(systemName: sensor.iconName)

                    Spacer(minLength: AppSpacing.small)

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(sensor.displayName)
                            .font(.headline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text(sensor.formattedValue)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let deviceClass = sensor.formattedDeviceClass {
                            Text(deviceClass)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
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
