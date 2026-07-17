import SwiftUI

enum DashboardAddItemMode: String, CaseIterable, Identifiable {
    case items = "Items"
    case cards = "Cards"

    var id: Self { self }
}

enum DashboardAddGalleryFilter: String, CaseIterable, Identifiable {
    case suggested = "Suggested"
    case all = "All"
    case controls = "Controls"
    case status = "Status"
    case sensors = "Sensors"
    case media = "Media"
    case actions = "Actions"
    case layout = "Layout"

    var id: Self { self }

    func matches(_ item: DashboardAddGalleryItem) -> Bool {
        guard let kind = item.presentationKind else {
            return self == .all || self == .layout
        }

        switch self {
        case .suggested:
            return item.isSuggested
        case .all:
            return true
        case .controls:
            return kind == .control
        case .status:
            return [.status, .chip].contains(kind)
        case .sensors:
            return [.gauge, .graph].contains(kind)
        case .media:
            return [.camera, .weather, .media].contains(kind)
        case .actions:
            return kind == .action
        case .layout:
            return false
        }
    }
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
    case configure(DashboardPresentationKind)
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

    var isSuggested: Bool {
        guard let kind = presentationKind else {
            if case .header = self { return true }
            return false
        }

        return [.control, .status, .gauge, .graph].contains(kind)
    }

    var presentationKind: DashboardPresentationKind? {
        guard case .presentation(let descriptor) = self else { return nil }
        return descriptor.kind
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
    // Roadmap concepts are debug-only metadata and stay out of production discovery.
    static let showsPlannedCards = false

    static var sections: [DashboardAddGallerySection] {
        var sections: [DashboardAddGallerySection] = [.elements, .cards]
#if DEBUG
        if showsPlannedCards {
            sections.append(.planned)
        }
#endif
        return sections
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
    let areaName: String?
    let deviceName: String?
    let icon: ResolvedIcon
    let suggestedPresentation: DashboardPresentationConfiguration

    var id: String { entityID }
    var iconName: String { icon.sfSymbolName }

    var searchableText: String {
        [entityID, displayName, state, domain.rawValue, areaName, deviceName]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

struct DashboardAddEntityCandidateGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let candidates: [DashboardAddEntityCandidate]
}

@MainActor
struct DashboardAddItemPresentation {
    let summaryCandidates: [DashboardAddSummaryCandidate]
    let entityGroups: [DashboardAddEntityCandidateGroup]

    static func make(stateStore: HAStateStore, searchText: String) -> Self {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspace = stateStore.dashboardSummaryWorkspace()
        let summaries = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            workspace: workspace
        )
        let summaryCandidates: [DashboardAddSummaryCandidate] = DashboardSummaryKind.allCases.compactMap { kind in
            guard let presentation = summaries[kind] else { return nil }
            let candidate = DashboardAddSummaryCandidate(
                kind: kind,
                title: presentation.title,
                value: presentation.value,
                systemImage: presentation.systemImage
            )
            guard query.isEmpty
                    || candidate.title.localizedCaseInsensitiveContains(query)
                    || candidate.value.localizedCaseInsensitiveContains(query) else {
                return nil
            }
            return candidate
        }

        let candidatesByID = Dictionary(uniqueKeysWithValues: workspace.entityBoxes.compactMap { entityBox -> (String, DashboardAddEntityCandidate)? in
            guard entityBox.homeEntity.isAvailable else { return nil }
            let candidate = DashboardAddEntityCandidate(
                entityID: entityBox.entityID,
                displayName: stateStore.displayNameForDeviceGroupedEntity(entityID: entityBox.entityID) ?? entityBox.homeEntity.displayName,
                state: entityBox.homeEntity.state,
                domain: entityBox.domain,
                areaName: stateStore.areaName(for: entityBox.entityID),
                deviceName: stateStore.entityRegistryMetadata(for: entityBox.entityID)?.deviceID
                    .flatMap { stateStore.deviceName(forDeviceID: $0) },
                icon: entityBox.homeEntity.resolvedIcon,
                suggestedPresentation: DashboardPresentationCatalog.recommendation(for: entityBox)
            )
            guard query.isEmpty || candidate.searchableText.localizedCaseInsensitiveContains(query) else {
                return nil
            }
            return (entityBox.entityID, candidate)
        })

        let entityGroups: [DashboardAddEntityCandidateGroup]
        if !stateStore.entityIDGroupsByDevice.isEmpty {
            entityGroups = stateStore.entityIDGroupsByDevice.compactMap { group in
                let candidates = group.entityIDs.compactMap { candidatesByID[$0] }
                guard !candidates.isEmpty else { return nil }
                return DashboardAddEntityCandidateGroup(
                    id: "item-device-\(group.id)",
                    title: group.title,
                    systemImage: "laptopcomputer.and.iphone",
                    candidates: candidates
                )
            }
        } else {
            entityGroups = stateStore.entityIDGroupsByDomain.compactMap { group in
                let candidates = group.entityIDs.compactMap { candidatesByID[$0] }
                guard !candidates.isEmpty else { return nil }
                return DashboardAddEntityCandidateGroup(
                    id: "item-domain-\(group.domain.rawValue)",
                    title: group.domain.displayName,
                    systemImage: group.domain.systemImage,
                    candidates: candidates
                )
            }
        }

        return Self(summaryCandidates: summaryCandidates, entityGroups: entityGroups)
    }
}
