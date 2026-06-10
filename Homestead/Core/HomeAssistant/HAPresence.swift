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

    var rowSubtitle: String {
        if isPerson, !linkedTrackers.isEmpty {
            return linkedTrackersSummary
        }

        if let linkedPersonName {
            return "Used by \(linkedPersonName)"
        }

        if let sourceTypeTitle {
            return sourceTypeTitle
        }

        return contextSummary
    }

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
            self = .zone(normalizedState.presenceDisplayTitle)
        }
    }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .away:
            return "Away"
        case .zone(let zone):
            return "At \(zone)"
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

    var sectionTitle: String {
        switch self {
        case .home:
            return "Home"
        case .away:
            return "Away"
        case .zone:
            return "Zones"
        case .unknown:
            return "Unknown"
        case .unavailable:
            return "Unavailable"
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

    var sortPriority: Int {
        switch self {
        case .home:
            return 0
        case .zone:
            return 1
        case .away:
            return 2
        case .unavailable:
            return 3
        case .unknown:
            return 4
        }
    }

    var isUnavailableLike: Bool {
        self == .unavailable || self == .unknown
    }
}

enum HAPresenceFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case home
    case away
    case zones
    case unavailable

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "All Presence"
        case .home:
            return "Home"
        case .away:
            return "Away"
        case .zones:
            return "Zones"
        case .unavailable:
            return "Unavailable"
        }
    }

    func includes(_ record: HAPresenceRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .home:
            return record.status == .home
        case .away:
            return record.status == .away
        case .zones:
            if case .zone = record.status {
                return true
            }
            return false
        case .unavailable:
            return record.status.isUnavailableLike
        }
    }
}

enum HAPresenceGrouping: String, CaseIterable, Identifiable, Sendable {
    case kind
    case status
    case area
    case device

    var id: Self { self }

    var title: String {
        switch self {
        case .kind:
            return "Kind"
        case .status:
            return "Status"
        case .area:
            return "Area"
        case .device:
            return "Device"
        }
    }

    var systemImage: String {
        switch self {
        case .kind:
            return "person.2"
        case .status:
            return "circle.dashed"
        case .area:
            return "square.grid.3x3"
        case .device:
            return "laptopcomputer.and.iphone"
        }
    }
}

struct HAPresenceSection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let records: [HAPresenceRecord]
}

struct HAPresenceSummary: Equatable, Sendable {
    let totalCount: Int
    let peopleCount: Int
    let trackerCount: Int
    let homeCount: Int
    let awayCount: Int
    let zoneCount: Int
    let unavailableCount: Int
}

struct HAPresencePresentation: Equatable, Sendable {
    let sections: [HAPresenceSection]
    let visibleCount: Int
    let summary: HAPresenceSummary

    static func make(
        records: [HAPresenceRecord],
        searchText: String,
        filter: HAPresenceFilter,
        grouping: HAPresenceGrouping
    ) -> HAPresencePresentation {
        let sortedRecords = records.sortedByPresenceTitle
        let matchingRecords = sortedRecords
            .filter { filter.includes($0) }
            .filter { $0.matches(query: searchText) }

        let sections: [HAPresenceSection]
        switch grouping {
        case .kind:
            sections = [
                HAPresenceSection(
                    id: "people",
                    title: "People",
                    records: matchingRecords.filter(\.isPerson).sortedByPresenceTitle
                ),
                HAPresenceSection(
                    id: "trackers",
                    title: "Trackers",
                    records: matchingRecords.filter(\.isTracker).sortedByPresenceTitle
                )
            ].filter { !$0.records.isEmpty }
        case .status:
            sections = groupedSections(
                matchingRecords,
                fallbackID: "status",
                fallbackTitle: "Status",
                title: { $0.status.sectionTitle },
                sort: { lhs, rhs in
                    let lhsPriority = lhs.records.first?.status.sortPriority ?? Int.max
                    let rhsPriority = rhs.records.first?.status.sortPriority ?? Int.max
                    if lhsPriority != rhsPriority {
                        return lhsPriority < rhsPriority
                    }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            )
        case .area:
            sections = groupedSections(
                matchingRecords,
                fallbackID: "no-area",
                fallbackTitle: "No Area",
                title: { $0.context.areaName }
            )
        case .device:
            sections = groupedSections(
                matchingRecords,
                fallbackID: "no-device",
                fallbackTitle: "No Device",
                title: { $0.context.deviceName }
            )
        }

        return HAPresencePresentation(
            sections: sections,
            visibleCount: matchingRecords.count,
            summary: HAPresenceSummary(
                totalCount: records.count,
                peopleCount: records.filter(\.isPerson).count,
                trackerCount: records.filter(\.isTracker).count,
                homeCount: records.filter { $0.status == .home }.count,
                awayCount: records.filter { $0.status == .away }.count,
                zoneCount: records.filter {
                    if case .zone = $0.status {
                        return true
                    }
                    return false
                }.count,
                unavailableCount: records.filter { $0.status.isUnavailableLike }.count
            )
        )
    }

    private static func groupedSections(
        _ records: [HAPresenceRecord],
        fallbackID: String,
        fallbackTitle: String,
        title: (HAPresenceRecord) -> String?,
        sort: ((HAPresenceSection, HAPresenceSection) -> Bool)? = nil
    ) -> [HAPresenceSection] {
        let sections = Dictionary(grouping: records) { record in
            title(record)?.nonEmptyPresenceValue ?? fallbackTitle
        }
        .map { title, records in
            HAPresenceSection(
                id: title == fallbackTitle ? fallbackID : title,
                title: title,
                records: records.sortedByPresenceTitle
            )
        }

        if let sort {
            return sections.sorted(by: sort)
        }

        return sections.sorted { lhs, rhs in
            if lhs.title == fallbackTitle {
                return false
            }

            if rhs.title == fallbackTitle {
                return true
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
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

    var presenceDisplayTitle: String {
        replacingOccurrences(of: "_", with: " ").capitalized
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
