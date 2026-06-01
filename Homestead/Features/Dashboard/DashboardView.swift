import SwiftUI

struct DashboardCardItem: Identifiable, Equatable {
    let id: UUID
    let entityID: String
    let size: DashboardCardSize
    let displayNameOverride: String?
    let iconNameOverride: String?
}

struct DashboardChipItem: Identifiable, Equatable {
    let id: UUID
    let chipKind: DashboardChipKind
    let entityID: String?
    let summaryKind: DashboardSummaryKind?
    let displayNameOverride: String?
    let iconNameOverride: String?
}

enum DashboardLayoutItemKind: Equatable {
    case header(DashboardItemConfiguration)
    case card(DashboardCardItem)
    case chip(DashboardChipItem)
}

struct DashboardLayoutItem: Identifiable, Equatable {
    let kind: DashboardLayoutItemKind
    let layoutMetadata: DashboardCardLayoutMetadata

    var id: String {
        switch kind {
        case .header(let item):
            "header-\(item.id)"
        case .card(let item):
            "card-\(item.id)"
        case .chip(let item):
            "chip-\(item.id)"
        }
    }
}

enum DashboardLayoutItemBuilder {
    static func makeItems(from configurationItems: [DashboardItemConfiguration]) -> [DashboardLayoutItem] {
        return configurationItems.compactMap { configurationItem in
            switch configurationItem.type {
            case .header:
                return DashboardLayoutItem(
                    kind: .header(configurationItem),
                    layoutMetadata: configurationItem.layoutMetadata
                )
            case .entity:
                guard let entityID = configurationItem.entityID else {
                    return nil
                }

                let configuredSize = configurationItem.resolvedCardSize
                let cardItem = DashboardCardItem(
                    id: configurationItem.id,
                    entityID: entityID,
                    size: configuredSize,
                    displayNameOverride: configurationItem.displayNameOverride,
                    iconNameOverride: configurationItem.iconNameOverride
                )
                return DashboardLayoutItem(
                    kind: .card(cardItem),
                    layoutMetadata: configuredSize.layoutMetadata
                )
            case .chip:
                let chipKind = configurationItem.chipKind ?? .summary
                let chipItem = DashboardChipItem(
                    id: configurationItem.id,
                    chipKind: chipKind,
                    entityID: configurationItem.entityID,
                    summaryKind: configurationItem.summaryKind,
                    displayNameOverride: configurationItem.displayNameOverride,
                    iconNameOverride: configurationItem.iconNameOverride
                )
                return DashboardLayoutItem(
                    kind: .chip(chipItem),
                    layoutMetadata: configurationItem.layoutMetadata
                )
            }
        }
    }
}

