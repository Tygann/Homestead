import Foundation

nonisolated enum DashboardChipKind: String, Codable, Equatable, Sendable {
    case summary
    case entity
}

nonisolated enum DashboardSummaryKind: String, CaseIterable, Codable, Equatable, Sendable {
    case lights
    case security
    case doors
    case locks
    case climate
    case batteries
    case cameras
    case media

    static var allCases: [DashboardSummaryKind] {
        [.lights, .security, .climate, .batteries, .media]
    }

    var canonicalKind: DashboardSummaryKind {
        switch self {
        case .doors, .locks, .cameras:
            .security
        case .lights, .security, .climate, .batteries, .media:
            self
        }
    }

    var title: String {
        switch canonicalKind {
        case .lights:
            "Lights"
        case .security:
            "Security"
        case .climate:
            "Climate"
        case .batteries:
            "Batteries"
        case .media:
            "Media"
        case .doors, .locks, .cameras:
            "Security"
        }
    }

    var systemImage: String {
        switch canonicalKind {
        case .lights:
            "lightbulb"
        case .security:
            "shield.fill"
        case .climate:
            "thermometer.medium"
        case .batteries:
            "battery.75percent"
        case .media:
            "play.tv"
        case .doors, .locks, .cameras:
            "shield.fill"
        }
    }
}

struct DashboardChipPresentation: Equatable, Sendable {
    let title: String
    let value: String
    let systemImage: String
    let isActive: Bool
    let isAvailable: Bool

    var accessibilityValue: String {
        value
    }
}

struct DashboardSummaryDetailPresentation: Equatable, Sendable {
    let kind: DashboardSummaryKind
    let summary: DashboardChipPresentation
    let sections: [DashboardSummarySectionPresentation]

    var isEmpty: Bool {
        sections.allSatisfy(\.items.isEmpty)
    }
}

struct DashboardSummarySectionPresentation: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let items: [DashboardSummaryEntityPresentation]
}

nonisolated enum DashboardSummaryEntityVisualStyle: Equatable, Sendable {
    case row
    case camera
}

struct DashboardSummaryEntityPresentation: Identifiable, Equatable, Sendable {
    let entityID: String
    let domain: EntityDomain
    let title: String
    let subtitle: String
    let detail: String?
    let systemImage: String
    let visualStyle: DashboardSummaryEntityVisualStyle
    let isActive: Bool
    let isAvailable: Bool
    let sortPriority: Int
    let primaryAction: DashboardEntityPrimaryAction?

    var id: String { entityID }
}

