import SwiftUI

struct DashboardAddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var mode: DashboardAddItemMode
    @State private var searchText = ""
    private let onAddItem: (UUID) -> Void

    init(initialMode: DashboardAddItemMode, onAddItem: @escaping (UUID) -> Void = { _ in }) {
        _mode = State(initialValue: initialMode)
        self.onAddItem = onAddItem
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .items:
                    itemsContent
                case .cards:
                    cardsContent
                }
            }
            .navigationTitle("Add to Dashboard")
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { modePicker }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
            .navigationDestination(for: DashboardAddRoute.self) { route in
                switch route {
                case .styles(let source):
                    DashboardChooseStyleView(source: source, add: add)
                case .sources(let kind):
                    DashboardCompatibleSourcesView(kind: kind, add: add)
                case .options(let source, let kind):
                    DashboardPresentationOptionsView(source: source, kind: kind, add: add)
                }
            }
            .onChange(of: mode) { _, _ in searchText = "" }
        }
        .presentationDetents([.large])
    }

    private var modePicker: some View {
        Picker("Add By", selection: $mode) {
            ForEach(DashboardAddItemMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
        .background(Color(.systemGroupedBackground))
    }

    private var itemsContent: some View {
        List {
            if !filteredSummaries.isEmpty {
                Section("Summaries") {
                    ForEach(filteredSummaries) { candidate in
                        sourceRow(
                            source: .summary(candidate.kind),
                            title: candidate.title,
                            subtitle: candidate.value,
                            icon: .sfSymbol(candidate.systemImage, provenance: .homesteadSemanticMapping)
                        )
                    }
                }
            }

            ForEach(filteredEntityGroups) { group in
                Section {
                    ForEach(group.candidates) { candidate in
                        sourceRow(
                            source: .entity(candidate.entityID),
                            title: candidate.displayName,
                            subtitle: candidate.entityID,
                            icon: candidate.icon
                        )
                    }
                } header: {
                    Label(group.title, systemImage: group.systemImage)
                }
            }
        }
        .overlay {
            if !stateStore.hasEntities {
                ContentUnavailableView("No Items Available", systemImage: "square.grid.2x2")
            } else if filteredSummaries.isEmpty && filteredEntityGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var cardsContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: AppSpacing.medium)], spacing: AppSpacing.medium) {
                ForEach(filteredPresentationDescriptors) { descriptor in
                    NavigationLink(value: DashboardAddRoute.sources(descriptor.kind)) {
                        DashboardPresentationGalleryTile(descriptor: descriptor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if filteredPresentationDescriptors.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func sourceRow(
        source: DashboardAddSource,
        title: String,
        subtitle: String,
        icon: ResolvedIcon
    ) -> some View {
        let recommendation = recommendation(for: source)
        let isAdded = recommendation.map {
            dashboardConfiguration.contains(source: source.reference, presentationKind: $0.kind)
        } ?? false

        return HStack(spacing: AppSpacing.medium) {
            NavigationLink(value: DashboardAddRoute.styles(source)) {
                Label {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                } icon: {
                    HomesteadIconView(icon: icon, pointSize: 18).foregroundStyle(Color.accentColor)
                }
            }

            Button {
                guard let recommendation else { return }
                add(source, recommendation)
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isAdded ? Color.secondary : Color.accentColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isAdded || recommendation == nil)
            .accessibilityLabel(isAdded ? "Already added" : "Add recommended style")
        }
        .frame(minHeight: 48)
    }

    private var filteredPresentationDescriptors: [DashboardPresentationDescriptor] {
        let query = normalizedSearch
        return DashboardPresentationCatalog.descriptors.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredSummaries: [DashboardAddSummaryCandidate] {
        let presentations = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            entityBoxes: stateStore.allEntityBoxes(),
            membershipContext: stateStore.dashboardSummaryMembershipContext()
        )
        return DashboardSummaryKind.allCases.compactMap { kind in
            guard let presentation = presentations[kind] else { return nil }
            let candidate = DashboardAddSummaryCandidate(
                kind: kind,
                title: presentation.title,
                value: presentation.value,
                systemImage: presentation.systemImage
            )
            guard normalizedSearch.isEmpty || candidate.title.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.value.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return candidate
        }
    }

    private var filteredEntityGroups: [DashboardAddEntityCandidateGroup] {
        let candidatesByID = Dictionary(uniqueKeysWithValues: stateStore.allEntityBoxes().compactMap { entityBox -> (String, DashboardAddEntityCandidate)? in
            guard entityBox.homeEntity.isAvailable else { return nil }
            let candidate = DashboardAddEntityCandidate(
                entityID: entityBox.entityID,
                displayName: stateStore.displayNameForDeviceGroupedEntity(entityID: entityBox.entityID) ?? entityBox.homeEntity.displayName,
                state: entityBox.homeEntity.state,
                domain: entityBox.domain,
                icon: entityBox.homeEntity.resolvedIcon
            )
            guard normalizedSearch.isEmpty
                    || candidate.displayName.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.entityID.localizedCaseInsensitiveContains(normalizedSearch)
                    || candidate.state.localizedCaseInsensitiveContains(normalizedSearch) else { return nil }
            return (entityBox.entityID, candidate)
        })

        if !stateStore.entityIDGroupsByDevice.isEmpty {
            return stateStore.entityIDGroupsByDevice.compactMap { group in
                let candidates = group.entityIDs.compactMap { candidatesByID[$0] }
                guard !candidates.isEmpty else { return nil }
                return DashboardAddEntityCandidateGroup(
                    id: "item-device-\(group.id)",
                    title: group.title,
                    systemImage: "laptopcomputer.and.iphone",
                    candidates: candidates
                )
            }
        }

        return stateStore.entityIDGroupsByDomain.compactMap { group in
            let candidates = group.entityIDs.compactMap { candidatesByID[$0] }
            guard !candidates.isEmpty else { return nil }
            return DashboardAddEntityCandidateGroup(
                id: "item-domain-\(group.domain.rawValue)",
                title: group.domain.displayName,
                systemImage: group.domain.systemImage,
                candidates: candidates
            )
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recommendation(for source: DashboardAddSource) -> DashboardPresentationConfiguration? {
        switch source {
        case .summary:
            .chip
        case .entity(let entityID):
            stateStore.entityBox(for: entityID).map(DashboardPresentationCatalog.recommendation(for:))
        }
    }

    private func add(_ source: DashboardAddSource, _ presentation: DashboardPresentationConfiguration) {
        guard let itemID = dashboardConfiguration.add(source: source.reference, presentation: presentation) else { return }
        HapticFeedback.selection()
        onAddItem(itemID)
    }
}

private struct DashboardPresentationGalleryTile: View {
    let descriptor: DashboardPresentationDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(height: 92)
                .overlay {
                    Image(systemName: descriptor.systemImage)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

            Text(descriptor.title)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(AppSpacing.medium)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

private struct DashboardCompatibleSourcesView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    let kind: DashboardPresentationKind
    let add: (DashboardAddSource, DashboardPresentationConfiguration) -> Void

    var body: some View {
        List {
            if kind == .chip {
                Section("Summaries") {
                    ForEach(availableSummaryKinds) { summaryKind in
                        sourceLink(.summary(summaryKind), title: summaryKind.title, icon: summaryKind.systemImage)
                    }
                }
            }

            Section("Entities") {
                ForEach(compatibleEntityBoxes, id: \.entityID) { entityBox in
                    sourceLink(
                        .entity(entityBox.entityID),
                        title: entityBox.homeEntity.displayName,
                        icon: entityBox.homeEntity.resolvedIcon.sfSymbolName
                    )
                }
            }
        }
        .navigationTitle(DashboardPresentationCatalog.descriptor(for: kind).title)
    }

    private var compatibleEntityBoxes: [HAEntityState] {
        stateStore.allEntityBoxes().filter { $0.homeEntity.isAvailable && DashboardPresentationCatalog.isCompatible(kind, with: $0) }
    }

    private var availableSummaryKinds: [DashboardSummaryKind] {
        let summaries = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            entityBoxes: stateStore.allEntityBoxes(),
            membershipContext: stateStore.dashboardSummaryMembershipContext()
        )
        return DashboardSummaryKind.allCases.filter { summaries[$0] != nil }
    }

    private func sourceLink(_ source: DashboardAddSource, title: String, icon: String) -> some View {
        NavigationLink(value: DashboardAddRoute.options(source, kind)) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                if dashboardConfiguration.contains(source: source.reference, presentationKind: kind) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Already added")
                }
            }
        }
    }
}
