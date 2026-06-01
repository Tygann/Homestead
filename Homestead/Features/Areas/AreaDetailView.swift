import SwiftUI

struct AreaDetailView: View {
    let area: DashboardAreaSummary
    @Environment(HAStateStore.self) private var stateStore

    @MainActor private var entityBoxes: [HAEntityState] {
        area.entityIDs.compactMap { stateStore.entityBox(for: $0) }
    }

    @MainActor private var currentArea: DashboardAreaSummary {
        DashboardAreaBuilder.buildArea(named: area.name, from: entityBoxes)
    }

    @MainActor private var sections: [AreaEntitySection] {
        var categorizedEntityIDs = Set<String>()

        let summarySections = DashboardSummaryKind.areaSectionOrder.compactMap { kind -> AreaEntitySection? in
            guard let detail = DashboardSummaryProvider.makeDetail(
                kind: kind,
                entityBoxes: entityBoxes,
                preferredClimateReadingEntityIDs: stateStore.preferredClimateReadingEntityIDs(),
                nonPrimaryEntityIDs: stateStore.nonPrimaryEntityIDs(),
                diagnosticEntityIDs: stateStore.diagnosticEntityIDs()
            ) else {
                return nil
            }

            let entityIDs = detail.sections.flatMap { section in
                section.items.map(\.entityID)
            }
            guard !entityIDs.isEmpty else {
                return nil
            }

            categorizedEntityIDs.formUnion(entityIDs)
            return makeSection(
                id: "summary-\(kind.rawValue)",
                title: kind.areaSectionTitle,
                systemImage: kind.systemImage,
                entityBoxes: entityBoxes(for: entityIDs)
            )
        }

        let remainingEntityBoxes = entityBoxes.filter { !categorizedEntityIDs.contains($0.entityID) }
        let grouped = Dictionary(grouping: remainingEntityBoxes, by: \.domain)
        let domainSections = grouped
            .map { domain, entityBoxes in
                makeSection(
                    id: "domain-\(domain.rawValue)",
                    title: domain.displayName,
                    systemImage: domain.systemImage,
                    entityBoxes: entityBoxes.sorted(by: displayNameAscending)
                )
            }
            .sorted { lhs, rhs in
                lhs.sortPriority < rhs.sortPriority
            }

        return summarySections + domainSections
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                AreaOverviewCard(area: currentArea)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AreaSectionHeader(section: section)

                        CardGrid {
                            ForEach(section.entityIDs, id: \.self) { entityID in
                                let entityBox = stateStore.entityBox(for: entityID)
                                let size = entityBox.map(DashboardCardSize.compactOrSquareForAvailableFeatures) ?? .compact

                                DashboardCardView(
                                    entityID: entityID,
                                    size: size,
                                    contextualAreaName: area.name
                                )
                                .cardGridSpan(size.layoutMetadata)
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
    }

    private func entityBoxes(for entityIDs: [String]) -> [HAEntityState] {
        let boxesByID = Dictionary(uniqueKeysWithValues: entityBoxes.map { ($0.entityID, $0) })
        return entityIDs.compactMap { boxesByID[$0] }
    }

    private func makeSection(
        id: String,
        title: String,
        systemImage: String,
        entityBoxes: [HAEntityState]
    ) -> AreaEntitySection {
        AreaEntitySection(
            id: id,
            title: title,
            systemImage: systemImage,
            entityIDs: entityBoxes
                .sorted(by: displayNameAscending)
                .map(\.entityID),
            activeCount: entityBoxes
                .map { DashboardEntityPresentation(entityBox: $0) }
                .filter(\.isActive)
                .count,
            unavailableCount: entityBoxes.filter { !$0.homeEntity.isAvailable }.count,
            sortPriority: entityBoxes
                .map(\.domain.dashboardPriority)
                .min() ?? EntityDomain.other.dashboardPriority
        )
    }

    private func displayNameAscending(_ lhs: HAEntityState, _ rhs: HAEntityState) -> Bool {
        lhs.homeEntity.displayName.localizedCaseInsensitiveCompare(rhs.homeEntity.displayName) == .orderedAscending
    }
}

private struct AreaEntitySection: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let entityIDs: [String]
    let activeCount: Int
    let unavailableCount: Int
    let sortPriority: Int

    var subtitle: String {
        var parts = ["\(entityIDs.count) \(entityIDs.count == 1 ? "entity" : "entities")"]

        if activeCount > 0 {
            parts.append("\(activeCount) active")
        }

        if unavailableCount > 0 {
            parts.append("\(unavailableCount) unavailable")
        }

        return parts.joined(separator: " • ")
    }
}

private struct AreaOverviewCard: View {
    let area: DashboardAreaSummary

    var body: some View {
        CardContainer(isActive: area.activeCount > 0, minHeight: 116) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .center, spacing: AppSpacing.medium) {
                    CardIconView(systemName: area.systemImage, isActive: area.activeCount > 0)

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(area.name)
                            .font(.title3.weight(.semibold))

                        Text(area.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: AppSpacing.small)],
                    alignment: .leading,
                    spacing: AppSpacing.small
                ) {
                    AreaMetricPill(title: area.entityCountText, systemImage: "circle.grid.2x2")

                    if area.activeCount > 0 {
                        AreaMetricPill(title: "\(area.activeCount) active", systemImage: "bolt.fill")
                    }

                    if area.unavailableCount > 0 {
                        AreaMetricPill(title: "\(area.unavailableCount) unavailable", systemImage: "exclamationmark.triangle.fill")
                    }
                }
            }
        }
    }
}

private struct AreaMetricPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
    }
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

                Text(section.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.medium)
        }
    }
}

private extension DashboardSummaryKind {
    var areaSectionTitle: String {
        switch canonicalKind {
        case .media:
            "Media Players"
        default:
            title
        }
    }
}
