import Foundation

struct HAPresenceRecord: Identifiable, Equatable, Sendable {
    let entityID: String
    let domain: EntityDomain
    let displayName: String
    let status: HAPresenceStatus
    let rawState: String
    let iconSystemName: String
    let isAvailable: Bool
    let lastChanged: Date?
    let lastUpdated: Date?
    let entityPicturePath: String?
    let sourceEntityID: String?
    let sourceType: String?
    let batteryLevel: Int?
    let gpsAccuracy: Double?
    let linkedPersonEntityID: String?
    let linkedPersonName: String?
    let linkedTrackers: [HAPresenceTrackerSummary]
    let context: HAPresenceContext

    var id: String { entityID }
    var isPerson: Bool { domain == .person }
    var isTracker: Bool { domain == .deviceTracker }

    var linkedTrackersSummary: String {
        let names = linkedTrackers.map(\.displayName)
        switch names.count {
        case 0:
            return "No linked trackers"
        case 1:
            return names[0]
        case 2:
            return names.joined(separator: " and ")
        default:
            return "\(names[0]) and \(names.count - 1) more"
        }
    }

    var contextSummary: String {
        let parts = [context.areaName, context.deviceName].compactMap { $0?.nonEmptyPresenceValue }
        return parts.isEmpty ? entityID : parts.joined(separator: " - ")
    }

    var sourceTypeTitle: String? {
        sourceType?.nonEmptyPresenceValue?.presenceSourceTypeTitle
    }

    var batteryText: String? {
        batteryLevel.map { "\($0)%" }
    }

    var gpsAccuracyText: String? {
        guard let gpsAccuracy else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        let value = formatter.string(from: NSNumber(value: gpsAccuracy)) ?? "\(Int(gpsAccuracy))"
        return "\(value)m"
    }

    func matches(query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        let searchableText = [
            entityID,
            displayName,
            status.title,
            status.shortTitle,
            rawState,
            sourceEntityID,
            sourceTypeTitle,
            linkedPersonName,
            context.deviceName,
            context.areaName,
            context.floorName,
            batteryText,
            gpsAccuracyText
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        let linkedTrackerText = linkedTrackers
            .flatMap { tracker in
                [
                    tracker.entityID,
                    tracker.displayName,
                    tracker.status.title,
                    tracker.context.deviceName,
                    tracker.context.areaName,
                    tracker.sourceTypeTitle
                ]
                    .compactMap { $0 }
            }
            .joined(separator: " ")

        return [searchableText, linkedTrackerText]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(trimmedQuery)
    }
}

struct HAPresenceTrackerSummary: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let status: HAPresenceStatus
    let sourceType: String?
    let batteryLevel: Int?
    let context: HAPresenceContext

    var id: String { entityID }

    var sourceTypeTitle: String? {
        sourceType?.nonEmptyPresenceValue?.presenceSourceTypeTitle
    }

    var subtitle: String {
        let parts = [sourceTypeTitle, context.deviceName, context.areaName]
            .compactMap { $0?.nonEmptyPresenceValue }
        return parts.isEmpty ? entityID : parts.joined(separator: " - ")
    }
}

struct HAPresenceContext: Equatable, Sendable {
    let deviceID: String?
    let deviceName: String?
    let areaID: String?
    let areaName: String?
    let floorID: String?
    let floorName: String?
}

enum HAPresenceStatus: Equatable, Sendable {
    case home
    case away
    case zone(String)
    case unknown
    case unavailable

    init(state: String) {
        let normalizedState = state.trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalizedState.lowercased() {
        case "home":
            self = .home
        case "not_home":
            self = .away
        case "unknown":
            self = .unknown
        case "unavailable":
            self = .unavailable
        default:
            self = normalizedState.isEmpty ? .unknown : .zone(normalizedState)
        }
    }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .away:
            return "Away"
        case .zone(let zone):
            return zone
        case .unknown:
            return "Unknown"
        case .unavailable:
            return "Unavailable"
        }
    }

    var shortTitle: String {
        switch self {
        case .zone(let zone):
            return zone
        default:
            return title
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .away:
            return "figure.walk"
        case .zone:
            return "mappin.and.ellipse"
        case .unknown:
            return "questionmark.circle"
        case .unavailable:
            return "exclamationmark.triangle.fill"
        }
    }

}

