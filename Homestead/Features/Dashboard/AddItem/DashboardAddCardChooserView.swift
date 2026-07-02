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
    @State private var selectedLayout: DashboardCardSize?

    let source: DashboardAddSource
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                Text(source.contextTitle(stateStore: stateStore))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if styleDescriptors.count > 1 {
                    styleSelector
                }

                if availableLayouts.count > 1 {
                    layoutSelector
                }

                if let selectedPresentation {
                    presentationOption(selectedPresentation)
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

    private var recommendedLayout: DashboardCardSize? {
        defaultPresentation?.cardConfiguration?.layout
    }

    private var resolvedLayout: DashboardCardSize? {
        if let selectedLayout, availableLayouts.contains(selectedLayout) {
            return selectedLayout
        }
        return recommendedLayout ?? availableLayouts.first
    }

    private var selectedPresentation: DashboardPresentationConfiguration? {
        guard case .card(let card) = defaultPresentation,
              let resolvedLayout else { return defaultPresentation }
        return .card(card.withLayout(resolvedLayout))
    }

    private var availableLayouts: [DashboardCardSize] {
        DashboardPresentationCatalog.descriptor(for: kind).supportedLayouts.filter { layout in
            DashboardPresentationCatalog.cardConfiguration(
                kind: kind,
                style: resolvedStyle,
                layout: layout
            ) != nil
        }
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
            selectedLayout = nil
            HapticFeedback.selection()
        } label: {
            VStack(spacing: AppSpacing.small) {
                Image(systemName: descriptor.systemImage)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(descriptor.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .background(
                isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemGroupedBackground),
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

    private var layoutSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Layout")
                .font(.headline)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.small), count: 3),
                spacing: AppSpacing.small
            ) {
                ForEach(availableLayouts, id: \.self) { layout in
                    layoutButton(layout)
                }
            }
        }
    }

    private func layoutButton(_ layout: DashboardCardSize) -> some View {
        let isSelected = layout == resolvedLayout
        let isDefault = layout == recommendedLayout

        return Button {
            selectedLayout = layout
            HapticFeedback.selection()
        } label: {
            VStack(spacing: AppSpacing.xSmall) {
                Image(systemName: layout.systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(layout.chooserTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(isDefault ? "Default" : " ")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(
                isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color(.separator).opacity(0.28),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(AppSpacing.xSmall)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(layout.chooserTitle)
        .accessibilityValue(
            [isSelected ? "Selected" : nil, isDefault ? "Default" : nil]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
        .accessibilityHint("Selects the \(layout.chooserTitle) layout")
    }

    private func presentationOption(_ presentation: DashboardPresentationConfiguration) -> some View {
        let isAdded = dashboardConfiguration.contains(
            source: source.reference,
            presentation: presentation
        )

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            DashboardAddPresentationPreview(source: source, presentation: presentation)

            Button {
                add(source, presentation)
            } label: {
                Label(isAdded ? "Added" : "Add", systemImage: isAdded ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAdded)
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
