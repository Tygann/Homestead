import SwiftUI

enum DashboardAddItemMode: String, CaseIterable, Identifiable {
    case cards = "Cards"
    case chips = "Chips"

    var id: Self { self }
}

enum DashboardAddChipCategory: Hashable, Identifiable {
    case all
    case summary
    case domain(EntityDomain)

    var id: String {
        switch self {
        case .all:
            "all"
        case .summary:
            "summary"
        case .domain(let domain):
            domain.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .summary:
            "Summary"
        case .domain(let domain):
            domain.displayName
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "square.grid.2x2"
        case .summary:
            "chart.bar.doc.horizontal"
        case .domain(let domain):
            domain.systemImage
        }
    }
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
