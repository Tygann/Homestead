import Foundation

@MainActor
enum DashboardAreaBuilder {
    nonisolated static let unassignedAreaName = "Unassigned"

    static func buildAreas(
        from entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String? = { _ in nil },
        membershipContext: DashboardSummaryMembershipContext = .empty
    ) -> [DashboardAreaSummary] {
        buildAreas(
            from: entityBoxes,
            areaContextForEntityID: { entityID in
                areaNameForEntityID(entityID).map {
                    DashboardAreaContext(
                        areaID: $0,
                        name: $0,
                        icon: nil,
                        floorID: nil,
                        floorName: nil,
                        floorLevel: nil,
                        floorSortOrder: nil
                    )
                }
            },
            membershipContext: membershipContext
        )
    }

    static func buildAreas(
        from entityBoxes: [HAEntityState],
        areaContextForEntityID: (String) -> DashboardAreaContext?,
        membershipContext: DashboardSummaryMembershipContext = .empty
    ) -> [DashboardAreaSummary] {
        let grouped = Dictionary(grouping: entityBoxes) { entityBox in
            areaGroupKey(for: areaContextForEntityID(entityBox.entityID))
        }

        return grouped
            .map { key, entityBoxes in
                buildArea(key: key, from: entityBoxes, membershipContext: membershipContext)
            }
            .sorted { lhs, rhs in
                areaNameAscending(lhs.name, rhs.name)
            }
    }

    static func buildArea(
        named areaName: String,
        from entityBoxes: [HAEntityState],
        membershipContext: DashboardSummaryMembershipContext = .empty
    ) -> DashboardAreaSummary {
        buildArea(
            key: AreaGroupKey(
                areaID: areaName,
                name: areaName,
                icon: nil,
                floorID: nil,
                floorName: nil,
                floorLevel: nil,
                floorSortOrder: nil
            ),
            from: entityBoxes,
            membershipContext: membershipContext
        )
    }

    static func buildSections(from areas: [DashboardAreaSummary]) -> [DashboardAreaSection] {
        let floorGroups = Dictionary(grouping: areas.filter { $0.floorName != nil }) { area in
            FloorGroupKey(
                floorID: area.floorID,
                floorName: area.floorName ?? "",
                floorLevel: area.floorLevel,
                floorSortOrder: area.floorSortOrder
            )
        }
        let floorSections = floorGroups
            .map { key, areas in
                DashboardAreaSection(
                    id: key.id,
                    title: key.floorName,
                    areas: areas.sorted(by: areaAscending)
                )
            }
            .sorted(by: sectionAscending)
        let otherAreas = areas
            .filter { $0.floorName == nil }
            .sorted(by: areaAscending)

        guard floorSections.count > 1 || (floorSections.count == 1 && !otherAreas.isEmpty) else {
            return [
                DashboardAreaSection(
                    id: "all",
                    title: nil,
                    areas: areas.sorted(by: areaAscending)
                )
            ]
        }

        if otherAreas.isEmpty {
            return floorSections
        }

        return floorSections + [
            DashboardAreaSection(
                id: "other",
                title: "Unassigned",
                areas: otherAreas
            )
        ]
    }

    private static func buildArea(
        key: AreaGroupKey,
        from entityBoxes: [HAEntityState],
        membershipContext: DashboardSummaryMembershipContext
    ) -> DashboardAreaSummary {
        let presentations = entityBoxes.map { DashboardEntityPresentation(entityBox: $0) }
        let activeDomainCounts = Dictionary(grouping: presentations.filter(\.isActive), by: \.capability.domain)
            .mapValues(\.count)

        return DashboardAreaSummary(
            id: key.areaID.map { "area-\($0)" } ?? "unassigned",
            areaID: key.areaID,
            name: key.name,
            icon: key.icon,
            floorID: key.floorID,
            floorName: key.floorName,
            floorLevel: key.floorLevel,
            floorSortOrder: key.floorSortOrder,
            entityIDs: entityBoxes
                .sorted { lhs, rhs in
                    lhs.homeEntity.displayName.localizedCaseInsensitiveCompare(rhs.homeEntity.displayName) == .orderedAscending
                }
                .map(\.entityID),
            activeCount: presentations
                .filter(\.isActive)
                .count,
            unavailableCount: entityBoxes.filter { !$0.homeEntity.isAvailable }.count,
            domainCounts: Dictionary(grouping: entityBoxes, by: \.domain)
                .mapValues(\.count),
            activeDomainCounts: activeDomainCounts,
            domainChips: makeDomainChips(
                from: Array(zip(entityBoxes, presentations)),
                membershipContext: membershipContext
            )
        )
    }

