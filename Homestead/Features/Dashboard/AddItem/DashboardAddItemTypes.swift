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
    case review(DashboardAddSource, DashboardPresentationKind)
    case header
}

enum DashboardAddGalleryItem: Identifiable {
    case presentation(DashboardPresentationDescriptor)
    case header
    case planned(DashboardPlannedGalleryCard)

    var id: String {
        switch self {
        case .presentation(let descriptor):
            "presentation-\(descriptor.kind.rawValue)"
        case .header:
            "header"
        case .planned(let card):
            "planned-\(card.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .presentation(let descriptor):
            descriptor.title
        case .header:
            "Header"
        case .planned(let card):
            card.title
        }
    }

    var isPlanned: Bool {
        if case .planned = self { return true }
        return false
    }
}

enum DashboardPlannedGalleryCard: String, CaseIterable, Identifiable {
    case calendar
    case map
    case picture
    case area
    case person
    case energy
    case text
    case spacer

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .calendar: "calendar"
        case .map: "map"
        case .picture: "photo"
        case .area: "square.grid.2x2"
        case .person: "person.crop.circle"
        case .energy: "bolt.fill"
        case .text: "textformat"
        case .spacer: "arrow.up.and.down"
        }
    }
}

enum DashboardAddGallerySection: String, CaseIterable, Identifiable {
    case elements = "Elements"
    case cards = "Cards"
    case planned = "Planned"

    var id: Self { self }

    var items: [DashboardAddGalleryItem] {
        switch self {
        case .elements:
            [
                .header,
                .presentation(DashboardPresentationCatalog.descriptor(for: .chip))
            ]
        case .cards:
            [
                .control,
                .status,
                .gauge,
                .graph,
                .camera,
                .weather,
                .media,
                .action
            ].map {
                .presentation(DashboardPresentationCatalog.descriptor(for: $0))
            }
        case .planned:
            DashboardPlannedGalleryCard.allCases.map(DashboardAddGalleryItem.planned)
        }
    }
}

enum DashboardAddGalleryCatalog {
    // Keep planned roadmap metadata easy to hide before a public release.
    static let showsPlannedCards = true

    static var sections: [DashboardAddGallerySection] {
        DashboardAddGallerySection.allCases.filter {
            showsPlannedCards || $0 != .planned
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
