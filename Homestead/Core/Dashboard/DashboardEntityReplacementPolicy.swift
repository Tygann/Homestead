import Foundation

@MainActor
enum DashboardEntityReplacementPolicy {
    static func preservesGaugeCustomization(
        from currentEntity: HAEntityState,
        to replacementEntity: HAEntityState
    ) -> Bool {
        guard let currentSensor = currentEntity.sensorEntity,
              let replacementSensor = replacementEntity.sensorEntity else {
            return false
        }

        return normalized(currentSensor.deviceClass) == normalized(replacementSensor.deviceClass)
            && normalized(currentSensor.unit) == normalized(replacementSensor.unit)
    }

    private static func normalized(_ value: String?) -> String? {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized?.isEmpty == false ? normalized : nil
    }
}
