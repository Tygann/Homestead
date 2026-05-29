import Foundation

@MainActor
enum DashboardAreaBuilder {
    static func buildAreas(
        from entityBoxes: [HAEntityState],
        areaNameForEntityID: (String) -> String? = { _ in nil }
    ) -> [DashboardAreaSummary] {
        let grouped = Dictionary(grouping: entityBoxes) { entityBox in
            areaNameForEntityID(entityBox.entityID)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmptyValue ?? "Unassigned"
        }

        return grouped
            .map { areaName, entityBoxes in
                buildArea(named: areaName, from: entityBoxes)
            }
            .sorted { lhs, rhs in
                lhs.name < rhs.name
            }
    }

    static func buildArea(
        named areaName: String,
        from entityBoxes: [HAEntityState]
    ) -> DashboardAreaSummary {
        DashboardAreaSummary(
            id: areaName,
            name: areaName,
            entityIDs: entityBoxes
                .map(\.entityID)
                .sorted { lhs, rhs in
                    displayName(for: lhs, in: entityBoxes)
                        .localizedCaseInsensitiveCompare(displayName(for: rhs, in: entityBoxes)) == .orderedAscending
                },
            activeCount: entityBoxes
                .map { DashboardEntityPresentation(entityBox: $0) }
                .filter(\.isActive)
                .count,
            unavailableCount: entityBoxes.filter { !$0.homeEntity.isAvailable }.count,
            domainCounts: Dictionary(grouping: entityBoxes, by: \.domain)
                .mapValues(\.count)
        )
    }

    private static func displayName(for entityID: String, in entityBoxes: [HAEntityState]) -> String {
        entityBoxes.first { $0.entityID == entityID }?.homeEntity.displayName ?? entityID
    }
}

private extension String {
    var nonEmptyValue: String? {
        isEmpty ? nil : self
    }
}
