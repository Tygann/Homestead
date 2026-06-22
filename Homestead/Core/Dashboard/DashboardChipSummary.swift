import Foundation

nonisolated enum DashboardChipKind: String, Codable, Equatable, Sendable {
    case summary
    case entity
}

nonisolated enum DashboardSummaryKind: String, CaseIterable, Codable, Equatable, Sendable {
    case lights
    case security
    case climate
    case maintenance
    case media

    static var areasOverviewOrder: [DashboardSummaryKind] {
        [.climate, .lights, .security, .media, .maintenance]
    }

    static var areaSectionOrder: [DashboardSummaryKind] {
        [.lights, .climate, .security, .media, .maintenance]
    }

    var title: String {
        switch self {
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
        }
    }

    var systemImage: String {
        switch self {
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
        }
    }
}

extension DashboardSummaryKind: Identifiable {
    var id: Self { self }
}

struct DashboardChipPresentation: Equatable, Sendable {
    let title: String
    let value: String
    let icon: ResolvedIcon
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
        icon = .sfSymbol(systemImage, provenance: .homesteadSemanticMapping)
        self.isActive = isActive
        self.isAvailable = isAvailable
        self.iconTint = iconTint
    }

    init(
        title: String,
        value: String,
        icon: ResolvedIcon,
        isActive: Bool,
        isAvailable: Bool,
        iconTint: DashboardChipIconTint = .status
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.isActive = isActive
        self.isAvailable = isAvailable
        self.iconTint = iconTint
    }

    var systemImage: String { icon.sfSymbolName }
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
    let groups: [DashboardSummaryGroupPresentation]

    var sections: [DashboardSummarySectionPresentation] {
        groups.flatMap(\.sections)
    }

    var isEmpty: Bool {
        sections.allSatisfy(\.items.isEmpty)
    }
}

struct DashboardSummaryGroupPresentation: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String?
    let sections: [DashboardSummarySectionPresentation]
}

struct DashboardSummarySectionPresentation: Identifiable, Equatable, Sendable {
    let id: String
    let areaID: String?
    let title: String?
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
    let icon: ResolvedIcon
    let visualStyle: DashboardSummaryEntityVisualStyle
    let isActive: Bool
    let isAvailable: Bool
    let sortPriority: Int
    let sortGroup: Int
    let primaryAction: DashboardEntityPrimaryAction?

    var id: String { entityID }
    var systemImage: String { icon.sfSymbolName }
}

@MainActor
struct DashboardSummaryWorkspace {
    let entityBoxes: [HAEntityState]
    let membershipContext: DashboardSummaryMembershipContext
    private let entityBoxesByKind: [DashboardSummaryKind: [HAEntityState]]
    private let securityContextsByEntityID: [String: SecurityContext]

    init(
        entityBoxes: [HAEntityState],
        membershipContext: DashboardSummaryMembershipContext = .empty
    ) {
        self.entityBoxes = entityBoxes
        self.membershipContext = membershipContext

        var entityBoxesByKind: [DashboardSummaryKind: [HAEntityState]] = [:]
        var securityContextsByEntityID: [String: SecurityContext] = [:]

        for entityBox in entityBoxes {
            for kind in DashboardSummaryKind.allCases where HomeAssistantSummaryClassifier.contains(
                entityBox,
                in: kind,
                context: membershipContext
            ) {
                entityBoxesByKind[kind, default: []].append(entityBox)
            }

            if let securityContext = DashboardSummaryProvider.securityContext(
                for: entityBox,
                membershipContext: membershipContext
            ) {
                securityContextsByEntityID[entityBox.entityID] = securityContext
            }
        }

        self.entityBoxesByKind = entityBoxesByKind
        self.securityContextsByEntityID = securityContextsByEntityID
    }

    func entityBoxes(in kind: DashboardSummaryKind) -> [HAEntityState] {
        entityBoxesByKind[kind, default: []]
    }

    fileprivate func securityContexts() -> [SecurityContext] {
        entityBoxes.compactMap { securityContextsByEntityID[$0.entityID] }
    }

    fileprivate func securityContext(for entityID: String) -> SecurityContext? {
        securityContextsByEntityID[entityID]
    }
}