struct HAPersonPresencePresentation: Equatable, Sendable {
    let people: [HAPresenceRecord]

    static func make(
        records: [HAPresenceRecord],
        searchText: String
    ) -> HAPersonPresencePresentation {
        let people = records
            .filter(\.isPerson)
            .filter { $0.matches(query: searchText) }
            .sortedByPresenceTitle

        return HAPersonPresencePresentation(people: people)
    }
}

extension EntityMapper {
    static func presenceRecord(
        from dto: HAEntityDTO,
        context: HAPresenceContext = HAPresenceContext(
            deviceID: nil,
            deviceName: nil,
            areaID: nil,
            areaName: nil,
            floorID: nil,
            floorName: nil
        ),
        linkedPersonEntityID: String? = nil,
        linkedPersonName: String? = nil,
        linkedTrackers: [HAPresenceTrackerSummary] = []
    ) -> HAPresenceRecord? {
        let domain = EntityDomain(entityID: dto.entityID)
        guard domain == .person || domain == .deviceTracker else {
            return nil
        }

        let normalizedState = dto.state.trimmingCharacters(in: .whitespacesAndNewlines)
        let homeEntity = homeEntity(from: dto)

        return HAPresenceRecord(
            entityID: dto.entityID,
            domain: domain,
            displayName: displayName(for: dto),
            status: HAPresenceStatus(state: normalizedState),
            rawState: normalizedState,
            iconSystemName: homeEntity.iconName,
            isAvailable: !["unavailable", "unknown"].contains(normalizedState.lowercased()),
            lastChanged: dto.lastChanged,
            lastUpdated: dto.lastUpdated,
            entityPicturePath: dto.attributes["entity_picture"]?.stringValue?.nonEmptyPresenceValue,
            sourceEntityID: dto.attributes["source"]?.stringValue?.nonEmptyPresenceValue,
            sourceType: dto.attributes["source_type"]?.stringValue?.nonEmptyPresenceValue,
            batteryLevel: batteryLevel(from: dto.attributes),
            gpsAccuracy: dto.attributes["gps_accuracy"]?.doubleValue,
            linkedPersonEntityID: linkedPersonEntityID?.nonEmptyPresenceValue,
            linkedPersonName: linkedPersonName?.nonEmptyPresenceValue,
            linkedTrackers: linkedTrackers.sortedByPresenceTrackerTitle,
            context: context
        )
    }

    static func presenceTrackerSummary(
        from dto: HAEntityDTO,
        context: HAPresenceContext
    ) -> HAPresenceTrackerSummary? {
        guard EntityDomain(entityID: dto.entityID) == .deviceTracker else {
            return nil
        }

        return HAPresenceTrackerSummary(
            entityID: dto.entityID,
            displayName: displayName(for: dto),
            status: HAPresenceStatus(state: dto.state),
            sourceType: dto.attributes["source_type"]?.stringValue?.nonEmptyPresenceValue,
            batteryLevel: batteryLevel(from: dto.attributes),
            context: context
        )
    }

    private static func batteryLevel(from attributes: [String: JSONValue]) -> Int? {
        if let batteryLevel = attributes["battery_level"]?.intValue {
            return batteryLevel
        }

        return attributes["battery"]?.intValue
    }
}

private extension Array where Element == HAPresenceRecord {
    var sortedByPresenceTitle: [HAPresenceRecord] {
        sorted { lhs, rhs in
            if lhs.domain != rhs.domain {
                return lhs.domain == .person
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

private extension Array where Element == HAPresenceTrackerSummary {
    var sortedByPresenceTrackerTitle: [HAPresenceTrackerSummary] {
        sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

private extension String {
    var nonEmptyPresenceValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    var presenceSourceTypeTitle: String {
        switch lowercased() {
        case "gps":
            return "GPS"
        case "bluetooth_le":
            return "Bluetooth LE"
        default:
            return replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
