import SwiftUI

struct AreaDetailView: View {
    let area: DashboardAreaSummary
    @Environment(HAStateStore.self) private var stateStore

    private var entityBoxes: [HAEntityState] {
        area.entityIDs.compactMap { stateStore.entityBox(for: $0) }
    }

    private var currentArea: DashboardAreaSummary {
        DashboardAreaBuilder.buildArea(named: area.name, from: entityBoxes)
    }

    private var sections: [AreaDomainSection] {
        let grouped = Dictionary(grouping: entityBoxes, by: \.domain)

        return grouped
            .map { domain, entityBoxes in
                AreaDomainSection(
                    domain: domain,
                    entityIDs: entityBoxes
                        .sorted {
                            $0.homeEntity.displayName.localizedCaseInsensitiveCompare($1.homeEntity.displayName) == .orderedAscending
                        }
                        .map(\.entityID),
                    activeCount: entityBoxes
                        .map(DashboardEntityPresentation.init(entityBox:))
                        .filter(\.isActive)
                        .count,
                    unavailableCount: entityBoxes.filter { !$0.homeEntity.isAvailable }.count
                )
            }
            .sorted { lhs, rhs in
                lhs.domain.dashboardPriority < rhs.domain.dashboardPriority
            }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                AreaOverviewCard(area: currentArea)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        AreaSectionHeader(section: section)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 158), spacing: AppSpacing.medium)],
                            spacing: AppSpacing.medium
                        ) {
                            ForEach(section.entityIDs, id: \.self) { entityID in
                                DashboardCardView(entityID: entityID, size: .compact)
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
}

private struct AreaDomainSection: Identifiable {
    let domain: EntityDomain
    let entityIDs: [String]
    let activeCount: Int
    let unavailableCount: Int

    var id: EntityDomain { domain }

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
    let section: AreaDomainSection

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Image(systemName: section.domain.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(section.domain.displayName)
                    .font(.headline)

                Text(section.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.medium)
        }
    }
}
