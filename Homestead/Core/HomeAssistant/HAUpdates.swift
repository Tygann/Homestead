import Foundation

struct HAUpdateEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let name: String
    let title: String
    let installedVersion: String?
    let latestVersion: String?
    let skippedVersion: String?
    let releaseSummary: String?
    let releaseURLString: String?
    let entityPicturePath: String?
    let deviceClass: String?
    let isAvailable: Bool
    let hasUpdate: Bool
    let isInProgress: Bool
    let progress: Double?
    let state: String
    let lastUpdated: Date?
    let context: HAUpdateContext

    var id: String { entityID }
    var isSkipped: Bool { skippedVersion != nil }

    var status: HAUpdateStatus {
        if !isAvailable {
            return .unavailable
        }

        if isInProgress {
            return .inProgress
        }

        if isSkipped {
            return .skipped
        }

        if hasUpdate {
            return .available
        }

        if state == "off" {
            return .upToDate
        }

        return .unknown
    }

    var iconSystemName: String {
        switch deviceClass {
        case "firmware":
            status == .upToDate ? "checkmark.circle" : "memorychip.fill"
        default:
            status == .upToDate ? "checkmark.circle" : "arrow.trianglehead.2.clockwise"
        }
    }

    var versionSummary: String {
        switch (installedVersion, latestVersion) {
        case (let installed?, let latest?) where installed != latest:
            "\(installed) -> \(latest)"
        case (let installed?, _):
            installed
        case (_, let latest?):
            latest
        default:
            "Version unknown"
        }
    }

    var contextSummary: String {
        let parts = [
            context.areaName,
            context.deviceName,
            entityID
        ].compactMap { $0?.nonEmptyUpdateValue }

        return parts.isEmpty ? entityID : parts.joined(separator: " • ")
    }

    func matches(query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        let searchableText = [
            entityID,
            name,
            title,
            installedVersion,
            latestVersion,
            skippedVersion,
            releaseSummary,
            releaseURLString,
            entityPicturePath,
            deviceClass,
            status.title,
            context.deviceName,
            context.areaName,
            context.floorName
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return searchableText.localizedCaseInsensitiveContains(trimmedQuery)
    }
}

struct HAUpdateContext: Equatable, Sendable {
    let deviceID: String?
    let deviceName: String?
    let areaID: String?
    let areaName: String?
    let floorID: String?
    let floorName: String?
}

enum HAUpdateStatus: String, CaseIterable, Identifiable, Sendable {
    case available
    case skipped
    case inProgress
    case unavailable
    case upToDate
    case unknown

    var id: Self { self }

    var title: String {
        switch self {
        case .available:
            "Update Available"
        case .skipped:
            "Skipped"
        case .inProgress:
            "In Progress"
        case .unavailable:
            "Unavailable"
        case .upToDate:
            "Up to Date"
        case .unknown:
            "Unknown"
        }
    }

    var shortTitle: String {
        switch self {
        case .available:
            "Available"
        case .inProgress:
            "Installing"
        case .upToDate:
            "Current"
        default:
            title
        }
    }

    var systemImage: String {
        switch self {
        case .available:
            "arrow.down.circle.fill"
        case .skipped:
            "forward.circle.fill"
        case .inProgress:
            "clock.arrow.circlepath"
        case .unavailable:
            "exclamationmark.triangle.fill"
        case .upToDate:
            "checkmark.circle.fill"
        case .unknown:
            "questionmark.circle"
        }
    }

    var sortPriority: Int {
        switch self {
        case .available:
            0
        case .inProgress:
            1
        case .skipped:
            2
        case .unavailable:
            3
        case .unknown:
            4
        case .upToDate:
            5
        }
    }
}

enum HAUpdateFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case available
    case skipped
    case inProgress
    case unavailable
    case upToDate

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            "All Updates"
        case .available:
            "Available"
        case .skipped:
            "Skipped"
        case .inProgress:
            "In Progress"
        case .unavailable:
            "Unavailable"
        case .upToDate:
            "Up to Date"
        }
    }

    func includes(_ update: HAUpdateEntity) -> Bool {
        switch self {
        case .all:
            true
        case .available:
            update.status == .available
        case .skipped:
            update.status == .skipped
        case .inProgress:
            update.status == .inProgress
        case .unavailable:
            update.status == .unavailable
        case .upToDate:
            update.status == .upToDate
        }
    }
}

enum HAUpdateGrouping: String, CaseIterable, Identifiable, Sendable {
    case status
    case area
    case device
    case name

    var id: Self { self }

