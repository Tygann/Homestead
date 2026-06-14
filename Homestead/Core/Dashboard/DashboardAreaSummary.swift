import Foundation

struct DashboardAreaSummary: Identifiable, Hashable, Sendable {
    let id: String
    let areaID: String?
    let name: String
    let icon: String?
    let floorID: String?
    let floorName: String?
    let floorLevel: Int?
    let floorSortOrder: Int?
    let entityIDs: [String]
    let activeCount: Int
    let unavailableCount: Int
    let domainCounts: [EntityDomain: Int]
    let activeDomainCounts: [EntityDomain: Int]

    var topDomains: [EntityDomain] {
        domainChips.map(\.domain)
    }

    var domainChips: [DashboardAreaDomainChip] {
        domainCounts
            .filter { $0.value > 0 }
            .map(\.key)
            .sorted { lhs, rhs in
                let lhsIsActive = activeDomainCounts[lhs, default: 0] > 0
                let rhsIsActive = activeDomainCounts[rhs, default: 0] > 0
                if lhsIsActive != rhsIsActive {
                    return lhsIsActive
                }

                return lhs.dashboardPriority < rhs.dashboardPriority
            }
            .map { domain in
                DashboardAreaDomainChip(
                    domain: domain,
                    isActive: activeDomainCounts[domain, default: 0] > 0
                )
            }
    }

    var resolvedIcon: ResolvedIcon {
        IconResolver.resolveArea(AreaIconResolutionInput(name: name, registryIcon: icon))
    }

    var systemImage: String { resolvedIcon.sfSymbolName }
}

struct DashboardAreaDomainChip: Hashable, Sendable {
    let domain: EntityDomain
    let isActive: Bool
}

struct DashboardAreaContext: Hashable, Sendable {
    let areaID: String
    let name: String
    let icon: String?
    let floorID: String?
    let floorName: String?
    let floorLevel: Int?
    let floorSortOrder: Int?
}

struct DashboardAreaSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String?
    let areas: [DashboardAreaSummary]
}
