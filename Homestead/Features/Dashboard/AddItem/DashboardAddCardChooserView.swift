import SwiftUI

struct DashboardChooseStyleView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    let source: DashboardAddSource
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        List {
            Section {
                sourceHeader
            }

            Section {
                ForEach(compatibleKinds, id: \.self) { kind in
                    let presentation = defaultPresentation(for: kind)
                    let isRecommended = recommendation?.kind == kind
                    let isAdded = dashboardConfiguration.contains(
                        source: source.reference,
                        presentationKind: kind
                    )

                    HStack(spacing: AppSpacing.medium) {
                        NavigationLink(value: DashboardAddRoute.options(source, kind)) {
                            Label {
                                HStack(spacing: AppSpacing.small) {
                                    Text(DashboardPresentationCatalog.descriptor(for: kind).title)
                                    if isRecommended {
                                        Text("Suggested")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(Color.accentColor)
                                            .padding(.horizontal, AppSpacing.small)
                                            .frame(height: 22)
                                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                                    }
                                }
                            } icon: {
                                Image(systemName: DashboardPresentationCatalog.descriptor(for: kind).systemImage)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .accessibilityHint("Choose a layout")

                        Button {
                            guard let presentation else { return }
                            add(source, presentation)
                        } label: {
                            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(isAdded ? Color.secondary : Color.accentColor)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(isAdded || presentation == nil)
                        .accessibilityLabel(
                            isAdded
                                ? "\(DashboardPresentationCatalog.descriptor(for: kind).title) added"
                                : "Add \(DashboardPresentationCatalog.descriptor(for: kind).title)"
                        )
                        .accessibilityHint(isAdded ? "" : "Adds the default layout")
                    }
                }
            } header: {
                Text("Styles")
            }
        }
        .navigationTitle("Choose a Style")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var sourceHeader: some View {
        switch source {
        case .summary(let kind):
            Label(kind.title, systemImage: kind.systemImage)
                .font(.headline)
        case .entity(let entityID):
            if let entityBox = stateStore.entityBox(for: entityID) {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(entityBox.homeEntity.displayName).font(.headline)
                        Text(entityID).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    HomesteadIconView(icon: entityBox.homeEntity.resolvedIcon, pointSize: 20)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var compatibleKinds: [DashboardPresentationKind] {
        switch source {
        case .summary:
            [.chip]
        case .entity(let entityID):
            stateStore.entityBox(for: entityID).map(DashboardPresentationCatalog.compatiblePresentationKinds(for:)) ?? []
        }
    }

    private var recommendation: DashboardPresentationConfiguration? {
        switch source {
        case .summary:
            .chip
        case .entity(let entityID):
            stateStore.entityBox(for: entityID).map(DashboardPresentationCatalog.recommendation(for:))
        }
    }

    private func defaultPresentation(for kind: DashboardPresentationKind) -> DashboardPresentationConfiguration? {
        switch source {
        case .summary:
            return kind == .chip ? DashboardPresentationConfiguration.chip : nil
        case .entity(let entityID):
            guard let entityBox = stateStore.entityBox(for: entityID) else { return nil }
            return DashboardPresentationCatalog.defaultPresentation(kind: kind, for: entityBox)
        }
    }
}

struct DashboardPresentationOptionsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    let source: DashboardAddSource
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if kind == .chip {
                    chipOption
                } else if let entityBox {
                    ForEach(DashboardPresentationCatalog.descriptor(for: kind).supportedLayouts, id: \.self) { layout in
                        cardOption(entityBox: entityBox, layout: layout)
                    }
                } else {
                    ContentUnavailableView("Item Unavailable", systemImage: "questionmark.circle")
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kind == .chip ? "Chip" : DashboardPresentationCatalog.descriptor(for: kind).title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var entityBox: HAEntityState? {
        guard case .entity(let entityID) = source else { return nil }
        return stateStore.entityBox(for: entityID)
    }

    @ViewBuilder
    private var chipOption: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if let presentation = chipPresentation {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                DashboardChipView(presentation: presentation)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                add(source, .chip)
            } label: {
                Label(isAlreadyAdded ? "Added" : "Add Chip", systemImage: isAlreadyAdded ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .frame(minHeight: 44)
            .disabled(isAlreadyAdded)
        }
    }

    @ViewBuilder
    private func cardOption(entityBox: HAEntityState, layout: DashboardCardSize) -> some View {
        if let card = DashboardPresentationCatalog.cardConfiguration(kind: kind, layout: layout) {
            let recommendation = DashboardPresentationCatalog.recommendation(for: entityBox)
            let isRecommended = recommendation.kind == kind
                && recommendation.cardConfiguration?.layout == layout

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    Label(layout.chooserTitle, systemImage: layout.systemImage)
                        .font(.headline)

                    if isRecommended {
                        Text("Suggested")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    Spacer()

                    Button {
                        add(source, .card(card))
                    } label: {
                        Label(isAlreadyAdded ? "Added" : "Add", systemImage: isAlreadyAdded ? "checkmark" : "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .frame(minHeight: 44)
                    .disabled(isAlreadyAdded)
                }

                CardGrid {
                    DashboardCardView(
                        entityID: entityBox.entityID,
                        size: layout,
                        presentationKind: kind,
                        featureVisibility: card.featureVisibility,
                        isPreview: true
                    )
                    .cardGridSpan(layout.layoutMetadata)
                }
            }
        }
    }

    private var isAlreadyAdded: Bool {
        dashboardConfiguration.contains(source: source.reference, presentationKind: kind)
    }

    private var chipPresentation: DashboardChipPresentation? {
        switch source {
        case .summary(let summaryKind):
            return DashboardSummaryProvider.makeSummary(
                kind: summaryKind,
                entityBoxes: stateStore.allEntityBoxes(),
                membershipContext: stateStore.dashboardSummaryMembershipContext()
            )
        case .entity(let entityID):
            guard let entityBox = stateStore.entityBox(for: entityID) else { return nil }
            return DashboardSummaryProvider.makeEntityChip(entityBox: entityBox)
        }
    }
}
