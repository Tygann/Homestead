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
                    NavigationLink(value: DashboardAddRoute.options(source, kind, presentation.style)) {
                        VStack(spacing: AppSpacing.small) {
                            DashboardAddPresentationPreview(source: source, presentation: presentation)

                            HStack {
                                Text(customizeTitle(for: kind, descriptor: descriptor))
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(customizeHint(for: kind, descriptor: descriptor))
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

    private func customizeTitle(
        for kind: DashboardPresentationKind,
        descriptor: DashboardPresentationDescriptor
    ) -> String {
        source.styleDescriptors(kind: kind, stateStore: stateStore).count > 1
            ? "Customize \(descriptor.title)"
            : "Customize \(descriptor.title) Layout"
    }

    private func customizeHint(
        for kind: DashboardPresentationKind,
        descriptor: DashboardPresentationDescriptor
    ) -> String {
        source.styleDescriptors(kind: kind, stateStore: stateStore).count > 1
            ? "Choose a style or layout for \(descriptor.title)"
            : "Choose another layout for \(descriptor.title)"
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
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if styleDescriptors.count > 1 {
                    stylePicker
                }

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

                    if case .card = presentation {
                        NavigationLink(value: DashboardAddRoute.options(source, kind, resolvedStyle)) {
                            HStack {
                                Label(customizeTitle, systemImage: "rectangle.3.group")
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
        source.defaultPresentation(kind: kind, style: resolvedStyle, stateStore: stateStore)
    }

    private var isAlreadyAdded: Bool {
        presentation.map {
            dashboardConfiguration.contains(source: source.reference, presentation: $0)
        } ?? false
    }

    private var styleDescriptors: [DashboardPresentationStyleDescriptor] {
        source.styleDescriptors(kind: kind, stateStore: stateStore)
    }

    private var resolvedStyle: DashboardPresentationStyle? {
        selectedStyle ?? styleDescriptors.first?.style
    }

    private var stylePicker: some View {
        Picker("Style", selection: Binding(
            get: { resolvedStyle ?? styleDescriptors[0].style },
            set: { selectedStyle = $0 }
        )) {
            ForEach(styleDescriptors) { descriptor in
                Label(descriptor.title, systemImage: descriptor.systemImage)
                    .tag(descriptor.style)
            }
        }
        .pickerStyle(.segmented)
    }

    private var customizeTitle: String {
        styleDescriptors.count > 1 ? "Customize Style & Layout" : "Customize Layout"
    }
}

struct DashboardPresentationOptionsView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var selectedStyle: DashboardPresentationStyle?

    let source: DashboardAddSource
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    init(
        source: DashboardAddSource,
        kind: DashboardPresentationKind,
        initialStyle: DashboardPresentationStyle?,
        add: @escaping (DashboardAddSource, DashboardPresentationConfiguration) -> Void
    ) {
        self.source = source
        self.kind = kind
        self.add = add
        _selectedStyle = State(initialValue: initialStyle)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if kind == .chip {
                    ContentUnavailableView("No Layout Options", systemImage: "capsule")
                } else if let entityBox {
                    if styleDescriptors.count > 1 {
                        stylePicker
                    }

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
        .navigationTitle(styleDescriptors.count > 1 ? "Customize \(familyTitle)" : "Choose Layout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var entityBox: HAEntityState? {
        guard case .entity(let entityID) = source else { return nil }
        return stateStore.entityBox(for: entityID)
    }

    @ViewBuilder
    private func cardOption(entityBox: HAEntityState, layout: DashboardCardSize) -> some View {
        if let card = DashboardPresentationCatalog.cardConfiguration(
            kind: kind,
            style: resolvedStyle,
            layout: layout
        ) {
            let presentation = DashboardPresentationConfiguration.card(card)
            let isDefault = source.defaultPresentation(
                kind: kind,
                style: resolvedStyle,
                stateStore: stateStore
            )?
                .cardConfiguration?.layout == layout
            let isAdded = dashboardConfiguration.contains(
                source: source.reference,
                presentation: presentation
            )

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
                        add(source, presentation)
                    } label: {
                        Label(isAdded ? "Added" : "Add", systemImage: isAdded ? "checkmark" : "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .frame(minHeight: 44)
                    .disabled(isAdded)
                }

                CardGrid {
                    DashboardCardView(
                        entityID: entityBox.entityID,
                        size: layout,
                        presentationKind: kind,
                        presentationStyle: card.style,
                        featureVisibility: card.featureVisibility,
                        isPreview: true
                    )
                    .cardGridSpan(layout.layoutMetadata)
                }
            }
        }
    }

    private var styleDescriptors: [DashboardPresentationStyleDescriptor] {
        source.styleDescriptors(kind: kind, stateStore: stateStore)
    }

    private var resolvedStyle: DashboardPresentationStyle? {
        selectedStyle ?? styleDescriptors.first?.style
    }

    private var familyTitle: String {
        DashboardPresentationCatalog.descriptor(for: kind).title
    }

    private var stylePicker: some View {
        Picker("Style", selection: Binding(
            get: { resolvedStyle ?? styleDescriptors[0].style },
            set: { selectedStyle = $0 }
        )) {
            ForEach(styleDescriptors) { descriptor in
                Label(descriptor.title, systemImage: descriptor.systemImage)
                    .tag(descriptor.style)
            }
        }
        .pickerStyle(.segmented)
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
