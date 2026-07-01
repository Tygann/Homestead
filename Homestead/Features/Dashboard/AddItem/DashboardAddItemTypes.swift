import SwiftUI

enum DashboardAddItemMode: String, CaseIterable, Identifiable {
    case items = "Items"
    case cards = "Cards"

    var id: Self { self }
}

enum DashboardAddSource: Hashable, Identifiable {
    case entity(String)
    case summary(DashboardSummaryKind)

    var id: String {
        switch self {
        case .entity(let entityID): "entity-\(entityID)"
        case .summary(let kind): "summary-\(kind.rawValue)"
        }
    }

    var reference: DashboardSourceReference {
        switch self {
        case .entity(let entityID): .entity(entityID)
        case .summary(let kind): .summary(kind)
        }
    }
}

enum DashboardAddRoute: Hashable {
    case styles(DashboardAddSource)
    case sources(DashboardPresentationKind)
    case options(DashboardAddSource, DashboardPresentationKind)
}

struct DashboardAddSummaryCandidate: Identifiable, Equatable {
    let kind: DashboardSummaryKind
    let title: String
    let value: String
    let systemImage: String

    var id: DashboardSummaryKind { kind }
}

struct DashboardAddEntityCandidate: Identifiable, Equatable {
    let entityID: String
    let displayName: String
    let state: String
    let domain: EntityDomain
    let icon: ResolvedIcon

    var id: String { entityID }
    var iconName: String { icon.sfSymbolName }
}

struct DashboardAddEntityCandidateGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let candidates: [DashboardAddEntityCandidate]
}

extension DashboardCardSize {
    var chooserTitle: String {
        switch self {
        case .mini:
            "Mini"
        case .compact:
            "Compact"
        case .row:
            "Row"
        case .square:
            "Square"
        case .wide:
            "Wide"
        case .large:
            "Large"
        }
    }
}