    private static func makeDomainChips(
        from entityPresentations: [(HAEntityState, DashboardEntityPresentation)],
        membershipContext: DashboardSummaryMembershipContext
    ) -> [DashboardAreaDomainChip] {
        let activeEntitiesByFamily = Dictionary(grouping: entityPresentations.filter { _, presentation in
            presentation.isActive
        }.compactMap { entityBox, presentation -> (DashboardAreaDomainChipFamily, EntityDomain)? in
            guard let family = domainChipFamily(for: entityBox, membershipContext: membershipContext) else {
                return nil
            }

            return (family, presentation.capability.domain)
        }, by: \.0)

        return activeEntitiesByFamily
            .map { family, entries in
                let domain = entries
                    .map(\.1)
                    .min { $0.dashboardPriority < $1.dashboardPriority } ?? .other
                return DashboardAreaDomainChip(domain: domain, isActive: true, family: family)
            }
            .sorted { lhs, rhs in
                lhs.family.sortPriority < rhs.family.sortPriority
            }
    }

    private static func domainChipFamily(
        for entityBox: HAEntityState,
        membershipContext: DashboardSummaryMembershipContext
    ) -> DashboardAreaDomainChipFamily? {
        if HomeAssistantSummaryClassifier.contains(entityBox, in: .lights, context: membershipContext) {
            return .lights
        }

        if HomeAssistantSummaryClassifier.contains(entityBox, in: .climate, context: membershipContext) {
            return .climate
        }

        if HomeAssistantSummaryClassifier.contains(entityBox, in: .security, context: membershipContext) {
            return .security
        }

        if entityBox.domain == .remote ||
            HomeAssistantSummaryClassifier.contains(entityBox, in: .media, context: membershipContext) {
            return .media
        }

        if HomeAssistantSummaryClassifier.contains(entityBox, in: .maintenance, context: membershipContext) {
            return .maintenance
        }

        return nil
    }

    private static func areaGroupKey(for context: DashboardAreaContext?) -> AreaGroupKey {
        guard let context else {
            return unassignedAreaGroupKey()
        }

        guard let areaID = context.areaID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyValue,
              let name = context.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyValue else {
            return unassignedAreaGroupKey()
        }

        let floorName = context.floorName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyValue

        return AreaGroupKey(
            areaID: areaID,
            name: name,
            icon: context.icon?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyValue,
            floorID: floorName == nil ? nil : context.floorID,
            floorName: floorName,
            floorLevel: floorName == nil ? nil : context.floorLevel,
            floorSortOrder: floorName == nil ? nil : context.floorSortOrder
        )
    }

    private static func unassignedAreaGroupKey() -> AreaGroupKey {
        AreaGroupKey(
            areaID: nil,
            name: unassignedAreaName,
            icon: nil,
            floorID: nil,
            floorName: nil,
            floorLevel: nil,
            floorSortOrder: nil
        )
    }

    private static func areaAscending(_ lhs: DashboardAreaSummary, _ rhs: DashboardAreaSummary) -> Bool {
        areaNameAscending(lhs.name, rhs.name)
    }

    private static func areaNameAscending(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private static func sectionAscending(_ lhs: DashboardAreaSection, _ rhs: DashboardAreaSection) -> Bool {
        let lhsArea = lhs.areas.first
        let rhsArea = rhs.areas.first

        switch (lhsArea?.floorSortOrder, rhsArea?.floorSortOrder) {
        case let (lhsOrder?, rhsOrder?) where lhsOrder != rhsOrder:
            return lhsOrder < rhsOrder
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }

        switch (lhsArea?.floorLevel, rhsArea?.floorLevel) {
        case let (lhsLevel?, rhsLevel?) where lhsLevel != rhsLevel:
            return lhsLevel < rhsLevel
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }

        return (lhs.title ?? "").localizedCaseInsensitiveCompare(rhs.title ?? "") == .orderedAscending
    }

}

private struct AreaGroupKey: Hashable {
    let areaID: String?
    let name: String
    let icon: String?
    let floorID: String?
    let floorName: String?
    let floorLevel: Int?
    let floorSortOrder: Int?
}

private struct FloorGroupKey: Hashable {
    let floorID: String?
    let floorName: String
    let floorLevel: Int?
    let floorSortOrder: Int?

    var id: String {
        floorID.map { "floor-\($0)" } ?? "floor-\(floorName)"
    }
}

private extension String {
    var nonEmptyValue: String? {
        isEmpty ? nil : self
    }
}
