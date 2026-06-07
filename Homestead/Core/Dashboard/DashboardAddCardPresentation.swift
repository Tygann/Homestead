import Foundation

enum DashboardAddCardCategory: Hashable, Identifiable, Sendable {
    case all
    case style(DashboardEntityCardStyle)

    var id: String {
        switch self {
        case .all:
            "all"
        case .style(let style):
            style.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .style(let style):
            style.addCardTitle
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "square.grid.2x2"
        case .style(let style):
            style.addCardSystemImage
        }
    }
}

struct DashboardAddCardCandidate: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let domain: EntityDomain
    let iconName: String
    let cardStyle: DashboardEntityCardStyle
    let recommendedSize: DashboardCardSize

    var id: String { entityID }
}

struct DashboardAddCardCandidateGroup: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let candidates: [DashboardAddCardCandidate]
}

struct DashboardAddCardSizeChoice: Identifiable, Equatable, Sendable {
    let size: DashboardCardSize
    let isRecommended: Bool
    let summary: String
    let featureTitles: [String]

    var id: DashboardCardSize { size }
}

enum DashboardAddCardPresentation {
    @MainActor
    static func makeCategories(from candidates: [DashboardAddCardCandidate]) -> [DashboardAddCardCategory] {
        let styles = Set(candidates.map(\.cardStyle))
        let styleCategories = DashboardEntityCardStyle.addCardOrder
            .filter { styles.contains($0) }
            .map(DashboardAddCardCategory.style)

        return [.all] + styleCategories
    }

    @MainActor
    static func makeCandidateGroups(
        entityBoxes: [HAEntityState],
        configuredEntityIDs: Set<String>,
        deviceGroups: [EntityDeviceGroup],
        domainGroups: [EntityDomainGroup],
        displayNameForDeviceGroupedEntity: (String) -> String?,
        category: DashboardAddCardCategory,
        searchText: String,
        includesUnavailable: Bool
    ) -> [DashboardAddCardCandidateGroup] {
        let candidatesByEntityID = Dictionary(
            uniqueKeysWithValues: entityBoxes.compactMap { entityBox -> (String, DashboardAddCardCandidate)? in
                guard !configuredEntityIDs.contains(entityBox.entityID),
                      includesUnavailable || entityBox.homeEntity.isAvailable else {
                    return nil
                }

                let displayName = displayNameForDeviceGroupedEntity(entityBox.entityID)
                    ?? entityBox.homeEntity.displayName
                let presentation = DashboardEntityPresentation(entityBox: entityBox)
                let recommendedSize = DashboardCardSize.compactOrSquareForAvailableFeatures(entityBox: entityBox)
                let candidate = DashboardAddCardCandidate(
                    entityID: entityBox.entityID,
                    displayName: displayName,
                    state: entityBox.homeEntity.state,
                    domain: entityBox.domain,
                    iconName: entityBox.homeEntity.iconName,
                    cardStyle: presentation.cardStyle,
                    recommendedSize: recommendedSize
                )

                return (entityBox.entityID, candidate)
            })

        let sourceGroups = makeSourceGroups(deviceGroups: deviceGroups, domainGroups: domainGroups)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return sourceGroups.compactMap { sourceGroup in
            let candidates = sourceGroup.entityIDs
                .compactMap { candidatesByEntityID[$0] }
                .filter { category.matches($0) }
                .filter { candidate in
                    guard !query.isEmpty else {
                        return true
                    }

                    return sourceGroup.title.localizedCaseInsensitiveContains(query) ||
                        candidate.displayName.localizedCaseInsensitiveContains(query) ||
                        candidate.entityID.localizedCaseInsensitiveContains(query) ||
                        candidate.state.localizedCaseInsensitiveContains(query) ||
                        candidate.domain.displayName.localizedCaseInsensitiveContains(query) ||
                        candidate.cardStyle.addCardTitle.localizedCaseInsensitiveContains(query)
                }

            guard !candidates.isEmpty else {
                return nil
            }

            return DashboardAddCardCandidateGroup(
                id: sourceGroup.id,
                title: sourceGroup.title,
                systemImage: sourceGroup.systemImage,
                candidates: candidates
            )
        }
    }

