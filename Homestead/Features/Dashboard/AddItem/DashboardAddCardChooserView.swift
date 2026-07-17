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

                if case .entity(let entityID) = source,
                   let entityBox = stateStore.entityBox(for: entityID),
                   case .configurable(let message) = DashboardPresentationCatalog.availability(of: kind, for: entityBox) {
                    Label(message, systemImage: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
    @State private var source: DashboardAddSource?
    @State private var selectedStyle: DashboardPresentationStyle?

    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    init(
        source: DashboardAddSource? = nil,
        kind: DashboardPresentationKind,
        add: @escaping (DashboardAddSource, DashboardPresentationConfiguration) -> Void
    ) {
        _source = State(initialValue: source)
        self.kind = kind
        self.add = add
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                sourceSelector

                if styleDescriptors.count > 1 {
                    styleSelector
                }

                if let source, let selectedPresentation {
                    presentationPreview(source: source, presentation: selectedPresentation)
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add \(DashboardPresentationCatalog.descriptor(for: kind).title) Card")
        .navigationSubtitle(source?.contextTitle(stateStore: stateStore) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    guard let source, let selectedPresentation else { return }
                    add(source, selectedPresentation)
                }
                .disabled(selectedPresentation == nil || selectedPresentationIsAdded)
                .accessibilityLabel(selectedPresentationIsAdded ? "Added" : "Add")
            }
        }
        .onChange(of: source) { _, _ in
            guard let selectedStyle,
                  !styleDescriptors.contains(where: { $0.style == selectedStyle }) else { return }
            self.selectedStyle = nil
        }
    }

    private var styleDescriptors: [DashboardPresentationStyleDescriptor] {
        source?.styleDescriptors(kind: kind, stateStore: stateStore)
            ?? DashboardPresentationCatalog.sourceIndependentStyleDescriptors(for: kind)
    }

    private var resolvedStyle: DashboardPresentationStyle? {
        if let selectedStyle,
           styleDescriptors.contains(where: { $0.style == selectedStyle }) {
            return selectedStyle
        }
        return styleDescriptors.first?.style
    }

    private var defaultPresentation: DashboardPresentationConfiguration? {
        source?.defaultPresentation(
            kind: kind,
            style: resolvedStyle,
            stateStore: stateStore
        )
    }

    private var selectedPresentation: DashboardPresentationConfiguration? {
        defaultPresentation
    }

    private var selectedPresentationIsAdded: Bool {
        guard let source, let selectedPresentation else { return false }
        return dashboardConfiguration.contains(
            source: source.reference,
            presentation: selectedPresentation
        )
    }

    private var sourceSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(sourceSectionTitle)
                .font(.headline)

            NavigationLink {
                DashboardSourcePickerView(selection: $source, kind: kind)
            } label: {
                HStack(spacing: AppSpacing.medium) {
                    sourceSelectorIcon

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(source?.contextTitle(stateStore: stateStore) ?? selectSourceTitle)
                            .font(.body.weight(source == nil ? .semibold : .regular))
                            .foregroundStyle(source == nil ? Color.accentColor : Color.primary)
                            .lineLimit(1)

                        if let sourceSubtitle {
                            Text(sourceSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(AppSpacing.medium)
                .frame(minHeight: 56)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(source.map { "Selected \($0.contextTitle(stateStore: stateStore))" } ?? selectSourceTitle)
            .accessibilityHint("Opens compatible \(sourceSectionTitle.lowercased())")
        }
    }

    @ViewBuilder
    private var sourceSelectorIcon: some View {
        if case .some(.entity(let entityID)) = source,
           let entityBox = stateStore.entityBox(for: entityID) {
            HomesteadIconView(icon: entityBox.homeEntity.resolvedIcon, pointSize: 20)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
        } else if case .some(.summary(let summaryKind)) = source {
            Image(systemName: summaryKind.systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
        } else {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
        }
    }

    private var sourceSectionTitle: String {
        kind == .chip ? "Item" : "Entity"
    }

    private var selectSourceTitle: String {
        "Select \(sourceSectionTitle)"
    }

    private var sourceSubtitle: String? {
        switch source {
        case .entity(let entityID):
            entityID
        case .summary(let summaryKind):
            source?.chipPresentation(stateStore: stateStore)?.value ?? summaryKind.title
        case nil:
            nil
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
            HapticFeedback.selection()
        } label: {
            VStack(spacing: AppSpacing.small) {
                Text(descriptor.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                stylePreview(for: descriptor)
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

    @ViewBuilder
    private func stylePreview(for descriptor: DashboardPresentationStyleDescriptor) -> some View {
        if let source,
           let presentation = source.defaultPresentation(
               kind: kind,
               style: descriptor.style,
               stateStore: stateStore
           ) {
            DashboardAddStylePreview(source: source, presentation: presentation)
        } else if let sampleEntityID = DashboardPresentationGallerySamples.entityID(for: kind),
                  let sampleEntity = DashboardPresentationGallerySamples.stateStore.entityBox(for: sampleEntityID),
                  let presentation = DashboardPresentationCatalog.defaultPresentation(
                      kind: kind,
                      style: descriptor.style,
                      for: sampleEntity
                  ) {
            DashboardAddStylePreview(
                source: .entity(sampleEntityID),
                presentation: presentation
            )
            .environment(DashboardPresentationGallerySamples.stateStore)
        }
    }

    @ViewBuilder
    private func presentationPreview(
        source: DashboardAddSource,
        presentation: DashboardPresentationConfiguration
    ) -> some View {
        if styleDescriptors.count <= 1 {
            DashboardAddPresentationPreview(source: source, presentation: presentation)
        }
    }
}

private struct DashboardSourcePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Binding var selection: DashboardAddSource?
    @State private var searchText = ""

    let kind: DashboardPresentationKind

    var body: some View {
        let summaryCandidates = filteredSummaryCandidates
        let entityBoxes = filteredEntityBoxes

        List {
            if !summaryCandidates.isEmpty {
                Section("Summaries") {
                    ForEach(summaryCandidates) { candidate in
                        sourceButton(
                            .summary(candidate.kind),
                            title: candidate.title,
                            subtitle: candidate.value,
                            icon: .sfSymbol(candidate.systemImage, provenance: .homesteadSemanticMapping)
                        )
                    }
                }
            }

            if !entityBoxes.isEmpty {
                Section("Entities") {
                    ForEach(entityBoxes, id: \.entityID) { entityBox in
                        sourceButton(
                            .entity(entityBox.entityID),
                            title: entityBox.homeEntity.displayName,
                            subtitle: entityBox.entityID,
                            icon: entityBox.homeEntity.resolvedIcon
                        )
                    }
                }
            }
        }
        .overlay {
            if summaryCandidates.isEmpty && entityBoxes.isEmpty {
                if normalizedSearch.isEmpty {
                    ContentUnavailableView("No Compatible Items", systemImage: "square.grid.2x2")
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle(kind == .chip ? "Select Item" : "Select Entity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredEntityBoxes: [HAEntityState] {
        stateStore.allEntityBoxes().filter { entityBox in
            guard entityBox.homeEntity.isAvailable,
                  DashboardPresentationCatalog.isCompatible(kind, with: entityBox) else { return false }
            return normalizedSearch.isEmpty
                || entityBox.homeEntity.displayName.localizedCaseInsensitiveContains(normalizedSearch)
                || entityBox.entityID.localizedCaseInsensitiveContains(normalizedSearch)
                || entityBox.homeEntity.state.localizedCaseInsensitiveContains(normalizedSearch)
        }
    }

    private var filteredSummaryCandidates: [DashboardAddSummaryCandidate] {
        guard kind == .chip else { return [] }
        let summaries = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            entityBoxes: stateStore.allEntityBoxes(),
            membershipContext: stateStore.dashboardSummaryMembershipContext()
        )
        return DashboardSummaryKind.allCases.compactMap { summaryKind in
            guard let summary = summaries[summaryKind] else { return nil }
            let candidate = DashboardAddSummaryCandidate(
                kind: summaryKind,
                title: summary.title,
                value: summary.value,
                systemImage: summary.systemImage
            )
            guard normalizedSearch.isEmpty
                    || candidate.title.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.value.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return candidate
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceButton(
        _ source: DashboardAddSource,
        title: String,
        subtitle: String,
        icon: ResolvedIcon
    ) -> some View {
        Button {
            selection = source
            HapticFeedback.selection()
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.medium) {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(title)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } icon: {
                    HomesteadIconView(icon: icon, pointSize: 18)
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                if selection == source {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selection == source ? "Selected" : "")
        .accessibilityHint("Selects \(title)")
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