@MainActor
enum DashboardSummaryProvider {
    static func makeSummary(
        kind: DashboardSummaryKind,
        entityBoxes: [HAEntityState],
        titleOverride: String? = nil,
        iconNameOverride: String? = nil,
        membershipContext: DashboardSummaryMembershipContext = .empty
    ) -> DashboardChipPresentation? {
        makeSummary(
            kind: kind,
            workspace: DashboardSummaryWorkspace(
                entityBoxes: entityBoxes,
                membershipContext: membershipContext
            ),
            titleOverride: titleOverride,
            iconNameOverride: iconNameOverride
        )
    }

    static func makeSummary(
        kind: DashboardSummaryKind,
        workspace: DashboardSummaryWorkspace,
        titleOverride: String? = nil,
        iconNameOverride: String? = nil
    ) -> DashboardChipPresentation? {
        let title = normalizedOverride(titleOverride) ?? kind.title
        let defaultSystemImage = normalizedOverride(iconNameOverride) ?? kind.systemImage

        switch kind {
        case .lights:
            let lights = workspace.entityBoxes(in: .lights)
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
            let securityItems = workspace.securityContexts()
            guard !securityItems.isEmpty else { return nil }
            let securityStatus = securitySummaryStatus(for: securityItems)
            return DashboardChipPresentation(
                title: title,
                value: securityStatus.value,
                systemImage: defaultSystemImage,
                isActive: securityStatus.isActive,
                isAvailable: securityItems.contains { $0.entityBox.homeEntity.isAvailable },
                iconTint: .security
            )
        case .climate:
            let climateItems = workspace.entityBoxes(in: .climate)
            guard !climateItems.isEmpty else { return nil }
            let activeCount = climateItems.filter(isClimateActive).count
            return DashboardChipPresentation(
                title: title,
                value: climateTemperatureRangeText(
                    from: climateItems,
                    preferredEntityIDs: workspace.membershipContext.preferredClimateReadingEntityIDs
                ),
                systemImage: defaultSystemImage,
                isActive: activeCount > 0,
                isAvailable: climateItems.contains { $0.homeEntity.isAvailable },
                iconTint: .climate
            )
        case .maintenance:
            let maintenanceItems = workspace.entityBoxes(in: .maintenance)
            guard !maintenanceItems.isEmpty else { return nil }
            let lowBatteryCount = maintenanceItems.filter {
                isLowBatteryIssue($0, membershipContext: workspace.membershipContext)
            }.count
            let unavailableCount = maintenanceItems.filter { !$0.homeEntity.isAvailable }.count
            return DashboardChipPresentation(
                title: title,
                value: maintenanceSummaryValue(lowBatteryCount: lowBatteryCount, unavailableCount: unavailableCount),
                systemImage: defaultSystemImage,
                isActive: lowBatteryCount > 0 || unavailableCount > 0,
                isAvailable: maintenanceItems.contains { $0.homeEntity.isAvailable },
                iconTint: .maintenance
            )
        case .media:
            let players = workspace.entityBoxes(in: .media)
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
        }
    }

    static func makeDetail(
        kind: DashboardSummaryKind,
        entityBoxes: [HAEntityState],
        titleOverride: String? = nil,
        iconNameOverride: String? = nil,
        membershipContext: DashboardSummaryMembershipContext = .empty,
        areaNameForEntityID: (String) -> String? = { _ in nil },
        areaContextForEntityID: ((String) -> DashboardAreaContext?)? = nil
    ) -> DashboardSummaryDetailPresentation? {
        makeDetail(
            kind: kind,
            workspace: DashboardSummaryWorkspace(
                entityBoxes: entityBoxes,
                membershipContext: membershipContext
            ),
            titleOverride: titleOverride,
            iconNameOverride: iconNameOverride,
            areaNameForEntityID: areaNameForEntityID,
            areaContextForEntityID: areaContextForEntityID
        )
    }