struct DashboardView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var isEditingDashboard = false
    @State private var addSheetMode: DashboardAddItemMode?
    @State private var isShowingReorderSheet = false
    @State private var selectedSummaryChip: DashboardSelectedSummaryChip?
    @State private var renamingHeaderID: UUID?
    @State private var renamingDisplayItemID: UUID?
    @State private var headerTitleDraft = ""
    @State private var displayTitleDraft = ""
    @State private var showsInitialSyncPlaceholder = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if !hasHomeAssistantSession {
                    DashboardSetupCard()
                }

                if !hasHomeAssistantSession {
                    EmptyView()
                } else if !stateStore.hasLoadedInitialSnapshot {
                    if showsInitialSyncPlaceholder {
                        DashboardInitialSyncView(
                            connectionStatus: homeAssistantService.connectionStatus,
                            errorMessage: homeAssistantService.lastErrorMessage,
                            reconnect: {
                                Task { await homeAssistantService.connectIfPossible(settings: connectionSettings) }
                            }
                        )
                    }
                } else if !stateStore.hasEntities {
                    EmptyDashboardCard()
                } else if visibleDashboardItems.isEmpty {
                    EmptyConfiguredDashboardCard(
                        isEditing: isEditingDashboard,
                        addCards: {
                            addSheetMode = .cards
                        },
                        addHeader: {
                            addHeaderAndRename()
                        },
                        reset: {
                            dashboardConfiguration.reset(using: stateStore.allEntities)
                        }
                    )
                } else {
                    configuredDashboardSection
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .refreshable {
            await homeAssistantService.refreshStates()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Homestead")
        //        .navigationSubtitle(connectionSettings.baseURL)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            if isEditingDashboard {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingReorderSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .bold()
                    }
                    .disabled(dashboardConfiguration.items.count < 2)
                    .accessibilityLabel("Reorder Dashboard")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        isEditingDashboard = false
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    optionsMenu
                }
            }
        }
        .sheet(item: $addSheetMode) { mode in
            DashboardAddItemView(initialMode: mode)
        }
        .sheet(isPresented: $isShowingReorderSheet) {
            DashboardReorderView()
        }
        .sheet(item: $selectedSummaryChip) { chip in
            DashboardSummaryView(
                kind: chip.kind,
                titleOverride: chip.titleOverride,
                iconNameOverride: chip.iconNameOverride
            )
        }
        .alert("Rename Header", isPresented: isRenamingHeader) {
            TextField("Header Title", text: $headerTitleDraft)

            Button("Cancel", role: .cancel) {
                renamingHeaderID = nil
                headerTitleDraft = ""
            }

            Button("Save", role: .confirm) {
                saveHeaderRename()
            }
        }
        .alert("Rename Item", isPresented: isRenamingDisplayItem) {
            TextField("Display Name", text: $displayTitleDraft)

            Button("Cancel", role: .cancel) {
                renamingDisplayItemID = nil
                displayTitleDraft = ""
            }

            Button("Reset Name", role: .destructive) {
                resetEntityRename()
            }

            Button("Save", role: .confirm) {
                saveEntityRename()
            }
        }
        .onAppear {
            reconcileDashboardConfigurationIfReady()
        }
        .task(id: initialSyncPlaceholderKey) {
            await updateInitialSyncPlaceholderVisibility()
        }
        .onChange(of: stateStore.entityCatalogSignature) { _, _ in
            reconcileDashboardConfigurationIfReady()
        }
    }

    private var initialSyncPlaceholderKey: String {
        [
            hasHomeAssistantSession.description,
            stateStore.hasLoadedInitialSnapshot.description,
            homeAssistantService.isLoadingCachedStates.description,
            homeAssistantService.hasCompletedInitialCacheLoad.description
        ]
        .joined(separator: "-")
    }

    private var hasHomeAssistantSession: Bool {
        connectionSettings.hasServerURL && homeAssistantService.authState.isSignedIn
    }

    @MainActor
    private func updateInitialSyncPlaceholderVisibility() async {
        guard hasHomeAssistantSession,
              !stateStore.hasLoadedInitialSnapshot,
              homeAssistantService.hasCompletedInitialCacheLoad,
              !homeAssistantService.isLoadingCachedStates else {
            showsInitialSyncPlaceholder = false
            return
        }

        showsInitialSyncPlaceholder = false

        do {
            try await Task.sleep(for: .milliseconds(220))
        } catch {
            return
        }

        guard !Task.isCancelled,
              hasHomeAssistantSession,
              !stateStore.hasLoadedInitialSnapshot,
              homeAssistantService.hasCompletedInitialCacheLoad,
              !homeAssistantService.isLoadingCachedStates else {
            return
        }

        showsInitialSyncPlaceholder = true
    }
    
    private var visibleDashboardItems: [DashboardItemConfiguration] {
        return dashboardConfiguration
            .visibleItems(fromAvailableEntityIDs: stateStore.availableEntityIDs)
            .compactMap { item in
                guard item.type == .entity, let entityID = item.entityID else {
                    return item
                }

                guard stateStore.entityBox(for: entityID) != nil else {
                    return nil
                }

                return item
            }
    }
    
    private func reconcileDashboardConfigurationIfReady() {
        guard stateStore.hasEntities else {
            return
        }
        
        dashboardConfiguration.reconcile(with: stateStore.allEntities)
    }

    private var isRenamingHeader: Binding<Bool> {
        Binding(
            get: { renamingHeaderID != nil },
            set: { isPresented in
                if !isPresented {
                    renamingHeaderID = nil
                    headerTitleDraft = ""
                }
            }
        )
    }

    private var isRenamingDisplayItem: Binding<Bool> {
        Binding(
            get: { renamingDisplayItemID != nil },
            set: { isPresented in
                if !isPresented {
                    renamingDisplayItemID = nil
                    displayTitleDraft = ""
                }
            }
        )
    }

    private func addHeaderAndRename() {
        let title = "New Section"
        let itemID = dashboardConfiguration.addHeader(title: title)
        headerTitleDraft = title
        renamingHeaderID = itemID
    }

    private func beginRenamingHeader(_ item: DashboardItemConfiguration) {
        headerTitleDraft = item.resolvedTitle
        renamingHeaderID = item.id
    }

    private func beginRenamingEntity(_ item: DashboardCardItem) {
        guard let entity = stateStore.entity(for: item.entityID) else {
            return
        }

        displayTitleDraft = dashboardConfiguration.entityDisplayNameOverride(for: item.entityID)
            ?? item.displayNameOverride
            ?? entity.displayName
        renamingDisplayItemID = item.id
    }

    private func beginRenamingChip(_ item: DashboardChipItem) {
        displayTitleDraft = item.displayNameOverride ?? defaultChipTitle(for: item)
        renamingDisplayItemID = item.id
    }

    private func saveHeaderRename() {
        guard let renamingHeaderID else {
            return
        }

        dashboardConfiguration.renameHeader(id: renamingHeaderID, title: headerTitleDraft)
        self.renamingHeaderID = nil
        headerTitleDraft = ""
    }

    private func saveEntityRename() {
        guard let renamingDisplayItemID else {
            return
        }

        if dashboardConfiguration.itemType(for: renamingDisplayItemID) == .entity {
            dashboardConfiguration.renameEntityItem(
                id: renamingDisplayItemID,
                displayNameOverride: displayTitleDraft
            )
        } else {
            dashboardConfiguration.renameDisplayItem(
                id: renamingDisplayItemID,
                displayNameOverride: displayTitleDraft
            )
        }
        self.renamingDisplayItemID = nil
        displayTitleDraft = ""
    }

    private func resetEntityRename() {
        guard let renamingDisplayItemID else {
            return
        }

        if dashboardConfiguration.itemType(for: renamingDisplayItemID) == .entity {
            dashboardConfiguration.renameEntityItem(
                id: renamingDisplayItemID,
                displayNameOverride: nil
            )
        } else {
            dashboardConfiguration.renameDisplayItem(
                id: renamingDisplayItemID,
                displayNameOverride: nil
            )
        }
        self.renamingDisplayItemID = nil
        displayTitleDraft = ""
    }
    
    private var configuredDashboardSection: some View {
        DashboardSection(isEmpty: visibleDashboardItems.isEmpty) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if !dashboardChipItems.isEmpty {
                    dashboardChipSummaryRow
                }

                if !dashboardGridItems.isEmpty {
                    CardGrid {
                        ForEach(dashboardGridItems) { item in
                            switch item.kind {
                            case .header(let configurationItem):
                                dashboardHeader(configurationItem)
                                    .cardGridSpan(item.layoutMetadata)
                            case .card(let cardItem):
                                dashboardCard(cardItem)
                                    .cardGridSpan(item.layoutMetadata)
                            case .chip:
                                EmptyView()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private var dashboardLayoutItems: [DashboardLayoutItem] {
        DashboardLayoutItemBuilder.makeItems(from: visibleDashboardItems)
    }

    private var dashboardChipItems: [DashboardChipItem] {
        dashboardLayoutItems.compactMap { item in
            guard case .chip(let chipItem) = item.kind else { return nil }
            return chipItem
        }
    }

    private var dashboardGridItems: [DashboardLayoutItem] {
        dashboardLayoutItems.filter { item in
            guard case .chip = item.kind else { return true }
            return false
        }
    }

    private var dashboardChipSummaryRow: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                ForEach(dashboardChipItems) { chipItem in
                    dashboardChip(chipItem)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 1, for: .scrollContent)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func dashboardHeader(_ item: DashboardItemConfiguration) -> some View {
        if isEditingDashboard {
            Menu {
                headerEditMenuContent(for: item)
            } label: {
                DashboardHeaderCardView(title: item.resolvedTitle)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            DashboardHeaderCardView(title: item.resolvedTitle)
                .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func dashboardCard(_ item: DashboardCardItem) -> some View {
        if isEditingDashboard {
            Menu {
                cardEditMenuContent(for: item)
            } label: {
                DashboardCardView(
                    entityID: item.entityID,
                    size: item.size,
                    displayNameOverride: item.displayNameOverride,
                    iconNameOverride: item.iconNameOverride,
                    isEditing: true
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            DashboardCardView(
                entityID: item.entityID,
                size: item.size,
                displayNameOverride: item.displayNameOverride,
                iconNameOverride: item.iconNameOverride
            )
            .frame(maxWidth: .infinity)
            .contextMenu {
                cardEditMenuContent(for: item)
            }
        }
    }

    @ViewBuilder
    private func dashboardChip(_ item: DashboardChipItem) -> some View {
        let presentation = chipPresentation(for: item)

        if let presentation {
            if isEditingDashboard {
                Menu {
                    chipEditMenuContent(for: item, presentation: presentation)
                } label: {
                    DashboardChipView(presentation: presentation)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                switch item.chipKind {
                case .summary:
                    if let summaryKind = item.summaryKind {
                        Button {
                            selectedSummaryChip = DashboardSelectedSummaryChip(
                                kind: summaryKind,
                                titleOverride: item.displayNameOverride,
                                iconNameOverride: item.iconNameOverride
                            )
                        } label: {
                            DashboardChipView(presentation: presentation)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            chipEditMenuContent(for: item, presentation: presentation)
                        }
                    }
                case .entity:
                    DashboardChipView(presentation: presentation)
                        .contextMenu {
                            chipEditMenuContent(for: item, presentation: presentation)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func headerEditMenuContent(for item: DashboardItemConfiguration) -> some View {
        Button {
            beginRenamingHeader(item)
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
            dashboardConfiguration.removeItem(id: item.id)
        } label: {
            Label("Remove Header", systemImage: "minus.circle")
        }
    }

    @ViewBuilder
    private func cardEditMenuContent(for item: DashboardCardItem) -> some View {
        Picker("Card Size", selection: Binding(
            get: { dashboardConfiguration.cardSize(forItemID: item.id) },
            set: { size in
                HapticFeedback.selection()
                dashboardConfiguration.setCardSize(size, forItemID: item.id)
            }
        )) {
            ForEach(DashboardCardSize.allCases, id: \.self) { option in
                Label(option.displayName, systemImage: option.systemImage)
                    .tag(option)
                    .tint(item.size == option ? .primary : .gray)
            }
        }
        .pickerStyle(.segmented)

        Divider()

        Button {
            beginRenamingEntity(item)
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Menu {
            iconOverrideMenuContent(
                selectedSystemName: currentCardIconName(for: item),
                setIconNameOverride: { iconName in
                    dashboardConfiguration.setIconNameOverride(iconName, forItemID: item.id)
                }
            )
        } label: {
            Label("Change Icon", systemImage: "circle.grid.2x2")
        }

        Divider()

        Button(role: .destructive) {
            dashboardConfiguration.removeItem(id: item.id)
        } label: {
            Label("Remove Card", systemImage: "minus.circle")
        }
    }

    @ViewBuilder
    private func chipEditMenuContent(for item: DashboardChipItem, presentation: DashboardChipPresentation) -> some View {
        Button {
            beginRenamingChip(item)
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Menu {
            iconOverrideMenuContent(
                selectedSystemName: presentation.systemImage,
                setIconNameOverride: { iconName in
                    dashboardConfiguration.setIconNameOverride(iconName, forItemID: item.id)
                }
            )
        } label: {
            Label("Change Icon", systemImage: "circle.grid.2x2")
        }

        Divider()

        Button(role: .destructive) {
            dashboardConfiguration.removeItem(id: item.id)
        } label: {
            Label("Remove Chip", systemImage: "minus.circle")
        }
    }

    @ViewBuilder
    private func iconOverrideMenuContent(
        selectedSystemName: String,
        setIconNameOverride: @escaping (String?) -> Void
    ) -> some View {
        Button {
            HapticFeedback.selection()
            setIconNameOverride(nil)
        } label: {
            Label("Default Icon", systemImage: "arrow.counterclockwise")
        }

        ForEach(DashboardIconChoice.choices) { choice in
            Button {
                HapticFeedback.selection()
                setIconNameOverride(choice.systemName)
            } label: {
                Label {
                    Text(choice.title)
                } icon: {
                    Image(systemName: choice.systemName == selectedSystemName ? "checkmark.circle.fill" : choice.systemName)
                }
            }
        }
    }

    private func currentCardIconName(for item: DashboardCardItem) -> String {
        item.iconNameOverride ?? stateStore.entity(for: item.entityID)?.iconName ?? "square.grid.2x2"
    }

    private func chipPresentation(for item: DashboardChipItem) -> DashboardChipPresentation? {
        switch item.chipKind {
        case .summary:
            guard let summaryKind = item.summaryKind else { return nil }
            return DashboardSummaryProvider.makeSummary(
                kind: summaryKind,
                entityBoxes: stateStore.allEntityBoxes(),
                titleOverride: item.displayNameOverride,
                iconNameOverride: item.iconNameOverride,
                preferredClimateReadingEntityIDs: stateStore.preferredClimateReadingEntityIDs(),
                nonPrimaryEntityIDs: stateStore.nonPrimaryEntityIDs(),
                diagnosticEntityIDs: stateStore.diagnosticEntityIDs()
            )
        case .entity:
            guard let entityID = item.entityID,
                  let entityBox = stateStore.entityBox(for: entityID) else {
                return nil
            }

            return DashboardSummaryProvider.makeEntityChip(
                entityBox: entityBox,
                titleOverride: item.displayNameOverride ?? dashboardConfiguration.entityDisplayNameOverride(for: entityID),
                iconNameOverride: item.iconNameOverride
            )
        }
    }

    private func defaultChipTitle(for item: DashboardChipItem) -> String {
        switch item.chipKind {
        case .summary:
            item.summaryKind?.title ?? "Chip"
        case .entity:
            item.entityID.flatMap { entityID in
                dashboardConfiguration.entityDisplayNameOverride(for: entityID) ?? stateStore.entity(for: entityID)?.displayName
            } ?? "Chip"
        }
    }
    
    // MARK: - Options Menu
    private var optionsMenu: some View {
        Menu {
            Button {
                addSheetMode = .cards
            } label: {
                Label("Add to Dashboard", systemImage: "plus.app")
            }

            Button {
                addHeaderAndRename()
            } label: {
                Label("Add Section Header", systemImage: "textformat.size")
            }

            Divider()

            Button {
                isEditingDashboard = true
            } label: {
                Label("Edit Dashboard", systemImage: "square.grid.2x2")
            }
        } label: {
            Image(systemName: "ellipsis")
                .bold()
        }
    }
}

private enum DashboardAddItemMode: String, CaseIterable, Identifiable {
    case cards = "Cards"
    case chips = "Chips"

    var id: Self { self }
}

private enum DashboardAddChipCategory: Hashable, Identifiable {
    case all
    case summary
    case domain(EntityDomain)

    var id: String {
        switch self {
        case .all:
            "all"
        case .summary:
            "summary"
        case .domain(let domain):
            domain.rawValue
        }
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .summary:
            "Summary"
        case .domain(let domain):
            domain.displayName
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            "square.grid.2x2"
        case .summary:
            "chart.bar.doc.horizontal"
        case .domain(let domain):
            domain.systemImage
        }
    }
}

private struct DashboardAddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var mode: DashboardAddItemMode
    @State private var chipCategory: DashboardAddChipCategory = .all
    @State private var collapsedChipGroups: Set<String> = []
    @State private var summaryCandidates: [DashboardAddSummaryCandidate] = []
    @State private var chipEntityGroups: [DashboardAddEntityCandidateGroup] = []
    @State private var searchText = ""

    init(initialMode: DashboardAddItemMode) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addFlowHeader
                switch mode {
                case .cards:
                    entityAddList(for: .cards)
                case .chips:
                    chipContent
                }
            }
            .navigationTitle("Add to Dashboard")
            .toolbarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .onChange(of: mode) { _, _ in
                searchText = ""
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

    private func entityAddList(for target: DashboardAddEntityTarget) -> some View {
        EntityBrowserList(
            hiddenEntityIDs: target == .cards ? selectedCardEntityIDs : [],
            emptyTitle: emptyTitle(for: target),
            emptySystemImage: emptySystemImage(for: target),
            showsFilters: true,
            includesUnavailableByDefault: false,
            searchText: $searchText,
            showsSearchField: false,
            showsGroupingMenu: false,
            rowAction: { entityBox in
                switch target {
                case .cards:
                    dashboardConfiguration.add(entityBox.entityID)
                case .entityChips:
                    dashboardConfiguration.addEntityChip(entityID: entityBox.entityID)
                }
            },
            accessory: { _ in
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        )
    }

    private var selectedCardEntityIDs: Set<String> {
        stateStore.availableEntityIDs.subtracting(
            dashboardConfiguration.addableEntityIDs(fromAvailableEntityIDs: stateStore.availableEntityIDs)
        )
    }

    private func rebuildAddCandidates() {
        let entityBoxes = stateStore.allEntityBoxes()
        let configuredKinds = configuredSummaryKinds

        summaryCandidates = DashboardSummaryKind.allCases.compactMap { kind in
            guard !configuredKinds.contains(kind),
                  let presentation = DashboardSummaryProvider.makeSummary(
                    kind: kind,
                    entityBoxes: entityBoxes,
                    preferredClimateReadingEntityIDs: stateStore.preferredClimateReadingEntityIDs(),
                    nonPrimaryEntityIDs: stateStore.nonPrimaryEntityIDs(),
                    diagnosticEntityIDs: stateStore.diagnosticEntityIDs()
                  ) else {
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
                return item.summaryKind?.canonicalKind
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
            iconName: entity.iconName
        )
    }

    private func emptyTitle(for target: DashboardAddEntityTarget) -> String {
        switch target {
        case .cards:
            stateStore.hasEntities ? "All Cards Added" : "No Devices"
        case .entityChips:
            stateStore.hasEntities ? "No Entities" : "No Devices"
        }
    }

    private func emptySystemImage(for target: DashboardAddEntityTarget) -> String {
        switch target {
        case .cards:
            stateStore.hasEntities ? "checkmark.circle" : "square.grid.2x2"
        case .entityChips:
            "capsule"
        }
    }
}

private enum DashboardAddEntityTarget {
    case cards
    case entityChips
}

private struct DashboardAddSummaryCandidate: Identifiable, Equatable {
    let kind: DashboardSummaryKind
    let title: String
    let value: String
    let systemImage: String

    var id: DashboardSummaryKind { kind }
}

private struct DashboardAddEntityCandidate: Identifiable, Equatable {
    let entityID: String
    let displayName: String
    let state: String
    let domain: EntityDomain
    let iconName: String

    var id: String { entityID }
}

private struct DashboardAddEntityCandidateGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let candidates: [DashboardAddEntityCandidate]
}

private struct DashboardAddFilterChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, AppSpacing.medium)
                .frame(height: 34)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardAddEntityRow: View {
    let candidate: DashboardAddEntityCandidate

    var body: some View {
        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(candidate.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(candidate.entityID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .layoutPriority(1)

                Spacer(minLength: AppSpacing.medium)

                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
        } icon: {
            Image(systemName: candidate.iconName)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}

private struct DashboardAddSummaryChipRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .layoutPriority(1)

                Spacer(minLength: AppSpacing.medium)

                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}

private struct DashboardReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    var body: some View {
        NavigationStack {
            List {
                ForEach(dashboardConfiguration.items) { item in
                    DashboardReorderRow(
                        item: item,
                        entityBox: item.entityID.flatMap { stateStore.entityBox(for: $0) }
                    )
                }
                .onMove { source, destination in
                    dashboardConfiguration.move(from: source, to: destination)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Dashboard")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct DashboardReorderRow: View {
    let item: DashboardItemConfiguration
    let entityBox: HAEntityState?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(item.type == .header ? Color.secondary : Color.accentColor)
                .frame(width: 30)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch item.type {
        case .header:
            item.resolvedTitle
        case .entity:
            item.resolvedDisplayName(default: entityBox?.homeEntity.displayName ?? item.entityID ?? "Missing Entity")
        case .chip:
            item.resolvedDisplayName(default: defaultChipTitle)
        }
    }

    private var subtitle: String {
        switch item.type {
        case .header:
            "Header"
        case .entity:
            entityBox?.homeEntity.entityID ?? item.entityID ?? "Entity"
        case .chip:
            item.chipKind == .entity ? (entityBox?.homeEntity.entityID ?? item.entityID ?? "Entity Chip") : "Summary Chip"
        }
    }

    private var systemImage: String {
        switch item.type {
        case .header:
            "textformat.size"
        case .entity:
            item.resolvedIconName(default: entityBox?.homeEntity.iconName ?? "square.grid.2x2")
        case .chip:
            item.resolvedIconName(default: defaultChipIconName)
        }
    }

    private var defaultChipTitle: String {
        switch item.chipKind ?? .summary {
        case .summary:
            item.summaryKind?.title ?? "Chip"
        case .entity:
            entityBox?.homeEntity.displayName ?? item.entityID ?? "Chip"
        }
    }

    private var defaultChipIconName: String {
        switch item.chipKind ?? .summary {
        case .summary:
            item.summaryKind?.systemImage ?? "capsule"
        case .entity:
            entityBox?.homeEntity.iconName ?? "capsule"
        }
    }
}

private struct DashboardHeaderCardView: View {
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: AppSpacing.medium)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, AppSpacing.small)
        .padding(.top, AppSpacing.small)
        .padding(.bottom, AppSpacing.xSmall)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator).opacity(0.32))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardSection<Content: View>: View {
    let isEmpty: Bool
    @ViewBuilder var content: Content

    var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                content
            }
        }
    }
}

private struct DashboardSetupCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "house")
                Text("Connect Home Assistant")
                    .font(.headline)
                Text("Add your server URL in Settings, then sign in with Home Assistant.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DashboardInitialSyncView: View {
    let connectionStatus: HAConnectionStatus
    let errorMessage: String?
    let reconnect: () -> Void

    var body: some View {
        switch connectionStatus {
        case .failed:
            DashboardInitialSyncFailureCard(
                errorMessage: errorMessage,
                reconnect: reconnect
            )
        case .disconnected, .connecting, .connected, .reconnecting:
            DashboardLoadingPlaceholderView(connectionStatus: connectionStatus)
        }
    }
}

private struct DashboardLoadingPlaceholderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let connectionStatus: HAConnectionStatus
    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: AppSpacing.small) {
                ProgressView()
                    .controlSize(.small)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .accessibilityElement(children: .combine)

            VStack(spacing: AppSpacing.medium) {
                DashboardSkeletonCard(size: .wide)

                CardGrid {
                    DashboardSkeletonCard(size: .square)
                        .cardGridSpan(DashboardCardSize.square.layoutMetadata)
                    DashboardSkeletonCard(size: .compact)
                        .cardGridSpan(DashboardCardSize.compact.layoutMetadata)
                    DashboardSkeletonCard(size: .compact)
                        .cardGridSpan(DashboardCardSize.compact.layoutMetadata)
                    DashboardSkeletonCard(size: .square)
                        .cardGridSpan(DashboardCardSize.square.layoutMetadata)
                    DashboardSkeletonCard(size: .compact)
                        .cardGridSpan(DashboardCardSize.compact.layoutMetadata)
                    DashboardSkeletonCard(size: .square)
                        .cardGridSpan(DashboardCardSize.square.layoutMetadata)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(skeletonOpacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.large)
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion else {
                isPulsing = false
                return
            }

            isPulsing = true
        }
    }

    private var skeletonOpacity: Double {
        reduceMotion ? 0.72 : (isPulsing ? 0.46 : 0.72)
    }

    private var title: String {
        switch connectionStatus {
        case .reconnecting:
            "Reconnecting"
        case .connecting:
            "Connecting"
        case .connected:
            "Loading Dashboard"
        case .disconnected, .failed:
            "Loading Dashboard"
        }
    }

    private var message: String {
        switch connectionStatus {
        case .reconnecting:
            "Restoring live state"
        case .disconnected:
            "Preparing"
        case .connecting, .connected, .failed:
            "Fetching latest state"
        }
    }
}

private struct DashboardSkeletonCard: View {
    let size: DashboardCardSize

    var body: some View {
        CardContainer(minHeight: cardContainerMinHeight) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .center, spacing: AppSpacing.medium) {
                    RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        skeletonLine(width: titleWidth, height: 13)
                        skeletonLine(width: 54, height: 11)
                    }
                }

                if size.rowSpan > 1 {
                    skeletonLine(width: 96, height: 24)
                }
            }
            .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
        }
    }

    private var cardContainerMinHeight: CGFloat {
        size.contentMinHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }

    private var cardContentMinHeight: CGFloat {
        max(0, cardContainerMinHeight - (AppSpacing.medium * 2))
    }

    private var titleWidth: CGFloat {
        switch size {
        case .mini:
            0
        case .compact:
            86
        case .row:
            154
        case .square:
            112
        case .wide:
            154
        case .large:
            180
        }
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
            .frame(width: width, height: height)
    }
}

private struct DashboardInitialSyncFailureCard: View {
    let errorMessage: String?
    let reconnect: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "exclamationmark.triangle.fill")

                Text("Unable to load Home Assistant")
                    .font(.headline)

                Text(errorMessage ?? "Check your connection settings and try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Reconnect", systemImage: "arrow.triangle.2.circlepath", action: reconnect)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, AppSpacing.small)
            }
        }
    }
}

private struct EmptyDashboardCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "square.grid.2x2")
                Text("No Home Assistant entities found")
                    .font(.headline)
                Text("Home Assistant loaded successfully, but did not return any entities.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyConfiguredDashboardCard: View {
    let isEditing: Bool
    let addCards: () -> Void
    let addHeader: () -> Void
    let reset: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "square.grid.2x2")
                Text("No cards selected")
                    .font(.headline)
                Text(isEditing ? "Use the plus button to add dashboard items or section headers." : "Choose Edit Home View to add cards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: AppSpacing.small) {
                    if isEditing {
                        Button("Add to Dashboard", systemImage: "plus", action: addCards)
                            .buttonStyle(.borderedProminent)

                        Button("Add Section Header", systemImage: "textformat.size", action: addHeader)
                            .buttonStyle(.bordered)

                        Button("Restore Suggested Cards", action: reset)
                            .buttonStyle(.bordered)
                    } else {
                        Button("Restore Suggested Cards", action: reset)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, AppSpacing.small)
            }
        }
    }
}