@MainActor
enum DashboardSummaryProvider {
    static func makeSummary(
        kind: DashboardSummaryKind,
        entityBoxes: [HAEntityState],
        titleOverride: String? = nil,
        iconNameOverride: String? = nil
    ) -> DashboardChipPresentation? {
        let canonicalKind = kind.canonicalKind
        let title = normalizedOverride(titleOverride) ?? canonicalKind.title
        let defaultSystemImage = normalizedOverride(iconNameOverride) ?? canonicalKind.systemImage

        switch canonicalKind {
        case .lights:
            let lights = entityBoxes.filter { $0.domain == .light }
            guard !lights.isEmpty else { return nil }
            let activeCount = lights.filter { $0.homeEntity.state == "on" }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(activeCount, activeWord: "on", inactiveWord: "off"),
                systemImage: activeCount > 0 ? "lightbulb.fill" : defaultSystemImage,
                isActive: activeCount > 0,
                isAvailable: lights.contains { $0.homeEntity.isAvailable }
            )
        case .security:
            let securityItems = entityBoxes.compactMap(securityContext)
            guard !securityItems.isEmpty else { return nil }
            let issues = securityItems.filter(\.isIssue)
            let issueValue = securitySummaryValue(for: issues)
            return DashboardChipPresentation(
                title: title,
                value: issueValue,
                systemImage: defaultSystemImage,
                isActive: !issues.isEmpty,
                isAvailable: securityItems.contains { $0.entityBox.homeEntity.isAvailable }
            )
        case .climate:
            let climateItems = entityBoxes.filter(isClimateSummaryEntity)
            guard !climateItems.isEmpty else { return nil }
            let activeCount = climateItems.filter(isClimateActive).count
            return DashboardChipPresentation(
                title: title,
                value: primaryClimateTemperatureText(from: climateItems) ?? (activeCount == 0 ? "All idle" : "\(activeCount) active"),
                systemImage: defaultSystemImage,
                isActive: activeCount > 0,
                isAvailable: climateItems.contains { $0.homeEntity.isAvailable }
            )
        case .batteries:
            let batteries = entityBoxes.compactMap(\.sensorEntity).filter { $0.displayKind == .battery }
            guard !batteries.isEmpty else { return nil }
            let lowCount = batteries.filter(\.isAlerting).count
            return DashboardChipPresentation(
                title: title,
                value: countValue(lowCount, activeWord: "low", inactiveWord: "ok"),
                systemImage: lowCount > 0 ? "battery.25percent" : defaultSystemImage,
                isActive: lowCount > 0,
                isAvailable: batteries.contains(where: \.isAvailable)
            )
        case .media:
            let players = entityBoxes.filter { $0.domain == .mediaPlayer }
            guard !players.isEmpty else { return nil }
            let playingCount = players.filter { $0.mediaPlayerEntity?.isPlaying == true }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(playingCount, activeWord: "playing", inactiveWord: "idle"),
                systemImage: playingCount > 0 ? "play.tv.fill" : defaultSystemImage,
                isActive: playingCount > 0,
                isAvailable: players.contains { $0.homeEntity.isAvailable }
            )
        case .doors, .locks, .cameras:
            return makeSummary(
                kind: .security,
                entityBoxes: entityBoxes,
                titleOverride: titleOverride,
                iconNameOverride: iconNameOverride
            )
        }
    }

    static func makeDetail(
        kind: DashboardSummaryKind,
        entityBoxes: [HAEntityState],
        titleOverride: String? = nil,
        iconNameOverride: String? = nil,
        areaNameForEntityID: (String) -> String? = { _ in nil }
    ) -> DashboardSummaryDetailPresentation? {
        let canonicalKind = kind.canonicalKind
        guard let summary = makeSummary(
            kind: canonicalKind,
            entityBoxes: entityBoxes,
            titleOverride: titleOverride,
            iconNameOverride: iconNameOverride
        ) else {
            return nil
        }

        let sections: [DashboardSummarySectionPresentation]
        switch canonicalKind {
        case .lights:
            sections = lightSections(from: entityBoxes, areaNameForEntityID: areaNameForEntityID)
        case .security:
            sections = securitySections(from: entityBoxes, areaNameForEntityID: areaNameForEntityID)
        case .climate:
            sections = climateSections(from: entityBoxes, areaNameForEntityID: areaNameForEntityID)
        case .batteries:
            sections = batterySections(from: entityBoxes, areaNameForEntityID: areaNameForEntityID)
        case .media:
            sections = mediaSections(from: entityBoxes, areaNameForEntityID: areaNameForEntityID)
        case .doors, .locks, .cameras:
            sections = securitySections(from: entityBoxes, areaNameForEntityID: areaNameForEntityID)
        }

        return DashboardSummaryDetailPresentation(
            kind: canonicalKind,
            summary: summary,
            sections: sections
        )
    }

    static func makeEntityChip(
        entityBox: HAEntityState,
        titleOverride: String? = nil,
        iconNameOverride: String? = nil
    ) -> DashboardChipPresentation {
        let presentation = DashboardEntityPresentation(
            entityBox: entityBox,
            displayNameOverride: titleOverride,
            iconNameOverride: iconNameOverride
        )

        return DashboardChipPresentation(
            title: presentation.title,
            value: presentation.headline ?? presentation.subtitle,
            systemImage: presentation.iconName,
            isActive: presentation.isActive,
            isAvailable: presentation.isAvailable
        )
    }

    private static func countValue(_ count: Int, activeWord: String, inactiveWord: String) -> String {
        count == 0 ? "All \(inactiveWord)" : "\(count) \(activeWord)"
    }

    private static func normalizedOverride(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func lightSections(
        from entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        areaSections(
            idPrefix: "lights",
            entityBoxes: entityBoxes.filter { $0.domain == .light },
            areaNameForEntityID: areaNameForEntityID,
            makeItem: lightItem
        )
    }

    private static func lightItem(for entityBox: HAEntityState) -> DashboardSummaryEntityPresentation {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let sortPriority: Int
        if presentation.isActive {
            sortPriority = 0
        } else if !presentation.isAvailable {
            sortPriority = 1
        } else {
            sortPriority = 2
        }

        return summaryItem(
            entityBox: entityBox,
            presentation: presentation,
            detail: entityBox.lightEntity?.brightnessPercentage.map { "\($0)% brightness" },
            sortPriority: sortPriority
        )
    }

    private static func securitySections(
        from entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        let contextsByEntityID = Dictionary(uniqueKeysWithValues: entityBoxes.compactMap { entityBox in
            securityContext(for: entityBox).map { (entityBox.entityID, $0) }
        })

        return areaSections(
            idPrefix: "security",
            entityBoxes: entityBoxes.filter { contextsByEntityID[$0.entityID] != nil },
            areaNameForEntityID: areaNameForEntityID,
            makeItem: { entityBox in
                securityItem(for: contextsByEntityID[entityBox.entityID]!)
            }
        )
    }

    private static func securityItem(for context: SecurityContext) -> DashboardSummaryEntityPresentation {
        let presentation = DashboardEntityPresentation(entityBox: context.entityBox)
        let sortPriority: Int
        if context.isIssue {
            sortPriority = context.issueKind.sortPriority
        } else if !context.entityBox.homeEntity.isAvailable {
            sortPriority = 10
        } else {
            sortPriority = 20
        }

        return summaryItem(
            entityBox: context.entityBox,
            presentation: presentation,
            detail: context.detail,
            sortPriority: sortPriority
        )
    }

    private static func climateSections(
        from entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        areaSections(
            idPrefix: "climate",
            entityBoxes: entityBoxes.filter(isClimateSummaryEntity),
            areaNameForEntityID: areaNameForEntityID,
            makeItem: climateItem
        )
    }

    private static func climateItem(for entityBox: HAEntityState) -> DashboardSummaryEntityPresentation {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let sortPriority: Int
        if isClimateActive(entityBox) {
            sortPriority = 0
        } else if !presentation.isAvailable {
            sortPriority = 1
        } else {
            sortPriority = 2
        }

        return summaryItem(
            entityBox: entityBox,
            presentation: presentation,
            detail: climateDetail(for: entityBox),
            sortPriority: sortPriority
        )
    }

    private static func batterySections(
        from entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        let batteryBoxes = entityBoxes.filter { $0.sensorEntity?.displayKind == .battery }
        return areaSections(
            idPrefix: "batteries",
            entityBoxes: batteryBoxes,
            areaNameForEntityID: areaNameForEntityID,
            makeItem: batteryItem
        )
    }

    private static func batteryItem(for entityBox: HAEntityState) -> DashboardSummaryEntityPresentation {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let sensor = entityBox.sensorEntity
        let sortPriority: Int
        if sensor?.isAlerting == true {
            sortPriority = 0
        } else if sensor?.isAvailable == false {
            sortPriority = 1
        } else {
            sortPriority = 2
        }

        return summaryItem(
            entityBox: entityBox,
            presentation: presentation,
            detail: sensor?.formattedValue,
            sortPriority: sortPriority
        )
    }

    private static func mediaSections(
        from entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        let playerBoxes = entityBoxes.filter { $0.domain == .mediaPlayer }
        return areaSections(
            idPrefix: "media",
            entityBoxes: playerBoxes,
            areaNameForEntityID: areaNameForEntityID,
            makeItem: mediaItem
        )
    }

    private static func mediaItem(for entityBox: HAEntityState) -> DashboardSummaryEntityPresentation {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let mediaPlayer = entityBox.mediaPlayerEntity
        let sortPriority: Int
        if mediaPlayer?.isPlaying == true {
            sortPriority = 0
        } else if mediaPlayer?.isAvailable == false {
            sortPriority = 1
        } else {
            sortPriority = 2
        }

        return summaryItem(
            entityBox: entityBox,
            presentation: presentation,
            detail: mediaPlayer?.source ?? mediaPlayer?.volumePercentage.map { "\($0)% volume" },
            sortPriority: sortPriority
        )
    }

    private static func summaryItem(
        entityBox: HAEntityState,
        presentation: DashboardEntityPresentation,
        detail: String?,
        sortPriority: Int
    ) -> DashboardSummaryEntityPresentation {
        DashboardSummaryEntityPresentation(
            entityID: entityBox.entityID,
            domain: entityBox.domain,
            title: presentation.title,
            subtitle: presentation.headline ?? presentation.subtitle,
            detail: detail,
            systemImage: presentation.iconName,
            visualStyle: entityBox.domain == .camera ? .camera : .row,
            isActive: presentation.isActive,
            isAvailable: presentation.isAvailable,
            sortPriority: sortPriority,
            primaryAction: presentation.primaryAction
        )
    }

    private static func areaSections(
        idPrefix: String,
        entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String?,
        makeItem: (HAEntityState) -> DashboardSummaryEntityPresentation
    ) -> [DashboardSummarySectionPresentation] {
        let itemsByArea = Dictionary(grouping: entityBoxes) { entityBox in
            areaNameForEntityID(entityBox.entityID) ?? "Unassigned"
        }

        return itemsByArea
            .map { area, boxes in
                DashboardSummarySectionPresentation(
                    id: "\(idPrefix)-\(area)",
                    title: area,
                    items: sortedItems(boxes.map(makeItem))
                )
            }
            .sorted { lhs, rhs in
                if lhs.title == "Unassigned" { return false }
                if rhs.title == "Unassigned" { return true }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private static func sortedItems(_ items: [DashboardSummaryEntityPresentation]) -> [DashboardSummaryEntityPresentation] {
        items.sorted { lhs, rhs in
            if lhs.sortPriority != rhs.sortPriority {
                return lhs.sortPriority < rhs.sortPriority
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func securitySummaryValue(for issues: [SecurityContext]) -> String {
        guard !issues.isEmpty else {
            return "All secure"
        }

        for issueKind in SecurityIssueKind.summaryPriority {
            let count = issues.filter { $0.issueKind == issueKind }.count
            guard count > 0 else {
                continue
            }

            return "\(count) \(issueKind.summaryWord)"
        }

        return "\(issues.count) need attention"
    }

    private static func securityContext(for entityBox: HAEntityState) -> SecurityContext? {
        let entity = entityBox.homeEntity
        let searchableText = "\(entity.entityID) \(entity.displayName)".lowercased()

        switch entity.domain {
        case .lock:
            let isIssue = entity.isAvailable && entity.state != "locked"
            return SecurityContext(
                entityBox: entityBox,
                isIssue: isIssue,
                issueKind: .unlocked,
                detail: entity.state.displayStateText
            )
        case .camera:
            return SecurityContext(
                entityBox: entityBox,
                isIssue: !entity.isAvailable,
                issueKind: .unavailable,
                detail: entity.isAvailable ? "Ready" : "Unavailable"
            )
        case .cover:
            guard containsAny(searchableText, ["garage", "gate", "door"]) else {
                return nil
            }
            let isIssue = entity.isAvailable && entityBox.coverEntity?.isOpen == true
            return SecurityContext(
                entityBox: entityBox,
                isIssue: isIssue,
                issueKind: .open,
                detail: entityBox.coverEntity?.displaySubtitle ?? entity.state.displayStateText
            )
        case .binarySensor:
            guard let binarySensor = entityBox.binarySensorEntity else {
                return nil
            }

            let isFallbackSecurityEntity = binarySensor.displayKind == .generic &&
                containsAny(searchableText, ["alarm", "security", "tamper"])

            guard binarySensor.isSecurityRelevant || isFallbackSecurityEntity else {
                return nil
            }

            let isIssue = entity.isAvailable && entity.state == "on"
            return SecurityContext(
                entityBox: entityBox,
                isIssue: isIssue,
                issueKind: securityIssueKind(for: binarySensor),
                detail: binarySensor.displaySubtitle
            )
        case .sensor:
            guard let sensor = entityBox.sensorEntity,
                  sensor.isAlerting,
                  containsAny(searchableText, ["tamper", "alarm", "security", "problem", "safety"]) else {
                return nil
            }
            return SecurityContext(
                entityBox: entityBox,
                isIssue: true,
                issueKind: .detected,
                detail: sensor.displaySubtitle
            )
        case .other:
            guard entity.entityID.hasPrefix("alarm_control_panel.") else {
                return nil
            }
            let isIssue = ["triggered", "pending", "arming"].contains(entity.state)
            return SecurityContext(
                entityBox: entityBox,
                isIssue: isIssue,
                issueKind: .alarm,
                detail: entity.state.displayStateText
            )
        case .light, .climate, .fan, .mediaPlayer, .switch, .vacuum, .scene, .script:
            return nil
        }
    }

    private static func securityIssueKind(for binarySensor: BinarySensorEntity) -> SecurityIssueKind {
        switch binarySensor.displayKind {
        case .door, .window, .garageDoor, .opening:
            .open
        case .lock:
            .unlocked
        case .smoke, .gas, .tamper, .safety, .problem:
            .alarm
        case .motion, .occupancy, .presence:
            .detected
        case .moisture, .connectivity, .plug, .power, .light, .generic:
            .detected
        }
    }

    private static func isClimateSummaryEntity(_ entityBox: HAEntityState) -> Bool {
        entityBox.domain == .climate || entityBox.domain == .fan || isClimateReading(entityBox)
    }

    private static func isClimateReading(_ entityBox: HAEntityState) -> Bool {
        guard let sensor = entityBox.sensorEntity else {
            return false
        }

        return sensor.displayKind == .temperature || sensor.displayKind == .humidity
    }

    private static func isClimateActive(_ entityBox: HAEntityState) -> Bool {
        if entityBox.climateEntity?.isActive == true {
            return true
        }

        if entityBox.fanEntity?.isOn == true {
            return true
        }

        return false
    }

    private static func climateDetail(for entityBox: HAEntityState) -> String? {
        if let climate = entityBox.climateEntity {
            return climate.currentTemperatureText.map { "\($0) now" }
        }

        if let fan = entityBox.fanEntity {
            return fan.percentage.map { "\($0)%" }
        }

        return entityBox.sensorEntity?.formattedValue
    }

    private static func primaryClimateTemperatureText(from entityBoxes: [HAEntityState]) -> String? {
        let climateTemperature = entityBoxes
            .compactMap(\.climateEntity)
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive {
                    return lhs.isActive && !rhs.isActive
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .compactMap(\.currentTemperatureText)
            .first

        if let climateTemperature {
            return climateTemperature
        }

        return entityBoxes
            .compactMap(\.sensorEntity)
            .filter { $0.displayKind == .temperature }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .compactMap(\.formattedValue.nonEmptyValue)
            .first
    }

    private static func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }

}

private struct SecurityContext {
    let entityBox: HAEntityState
    let isIssue: Bool
    let issueKind: SecurityIssueKind
    let detail: String?
}

private enum SecurityIssueKind {
    case open
    case unlocked
    case detected
    case unavailable
    case alarm

    static let summaryPriority: [SecurityIssueKind] = [
        .unlocked,
        .open,
        .alarm,
        .detected,
        .unavailable
    ]

    var summaryWord: String {
        switch self {
        case .open:
            "open"
        case .unlocked:
            "unlocked"
        case .detected:
            "detected"
        case .unavailable:
            "unavailable"
        case .alarm:
            "alert"
        }
    }

    var sortPriority: Int {
        Self.summaryPriority.firstIndex(of: self) ?? Self.summaryPriority.count
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