    static func makeDetail(
        kind: DashboardSummaryKind,
        workspace: DashboardSummaryWorkspace,
        titleOverride: String? = nil,
        iconNameOverride: String? = nil,
        areaNameForEntityID: (String) -> String? = { _ in nil },
        areaContextForEntityID: ((String) -> DashboardAreaContext?)? = nil
    ) -> DashboardSummaryDetailPresentation? {
        guard let summary = makeSummary(
            kind: kind,
            workspace: workspace,
            titleOverride: titleOverride,
            iconNameOverride: iconNameOverride
        ) else {
            return nil
        }

        let groups: [DashboardSummaryGroupPresentation]
        switch kind {
        case .lights:
            groups = lightSections(
                workspace: workspace,
                areaNameForEntityID: areaNameForEntityID,
                areaContextForEntityID: areaContextForEntityID
            )
        case .security:
            groups = securitySections(
                workspace: workspace,
                areaNameForEntityID: areaNameForEntityID,
                areaContextForEntityID: areaContextForEntityID
            )
        case .climate:
            groups = climateSections(
                workspace: workspace,
                areaNameForEntityID: areaNameForEntityID,
                areaContextForEntityID: areaContextForEntityID
            )
        case .maintenance:
            groups = maintenanceSections(
                workspace: workspace,
                areaNameForEntityID: areaNameForEntityID,
                areaContextForEntityID: areaContextForEntityID
            )
        case .media:
            groups = mediaSections(
                workspace: workspace,
                areaNameForEntityID: areaNameForEntityID,
                areaContextForEntityID: areaContextForEntityID
            )
        }

        return DashboardSummaryDetailPresentation(
            kind: kind,
            summary: summary,
            groups: groups
        )
    }