    var title: String {
        switch self {
        case .status:
            "Status"
        case .area:
            "Area"
        case .device:
            "Device"
        case .name:
            "Name"
        }
    }

    var systemImage: String {
        switch self {
        case .status:
            "circle.dashed"
        case .area:
            "square.grid.3x3"
        case .device:
            "laptopcomputer.and.iphone"
        case .name:
            "textformat"
        }
    }
}

struct HAUpdateSection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let updates: [HAUpdateEntity]
}

struct HAUpdateSummary: Equatable, Sendable {
    let totalCount: Int
    let availableCount: Int
    let skippedCount: Int
    let inProgressCount: Int
    let unavailableCount: Int
}

struct HAUpdatePresentation: Equatable, Sendable {
    let sections: [HAUpdateSection]
    let visibleCount: Int
    let summary: HAUpdateSummary

    static func makeActionable(
        updates: [HAUpdateEntity],
        searchText: String = ""
    ) -> HAUpdatePresentation {
        let sortedUpdates = updates.sortedByUpdatePriority
        let matchingUpdates = sortedUpdates
            .filter { $0.status == .available || $0.status == .inProgress }
            .filter { $0.matches(query: searchText) }

        let sections = [
            HAUpdateSection(id: "available-updates", title: "Available Updates", updates: matchingUpdates)
        ].filter { !$0.updates.isEmpty }

        return HAUpdatePresentation(
            sections: sections,
            visibleCount: matchingUpdates.count,
            summary: summary(for: updates)
        )
    }

    static func make(
        updates: [HAUpdateEntity],
        searchText: String,
        filter: HAUpdateFilter,
        grouping: HAUpdateGrouping
    ) -> HAUpdatePresentation {
        let sortedUpdates = updates.sortedByUpdatePriority
        let matchingUpdates = sortedUpdates
            .filter { filter.includes($0) }
            .filter { $0.matches(query: searchText) }

        let sections: [HAUpdateSection]
        switch grouping {
        case .status:
            sections = HAUpdateStatus.allCases.compactMap { status in
                let rows = matchingUpdates.filter { $0.status == status }
                guard !rows.isEmpty else { return nil }
                return HAUpdateSection(id: status.rawValue, title: status.title, updates: rows.sortedByUpdatePriority)
            }
        case .area:
            sections = groupedSections(
                matchingUpdates,
                fallbackID: "no-area",
                fallbackTitle: "No Area",
                title: { $0.context.areaName }
            )
        case .device:
            sections = groupedSections(
                matchingUpdates,
                fallbackID: "no-device",
                fallbackTitle: "No Device",
                title: { $0.context.deviceName }
            )
        case .name:
            sections = [
                HAUpdateSection(id: "updates", title: "Updates", updates: matchingUpdates.sortedByUpdatePriority)
            ].filter { !$0.updates.isEmpty }
        }

        return HAUpdatePresentation(
            sections: sections,
            visibleCount: matchingUpdates.count,
            summary: summary(for: updates)
        )
    }

    private static func summary(for updates: [HAUpdateEntity]) -> HAUpdateSummary {
        HAUpdateSummary(
            totalCount: updates.count,
            availableCount: updates.filter { $0.status == .available }.count,
            skippedCount: updates.filter { $0.status == .skipped }.count,
            inProgressCount: updates.filter { $0.status == .inProgress }.count,
            unavailableCount: updates.filter { $0.status == .unavailable }.count
        )
    }

