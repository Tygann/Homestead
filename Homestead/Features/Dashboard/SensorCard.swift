import SwiftUI

struct SensorCard: View {
    @Environment(HAStateStore.self) private var stateStore

    let entityID: String

    var body: some View {
        if let sensor = stateStore.sensorEntity(for: entityID) {
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
    SensorCard(entityID: "sensor.hallway_temperature")
        .padding()
        .background(Color(.systemGroupedBackground))
        .withPreviewEnvironment()
}
#endif