    static func makeSummaries(
        kinds: [DashboardSummaryKind],
        entityBoxes: [HAEntityState],
        membershipContext: DashboardSummaryMembershipContext = .empty
    ) -> [DashboardSummaryKind: DashboardChipPresentation] {
        let workspace = DashboardSummaryWorkspace(
            entityBoxes: entityBoxes,
            membershipContext: membershipContext
        )
        return Dictionary(
            uniqueKeysWithValues: kinds.compactMap { kind in
                makeSummary(kind: kind, workspace: workspace).map { (kind, $0) }
            }
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
            icon: presentation.icon,
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
        workspace: DashboardSummaryWorkspace,
        areaNameForEntityID: (String) -> String?,
        areaContextForEntityID: ((String) -> DashboardAreaContext?)?
    ) -> [DashboardSummaryGroupPresentation] {
        areaSections(
            idPrefix: "lights",
            entityBoxes: workspace.entityBoxes(in: .lights),
            areaNameForEntityID: areaNameForEntityID,
            areaContextForEntityID: areaContextForEntityID,
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
        workspace: DashboardSummaryWorkspace,
        areaNameForEntityID: (String) -> String?,
        areaContextForEntityID: ((String) -> DashboardAreaContext?)?
    ) -> [DashboardSummaryGroupPresentation] {
        let securityBoxes = workspace.securityContexts().map(\.entityBox)

        return areaSections(
            idPrefix: "security",
            entityBoxes: securityBoxes,
            areaNameForEntityID: areaNameForEntityID,
            areaContextForEntityID: areaContextForEntityID,
            makeItem: { entityBox in
                securityItem(for: workspace.securityContext(for: entityBox.entityID)!)
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
        workspace: DashboardSummaryWorkspace,
        areaNameForEntityID: (String) -> String?,
        areaContextForEntityID: ((String) -> DashboardAreaContext?)?
    ) -> [DashboardSummaryGroupPresentation] {
        areaSections(
            idPrefix: "climate",
            entityBoxes: workspace.entityBoxes(in: .climate),
            areaNameForEntityID: areaNameForEntityID,
            areaContextForEntityID: areaContextForEntityID,
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
        workspace: DashboardSummaryWorkspace,
        areaNameForEntityID: (String) -> String?,
        areaContextForEntityID: ((String) -> DashboardAreaContext?)?
    ) -> [DashboardSummaryGroupPresentation] {
        let maintenanceBoxes = workspace.entityBoxes(in: .maintenance)
        return areaSections(
            idPrefix: "maintenance",
            entityBoxes: maintenanceBoxes,
            areaNameForEntityID: areaNameForEntityID,
            areaContextForEntityID: areaContextForEntityID,
            makeItem: { maintenanceItem(for: $0, membershipContext: workspace.membershipContext) }
        )
    }

    private static func maintenanceItem(
        for entityBox: HAEntityState,
        membershipContext: DashboardSummaryMembershipContext
    ) -> DashboardSummaryEntityPresentation {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let sensor = entityBox.sensorEntity
        let binarySensor = entityBox.binarySensorEntity
        let sortPriority: Int
        if isMaintenanceIssue(entityBox, membershipContext: membershipContext) {
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
        workspace: DashboardSummaryWorkspace,
        areaNameForEntityID: (String) -> String?,
        areaContextForEntityID: ((String) -> DashboardAreaContext?)?
    ) -> [DashboardSummaryGroupPresentation] {
        let playerBoxes = workspace.entityBoxes(in: .media)
        return areaSections(
            idPrefix: "media",
            entityBoxes: playerBoxes,
            areaNameForEntityID: areaNameForEntityID,
            areaContextForEntityID: areaContextForEntityID,
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
            icon: presentation.icon,
            visualStyle: entityBox.domain == .camera ? .camera : .row,
            isActive: presentation.isActive,
            isAvailable: presentation.isAvailable,
            sortPriority: sortPriority,
            sortGroup: summarySortGroup(for: entityBox.domain),
            primaryAction: presentation.primaryAction
        )
    }

    private static func areaSections(
        idPrefix: String,
        entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String?,
        areaContextForEntityID: ((String) -> DashboardAreaContext?)?,
        makeItem: (HAEntityState) -> DashboardSummaryEntityPresentation
    ) -> [DashboardSummaryGroupPresentation] {
        let resolvedContext: (String) -> DashboardAreaContext? = { entityID in
            if let context = areaContextForEntityID?(entityID) {
                return context
            }

            return areaNameForEntityID(entityID).map { areaName in
                DashboardAreaContext(
                    areaID: areaName,
                    name: areaName,
                    icon: nil,
                    floorID: nil,
                    floorName: nil,
                    floorLevel: nil,
                    floorSortOrder: nil
                )
            }
        }
        let boxesByEntityID = Dictionary(uniqueKeysWithValues: entityBoxes.map { ($0.entityID, $0) })
        let areas = DashboardAreaBuilder.buildAreas(
            from: entityBoxes,
            areaContextForEntityID: resolvedContext
        )
        let assignedAreas = areas.filter { $0.areaID != nil }
        var groups = assignedAreas.isEmpty ? [] : DashboardAreaBuilder.buildSections(from: assignedAreas).map { areaSection in
            DashboardSummaryGroupPresentation(
                id: "\(idPrefix)-\(areaSection.id)",
                title: summaryAreaGroupTitle(for: areaSection),
                systemImage: nil,
                sections: areaSection.areas.map { area in
                    DashboardSummarySectionPresentation(
                        id: "\(idPrefix)-\(area.id)",
                        areaID: area.areaID,
                        title: area.name,
                        items: sortedItems(
                            area.entityIDs.compactMap { boxesByEntityID[$0] }.map(makeItem)
                        )
                    )
                }
            )
        }

        if let unassignedArea = areas.first(where: { $0.areaID == nil }) {
            groups.append(
                DashboardSummaryGroupPresentation(
                    id: "\(idPrefix)-unassigned",
                    title: DashboardAreaBuilder.unassignedAreaName,
                    systemImage: "square.grid.2x2",
                    sections: [
                        DashboardSummarySectionPresentation(
                            id: "\(idPrefix)-unassigned-items",
                            areaID: nil,
                            title: nil,
                            items: sortedItems(
                                unassignedArea.entityIDs.compactMap { boxesByEntityID[$0] }.map(makeItem)
                            )
                        )
                    ]
                )
            )
        }

        return groups
    }

    private static func summaryAreaGroupTitle(for areaSection: DashboardAreaSection) -> String {
        if areaSection.id == "other", areaSection.areas.allSatisfy({ $0.areaID != nil }) {
            return "Other Areas"
        }

        return areaSection.title ?? "Areas"
    }

    private static func sortedItems(_ items: [DashboardSummaryEntityPresentation]) -> [DashboardSummaryEntityPresentation] {
        items.sorted { lhs, rhs in
            if lhs.sortGroup != rhs.sortGroup {
                return lhs.sortGroup < rhs.sortGroup
            }

            if lhs.sortPriority != rhs.sortPriority {
                return lhs.sortPriority < rhs.sortPriority
            }

            let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.entityID.localizedCaseInsensitiveCompare(rhs.entityID) == .orderedAscending
        }
    }

    private static func summarySortGroup(for domain: EntityDomain) -> Int {
        switch domain {
        case .binarySensor, .cover:
            0
        case .lock:
            1
        case .alarmControlPanel, .siren:
            2
        case .climate:
            3
        case .fan:
            4
        case .light:
            5
        case .mediaPlayer:
            6
        case .camera, .image:
            7
        case .sensor:
            8
        default:
            20
        }
    }

    private static func securitySummaryStatus(for contexts: [SecurityContext]) -> SecuritySummaryStatus {
        let unlockedLockCount = contexts.filter { context in
            context.entityBox.domain == .lock &&
                ["unlocked", "jammed", "open"].contains(context.entityBox.homeEntity.state)
        }.count
        if unlockedLockCount > 0 {
            return SecuritySummaryStatus(value: "\(unlockedLockCount) Unlocked", isActive: true)
        }

        let disarmedAlarmCount = contexts.filter { context in
            context.entityBox.domain == .alarmControlPanel && context.entityBox.homeEntity.state == "disarmed"
        }.count
        if disarmedAlarmCount > 0 {
            return SecuritySummaryStatus(value: "\(disarmedAlarmCount) Disarmed", isActive: true)
        }

        return SecuritySummaryStatus(value: "All Secure", isActive: false)
    }

    fileprivate static func securityContext(
        for entityBox: HAEntityState,
        membershipContext: DashboardSummaryMembershipContext
    ) -> SecurityContext? {
        guard HomeAssistantSummaryClassifier.contains(entityBox, in: .security, context: membershipContext) else {
            return nil
        }
        let entity = entityBox.homeEntity

        switch entity.domain {
        case .lock:
            let isIssue = entity.isAvailable && ["unlocked", "jammed", "open"].contains(entity.state)
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

            let isIssue = entity.isAvailable && entity.state == "on"
            return SecurityContext(
                entityBox: entityBox,
                isIssue: isIssue,
                issueKind: securityIssueKind(for: binarySensor),
                detail: binarySensor.displaySubtitle
            )
        case .alarmControlPanel:
            let isIssue = entity.state == "disarmed"
            return SecurityContext(
                entityBox: entityBox,
                isIssue: isIssue,
                issueKind: .alarm,
                detail: entity.state.displayStateText
            )
        default:
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

    private static func isMaintenanceIssue(
        _ entityBox: HAEntityState,
        membershipContext: DashboardSummaryMembershipContext
    ) -> Bool {
        if !entityBox.homeEntity.isAvailable {
            return true
        }

        return isLowBatteryIssue(entityBox, membershipContext: membershipContext)
    }

    private static func isLowBatteryIssue(
        _ entityBox: HAEntityState,
        membershipContext: DashboardSummaryMembershipContext
    ) -> Bool {
        if entityBox.sensorEntity?.isAlerting == true {
            return !HomeAssistantSummaryClassifier.isCharging(entityBox, context: membershipContext)
        }

        if entityBox.binarySensorEntity?.displayKind == .battery {
            return entityBox.binarySensorEntity?.isActive == true
        }

        return false
    }

    private static func maintenanceSummaryValue(lowBatteryCount: Int, unavailableCount: Int) -> String {
        var parts: [String] = []
        if lowBatteryCount > 0 {
            parts.append("\(lowBatteryCount) Low Battery")
        }
        if unavailableCount > 0 {
            parts.append("\(unavailableCount) Unavailable")
        }
        return parts.isEmpty ? "All Good" : parts.joined(separator: ", ")
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

    private static func climateTemperatureRangeText(
        from entityBoxes: [HAEntityState],
        preferredEntityIDs: Set<String>
    ) -> String {
        let values = entityBoxes.compactMap { entityBox -> Double? in
            guard preferredEntityIDs.contains(entityBox.entityID),
                  entityBox.sensorEntity?.deviceClass == "temperature" else {
                return nil
            }
            return entityBox.sensorEntity?.numericValue
        }
        guard let minimum = values.min(), let maximum = values.max() else {
            return ""
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let minimumText = formatter.string(from: NSNumber(value: minimum)) ?? String(format: "%.1f", minimum)
        let maximumText = formatter.string(from: NSNumber(value: maximum)) ?? String(format: "%.1f", maximum)
        return minimumText == maximumText ? "\(minimumText)°" : "\(minimumText) - \(maximumText)°"
    }

}

fileprivate struct SecurityContext {
    let entityBox: HAEntityState
    let isIssue: Bool
    let issueKind: SecurityIssueKind
    let detail: String?
}

private struct SecuritySummaryStatus {
    let value: String
    let isActive: Bool
}

fileprivate enum SecurityIssueKind {
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
