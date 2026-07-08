import SwiftUI

struct DashboardChooseStyleView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    let source: DashboardAddSource
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                Text(source.contextTitle(stateStore: stateStore))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

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
                presentation: presentation
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
                        Label(isAdded ? "Added" : "Add", systemImage: isAdded ? "checkmark" : "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(minHeight: 44)
                    .disabled(isAdded)
                    .accessibilityLabel(isAdded ? "\(descriptor.title) added" : "Add \(descriptor.title)")
                    .accessibilityHint(isAdded ? "" : "Adds the default \(descriptor.title)")
                }

                if kind == .chip {
                    DashboardAddPresentationPreview(source: source, presentation: presentation)
                } else {
                    NavigationLink(value: DashboardAddRoute.review(source, kind)) {
                        VStack(spacing: AppSpacing.small) {
                            DashboardAddPresentationPreview(source: source, presentation: presentation)

                            HStack {
                                Text(customizeTitle(descriptor: descriptor))
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(customizeHint(descriptor: descriptor))
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

    private func customizeTitle(descriptor: DashboardPresentationDescriptor) -> String {
        "Configure \(descriptor.title)"
    }

    private func customizeHint(descriptor: DashboardPresentationDescriptor) -> String {
        "Choose a style and layout for \(descriptor.title)"
    }
}

struct DashboardPresentationReviewView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var selectedStyle: DashboardPresentationStyle?

    let source: DashboardAddSource
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if styleDescriptors.count > 1 {
                    styleSelector
                }

                if let selectedPresentation {
                    presentationPreview(selectedPresentation)
                } else {
                    ContentUnavailableView("Item Unavailable", systemImage: "questionmark.circle")
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add \(DashboardPresentationCatalog.descriptor(for: kind).title) Card")
        .navigationSubtitle(source.contextTitle(stateStore: stateStore))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    guard let selectedPresentation else { return }
                    add(source, selectedPresentation)
                }
                .disabled(selectedPresentation == nil || selectedPresentationIsAdded)
                .accessibilityLabel(selectedPresentationIsAdded ? "Added" : "Add")
            }
        }
    }

    private var styleDescriptors: [DashboardPresentationStyleDescriptor] {
        source.styleDescriptors(kind: kind, stateStore: stateStore)
    }

    private var resolvedStyle: DashboardPresentationStyle? {
        selectedStyle ?? styleDescriptors.first?.style
    }

    private var defaultPresentation: DashboardPresentationConfiguration? {
        source.defaultPresentation(
            kind: kind,
            style: resolvedStyle,
            stateStore: stateStore
        )
    }

    private var selectedPresentation: DashboardPresentationConfiguration? {
        defaultPresentation
    }

    private var selectedPresentationIsAdded: Bool {
        guard let selectedPresentation else { return false }
        return dashboardConfiguration.contains(
            source: source.reference,
            presentation: selectedPresentation
        )
    }

    private var styleSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Style")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: AppSpacing.medium)],
                spacing: AppSpacing.medium
            ) {
                ForEach(styleDescriptors) { descriptor in
                    styleButton(descriptor)
                }
            }
        }
    }

    private func styleButton(_ descriptor: DashboardPresentationStyleDescriptor) -> some View {
        let isSelected = descriptor.style == resolvedStyle

        return Button {
            selectedStyle = descriptor.style
            HapticFeedback.selection()
        } label: {
            VStack(spacing: AppSpacing.small) {
                Text(descriptor.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let previewPresentation = stylePreviewPresentation(for: descriptor) {
                    DashboardAddStylePreview(
                        source: source,
                        presentation: previewPresentation
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.small)
            .background(
                isSelected ? Color.accentColor.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color(.separator).opacity(0.28),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(AppSpacing.small)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(descriptor.title)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint("Selects the \(descriptor.title) style")
    }

    private func stylePreviewPresentation(
        for descriptor: DashboardPresentationStyleDescriptor
    ) -> DashboardPresentationConfiguration? {
        guard case .card(let card) = source.defaultPresentation(
            kind: kind,
            style: descriptor.style,
            stateStore: stateStore
        ) else { return nil }

        return .card(card)
    }

    @ViewBuilder
    private func presentationPreview(_ presentation: DashboardPresentationConfiguration) -> some View {
        if styleDescriptors.count <= 1 {
            DashboardAddPresentationPreview(source: source, presentation: presentation)
        }
    }
}

private struct DashboardAddStylePreview: View {
    static let canvasHeight = DashboardCardSize.square.renderedHeight(
        rowSpacing: AppSpacing.medium,
        cardPadding: AppSpacing.medium
    )

    @Environment(HAStateStore.self) private var stateStore
    let source: DashboardAddSource
    let presentation: DashboardPresentationConfiguration

    @ViewBuilder
    var body: some View {
        if case .card(let card) = presentation,
           case .entity(let entityID) = source,
           stateStore.entityBox(for: entityID) != nil {
            let renderedHeight = card.layout.renderedHeight(
                rowSpacing: AppSpacing.medium,
                cardPadding: AppSpacing.medium
            )
            let scale = min(1, Self.canvasHeight / renderedHeight)

            DashboardCardView(
                entityID: entityID,
                size: card.layout,
                presentationKind: card.kind,
                presentationStyle: card.style,
                featureVisibility: card.featureVisibility,
                isPreview: true
            )
            .frame(height: renderedHeight)
            .scaleEffect(scale)
            .frame(height: Self.canvasHeight)
            .clipped()
            .allowsHitTesting(false)
        }
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
                        presentationStyle: card.style,
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

extension DashboardAddSource {
    func contextTitle(stateStore: HAStateStore) -> String {
        switch self {
        case .summary(let kind):
            kind.title
        case .entity(let entityID):
            stateStore.entityBox(for: entityID)?.homeEntity.displayName ?? entityID
        }
    }

    func defaultPresentation(
        kind: DashboardPresentationKind,
        style: DashboardPresentationStyle? = nil,
        stateStore: HAStateStore
    ) -> DashboardPresentationConfiguration? {
        switch self {
        case .summary:
            kind == .chip ? .chip : nil
        case .entity(let entityID):
            stateStore.entityBox(for: entityID).flatMap {
                DashboardPresentationCatalog.defaultPresentation(kind: kind, style: style, for: $0)
            }
        }
    }

    func styleDescriptors(
        kind: DashboardPresentationKind,
        stateStore: HAStateStore
    ) -> [DashboardPresentationStyleDescriptor] {
        guard case .entity(let entityID) = self,
              let entityBox = stateStore.entityBox(for: entityID) else {
            return []
        }
        return DashboardPresentationCatalog.styleDescriptors(for: kind, entityBox: entityBox)
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

// TODO: Add previewer

//#if DEBUG
//#Preview {
//    NavigationStack {
//
//    }
//    .withPreviewEnvironment()
//}
//#endif
