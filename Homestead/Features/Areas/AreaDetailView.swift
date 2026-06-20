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
                                    featureVisibility: item.featureVisibility,
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
        .homesteadWallpaperBackground()
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
        let membershipContext = stateStore.dashboardSummaryMembershipContext()

        let sections = DashboardAreaDetailSectionProvider.makeSections(
            from: entityBoxes,
            membershipContext: membershipContext
        ).compactMap { section -> AreaEntitySection? in
            let sectionBoxes = section.entityIDs.compactMap { boxesByID[$0] }
            guard !sectionBoxes.isEmpty else {
                return nil
            }

            return makeSection(
                id: "area-\(section.id)",
                title: section.title,
                systemImage: section.systemImage,
                entityBoxes: sectionBoxes
            )
        }

        return AreaDetailPresentation(sections: sections)
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
                let cardSize = DashboardCardSize.defaultGeneratedSize(entityBox: entityBox)
                return AreaEntityItem(
                    entityID: entityBox.entityID,
                    cardSize: cardSize,
                    featureVisibility: DashboardCardSize.defaultGeneratedFeatureVisibility(
                        entityBox: entityBox,
                        size: cardSize
                    )
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
    let featureVisibility: DashboardCardFeatureVisibility

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
