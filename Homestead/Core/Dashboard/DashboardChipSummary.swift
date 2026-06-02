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
    case maintenance
    case batteries
    case cameras
    case media

    static var allCases: [DashboardSummaryKind] {
        [.lights, .security, .climate, .maintenance, .media]
    }

    static var areasOverviewOrder: [DashboardSummaryKind] {
        [.climate, .lights, .security, .media, .maintenance]
    }

    static var areaSectionOrder: [DashboardSummaryKind] {
        [.lights, .climate, .security, .media, .maintenance]
    }

    var canonicalKind: DashboardSummaryKind {
        switch self {
        case .doors, .locks, .cameras:
            .security
        case .batteries:
            .maintenance
        case .lights, .security, .climate, .maintenance, .media:
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
        case .maintenance:
            "Maintenance"
        case .media:
            "Media"
        case .batteries:
            "Maintenance"
        case .doors, .locks, .cameras:
            "Security"
        }
    }

    var systemImage: String {
        switch canonicalKind {
        case .lights:
            "lightbulb.fill"
        case .security:
            "lock.fill"
        case .climate:
            "fan.fill"
        case .maintenance:
            "wrench.fill"
        case .media:
            "play.tv.fill"
        case .batteries:
            "wrench.fill"
        case .doors, .locks, .cameras:
            "lock.fill"
        }
    }
}

extension DashboardSummaryKind: Identifiable {
    var id: Self { self }
}

struct DashboardChipPresentation: Equatable, Sendable {
    let title: String
    let value: String
    let systemImage: String
    let isActive: Bool
    let isAvailable: Bool
    let iconTint: DashboardChipIconTint

    var accessibilityValue: String {
        value
    }

    init(
        title: String,
        value: String,
        systemImage: String,
        isActive: Bool,
        isAvailable: Bool,
        iconTint: DashboardChipIconTint = .status
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.isActive = isActive
        self.isAvailable = isAvailable
        self.iconTint = iconTint
    }
}