private struct DashboardSelectedSummaryChip: Identifiable {
    let kind: DashboardSummaryKind
    let titleOverride: String?
    let iconNameOverride: String?

    var id: String {
        [
            kind.canonicalKind.rawValue,
            titleOverride ?? "",
            iconNameOverride ?? ""
        ]
        .joined(separator: "-")
    }
}

struct DashboardSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore

    let kind: DashboardSummaryKind
    let titleOverride: String?
    let iconNameOverride: String?

    init(
        kind: DashboardSummaryKind,
        titleOverride: String? = nil,
        iconNameOverride: String? = nil
    ) {
        self.kind = kind
        self.titleOverride = titleOverride
        self.iconNameOverride = iconNameOverride
    }

    private var detail: DashboardSummaryDetailPresentation? {
        DashboardSummaryProvider.makeDetail(
            kind: kind,
            entityBoxes: stateStore.allEntityBoxes(),
            titleOverride: titleOverride,
            iconNameOverride: iconNameOverride,
            preferredClimateReadingEntityIDs: stateStore.preferredClimateReadingEntityIDs(),
            nonPrimaryEntityIDs: stateStore.nonPrimaryEntityIDs(),
            diagnosticEntityIDs: stateStore.diagnosticEntityIDs(),
            areaNameForEntityID: stateStore.areaName(for:)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let detail {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                            DashboardSummaryHeader(presentation: detail.summary)

                            ForEach(detail.sections) { section in
                                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                    Text(section.title)
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    CardGrid {
                                        ForEach(section.items) { item in
                                            let entityBox = stateStore.entityBox(for: item.entityID)
                                            let size = cardSize(for: entityBox)

                                            DashboardCardView(
                                                entityID: item.entityID,
                                                size: size,
                                                contextualAreaName: section.title
                                            )
                                                .cardGridSpan(size.layoutMetadata)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.large)
                        .padding(.vertical, AppSpacing.xLarge)
                    }
                    .background(Color(.systemGroupedBackground))
                } else {
                    ContentUnavailableView("No Summary Available", systemImage: kind.canonicalKind.systemImage)
                }
            }
            .navigationTitle(detail?.summary.title ?? kind.canonicalKind.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func cardSize(for entityBox: HAEntityState?) -> DashboardCardSize {
        guard let entityBox else { return .compact }
        return DashboardCardSize.compactOrSquareForAvailableFeatures(entityBox: entityBox)
    }
}

private struct DashboardSummaryHeader: View {
    let presentation: DashboardChipPresentation

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Image(systemName: presentation.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 48, height: 48)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(presentation.value)
                    .font(.headline)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: AppSpacing.small)
        }
        .padding(.vertical, AppSpacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.value)
    }

    private var iconColor: Color {
        guard presentation.isAvailable else { return .red }
        return presentation.isActive ? .accentColor : .secondary
    }

    private var valueColor: Color {
        guard presentation.isAvailable else { return .red }
        return presentation.isActive ? .primary : .secondary
    }

    private var iconBackground: Color {
        guard presentation.isAvailable else { return Color.red.opacity(0.12) }
        return presentation.isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DashboardView()
    }
    .withPreviewEnvironment()
}
#endif