    private static func makeSourceGroups(
        deviceGroups: [EntityDeviceGroup],
        domainGroups: [EntityDomainGroup]
    ) -> [DashboardAddCardSourceGroup] {
        if !deviceGroups.isEmpty {
            return deviceGroups.map { group in
                DashboardAddCardSourceGroup(
                    id: "card-device-\(group.id)",
                    title: group.title,
                    systemImage: "laptopcomputer.and.iphone",
                    entityIDs: group.entityIDs
                )
            }
        }

        return domainGroups.map { group in
            DashboardAddCardSourceGroup(
                id: "card-type-\(group.domain.rawValue)",
                title: group.domain.displayName,
                systemImage: group.domain.systemImage,
                entityIDs: group.entityIDs
            )
        }
    }

    @MainActor
    static func makeSizeChoices(for entityBox: HAEntityState) -> [DashboardAddCardSizeChoice] {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let features = DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation)
        let recommendedSize = DashboardCardSize.compactOrSquareForAvailableFeatures(entityBox: entityBox)

        return DashboardCardSize.allCases.map { size in
            let visibleFeatures = size.visibleFeatures(from: features)
            return DashboardAddCardSizeChoice(
                size: size,
                isRecommended: size == recommendedSize,
                summary: summary(
                    for: size,
                    entityBox: entityBox,
                    presentation: presentation,
                    visibleFeatures: visibleFeatures
                ),
                featureTitles: visibleFeatures.map(\.title)
            )
        }
    }

    private static func summary(
        for size: DashboardCardSize,
        entityBox: HAEntityState,
        presentation: DashboardEntityPresentation,
        visibleFeatures: [DashboardCardFeature]
    ) -> String {
        if DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: size) {
            return "Shows a 6-hour trend chart."
        }

        if presentation.capability.domain == .camera, size.usesCameraPreviewCard {
            return "Shows a live camera-style preview."
        }

        if !visibleFeatures.isEmpty {
            return "Includes \(featureSummary(from: visibleFeatures))."
        }

        switch size {
        case .mini:
            return "Shows an icon-only glance."
        case .compact:
            return "Shows name and current state."
        case .row:
            return "Shows a full-width status row."
        case .square:
            return "Shows expanded status details."
        case .wide:
            return "Shows expanded status and metrics."
        case .large:
            return "Shows the richest status and metrics."
        }
    }

    private static func featureSummary(from features: [DashboardCardFeature]) -> String {
        let titles = features.map(\.title)
        guard let firstTitle = titles.first else {
            return "inline controls"
        }

        if titles.count == 1 {
            return "\(firstTitle.lowercased()) controls"
        }

        let remainingTitles = titles.dropFirst().map { $0.lowercased() }
        return ([firstTitle.lowercased()] + remainingTitles).joined(separator: " and ") + " controls"
    }
}

private struct DashboardAddCardSourceGroup {
    let id: String
    let title: String
    let systemImage: String
    let entityIDs: [String]
}

private extension DashboardAddCardCategory {
    func matches(_ candidate: DashboardAddCardCandidate) -> Bool {
        switch self {
        case .all:
            true
        case .style(let style):
            candidate.cardStyle == style
        }
    }
}

extension DashboardCardSize {
    var usesCameraPreviewCard: Bool {
        switch self {
        case .square, .wide, .large:
            true
        case .mini, .compact, .row:
            false
        }
    }
}

extension DashboardEntityCardStyle {
    static var addCardOrder: [DashboardEntityCardStyle] {
        [.control, .value, .status, .media, .camera, .action, .generic]
    }

    var addCardTitle: String {
        switch self {
        case .control:
            "Controls"
        case .value:
            "Values"
        case .status:
            "Status"
        case .media:
            "Media"
        case .camera:
            "Cameras"
        case .action:
            "Actions"
        case .generic:
            "Other"
        }
    }

    var addCardSingularTitle: String {
        switch self {
        case .control:
            "Control card"
        case .value:
            "Value card"
        case .status:
            "Status card"
        case .media:
            "Media card"
        case .camera:
            "Camera card"
        case .action:
            "Action card"
        case .generic:
            "Generic card"
        }
    }

    var addCardSystemImage: String {
        switch self {
        case .control:
            "switch.2"
        case .value:
            "gauge.with.dots.needle.33percent"
        case .status:
            "circle.lefthalf.filled"
        case .media:
            "play.tv.fill"
        case .camera:
            "camera.fill"
        case .action:
            "sparkles"
        case .generic:
            "square.grid.2x2"
        }
    }
}
