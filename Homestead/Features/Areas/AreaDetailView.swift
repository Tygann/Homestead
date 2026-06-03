import SwiftUI

struct AreaDetailView: View {
    let area: DashboardAreaSummary
    @Environment(HAStateStore.self) private var stateStore
    @State private var selectedEntityDetailRoute: DashboardEntityDetailRoute?
    @Namespace private var cardTransitionNamespace

    var body: some View {
        let presentation = AreaDetailPresentation.make(area: area, stateStore: stateStore)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                ForEach(presentation.sections) { section in
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AreaSectionHeader(section: section)

                        CardGrid {
                            ForEach(section.items) { item in
                                DashboardCardView(
                                    entityID: item.entityID,
                                    size: item.cardSize,
                                    contextualAreaName: area.name,
                                    openDetails: {
                                        selectedEntityDetailRoute = DashboardEntityDetailRoute(
                                            entityID: item.entityID,
                                            sourceID: cardTransitionID(for: item)
                                        )
                                    }
                                )
                                .cardGridSpan(item.cardSize.layoutMetadata)
                                .matchedTransitionSource(id: cardTransitionID(for: item), in: cardTransitionNamespace)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(area.name)
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationDestination(item: $selectedEntityDetailRoute) { route in
            if let entityBox = stateStore.entityBox(for: route.entityID) {
                EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation)
                    .navigationTransition(.zoom(sourceID: route.sourceID, in: cardTransitionNamespace))
            } else {
                ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                    .navigationTransition(.zoom(sourceID: route.sourceID, in: cardTransitionNamespace))
            }
        }
    }

    private func cardTransitionID(for item: AreaEntityItem) -> String {
        "area-\(area.id)-card-\(item.entityID)"
    }
}

private struct AreaDetailPresentation {
    let sections: [AreaEntitySection]

    @MainActor
    static func make(area: DashboardAreaSummary, stateStore: HAStateStore) -> AreaDetailPresentation {
        let entityBoxes = area.entityIDs.compactMap { stateStore.entityBox(for: $0) }
        let boxesByID = Dictionary(uniqueKeysWithValues: entityBoxes.map { ($0.entityID, $0) })
        let preferredClimateReadingEntityIDs = stateStore.preferredClimateReadingEntityIDs()
        let nonPrimaryEntityIDs = stateStore.nonPrimaryEntityIDs()
        let diagnosticEntityIDs = stateStore.diagnosticEntityIDs()
        var categorizedEntityIDs = Set<String>()

        let summarySections = DashboardSummaryKind.areaSectionOrder.compactMap { kind -> AreaEntitySection? in
            guard let detail = DashboardSummaryProvider.makeDetail(
                kind: kind,
                entityBoxes: entityBoxes,
                preferredClimateReadingEntityIDs: preferredClimateReadingEntityIDs,
                nonPrimaryEntityIDs: nonPrimaryEntityIDs,
                diagnosticEntityIDs: diagnosticEntityIDs
            ) else {
                return nil
            }

            let sectionEntityIDs = detail.sections.flatMap { section in
                section.items.map(\.entityID)
            }
            guard !sectionEntityIDs.isEmpty else {
                return nil
            }

            let sectionBoxes = sectionEntityIDs.compactMap { boxesByID[$0] }
            guard !sectionBoxes.isEmpty else {
                return nil
            }

            categorizedEntityIDs.formUnion(sectionEntityIDs)
            return makeSection(
                id: "summary-\(kind.rawValue)",
                title: kind.areaSectionTitle,
                systemImage: kind.systemImage,
                entityBoxes: sectionBoxes
            )
        }

        let remainingEntityBoxes = entityBoxes.filter { !categorizedEntityIDs.contains($0.entityID) }
        let domainSections = Dictionary(grouping: remainingEntityBoxes, by: \.domain)
            .map { domain, entityBoxes in
                makeSection(
                    id: "domain-\(domain.rawValue)",
                    title: domain.displayName,
                    systemImage: domain.systemImage,
                    entityBoxes: entityBoxes
                )
            }
            .sorted { lhs, rhs in
                lhs.sortPriority < rhs.sortPriority
            }

        return AreaDetailPresentation(sections: summarySections + domainSections)
    }

    @MainActor
    private static func makeSection(
        id: String,
        title: String,
        systemImage: String,
        entityBoxes: [HAEntityState]
    ) -> AreaEntitySection {
        let sortedEntityBoxes = entityBoxes.sorted(by: displayNameAscending)
        return AreaEntitySection(
            id: id,
            title: title,
            systemImage: systemImage,
            items: sortedEntityBoxes.map { entityBox in
                AreaEntityItem(
                    entityID: entityBox.entityID,
                    cardSize: DashboardCardSize.compactOrSquareForAvailableFeatures(entityBox: entityBox)
                )
            },
            sortPriority: entityBoxes
                .map(\.domain.dashboardPriority)
                .min() ?? EntityDomain.other.dashboardPriority
        )
    }

    private static func displayNameAscending(_ lhs: HAEntityState, _ rhs: HAEntityState) -> Bool {
        lhs.homeEntity.displayName.localizedCaseInsensitiveCompare(rhs.homeEntity.displayName) == .orderedAscending
    }
}

private struct AreaEntitySection: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let items: [AreaEntityItem]
    let sortPriority: Int
}

private struct AreaEntityItem: Identifiable {
    let entityID: String
    let cardSize: DashboardCardSize

    var id: String { entityID }
}

private struct AreaSectionHeader: View {
    let section: AreaEntitySection

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Image(systemName: section.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(section.title)
                    .font(.headline)
            }

            Spacer(minLength: AppSpacing.medium)
        }
    }
}

private extension DashboardSummaryKind {
    var areaSectionTitle: String {
        switch self {
        case .media:
            "Media Players"
        default:
            title
        }
    }
}
