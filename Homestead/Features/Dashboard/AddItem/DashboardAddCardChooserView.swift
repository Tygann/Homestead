import SwiftUI

struct DashboardChooseStyleView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    let source: DashboardAddSource
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                ForEach(compatibleKinds, id: \.self) { kind in
                    styleChoice(kind: kind)
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Choose a Style")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func styleChoice(kind: DashboardPresentationKind) -> some View {
        if let presentation = source.defaultPresentation(kind: kind, stateStore: stateStore) {
            let descriptor = DashboardPresentationCatalog.descriptor(for: kind)
            let isRecommended = recommendation?.kind == kind
            let isAdded = dashboardConfiguration.contains(
                source: source.reference,
                presentationKind: kind
            )

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    Label(descriptor.title, systemImage: descriptor.systemImage)
                        .font(.headline)

                    if isRecommended {
                        Text("Suggested")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, AppSpacing.small)
                            .frame(height: 22)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    Button {
                        add(source, presentation)
                    } label: {
                        Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isAdded ? Color.secondary : Color.accentColor)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdded)
                    .accessibilityLabel(isAdded ? "\(descriptor.title) added" : "Add \(descriptor.title)")
                    .accessibilityHint(isAdded ? "" : "Adds the suggested layout")
                }

                if kind == .chip || isAdded {
                    DashboardAddPresentationPreview(source: source, presentation: presentation)
                } else {
                    NavigationLink(value: DashboardAddRoute.options(source, kind)) {
                        VStack(spacing: AppSpacing.small) {
                            DashboardAddPresentationPreview(source: source, presentation: presentation)

                            HStack {
                                Text("Customize Layout")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Choose another layout for \(descriptor.title)")
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
}

struct DashboardPresentationReviewView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    let source: DashboardAddSource
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if let presentation {
                    DashboardAddPresentationPreview(source: source, presentation: presentation)

                    Button {
                        add(source, presentation)
                    } label: {
                        Label(isAlreadyAdded ? "Added" : "Add", systemImage: isAlreadyAdded ? "checkmark" : "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isAlreadyAdded)

                    if case .card = presentation, !isAlreadyAdded {
                        NavigationLink(value: DashboardAddRoute.options(source, kind)) {
                            HStack {
                                Label("Customize Layout", systemImage: "rectangle.3.group")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ContentUnavailableView("Item Unavailable", systemImage: "questionmark.circle")
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(DashboardPresentationCatalog.descriptor(for: kind).title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var presentation: DashboardPresentationConfiguration? {
        source.defaultPresentation(kind: kind, stateStore: stateStore)
    }

    private var isAlreadyAdded: Bool {
        dashboardConfiguration.contains(source: source.reference, presentationKind: kind)
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
                    ContentUnavailableView("No Layout Options", systemImage: "capsule")
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
        .navigationTitle("Choose Layout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var entityBox: HAEntityState? {
        guard case .entity(let entityID) = source else { return nil }
        return stateStore.entityBox(for: entityID)
    }

    @ViewBuilder
    private func cardOption(entityBox: HAEntityState, layout: DashboardCardSize) -> some View {
        if let card = DashboardPresentationCatalog.cardConfiguration(kind: kind, layout: layout) {
            let isDefault = source.defaultPresentation(kind: kind, stateStore: stateStore)?
                .cardConfiguration?.layout == layout

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    Label(layout.chooserTitle, systemImage: layout.systemImage)
                        .font(.headline)

                    if isDefault {
                        Text("Default")
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
}

private struct DashboardAddPresentationPreview: View {
    @Environment(HAStateStore.self) private var stateStore
    let source: DashboardAddSource
    let presentation: DashboardPresentationConfiguration

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .chip:
            if let chip = source.chipPresentation(stateStore: stateStore) {
                DashboardChipView(presentation: chip)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
            }
        case .card(let card):
            if case .entity(let entityID) = source,
               stateStore.entityBox(for: entityID) != nil {
                CardGrid {
                    DashboardCardView(
                        entityID: entityID,
                        size: card.layout,
                        presentationKind: card.kind,
                        featureVisibility: card.featureVisibility,
                        isPreview: true
                    )
                    .cardGridSpan(card.layout.layoutMetadata)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

private extension DashboardAddSource {
    func defaultPresentation(
        kind: DashboardPresentationKind,
        stateStore: HAStateStore
    ) -> DashboardPresentationConfiguration? {
        switch self {
        case .summary:
            kind == .chip ? .chip : nil
        case .entity(let entityID):
            stateStore.entityBox(for: entityID).flatMap {
                DashboardPresentationCatalog.defaultPresentation(kind: kind, for: $0)
            }
        }
    }

    func chipPresentation(stateStore: HAStateStore) -> DashboardChipPresentation? {
        switch self {
        case .summary(let kind):
            DashboardSummaryProvider.makeSummary(
                kind: kind,
                entityBoxes: stateStore.allEntityBoxes(),
                membershipContext: stateStore.dashboardSummaryMembershipContext()
            )
        case .entity(let entityID):
            stateStore.entityBox(for: entityID).map {
                DashboardSummaryProvider.makeEntityChip(entityBox: $0)
            }
        }
    }
}
