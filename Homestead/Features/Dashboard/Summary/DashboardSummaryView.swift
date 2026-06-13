import SwiftUI

struct DashboardSummaryView: View {
    @Environment(HAStateStore.self) private var stateStore
    @State private var selectedEntityDetailRoute: DashboardEntityDetailRoute?
    @Namespace private var cardTransitionNamespace

    let kind: DashboardSummaryKind
    let titleOverride: String?
    let iconNameOverride: String?

    init(
        kind: DashboardSummaryKind,
        titleOverride: String? = nil,
        iconNameOverride: String? = nil
    ) {
        self.kind = kind
        self.titleOverride = titleOverride
        self.iconNameOverride = iconNameOverride
    }

    var body: some View {
        let detail = DashboardSummaryProvider.makeDetail(
            kind: kind,
            entityBoxes: stateStore.allEntityBoxes(),
            titleOverride: titleOverride,
            iconNameOverride: iconNameOverride,
            membershipContext: stateStore.dashboardSummaryMembershipContext(),
            areaNameForEntityID: stateStore.areaName(for:)
        )

        Group {
            if let detail {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        DashboardSummaryHeader(presentation: detail.summary)

                        ForEach(detail.sections) { section in
                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                Text(section.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                CardGrid {
                                    ForEach(section.items) { item in
                                        let entityBox = stateStore.entityBox(for: item.entityID)
                                        let size = cardSize(for: entityBox)

                                        DashboardCardView(
                                            entityID: item.entityID,
                                            size: size,
                                            contextualAreaName: section.title,
                                            openDetails: {
                                                selectedEntityDetailRoute = DashboardEntityDetailRoute(
                                                    entityID: item.entityID,
                                                    sourceID: cardTransitionID(for: item)
                                                )
                                            }
                                        )
                                        .cardGridSpan(size.layoutMetadata)
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
            } else {
                ContentUnavailableView("No Summary Available", systemImage: kind.systemImage)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(detail?.summary.title ?? kind.title)
        .toolbarTitleDisplayMode(.inline)
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

    @MainActor
    private func cardSize(for entityBox: HAEntityState?) -> DashboardCardSize {
        guard let entityBox else { return .compact }
        return DashboardCardSize.defaultGeneratedSize(entityBox: entityBox)
    }

    private func cardTransitionID(for item: DashboardSummaryEntityPresentation) -> String {
        "summary-\(kind.rawValue)-card-\(item.entityID)"
    }
}

private struct DashboardSummaryHeader: View {
    let presentation: DashboardChipPresentation

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Image(systemName: presentation.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 48)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(presentation.value)
                    .font(.headline)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: AppSpacing.small)
        }
        .padding(.vertical, AppSpacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.value)
    }

    private var iconColor: Color {
        guard presentation.isAvailable else { return .red }
        return presentation.isActive ? .accentColor : .secondary
    }

    private var valueColor: Color {
        guard presentation.isAvailable else { return .red }
        return presentation.isActive ? .primary : .secondary
    }

    private var iconBackground: Color {
        guard presentation.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }
}
