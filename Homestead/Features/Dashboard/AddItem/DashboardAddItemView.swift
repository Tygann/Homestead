import SwiftUI

struct DashboardAddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var mode: DashboardAddItemMode
    @State private var cardCategory: DashboardAddCardCategory = .all
    @State private var cardIncludesUnavailable = false
    @State private var collapsedCardGroups: Set<String> = []
    @State private var selectedCardCandidate: DashboardAddCardCandidate?
    @State private var chipCategory: DashboardAddChipCategory = .all
    @State private var collapsedChipGroups: Set<String> = []
    @State private var summaryCandidates: [DashboardAddSummaryCandidate] = []
    @State private var chipEntityGroups: [DashboardAddEntityCandidateGroup] = []
    @State private var searchText = ""
    private let onAddItem: (UUID) -> Void

    init(
        initialMode: DashboardAddItemMode,
        onAddItem: @escaping (UUID) -> Void = { _ in }
    ) {
        _mode = State(initialValue: initialMode)
        self.onAddItem = onAddItem
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addFlowHeader
                switch mode {
                case .cards:
                    cardContent
                case .chips:
                    chipContent
                }
            }
            .navigationTitle("Add to Dashboard")
            .toolbarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .onChange(of: mode) { _, _ in
                searchText = ""
                if mode == .cards {
                    cardCategory = .all
                    collapsedCardGroups.removeAll()
                }
                if mode == .chips {
                    chipCategory = .all
                    collapsedChipGroups.removeAll()
                }
            }
            .onChange(of: stateStore.entityCatalogSignature) { _, _ in
                rebuildAddCandidates()
            }
            .onAppear {
                rebuildAddCandidates()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedCardCandidate) { candidate in
                DashboardAddCardChooserView(candidate: candidate) { size, featureVisibility in
                    addCard(candidate, size: size, featureVisibility: featureVisibility)
                    selectedCardCandidate = nil
                }
            }
        }
    }

    private var addFlowHeader: some View {
        VStack(spacing: AppSpacing.medium) {
            Picker("Dashboard Item Type", selection: $mode) {
                ForEach(DashboardAddItemMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.top, AppSpacing.medium)
        .padding(.bottom, AppSpacing.small)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 0) {
            cardCategoryBar
            cardCandidateList
        }
    }

    private var cardCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                ForEach(cardCategories) { category in
                    DashboardAddFilterChip(
                        title: category.category.title,
                        systemImage: category.category.systemImage,
                        trailingValue: category.count.formatted(),
                        isSelected: cardCategory == category.category
                    ) {
                        cardCategory = category.category
                        collapsedCardGroups.removeAll()
                    }
                }

                Button {
                    cardIncludesUnavailable.toggle()
                    collapsedCardGroups.removeAll()
                } label: {
                    Label("Unavailable", systemImage: cardIncludesUnavailable ? "eye" : "eye.slash")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, AppSpacing.medium)
                        .frame(height: 34)
                        .background(
                            cardIncludesUnavailable
                                ? Color.accentColor.opacity(0.14)
                                : Color(.tertiarySystemGroupedBackground),
                            in: Capsule()
                        )
                        .foregroundStyle(cardIncludesUnavailable ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cardIncludesUnavailable ? "Hide unavailable entities" : "Show unavailable entities")
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var cardCandidateList: some View {
        List {
            if showsCardGroupControls {
                Section {
                    Button {
                        toggleAllCardGroups()
                    } label: {
                        Label(cardGroupControlTitle, systemImage: cardGroupControlSystemImage)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }

            ForEach(filteredCardCandidateGroups) { group in
                Section {
                    if !collapsedCardGroups.contains(group.id) {
                        ForEach(group.candidates) { candidate in
                            DashboardAddCardRow(
                                candidate: candidate,
                                openChooser: {
                                    selectedCardCandidate = candidate
                                },
                                quickAdd: {
                                    addCard(
                                        candidate,
                                        size: candidate.recommendedSize,
                                        featureVisibility: candidate.recommendedFeatureVisibility
                                    )
                                }
                            )
                        }
                    }
                } header: {
                    Button {
                        toggleCardGroup(group.id)
                    } label: {
                        HStack {
                            Label(group.title, systemImage: group.systemImage)
                            Spacer()
                            Text(group.candidates.count.formatted())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, AppSpacing.small)
                                .frame(minWidth: 28, minHeight: 22)
                                .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                            Image(systemName: collapsedCardGroups.contains(group.id) ? "chevron.right" : "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if !stateStore.hasEntities {
                ContentUnavailableView("No Devices", systemImage: "square.grid.2x2")
            } else if filteredCardCandidateGroups.isEmpty {
                cardEmptyState
            }
        }
    }

    @ViewBuilder
    private var cardEmptyState: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if cardCategory != .all {
            ContentUnavailableView("No Matching Cards", systemImage: "line.3.horizontal.decrease.circle")
        } else {
            ContentUnavailableView("All Cards Added", systemImage: "checkmark.circle")
        }
    }

    private var cardCategories: [DashboardAddCardCategorySummary] {
        DashboardAddCardPresentation.makeCategorySummaries(
            from: cardCandidateGroups(
                category: .all,
                searchText: "",
                includesUnavailable: cardIncludesUnavailable
            )
            .flatMap(\.candidates)
        )
    }

    private var showsCardGroupControls: Bool {
        filteredCardCandidateGroups.count > 1
    }

    private var allVisibleCardGroupsCollapsed: Bool {
        let groupIDs = Set(filteredCardCandidateGroups.map(\.id))
        return !groupIDs.isEmpty && groupIDs.isSubset(of: collapsedCardGroups)
    }

    private var cardGroupControlTitle: String {
        allVisibleCardGroupsCollapsed ? "Expand Groups" : "Collapse Groups"
    }

    private var cardGroupControlSystemImage: String {
        allVisibleCardGroupsCollapsed ? "chevron.down.circle" : "chevron.up.circle"
    }

    private var filteredCardCandidateGroups: [DashboardAddCardCandidateGroup] {
        cardCandidateGroups(
            category: cardCategory,
            searchText: searchText,
            includesUnavailable: cardIncludesUnavailable
        )
    }

    private func cardCandidateGroups(
        category: DashboardAddCardCategory,
        searchText: String,
        includesUnavailable: Bool
    ) -> [DashboardAddCardCandidateGroup] {
        DashboardAddCardPresentation.makeCandidateGroups(
            entityBoxes: stateStore.allEntityBoxes(),
            configuredEntityIDs: selectedCardEntityIDs,
            deviceGroups: stateStore.entityIDGroupsByDevice,
            domainGroups: stateStore.entityIDGroupsByDomain,
            displayNameForDeviceGroupedEntity: stateStore.displayNameForDeviceGroupedEntity(entityID:),
            category: category,
            searchText: searchText,
            includesUnavailable: includesUnavailable
        )
    }

    private func toggleCardGroup(_ groupID: String) {
        if collapsedCardGroups.contains(groupID) {
            collapsedCardGroups.remove(groupID)
        } else {
            collapsedCardGroups.insert(groupID)
        }
    }

    private func toggleAllCardGroups() {
        let groupIDs = Set(filteredCardCandidateGroups.map(\.id))
        if allVisibleCardGroupsCollapsed {
            collapsedCardGroups.subtract(groupIDs)
        } else {
            collapsedCardGroups.formUnion(groupIDs)
        }
    }

    private func addCard(
        _ candidate: DashboardAddCardCandidate,
        size: DashboardCardSize,
        featureVisibility: DashboardCardFeatureVisibility
    ) {
        let itemID = dashboardConfiguration.add(candidate.entityID, size: size)
        dashboardConfiguration.setFeatureVisibility(featureVisibility, forItemID: itemID)
        onAddItem(itemID)
    }

    @ViewBuilder
    private var chipContent: some View {
        VStack(spacing: 0) {
            chipCategoryBar
            chipCandidateList
        }
    }

    private var chipCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                ForEach(chipCategories) { category in
                    DashboardAddFilterChip(
                        title: category.title,
                        systemImage: category.systemImage,
                        isSelected: chipCategory == category
                    ) {
                        chipCategory = category
                        collapsedChipGroups.removeAll()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var chipCandidateList: some View {
        List {
            if showsSummaryChipSection {
                Section("Summary Chips") {
                    ForEach(filteredSummaryCandidates) { candidate in
                        Button {
                            dashboardConfiguration.addSummaryChip(kind: candidate.kind)
                            rebuildAddCandidates()
                        } label: {
                            DashboardAddSummaryChipRow(
                                title: candidate.title,
                                value: candidate.value,
                                systemImage: candidate.systemImage
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if chipCategory != .summary {
                ForEach(filteredChipEntityGroups) { group in
                    Section {
                        if !collapsedChipGroups.contains(group.id) {
                            ForEach(group.candidates) { candidate in
                                Button {
                                    dashboardConfiguration.addEntityChip(entityID: candidate.entityID)
                                } label: {
                                    DashboardAddEntityRow(candidate: candidate)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Button {
                            toggleChipGroup(group.id)
                        } label: {
                            HStack {
                                Label(group.title, systemImage: group.systemImage)
                                Spacer()
                                Image(systemName: collapsedChipGroups.contains(group.id) ? "chevron.right" : "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if !stateStore.hasEntities {
                ContentUnavailableView("No Devices", systemImage: "capsule")
            } else if hasNoVisibleChipCandidates {
                chipEmptyState
            }
        }
    }

    @ViewBuilder
    private var chipEmptyState: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView(chipEmptyTitle, systemImage: chipEmptySystemImage)
        }
    }

    private var showsSummaryChipSection: Bool {
        (chipCategory == .all || chipCategory == .summary) && !filteredSummaryCandidates.isEmpty
    }

    private var hasNoVisibleChipCandidates: Bool {
        let hasVisibleSummaries = showsSummaryChipSection
        let hasVisibleEntities = chipCategory != .summary && !filteredChipEntityGroups.isEmpty

        return !hasVisibleSummaries && !hasVisibleEntities
    }

    private var chipCategories: [DashboardAddChipCategory] {
        var categories: [DashboardAddChipCategory] = [.all]

        if !summaryCandidates.isEmpty || chipCategory == .summary {
            categories.append(.summary)
        }

        categories.append(contentsOf: chipEntityDomains.map(DashboardAddChipCategory.domain))
        return categories
    }

    private var chipEntityDomains: [EntityDomain] {
        let domains = Set(chipEntityGroups.flatMap(\.candidates).map(\.domain))

        return EntityDomain.allCases.filter { domains.contains($0) }
    }

    private var filteredChipEntityGroups: [DashboardAddEntityCandidateGroup] {
        let groups = chipEntityGroups.compactMap { group -> DashboardAddEntityCandidateGroup? in
            let categoryCandidates = group.candidates.filter(chipEntityPassesCategory)
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidates: [DashboardAddEntityCandidate]
            if !query.isEmpty && group.title.localizedCaseInsensitiveContains(query) {
                candidates = categoryCandidates
            } else {
                candidates = categoryCandidates.filter(chipEntityMatchesSearch)
            }
            guard !candidates.isEmpty else {
                return nil
            }

            return DashboardAddEntityCandidateGroup(
                id: group.id,
                title: group.title,
                systemImage: group.systemImage,
                candidates: candidates
            )
        }

        return groups
    }

    private func makeChipEntityGroups() -> [DashboardAddEntityCandidateGroup] {
        if !stateStore.entityIDGroupsByDevice.isEmpty {
            return stateStore.entityIDGroupsByDevice.compactMap { group in
                let candidates = group.entityIDs.compactMap(makeChipEntityCandidate)
                guard !candidates.isEmpty else {
                    return nil
                }

                return DashboardAddEntityCandidateGroup(
                    id: "chip-device-\(group.id)",
                    title: group.title,
                    systemImage: "laptopcomputer.and.iphone",
                    candidates: candidates
                )
            }
        }

        return stateStore.entityIDGroupsByDomain.compactMap { group in
            let candidates = group.entityIDs.compactMap(makeChipEntityCandidate)
            guard !candidates.isEmpty else {
                return nil
            }

            return DashboardAddEntityCandidateGroup(
                id: "chip-type-\(group.domain.rawValue)",
                title: group.domain.displayName,
                systemImage: group.domain.systemImage,
                candidates: candidates
            )
        }
    }

    private func chipEntityPassesCategory(_ candidate: DashboardAddEntityCandidate) -> Bool {
        switch chipCategory {
        case .all:
            return true
        case .summary:
            return false
        case .domain(let domain):
            return candidate.domain == domain
        }
    }

    private func chipEntityMatchesSearch(_ candidate: DashboardAddEntityCandidate) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }

        return candidate.displayName.localizedCaseInsensitiveContains(query) ||
            candidate.entityID.localizedCaseInsensitiveContains(query) ||
            candidate.state.localizedCaseInsensitiveContains(query)
    }

    private func toggleChipGroup(_ groupID: String) {
        if collapsedChipGroups.contains(groupID) {
            collapsedChipGroups.remove(groupID)
        } else {
            collapsedChipGroups.insert(groupID)
        }
    }

    private var filteredSummaryCandidates: [DashboardAddSummaryCandidate] {
        guard chipCategory == .all || chipCategory == .summary else {
            return []
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return summaryCandidates
        }

        return summaryCandidates.filter { candidate in
            candidate.title.localizedCaseInsensitiveContains(query) ||
                candidate.value.localizedCaseInsensitiveContains(query)
        }
    }

    private var chipEmptyTitle: String {
        switch chipCategory {
        case .all:
            return "No Chips Available"
        case .summary:
            return stateStore.hasEntities ? "All Summary Chips Added" : "No Devices"
        case .domain:
            return "No Matching Entities"
        }
    }

    private var chipEmptySystemImage: String {
        switch chipCategory {
        case .all:
            return "capsule"
        case .summary:
            return stateStore.hasEntities ? "checkmark.circle" : "capsule"
        case .domain:
            return "line.3.horizontal.decrease.circle"
        }
    }

    private var selectedCardEntityIDs: Set<String> {
        Set(dashboardConfiguration.entityIDs)
    }

    private func rebuildAddCandidates() {
        let entityBoxes = stateStore.allEntityBoxes()
        let configuredKinds = configuredSummaryKinds
        let summaryPresentations = DashboardSummaryProvider.makeSummaries(
            kinds: DashboardSummaryKind.allCases,
            entityBoxes: entityBoxes,
            membershipContext: stateStore.dashboardSummaryMembershipContext()
        )

        summaryCandidates = DashboardSummaryKind.allCases.compactMap { kind in
            guard !configuredKinds.contains(kind),
                  let presentation = summaryPresentations[kind] else {
                return nil
            }

            return DashboardAddSummaryCandidate(
                kind: kind,
                title: presentation.title,
                value: presentation.value,
                systemImage: presentation.systemImage
            )
        }

        chipEntityGroups = makeChipEntityGroups()
    }

    private var configuredSummaryKinds: Set<DashboardSummaryKind> {
        Set(
            dashboardConfiguration.items.compactMap { item in
                guard item.type == .chip, item.chipKind == .summary else {
                    return nil
                }
                return item.summaryKind
            }
        )
    }

    private func makeChipEntityCandidate(entityID: String) -> DashboardAddEntityCandidate? {
        guard let entityBox = stateStore.entityBox(for: entityID) else {
            return nil
        }

        let entity = entityBox.homeEntity
        guard entity.isAvailable else {
            return nil
        }

        return DashboardAddEntityCandidate(
            entityID: entity.entityID,
            displayName: stateStore.displayNameForDeviceGroupedEntity(entityID: entityID) ?? entity.displayName,
            state: entity.state,
            domain: entity.domain,
            icon: entity.resolvedIcon
        )
    }

}