    private static func groupedSections(
        _ updates: [HAUpdateEntity],
        fallbackID: String,
        fallbackTitle: String,
        title: (HAUpdateEntity) -> String?
    ) -> [HAUpdateSection] {
        Dictionary(grouping: updates) { update in
            title(update)?.nonEmptyUpdateValue ?? fallbackTitle
        }
        .map { title, updates in
            HAUpdateSection(
                id: title == fallbackTitle ? fallbackID : title,
                title: title,
                updates: updates.sortedByUpdatePriority
            )
        }
        .sorted { lhs, rhs in
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

struct HAUpdateSettingsActionAvailability: Equatable, Sendable {
    let canInstall: Bool
    let canSkip: Bool
    let canClearSkipped: Bool
    let installUnavailableReason: String?
    let skipUnavailableReason: String?
    let clearSkippedUnavailableReason: String?

    static func make(
        update: HAUpdateEntity,
        serviceActionAvailable: (String, String) -> Bool
    ) -> HAUpdateSettingsActionAvailability {
        let installServiceAvailable = serviceActionAvailable("update", "install")
        let skipServiceAvailable = serviceActionAvailable("update", "skip")
        let clearSkippedServiceAvailable = serviceActionAvailable("update", "clear_skipped")

        return HAUpdateSettingsActionAvailability(
            canInstall: installServiceAvailable && update.status == .available,
            canSkip: skipServiceAvailable && update.status == .available,
            canClearSkipped: clearSkippedServiceAvailable && update.status == .skipped,
            installUnavailableReason: unavailableReason(
                update: update,
                serviceAvailable: installServiceAvailable,
                requiredStatus: .available,
                action: "Install"
            ),
            skipUnavailableReason: unavailableReason(
                update: update,
                serviceAvailable: skipServiceAvailable,
                requiredStatus: .available,
                action: "Skip"
            ),
            clearSkippedUnavailableReason: unavailableReason(
                update: update,
                serviceAvailable: clearSkippedServiceAvailable,
                requiredStatus: .skipped,
                action: "Clear skipped"
            )
        )
    }

    private static func unavailableReason(
        update: HAUpdateEntity,
        serviceAvailable: Bool,
        requiredStatus: HAUpdateStatus,
        action: String
    ) -> String? {
        guard serviceAvailable else {
            return "\(action) is not available on this Home Assistant server."
        }

        guard update.isAvailable else {
            return "This update entity is unavailable."
        }

        guard !update.isInProgress else {
            return "An update is already in progress."
        }

        guard update.status == requiredStatus else {
            switch requiredStatus {
            case .available:
                return "There is no available update to \(action.lowercased())."
            case .skipped:
                return "This update is not skipped."
            default:
                return nil
            }
        }

        return nil
    }
}

extension EntityMapper {
    static func updateEntity(
        from dto: HAEntityDTO,
        deviceID: String? = nil,
        deviceName: String? = nil,
        areaID: String? = nil,
        areaName: String? = nil,
        floorID: String? = nil,
        floorName: String? = nil
    ) -> HAUpdateEntity? {
        guard EntityDomain(entityID: dto.entityID) == .update else { return nil }

        let displayName = displayName(for: dto)
        let title = dto.attributes["title"]?.stringValue?.nonEmptyUpdateValue ?? displayName
        let inProgress = inProgressValue(from: dto.attributes["in_progress"])
        let state = dto.state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return HAUpdateEntity(
            entityID: dto.entityID,
            name: displayName,
            title: title,
            installedVersion: dto.attributes["installed_version"]?.stringValue?.nonEmptyUpdateValue,
            latestVersion: dto.attributes["latest_version"]?.stringValue?.nonEmptyUpdateValue,
            skippedVersion: dto.attributes["skipped_version"]?.stringValue?.nonEmptyUpdateValue,
            releaseSummary: dto.attributes["release_summary"]?.stringValue?.nonEmptyUpdateValue,
            releaseURLString: dto.attributes["release_url"]?.stringValue?.nonEmptyUpdateValue,
            entityPicturePath: dto.attributes["entity_picture"]?.stringValue?.nonEmptyUpdateValue,
            deviceClass: dto.attributes["device_class"]?.stringValue?.nonEmptyUpdateValue,
            isAvailable: !["unavailable", "unknown"].contains(state),
            hasUpdate: state == "on",
            isInProgress: inProgress.isInProgress,
            progress: inProgress.progress,
            state: state,
            lastUpdated: dto.lastUpdated,
            context: HAUpdateContext(
                deviceID: deviceID?.nonEmptyUpdateValue,
                deviceName: deviceName?.nonEmptyUpdateValue,
                areaID: areaID?.nonEmptyUpdateValue,
                areaName: areaName?.nonEmptyUpdateValue,
                floorID: floorID?.nonEmptyUpdateValue,
                floorName: floorName?.nonEmptyUpdateValue
            )
        )
    }

    private static func inProgressValue(from value: JSONValue?) -> (isInProgress: Bool, progress: Double?) {
        switch value {
        case .bool(let isInProgress):
            return (isInProgress, nil)
        case .number(let progress):
            return (progress > 0, progress)
        case .string(let rawValue):
            let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let progress = Double(normalizedValue) {
                return (progress > 0, progress)
            }
            return (["true", "yes", "on"].contains(normalizedValue), nil)
        case .object, .array, .null, nil:
            return (false, nil)
        }
    }
}

extension Array where Element == HAUpdateEntity {
    var sortedByUpdatePriority: [HAUpdateEntity] {
        sorted { lhs, rhs in
            if lhs.status.sortPriority != rhs.status.sortPriority {
                return lhs.status.sortPriority < rhs.status.sortPriority
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private extension String {
    var nonEmptyUpdateValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
