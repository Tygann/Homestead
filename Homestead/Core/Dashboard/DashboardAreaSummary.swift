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
    let domainChips: [DashboardAreaDomainChip]

    var topDomains: [EntityDomain] {
        domainChips.map(\.domain)
    }

    var resolvedIcon: ResolvedIcon {
        IconResolver.resolveArea(AreaIconResolutionInput(name: name, registryIcon: icon))
    }

    var systemImage: String { resolvedIcon.sfSymbolName }
}

struct DashboardAreaDomainChip: Hashable, Sendable {
    let domain: EntityDomain
    let isActive: Bool
    let family: DashboardAreaDomainChipFamily

    var displayName: String { family.displayName }
    var systemImage: String { family.systemImage }
}

enum DashboardAreaDomainChipFamily: Hashable, Sendable {
    case lights
    case climate
    case security
    case media
    case maintenance

    var displayName: String {
        switch self {
        case .lights:
            "Lights"
        case .climate:
            "Climate"
        case .security:
            "Security"
        case .media:
            "Media"
        case .maintenance:
            "Maintenance"
        }
    }

    var systemImage: String {
        switch self {
        case .lights:
            DashboardSummaryKind.lights.systemImage
        case .climate:
            DashboardSummaryKind.climate.systemImage
        case .security:
            DashboardSummaryKind.security.systemImage
        case .media:
            DashboardSummaryKind.media.systemImage
        case .maintenance:
            DashboardSummaryKind.maintenance.systemImage
        }
    }

    var sortPriority: Int {
        switch self {
        case .lights:
            0
        case .climate:
            1
        case .security:
            2
        case .media:
            3
        case .maintenance:
            4
        }
    }
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
