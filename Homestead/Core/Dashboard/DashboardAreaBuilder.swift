import Foundation

@MainActor
enum DashboardAreaBuilder {
    static func buildAreas(
        from entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String? = { _ in nil }
    ) -> [DashboardAreaSummary] {
        buildAreas(
            from: entityBoxes,
            areaContextForEntityID: { entityID in
                areaNameForEntityID(entityID).map {
                    DashboardAreaContext(
                        areaID: $0,
                        name: $0,
                        floorID: nil,
                        floorName: nil,
                        floorLevel: nil,
                        floorSortOrder: nil
                    )
                }
            }
        )
    }

    static func buildAreas(
        from entityBoxes: [HAEntityState],
        areaContextForEntityID: (String) -> DashboardAreaContext?
    ) -> [DashboardAreaSummary] {
        let grouped = Dictionary(grouping: entityBoxes) { entityBox in
            areaGroupKey(for: areaContextForEntityID(entityBox.entityID))
        }

        return grouped
            .map { key, entityBoxes in
                buildArea(key: key, from: entityBoxes)
            }
            .sorted { lhs, rhs in
                areaNameAscending(lhs.name, rhs.name)
            }
    }

    static func buildArea(
        named areaName: String,
        from entityBoxes: [HAEntityState]
    ) -> DashboardAreaSummary {
        buildArea(
            key: AreaGroupKey(
                areaID: areaName,
                name: areaName,
                floorID: nil,
                floorName: nil,
                floorLevel: nil,
                floorSortOrder: nil
            ),
            from: entityBoxes
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
                title: "Other Areas",
                areas: otherAreas
            )
        ]
    }

    private static func buildArea(
        key: AreaGroupKey,
        from entityBoxes: [HAEntityState]
    ) -> DashboardAreaSummary {
        DashboardAreaSummary(
            id: key.areaID.map { "area-\($0)" } ?? "unassigned",
            areaID: key.areaID,
            name: key.name,
            floorID: key.floorID,
            floorName: key.floorName,
            floorLevel: key.floorLevel,
            floorSortOrder: key.floorSortOrder,
            entityIDs: entityBoxes
                .sorted { lhs, rhs in
                    lhs.homeEntity.displayName.localizedCaseInsensitiveCompare(rhs.homeEntity.displayName) == .orderedAscending
                }
                .map(\.entityID),
            activeCount: entityBoxes
                .map { DashboardEntityPresentation(entityBox: $0) }
                .filter(\.isActive)
                .count,
            unavailableCount: entityBoxes.filter { !$0.homeEntity.isAvailable }.count,
            domainCounts: Dictionary(grouping: entityBoxes, by: \.domain)
                .mapValues(\.count)
        )
    }

    private static func areaGroupKey(for context: DashboardAreaContext?) -> AreaGroupKey {
        guard let context else {
            return AreaGroupKey(
                areaID: nil,
                name: "Unassigned",
                floorID: nil,
                floorName: nil,
                floorLevel: nil,
                floorSortOrder: nil
            )
        }

        let name = context.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyValue ?? "Unassigned"
        let floorName = context.floorName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyValue

        return AreaGroupKey(
            areaID: context.areaID,
            name: name,
            floorID: floorName == nil ? nil : context.floorID,
            floorName: floorName,
            floorLevel: floorName == nil ? nil : context.floorLevel,
            floorSortOrder: floorName == nil ? nil : context.floorSortOrder
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
