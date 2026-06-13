import Foundation

nonisolated struct DashboardSummaryEntityMetadata: Equatable, Sendable {
    let isHidden: Bool
    let entityCategory: String?
    let deviceID: String?
}

nonisolated struct DashboardSummaryMembershipContext: Equatable, Sendable {
    let entityMetadataByID: [String: DashboardSummaryEntityMetadata]
    let preferredClimateReadingEntityIDs: Set<String>
    let chargingDeviceIDs: Set<String>

    static let empty = DashboardSummaryMembershipContext(
        entityMetadataByID: [:],
        preferredClimateReadingEntityIDs: [],
        chargingDeviceIDs: []
    )

    func metadata(for entityID: String) -> DashboardSummaryEntityMetadata? {
        entityMetadataByID[entityID]
    }
}

@MainActor
enum HomeAssistantSummaryClassifier {
    static func securityActivityEntityIDs(
        from entityBoxes: [HAEntityState],
        context: DashboardSummaryMembershipContext
    ) -> Set<String> {
        Set(entityBoxes.compactMap { entityBox in
            if entityBox.domain == .person {
                return entityBox.entityID
            }

            return contains(entityBox, in: .security, context: context) ? entityBox.entityID : nil
        })
    }

    static func contains(
        _ entityBox: HAEntityState,
        in kind: DashboardSummaryKind,
        context: DashboardSummaryMembershipContext
    ) -> Bool {
        let metadata = context.metadata(for: entityBox.entityID)
        guard metadata?.isHidden != true else {
            return false
        }

        switch kind {
        case .lights:
            return entityBox.domain == .light && hasNoEntityCategory(metadata)
        case .climate:
            return isClimateEntity(entityBox, metadata: metadata, context: context)
        case .security:
            return isSecurityEntity(entityBox, metadata: metadata)
        case .maintenance:
            return isMaintenanceEntity(entityBox, metadata: metadata)
        case .media:
            return entityBox.domain == .mediaPlayer && hasNoEntityCategory(metadata)
        }
    }

    static func isCharging(
        _ entityBox: HAEntityState,
        context: DashboardSummaryMembershipContext
    ) -> Bool {
        guard let deviceID = context.metadata(for: entityBox.entityID)?.deviceID else {
            return false
        }
        return context.chargingDeviceIDs.contains(deviceID)
    }

    private static func isClimateEntity(
        _ entityBox: HAEntityState,
        metadata: DashboardSummaryEntityMetadata?,
        context: DashboardSummaryMembershipContext
    ) -> Bool {
        if context.preferredClimateReadingEntityIDs.contains(entityBox.entityID) {
            return isClimateReading(entityBox)
        }

        guard hasNoEntityCategory(metadata) else {
            return false
        }

        switch entityBox.domain {
        case .climate, .humidifier, .fan, .waterHeater:
            return true
        case .cover:
            let deviceClasses = ["awning", "blind", "curtain", "shade", "shutter", "window", "none"]
            return deviceClasses.contains(entityBox.coverEntity?.deviceClass ?? "none")
        case .binarySensor:
            return entityBox.binarySensorEntity?.deviceClass == "window"
        default:
            return false
        }
    }

    private static func isSecurityEntity(
        _ entityBox: HAEntityState,
        metadata: DashboardSummaryEntityMetadata?
    ) -> Bool {
        switch entityBox.domain {
        case .camera, .alarmControlPanel, .lock:
            return hasNoEntityCategory(metadata)
        case .cover:
            let deviceClasses = ["door", "garage", "gate", "window"]
            return hasNoEntityCategory(metadata) && deviceClasses.contains(entityBox.coverEntity?.deviceClass ?? "")
        case .binarySensor:
            guard let deviceClass = entityBox.binarySensorEntity?.deviceClass else {
                return false
            }
            if deviceClass == "tamper", metadata?.entityCategory == "diagnostic" {
                return true
            }
            let deviceClasses = [
                "lock", "door", "window", "garage_door", "opening",
                "carbon_monoxide", "gas", "moisture", "safety", "smoke", "tamper"
            ]
            return hasNoEntityCategory(metadata) && deviceClasses.contains(deviceClass)
        default:
            return false
        }
    }

    private static func isMaintenanceEntity(
        _ entityBox: HAEntityState,
        metadata: DashboardSummaryEntityMetadata?
    ) -> Bool {
        switch entityBox.domain {
        case .sensor:
            return entityBox.sensorEntity?.deviceClass == "battery"
        case .binarySensor:
            return entityBox.binarySensorEntity?.deviceClass == "battery" && hasNoEntityCategory(metadata)
        default:
            return false
        }
    }

    private static func hasNoEntityCategory(_ metadata: DashboardSummaryEntityMetadata?) -> Bool {
        metadata?.entityCategory == nil
    }

    private static func isClimateReading(_ entityBox: HAEntityState) -> Bool {
        guard let sensor = entityBox.sensorEntity else {
            return false
        }
        return sensor.deviceClass == "temperature" || sensor.deviceClass == "humidity"
    }
}
