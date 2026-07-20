import SwiftUI

struct DashboardChooseCardView: View {
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
                    cardChoice(kind: kind)
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Choose a Card")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func cardChoice(kind: DashboardPresentationKind) -> some View {
        if let presentation = source.defaultPresentation(kind: kind, stateStore: stateStore) {
            let descriptor = DashboardPresentationCatalog.descriptor(for: kind)
            let isRecommended = recommendation?.kind == kind
            let presentationCount = dashboardConfiguration.presentationCount(
                source: source.reference,
                presentation: presentation
            )
            let isAdded = presentationCount > 0
            let canAddAnother = source.isEntity

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
                        Label(
                            isAdded && canAddAnother ? "Add Another" : isAdded ? "Added" : "Add",
                            systemImage: isAdded && !canAddAnother ? "checkmark" : "plus"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(minHeight: 44)
                    .disabled(isAdded && !canAddAnother)
                    .accessibilityLabel(
                        isAdded && canAddAnother
                            ? "Add another \(descriptor.title)"
                            : isAdded ? "\(descriptor.title) added" : "Add \(descriptor.title)"
                    )
                    .accessibilityHint(isAdded && !canAddAnother ? "" : "Adds the default \(descriptor.title)")
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
        "Configure \(descriptor.title)"
    }
}

struct DashboardPresentationReviewView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var source: DashboardAddSource?

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

                presentationPreview
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add \(DashboardPresentationCatalog.descriptor(for: kind).title) Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    guard let source, let selectedPresentation else { return }
                    add(source, selectedPresentation)
                }
                .disabled(selectedPresentation == nil || selectedPresentationIsSingletonAdded)
                .accessibilityLabel(addActionAccessibilityLabel)
            }
        }
    }

    private var defaultPresentation: DashboardPresentationConfiguration? {
        source?.defaultPresentation(kind: kind, stateStore: stateStore)
    }

    private var selectedPresentation: DashboardPresentationConfiguration? {
        defaultPresentation
    }

    private var selectedPresentationCount: Int {
        guard let source, let selectedPresentation else { return 0 }
        return dashboardConfiguration.presentationCount(
            source: source.reference,
            presentation: selectedPresentation
        )
    }

    private var selectedPresentationIsSingletonAdded: Bool {
        guard case .some(.summary) = source else { return false }
        return selectedPresentationCount > 0
    }

    private var addActionAccessibilityLabel: String {
        guard source != nil, selectedPresentation != nil else { return "Add" }
        if selectedPresentationIsSingletonAdded { return "Added" }
        return selectedPresentationCount > 0 ? "Add Another" : "Add"
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

    @ViewBuilder
    private var presentationPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Preview")
                .font(.headline)

            if let source, let selectedPresentation {
                DashboardAddPresentationPreview(source: source, presentation: selectedPresentation)
            } else if let entityID = DashboardPresentationGallerySamples.configurationEntityID(for: kind),
                      let entityBox = DashboardPresentationGallerySamples.configurationStateStore.entityBox(for: entityID),
                      let presentation = DashboardPresentationCatalog.defaultPresentation(kind: kind, for: entityBox) {
                DashboardAddPresentationPreview(source: .entity(entityID), presentation: presentation)
                    .environment(DashboardPresentationGallerySamples.configurationStateStore)
            }
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
        .searchable(text: $searchText, prompt: kind == .chip ? "Search items" : "Search entities")
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
    var isEntity: Bool {
        if case .entity = self { return true }
        return false
    }

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

// TODO: Add previewer

//#if DEBUG
//#Preview {
//    NavigationStack {
//
//    }
//    .withPreviewEnvironment()
//}
//#endif