nonisolated enum DashboardChipIconTint: Equatable, Sendable {
    case status
    case lights
    case security
    case climate
    case maintenance
    case media
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
        iconNameOverride: String? = nil,
        preferredClimateReadingEntityIDs: Set<String> = [],
        nonPrimaryEntityIDs: Set<String> = [],
        diagnosticEntityIDs: Set<String> = []
    ) -> DashboardChipPresentation? {
        let canonicalKind = kind.canonicalKind
        let title = normalizedOverride(titleOverride) ?? canonicalKind.title
        let defaultSystemImage = normalizedOverride(iconNameOverride) ?? canonicalKind.systemImage

        switch canonicalKind {
        case .lights:
            let lights = entityBoxes.filter { isPrimaryEntity($0, nonPrimaryEntityIDs: nonPrimaryEntityIDs) && $0.domain == .light }
            guard !lights.isEmpty else { return nil }
            let activeCount = lights.filter { $0.homeEntity.state == "on" }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(activeCount, activeWord: "on", inactiveWord: "off"),
                systemImage: defaultSystemImage,
                isActive: activeCount > 0,
                isAvailable: lights.contains { $0.homeEntity.isAvailable },
                iconTint: .lights
            )
        case .security:
            let securityItems = entityBoxes.compactMap {
                securityContext(
                    for: $0,
                    nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                    diagnosticEntityIDs: diagnosticEntityIDs
                )
            }
            guard !securityItems.isEmpty else { return nil }
            let issues = securityItems.filter(\.isIssue)
            let issueValue = securitySummaryValue(for: issues)
            return DashboardChipPresentation(
                title: title,
                value: issueValue,
                systemImage: defaultSystemImage,
                isActive: !issues.isEmpty,
                isAvailable: securityItems.contains { $0.entityBox.homeEntity.isAvailable },
                iconTint: .security
            )
        case .climate:
            let climateItems = entityBoxes.filter {
                isClimateSummaryEntity(
                    $0,
                    preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs,
                    nonPrimaryEntityIDs: nonPrimaryEntityIDs
                )
            }
            guard !climateItems.isEmpty else { return nil }
            let activeCount = climateItems.filter(isClimateActive).count
            return DashboardChipPresentation(
                title: title,
                value: primaryClimateTemperatureText(from: climateItems) ?? countValue(activeCount, activeWord: "active", inactiveWord: "idle"),
                systemImage: defaultSystemImage,
                isActive: activeCount > 0,
                isAvailable: climateItems.contains { $0.homeEntity.isAvailable },
                iconTint: .climate
            )
        case .maintenance:
            let maintenanceItems = entityBoxes.filter {
                isMaintenanceSummaryEntity(
                    $0,
                    nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                    diagnosticEntityIDs: diagnosticEntityIDs
                )
            }
            guard !maintenanceItems.isEmpty else { return nil }
            let issueCount = maintenanceItems.filter(isMaintenanceIssue).count
            return DashboardChipPresentation(
                title: title,
                value: countValue(issueCount, activeWord: "issue", inactiveWord: "ok"),
                systemImage: defaultSystemImage,
                isActive: issueCount > 0,
                isAvailable: maintenanceItems.contains { $0.homeEntity.isAvailable },
                iconTint: .maintenance
            )
        case .media:
            let players = entityBoxes.filter { isPrimaryEntity($0, nonPrimaryEntityIDs: nonPrimaryEntityIDs) && $0.domain == .mediaPlayer }
            guard !players.isEmpty else { return nil }
            let playingCount = players.filter { $0.mediaPlayerEntity?.isPlaying == true }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(playingCount, activeWord: "playing", inactiveWord: "idle"),
                systemImage: defaultSystemImage,
                isActive: playingCount > 0,
                isAvailable: players.contains { $0.homeEntity.isAvailable },
                iconTint: .media
            )
        case .batteries:
            return makeSummary(
                kind: .maintenance,
                entityBoxes: entityBoxes,
                titleOverride: titleOverride,
                iconNameOverride: iconNameOverride,
                preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs
            )
        case .doors, .locks, .cameras:
            return makeSummary(
                kind: .security,
                entityBoxes: entityBoxes,
                titleOverride: titleOverride,
                iconNameOverride: iconNameOverride,
                preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs
            )
        }
    }

    static func makeDetail(
        kind: DashboardSummaryKind,
        entityBoxes: [HAEntityState],
        titleOverride: String? = nil,
        iconNameOverride: String? = nil,
        preferredClimateReadingEntityIDs: Set<String> = [],
        nonPrimaryEntityIDs: Set<String> = [],
        diagnosticEntityIDs: Set<String> = [],
        areaNameForEntityID: (String) -> String? = { _ in nil }
    ) -> DashboardSummaryDetailPresentation? {
        let canonicalKind = kind.canonicalKind
        guard let summary = makeSummary(
            kind: canonicalKind,
            entityBoxes: entityBoxes,
            titleOverride: titleOverride,
            iconNameOverride: iconNameOverride,
            preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs,
            nonPrimaryEntityIDs: nonPrimaryEntityIDs,
            diagnosticEntityIDs: diagnosticEntityIDs
        ) else {
            return nil
        }

        let sections: [DashboardSummarySectionPresentation]
        switch canonicalKind {
        case .lights:
            sections = lightSections(
                from: entityBoxes,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                areaNameForEntityID: areaNameForEntityID
            )
        case .security:
            sections = securitySections(
                from: entityBoxes,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs,
                areaNameForEntityID: areaNameForEntityID
            )
        case .climate:
            sections = climateSections(
                from: entityBoxes,
                preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                areaNameForEntityID: areaNameForEntityID
            )
        case .maintenance:
            sections = maintenanceSections(
                from: entityBoxes,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs,
                areaNameForEntityID: areaNameForEntityID
            )
        case .media:
            sections = mediaSections(
                from: entityBoxes,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                areaNameForEntityID: areaNameForEntityID
            )
        case .batteries:
            sections = maintenanceSections(
                from: entityBoxes,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs,
                areaNameForEntityID: areaNameForEntityID
            )
        case .doors, .locks, .cameras:
            sections = securitySections(
                from: entityBoxes,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs,
                areaNameForEntityID: areaNameForEntityID
            )
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
        count == 0 ? "All \(inactiveWord.capitalizedFirstLetter)" : "\(count) \(activeWord.capitalizedFirstLetter)"
    }

    private static func normalizedOverride(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func lightSections(
        from entityBoxes: [HAEntityState],
        nonPrimaryEntityIDs: Set<String>,
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        areaSections(
            idPrefix: "lights",
            entityBoxes: entityBoxes.filter { isPrimaryEntity($0, nonPrimaryEntityIDs: nonPrimaryEntityIDs) && $0.domain == .light },
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
        nonPrimaryEntityIDs: Set<String>,
        diagnosticEntityIDs: Set<String>,
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        let contextsByEntityID = Dictionary(uniqueKeysWithValues: entityBoxes.compactMap { entityBox in
            securityContext(
                for: entityBox,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs
            ).map { (entityBox.entityID, $0) }
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
        preferredClimateReadingEntityIDs: Set<String>,
        nonPrimaryEntityIDs: Set<String>,
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        areaSections(
            idPrefix: "climate",
            entityBoxes: entityBoxes.filter {
                isClimateSummaryEntity(
                    $0,
                    preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs,
                    nonPrimaryEntityIDs: nonPrimaryEntityIDs
                )
            },
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

    private static func maintenanceSections(
        from entityBoxes: [HAEntityState],
        nonPrimaryEntityIDs: Set<String>,
        diagnosticEntityIDs: Set<String>,
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        let maintenanceBoxes = entityBoxes.filter {
            isMaintenanceSummaryEntity(
                $0,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs
            )
        }
        return areaSections(
            idPrefix: "maintenance",
            entityBoxes: maintenanceBoxes,
            areaNameForEntityID: areaNameForEntityID,
            makeItem: maintenanceItem
        )
    }

    private static func maintenanceItem(for entityBox: HAEntityState) -> DashboardSummaryEntityPresentation {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let sensor = entityBox.sensorEntity
        let binarySensor = entityBox.binarySensorEntity
        let sortPriority: Int
        if isMaintenanceIssue(entityBox) {
            sortPriority = 0
        } else if !entityBox.homeEntity.isAvailable {
            sortPriority = 1
        } else {
            sortPriority = 2
        }

        return summaryItem(
            entityBox: entityBox,
            presentation: presentation,
            detail: sensor?.formattedValue ?? binarySensor?.displaySubtitle,
            sortPriority: sortPriority
        )
    }

    private static func mediaSections(
        from entityBoxes: [HAEntityState],
        nonPrimaryEntityIDs: Set<String>,
        areaNameForEntityID: (String) -> String?
    ) -> [DashboardSummarySectionPresentation] {
        let playerBoxes = entityBoxes.filter { isPrimaryEntity($0, nonPrimaryEntityIDs: nonPrimaryEntityIDs) && $0.domain == .mediaPlayer }
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

            return "\(count) \(issueKind.summaryWord.capitalizedFirstLetter)"
        }

        return "\(issues.count) \("need attention".capitalizedFirstLetter)"
    }

    private static func securityContext(
        for entityBox: HAEntityState,
        nonPrimaryEntityIDs: Set<String>,
        diagnosticEntityIDs: Set<String>
    ) -> SecurityContext? {
        let entity = entityBox.homeEntity

        switch entity.domain {
        case .lock:
            guard isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs) else { return nil }
            let isIssue = entity.isAvailable && entity.state != "locked"
            return SecurityContext(
                entityBox: entityBox,
                isIssue: isIssue,
                issueKind: .unlocked,
                detail: entity.state.displayStateText
            )
        case .camera:
            guard isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs) else { return nil }
            return SecurityContext(
                entityBox: entityBox,
                isIssue: !entity.isAvailable,
                issueKind: .unavailable,
                detail: entity.isAvailable ? "Ready" : "Unavailable"
            )
        case .cover:
            let securityCoverClasses = ["door", "garage", "gate", "window"]
            guard isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs),
                  securityCoverClasses.contains(entityBox.coverEntity?.deviceClass ?? "") else {
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

            guard isHomeAssistantSecurityBinarySensor(binarySensor),
                  isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs) ||
                    isDiagnosticTamperSensor(entityBox, diagnosticEntityIDs: diagnosticEntityIDs) else {
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
            return nil
        case .other:
            guard isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs),
                  entity.entityID.hasPrefix("alarm_control_panel.") else {
                return nil
            }
            let isIssue = ["triggered", "pending", "arming"].contains(entity.state)
            return SecurityContext(
                entityBox: entityBox,
                isIssue: isIssue,
                issueKind: .alarm,
                detail: entity.state.displayStateText
            )
        case .light, .climate, .fan, .mediaPlayer, .switch, .vacuum, .scene, .script, .automation:
            return nil
        }
    }

    private static func securityIssueKind(for binarySensor: BinarySensorEntity) -> SecurityIssueKind {
        switch binarySensor.displayKind {
        case .door, .window, .garageDoor, .opening:
            .open
        case .lock:
            .unlocked
        case .smoke, .gas, .carbonMonoxide, .heat, .tamper, .safety, .problem, .vibration:
            .alarm
        case .motion, .occupancy, .presence:
            .detected
        case .moisture:
            .alarm
        case .battery, .batteryCharging, .cold, .moving, .running, .sound, .update, .connectivity, .plug, .power, .light, .generic:
            .detected
        }
    }

    private static func isClimateSummaryEntity(
        _ entityBox: HAEntityState,
        preferredClimateReadingEntityIDs: Set<String>,
        nonPrimaryEntityIDs: Set<String>
    ) -> Bool {
        switch entityBox.domain {
        case .climate, .fan:
            return isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs)
        case .cover:
            let climateCoverClasses = ["awning", "blind", "curtain", "shade", "shutter", "window", "none"]
            return isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs) &&
                climateCoverClasses.contains(entityBox.coverEntity?.deviceClass ?? "")
        case .binarySensor:
            return isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs) &&
                entityBox.binarySensorEntity?.displayKind == .window
        case .sensor:
            return preferredClimateReadingEntityIDs.contains(entityBox.entityID) && isClimateReading(entityBox)
        case .light, .lock, .mediaPlayer, .camera, .switch, .vacuum, .scene, .script, .automation, .other:
            return false
        }
    }

    private static func isPrimaryEntity(
        _ entityBox: HAEntityState,
        nonPrimaryEntityIDs: Set<String>
    ) -> Bool {
        !nonPrimaryEntityIDs.contains(entityBox.entityID)
    }

    private static func isHomeAssistantSecurityBinarySensor(_ binarySensor: BinarySensorEntity) -> Bool {
        switch binarySensor.displayKind {
        case .lock, .door, .window, .garageDoor, .opening, .gas, .carbonMonoxide, .heat, .moisture, .safety, .smoke, .tamper, .vibration:
            return true
        case .motion, .occupancy, .presence, .problem, .battery, .batteryCharging, .cold, .moving, .running, .sound, .update, .connectivity, .plug, .power, .light, .generic:
            return false
        }
    }

    private static func isDiagnosticTamperSensor(
        _ entityBox: HAEntityState,
        diagnosticEntityIDs: Set<String>
    ) -> Bool {
        diagnosticEntityIDs.contains(entityBox.entityID) &&
            entityBox.binarySensorEntity?.displayKind == .tamper
    }

    private static func isMaintenanceSummaryEntity(
        _ entityBox: HAEntityState,
        nonPrimaryEntityIDs: Set<String>,
        diagnosticEntityIDs: Set<String>
    ) -> Bool {
        guard isPrimaryEntity(entityBox, nonPrimaryEntityIDs: nonPrimaryEntityIDs),
              !diagnosticEntityIDs.contains(entityBox.entityID) else {
            return false
        }

        switch entityBox.domain {
        case .sensor:
            return entityBox.sensorEntity?.displayKind == .battery
        case .binarySensor:
            return entityBox.binarySensorEntity?.displayKind == .battery
        case .light, .climate, .cover, .fan, .lock, .mediaPlayer, .camera, .switch, .vacuum, .scene, .script, .automation, .other:
            return false
        }
    }

    private static func isMaintenanceIssue(_ entityBox: HAEntityState) -> Bool {
        if !entityBox.homeEntity.isAvailable {
            return true
        }

        if entityBox.sensorEntity?.isAlerting == true {
            return true
        }

        if entityBox.binarySensorEntity?.displayKind == .battery {
            return entityBox.binarySensorEntity?.isActive == true
        }

        return false
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
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
