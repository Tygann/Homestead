import SwiftUI
import UIKit

struct DashboardCardItem: Identifiable, Equatable {
    let id: UUID
    let entityID: String
    let size: DashboardCardSize
    let displayNameOverride: String?
    let iconNameOverride: String?
    let featureVisibility: DashboardCardFeatureVisibility
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

    var configurationItemID: UUID {
        switch kind {
        case .header(let item):
            item.id
        case .card(let item):
            item.id
        case .chip(let item):
            item.id
        }
    }

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

struct DashboardEntityDetailRoute: Identifiable, Equatable, Hashable {
    let entityID: String
    let sourceID: String

    var id: String {
        "\(sourceID)-\(entityID)"
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
                    iconNameOverride: configurationItem.iconNameOverride,
                    featureVisibility: configurationItem.resolvedFeatureVisibility
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
    @State private var selectedEntityDetailRoute: DashboardEntityDetailRoute?
    @State private var renamingHeaderID: UUID?
    @State private var renamingDisplayItemID: UUID?
    @State private var headerTitleDraft = ""
    @State private var displayTitleDraft = ""
    @State private var showsInitialSyncPlaceholder = false
    @State private var cameraRefreshGeneration = 0
    @State private var highlightedDashboardItemID: UUID?
    @State private var pendingScrollDashboardItemID: UUID?
    @State private var gridItemFrames: [UUID: CGRect] = [:]
    @State private var draggingGridItemID: UUID?
    @State private var activeDragTranslation = CGSize.zero
    @State private var previewGridItemIDs: [UUID]?
    @State private var dragStartGridItemIDs: [UUID] = []
    @State private var dragStartFrame: CGRect?
    @State private var chipItemFrames: [UUID: CGRect] = [:]
    @State private var draggingChipItemID: UUID?
    @State private var activeChipDragTranslation = CGSize.zero
    @State private var previewChipItemIDs: [UUID]?
    @State private var dragStartChipItemIDs: [UUID] = []
    @State private var dragStartChipFrame: CGRect?
    @Namespace private var cardTransitionNamespace
    @Namespace private var summaryTransitionNamespace
    
    var body: some View {
        let visibleItemsSnapshot = visibleDashboardItems

        ScrollViewReader { scrollProxy in
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
                        configuredDashboardSection(visibleItems: visibleItemsSnapshot)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.xLarge)
            }
            .refreshable {
                await homeAssistantService.refreshStates()
                cameraRefreshGeneration += 1
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Homestead")
            //        .navigationSubtitle(connectionSettings.baseURL)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                if isEditingDashboard {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .confirm) {
                            isEditingDashboard = false
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        optionsMenu
                    }

                    ToolbarSpacer(.fixed, placement: .topBarTrailing)

                    ToolbarItem(placement: .topBarTrailing) {
                        SettingsAccountButton()
                    }
                }
            }
            .sheet(item: $addSheetMode) { mode in
                DashboardAddItemView(initialMode: mode, onAddItem: dashboardItemWasAdded)
            }
            .navigationDestination(item: $selectedEntityDetailRoute) { route in
                if let entityBox = stateStore.entityBox(for: route.entityID) {
                    EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation)
                        .navigationTransition(.zoom(sourceID: route.sourceID, in: cardTransitionNamespace))
                } else {
                    ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                        .navigationTransition(.zoom(sourceID: route.sourceID, in: cardTransitionNamespace))
                }
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
            .alert("Dashboard Name", isPresented: isRenamingDisplayItem) {
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
            .onChange(of: isEditingDashboard) { _, isEditing in
                if !isEditing {
                    endDashboardGridDrag()
                    endDashboardChipDrag()
                }
            }
            .onChange(of: pendingScrollDashboardItemID) { _, itemID in
                scrollToDashboardItem(itemID, scrollProxy: scrollProxy)
            }
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

    private var visibleDashboardGridItemIDs: [UUID] {
        visibleDashboardItems.compactMap { item in
            item.type == .chip ? nil : item.id
        }
    }

    private var activeDashboardGridItemIDs: [UUID] {
        previewGridItemIDs ?? visibleDashboardGridItemIDs
    }

    private var visibleDashboardChipItemIDs: [UUID] {
        visibleDashboardItems.compactMap { item in
            item.type == .chip ? item.id : nil
        }
    }

    private var activeDashboardChipItemIDs: [UUID] {
        previewChipItemIDs ?? visibleDashboardChipItemIDs
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
        dashboardItemWasAdded(itemID)
        headerTitleDraft = title
        renamingHeaderID = itemID
    }

    private func dashboardItemWasAdded(_ itemID: UUID) {
        highlightedDashboardItemID = itemID
        pendingScrollDashboardItemID = itemID

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_600))
            if highlightedDashboardItemID == itemID {
                highlightedDashboardItemID = nil
            }
        }
    }

    private func scrollToDashboardItem(_ itemID: UUID?, scrollProxy: ScrollViewProxy) {
        guard let itemID else {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.snappy(duration: 0.32)) {
                scrollProxy.scrollTo(dashboardScrollID(for: itemID), anchor: .center)
            }
            pendingScrollDashboardItemID = nil
        }
    }

    private func dashboardScrollID(for itemID: UUID) -> String {
        switch dashboardConfiguration.itemType(for: itemID) {
        case .header:
            "header-\(itemID)"
        case .entity:
            "card-\(itemID)"
        case .chip, nil:
            "chip-\(itemID)"
        }
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
    
    private func configuredDashboardSection(visibleItems: [DashboardItemConfiguration]) -> some View {
        let layoutItems = DashboardLayoutItemBuilder.makeItems(from: visibleItems)
        let chipItems: [DashboardChipItem] = layoutItems.compactMap { item in
            guard case .chip(let chipItem) = item.kind else { return nil }
            return chipItem
        }
        let gridItems: [DashboardLayoutItem] = layoutItems.filter { item in
            guard case .chip = item.kind else { return true }
            return false
        }
        let renderedGridItems = orderedGridItems(gridItems)

        return DashboardSection(isEmpty: visibleItems.isEmpty) {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if !chipItems.isEmpty {
                    dashboardChipSummaryRow(items: chipItems)
                }

                if !gridItems.isEmpty {
                    CardGrid {
                        ForEach(renderedGridItems) { item in
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
                    .coordinateSpace(name: DashboardGridCoordinateSpace.name)
                    .overlay(alignment: .topLeading) {
                        if let draggedGridItem = draggedGridItem(from: gridItems) {
                            dashboardGridDragPreview(draggedGridItem)
                        }
                    }
                    .onPreferenceChange(DashboardGridItemFramePreferenceKey.self) { frames in
                        gridItemFrames = frames
                    }
                    .animation(.snappy(duration: 0.18), value: activeDashboardGridItemIDs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func orderedGridItems(_ gridItems: [DashboardLayoutItem]) -> [DashboardLayoutItem] {
        guard let previewGridItemIDs else {
            return gridItems
        }

        let itemsByID = Dictionary(uniqueKeysWithValues: gridItems.map { ($0.configurationItemID, $0) })
        let previewItems = previewGridItemIDs.compactMap { itemsByID[$0] }
        let previewIDSet = Set(previewGridItemIDs)
        let remainingItems = gridItems.filter { !previewIDSet.contains($0.configurationItemID) }
        return previewItems + remainingItems
    }

    private func orderedChipItems(_ chipItems: [DashboardChipItem]) -> [DashboardChipItem] {
        guard let previewChipItemIDs else {
            return chipItems
        }

        let itemsByID = Dictionary(uniqueKeysWithValues: chipItems.map { ($0.id, $0) })
        let previewItems = previewChipItemIDs.compactMap { itemsByID[$0] }
        let previewIDSet = Set(previewChipItemIDs)
        let remainingItems = chipItems.filter { !previewIDSet.contains($0.id) }
        return previewItems + remainingItems
    }

    private func draggedGridItem(from gridItems: [DashboardLayoutItem]) -> DashboardLayoutItem? {
        guard let draggingGridItemID else {
            return nil
        }

        return gridItems.first { $0.configurationItemID == draggingGridItemID }
    }

    private func draggedChipItem(from chipItems: [DashboardChipItem]) -> DashboardChipItem? {
        guard let draggingChipItemID else {
            return nil
        }

        return chipItems.first { $0.id == draggingChipItemID }
    }

    private func dashboardChipSummaryRow(items: [DashboardChipItem]) -> some View {
        let renderedChipItems = orderedChipItems(items)

        return ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                ForEach(renderedChipItems) { chipItem in
                    dashboardChip(chipItem)
                }
            }
            .coordinateSpace(name: DashboardChipCoordinateSpace.name)
            .overlay(alignment: .topLeading) {
                if let draggedChipItem = draggedChipItem(from: items) {
                    dashboardChipDragPreview(draggedChipItem)
                }
            }
            .onPreferenceChange(DashboardChipItemFramePreferenceKey.self) { frames in
                chipItemFrames = frames
            }
            .animation(.snappy(duration: 0.18), value: activeDashboardChipItemIDs)
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 1, for: .scrollContent)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func dashboardHeader(_ item: DashboardItemConfiguration) -> some View {
        if isEditingDashboard {
            editableDashboardGridItem(
                id: item.id,
                editAccessibilityLabel: "Edit \(item.resolvedTitle)"
            ) {
                DashboardHeaderCardView(title: item.resolvedTitle)
                    .frame(maxWidth: .infinity)
            } editMenuContent: {
                headerEditMenuContent(for: item)
            }
        } else {
            DashboardHeaderCardView(title: item.resolvedTitle)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .dashboardHighlightBorder(isHighlighted: highlightedDashboardItemID == item.id)
                .contextMenu {
                    headerEditMenuContent(for: item)
                }
        }
    }
    
    @ViewBuilder
    private func dashboardCard(_ item: DashboardCardItem) -> some View {
        if isEditingDashboard {
            editableDashboardGridItem(
                id: item.id,
                editAccessibilityLabel: "Edit \(dashboardCardEditTitle(for: item))"
            ) {
                DashboardCardView(
                    entityID: item.entityID,
                    size: item.size,
                    displayNameOverride: currentCardDisplayNameOverride(for: item),
                    iconNameOverride: item.iconNameOverride,
                    featureVisibility: item.featureVisibility,
                    cameraRefreshGeneration: cameraRefreshGeneration,
                    isEditing: true
                )
                .frame(maxWidth: .infinity)
            } editMenuContent: {
                cardEditMenuContent(for: item)
            }
        } else {
            DashboardCardView(
                entityID: item.entityID,
                size: item.size,
                displayNameOverride: currentCardDisplayNameOverride(for: item),
                iconNameOverride: item.iconNameOverride,
                featureVisibility: item.featureVisibility,
                cameraRefreshGeneration: cameraRefreshGeneration,
                openDetails: {
                    selectedEntityDetailRoute = DashboardEntityDetailRoute(
                        entityID: item.entityID,
                        sourceID: cardTransitionID(for: item)
                    )
                }
            )
            .frame(maxWidth: .infinity)
            .dashboardHighlightBorder(isHighlighted: highlightedDashboardItemID == item.id)
            .matchedTransitionSource(id: cardTransitionID(for: item), in: cardTransitionNamespace)
            .contextMenu {
                cardEditMenuContent(for: item)
            }
        }
    }

    private func editableDashboardGridItem<Content: View, MenuContent: View>(
        id itemID: UUID,
        editAccessibilityLabel: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder editMenuContent: @escaping () -> MenuContent
    ) -> some View {
        let isDragging = draggingGridItemID == itemID
        return content()
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .dashboardGridItemFrame(id: itemID)
            .dashboardHighlightBorder(isHighlighted: highlightedDashboardItemID == itemID)
            .opacity(isDragging ? 0 : 1)
            .dashboardLongPressDragSurface(
                isEnabled: !isDragging,
                onChanged: { translation in
                    updateDashboardGridDrag(itemID: itemID, translation: translation)
                },
                onEnded: { translation in
                    finishDashboardGridDrag(itemID: itemID, translation: translation)
                },
                onCancelled: {
                    endDashboardGridDrag()
                }
            )
            .dashboardEditAffordance(
                isVisible: !isDragging,
                accessibilityLabel: editAccessibilityLabel,
                menuContent: editMenuContent
            )
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    @ViewBuilder
    private func dashboardGridDragPreview(_ item: DashboardLayoutItem) -> some View {
        if let dragStartFrame {
            dashboardGridPreviewContent(for: item)
                .frame(width: dragStartFrame.width, height: dragStartFrame.height)
                .scaleEffect(1.025)
                .offset(
                    x: dragStartFrame.minX + activeDragTranslation.width,
                    y: dragStartFrame.minY + activeDragTranslation.height
                )
                .allowsHitTesting(false)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .zIndex(20)
        }
    }

    @ViewBuilder
    private func dashboardGridPreviewContent(for item: DashboardLayoutItem) -> some View {
        switch item.kind {
        case .header(let configurationItem):
            DashboardHeaderCardView(title: configurationItem.resolvedTitle)
                .frame(maxWidth: .infinity)
        case .card(let cardItem):
            DashboardCardView(
                entityID: cardItem.entityID,
                size: cardItem.size,
                displayNameOverride: currentCardDisplayNameOverride(for: cardItem),
                iconNameOverride: cardItem.iconNameOverride,
                featureVisibility: cardItem.featureVisibility,
                cameraRefreshGeneration: cameraRefreshGeneration,
                isEditing: true
            )
            .frame(maxWidth: .infinity)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
            )
        case .chip:
            EmptyView()
        }
    }

    private func updateDashboardGridDrag(itemID: UUID, translation: CGSize) {
        if draggingGridItemID != itemID {
            draggingGridItemID = itemID
            dragStartGridItemIDs = visibleDashboardGridItemIDs
            previewGridItemIDs = visibleDashboardGridItemIDs
            dragStartFrame = gridItemFrames[itemID]
            HapticFeedback.selection()
        }

        activeDragTranslation = translation

        let targetItemID = dashboardGridInsertionTargetID(
            for: itemID,
            translation: translation,
            sourceFrame: dragStartFrame
        )

        let baseItemIDs = dragStartGridItemIDs.isEmpty ? visibleDashboardGridItemIDs : dragStartGridItemIDs
        let updatedPreviewItemIDs = reorderedGridItemIDs(
            moving: itemID,
            before: targetItemID,
            in: baseItemIDs
        )

        guard updatedPreviewItemIDs != previewGridItemIDs else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            previewGridItemIDs = updatedPreviewItemIDs
        }
    }

    private func dashboardGridInsertionTargetID(
        for movingItemID: UUID,
        translation: CGSize,
        sourceFrame: CGRect?
    ) -> UUID? {
        guard let movingFrame = sourceFrame ?? gridItemFrames[movingItemID] else {
            return nil
        }

        let dragCenter = CGPoint(
            x: movingFrame.midX + translation.width,
            y: movingFrame.midY + translation.height
        )
        let candidates = activeDashboardGridItemIDs.compactMap { itemID -> (id: UUID, frame: CGRect)? in
            guard itemID != movingItemID,
                  let frame = gridItemFrames[itemID] else {
                return nil
            }

            return (itemID, frame)
        }
        .sorted { lhs, rhs in
            if abs(lhs.frame.minY - rhs.frame.minY) > 1 {
                return lhs.frame.minY < rhs.frame.minY
            }

            return lhs.frame.minX < rhs.frame.minX
        }

        for candidate in candidates {
            if dragCenter.y < candidate.frame.midY ||
                (dragCenter.y < candidate.frame.maxY && dragCenter.x < candidate.frame.midX) {
                return candidate.id
            }
        }

        return nil
    }

    private func reorderedGridItemIDs(
        moving movingItemID: UUID,
        before targetItemID: UUID?,
        in itemIDs: [UUID]
    ) -> [UUID] {
        let orderedItemIDs = itemIDs.reduce(into: [UUID]()) { partialResult, itemID in
            if !partialResult.contains(itemID) {
                partialResult.append(itemID)
            }
        }
        guard orderedItemIDs.contains(movingItemID),
              targetItemID != movingItemID,
              targetItemID.map(orderedItemIDs.contains) ?? true else {
            return orderedItemIDs
        }

        var updatedItemIDs = orderedItemIDs.filter { $0 != movingItemID }
        let insertionIndex = targetItemID
            .flatMap { updatedItemIDs.firstIndex(of: $0) }
            ?? updatedItemIDs.count
        updatedItemIDs.insert(movingItemID, at: insertionIndex)
        return updatedItemIDs
    }

    private func finishDashboardGridDrag(itemID: UUID, translation: CGSize) {
        let targetItemID = dashboardGridInsertionTargetID(
            for: itemID,
            translation: translation,
            sourceFrame: dragStartFrame
        )
        let visibleItemIDs = dragStartGridItemIDs.isEmpty ? visibleDashboardGridItemIDs : dragStartGridItemIDs

        withAnimation(.snappy(duration: 0.2)) {
            dashboardConfiguration.moveVisibleGridItem(
                id: itemID,
                before: targetItemID,
                visibleGridItemIDs: visibleItemIDs
            )
        }

        HapticFeedback.selection()
        endDashboardGridDrag()
    }

    private func endDashboardGridDrag() {
        withAnimation(.snappy(duration: 0.18)) {
            draggingGridItemID = nil
            activeDragTranslation = .zero
            previewGridItemIDs = nil
            dragStartGridItemIDs = []
            dragStartFrame = nil
        }
    }

    @ViewBuilder
    private func dashboardChipDragPreview(_ item: DashboardChipItem) -> some View {
        if let dragStartChipFrame, let presentation = chipPresentation(for: item) {
            DashboardChipView(presentation: presentation)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .frame(width: dragStartChipFrame.width, height: dragStartChipFrame.height)
                .scaleEffect(1.025)
                .offset(
                    x: dragStartChipFrame.minX + activeChipDragTranslation.width,
                    y: dragStartChipFrame.minY
                )
                .allowsHitTesting(false)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .zIndex(20)
        }
    }

    private func updateDashboardChipDrag(itemID: UUID, translation: CGSize) {
        if draggingChipItemID != itemID {
            draggingChipItemID = itemID
            dragStartChipItemIDs = visibleDashboardChipItemIDs
            previewChipItemIDs = visibleDashboardChipItemIDs
            dragStartChipFrame = chipItemFrames[itemID]
            HapticFeedback.selection()
        }

        activeChipDragTranslation = CGSize(width: translation.width, height: 0)

        let targetItemID = dashboardChipInsertionTargetID(
            for: itemID,
            translation: activeChipDragTranslation,
            sourceFrame: dragStartChipFrame
        )

        let baseItemIDs = dragStartChipItemIDs.isEmpty ? visibleDashboardChipItemIDs : dragStartChipItemIDs
        let updatedPreviewItemIDs = reorderedGridItemIDs(
            moving: itemID,
            before: targetItemID,
            in: baseItemIDs
        )

        guard updatedPreviewItemIDs != previewChipItemIDs else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            previewChipItemIDs = updatedPreviewItemIDs
        }
    }

    private func dashboardChipInsertionTargetID(
        for movingItemID: UUID,
        translation: CGSize,
        sourceFrame: CGRect?
    ) -> UUID? {
        guard let movingFrame = sourceFrame ?? chipItemFrames[movingItemID] else {
            return nil
        }

        let dragCenterX = movingFrame.midX + translation.width
        let candidates = activeDashboardChipItemIDs.compactMap { itemID -> (id: UUID, frame: CGRect)? in
            guard itemID != movingItemID,
                  let frame = chipItemFrames[itemID] else {
                return nil
            }

            return (itemID, frame)
        }
        .sorted { lhs, rhs in
            lhs.frame.minX < rhs.frame.minX
        }

        for candidate in candidates where dragCenterX < candidate.frame.midX {
            return candidate.id
        }

        return nil
    }

    private func finishDashboardChipDrag(itemID: UUID, translation: CGSize) {
        let horizontalTranslation = CGSize(width: translation.width, height: 0)
        let targetItemID = dashboardChipInsertionTargetID(
            for: itemID,
            translation: horizontalTranslation,
            sourceFrame: dragStartChipFrame
        )
        let visibleItemIDs = dragStartChipItemIDs.isEmpty ? visibleDashboardChipItemIDs : dragStartChipItemIDs

        withAnimation(.snappy(duration: 0.2)) {
            dashboardConfiguration.moveVisibleChipItem(
                id: itemID,
                before: targetItemID,
                visibleChipItemIDs: visibleItemIDs
            )
        }

        HapticFeedback.selection()
        endDashboardChipDrag()
    }

    private func endDashboardChipDrag() {
        withAnimation(.snappy(duration: 0.18)) {
            draggingChipItemID = nil
            activeChipDragTranslation = .zero
            previewChipItemIDs = nil
            dragStartChipItemIDs = []
            dragStartChipFrame = nil
        }
    }

    @ViewBuilder
    private func dashboardChip(_ item: DashboardChipItem) -> some View {
        let presentation = chipPresentation(for: item)

        if let presentation {
            if isEditingDashboard {
                editableDashboardChip(item: item, presentation: presentation)
            } else {
                switch item.chipKind {
                case .summary:
                    if let summaryKind = item.summaryKind {
                        NavigationLink {
                            DashboardSummaryView(
                                kind: summaryKind,
                                titleOverride: item.displayNameOverride,
                                iconNameOverride: item.iconNameOverride
                            )
                            .navigationTransition(.zoom(sourceID: summaryTransitionID(for: item), in: summaryTransitionNamespace))
                        } label: {
                            DashboardChipView(presentation: presentation)
                                .matchedTransitionSource(id: summaryTransitionID(for: item), in: summaryTransitionNamespace)
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

    private func editableDashboardChip(
        item: DashboardChipItem,
        presentation: DashboardChipPresentation
    ) -> some View {
        let isDragging = draggingChipItemID == item.id
        return DashboardChipView(presentation: presentation)
            .contentShape(Capsule())
            .dashboardChipItemFrame(id: item.id)
            .opacity(isDragging ? 0 : 1)
            .dashboardLongPressDragSurface(
                isEnabled: !isDragging,
                onChanged: { translation in
                    updateDashboardChipDrag(itemID: item.id, translation: translation)
                },
                onEnded: { translation in
                    finishDashboardChipDrag(itemID: item.id, translation: translation)
                },
                onCancelled: {
                    endDashboardChipDrag()
                }
            )
            .dashboardChipEditAffordance(
                isVisible: !isDragging,
                accessibilityLabel: "Edit \(presentation.title)"
            ) {
                chipEditMenuContent(for: item, presentation: presentation)
            }
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private func summaryTransitionID(for item: DashboardChipItem) -> String {
        "dashboard-summary-\(item.id.uuidString)"
    }

    private func cardTransitionID(for item: DashboardCardItem) -> String {
        "dashboard-card-\(item.id.uuidString)"
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
            Label("Rename Card", systemImage: "pencil")
        }

        if cardSupportsFeatures(item) {
            Menu {
                ForEach(DashboardCardFeatureVisibility.allCases, id: \.self) { option in
                    Button {
                        HapticFeedback.selection()
                        dashboardConfiguration.setFeatureVisibility(option, forItemID: item.id)
                    } label: {
                        let selectedOption = dashboardConfiguration.featureVisibility(forItemID: item.id)
                        Label(
                            option.displayName,
                            systemImage: selectedOption == option ? "checkmark" : option.systemImage
                        )
                    }
                }
            } label: {
                Label("Card Features", systemImage: "slider.horizontal.3")
            }
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
            Label("Rename Chip", systemImage: "pencil")
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

    private func currentCardDisplayNameOverride(for item: DashboardCardItem) -> String? {
        item.displayNameOverride ?? dashboardConfiguration.entityDisplayNameOverride(for: item.entityID)
    }

    private func dashboardCardEditTitle(for item: DashboardCardItem) -> String {
        currentCardDisplayNameOverride(for: item)
            ?? stateStore.entity(for: item.entityID)?.displayName
            ?? "Card"
    }

    private func cardSupportsFeatures(_ item: DashboardCardItem) -> Bool {
        guard let entityBox = stateStore.entityBox(for: item.entityID) else {
            return false
        }

        let presentation = DashboardEntityPresentation(
            entityBox: entityBox,
            displayNameOverride: currentCardDisplayNameOverride(for: item),
            iconNameOverride: item.iconNameOverride
        )
        return !DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation).isEmpty
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

private enum DashboardGridCoordinateSpace {
    static let name = "dashboard-grid"
}

private enum DashboardChipCoordinateSpace {
    static let name = "dashboard-chip-row"
}

private enum DashboardDragTiming {
    static let liftDelay: TimeInterval = 0.45
    static let allowableMovement: CGFloat = 8
}

private struct DashboardGridItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct DashboardChipItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private extension View {
    func dashboardGridItemFrame(id: UUID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DashboardGridItemFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(DashboardGridCoordinateSpace.name))]
                )
            }
        }
    }

    func dashboardChipItemFrame(id: UUID) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DashboardChipItemFramePreferenceKey.self,
                    value: [id: proxy.frame(in: .named(DashboardChipCoordinateSpace.name))]
                )
            }
        }
    }

    func dashboardHighlightBorder(isHighlighted: Bool) -> some View {
        overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.72), lineWidth: 3)
                    .padding(1)
                    .allowsHitTesting(false)
            }
        }
    }

    func dashboardEditAffordance<MenuContent: View>(
        isVisible: Bool,
        accessibilityLabel: String,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) -> some View {
        overlay(alignment: .topTrailing) {
            DashboardGridEditAffordance(
                isVisible: isVisible,
                accessibilityLabel: accessibilityLabel,
                menuContent: menuContent
            )
        }
    }

    func dashboardChipEditAffordance<MenuContent: View>(
        isVisible: Bool,
        accessibilityLabel: String,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) -> some View {
        overlay(alignment: .topTrailing) {
            DashboardChipEditAffordance(
                isVisible: isVisible,
                accessibilityLabel: accessibilityLabel,
                menuContent: menuContent
            )
        }
    }

    func dashboardLongPressDragSurface(
        isEnabled: Bool,
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping (CGSize) -> Void,
        onCancelled: @escaping () -> Void
    ) -> some View {
        overlay {
            if isEnabled {
                DashboardLongPressDragSurface(
                    minimumDuration: DashboardDragTiming.liftDelay,
                    maximumMovement: DashboardDragTiming.allowableMovement,
                    onChanged: onChanged,
                    onEnded: onEnded,
                    onCancelled: onCancelled
                )
            }
        }
    }
}

private struct DashboardLongPressDragSurface: UIViewRepresentable {
    let minimumDuration: TimeInterval
    let maximumMovement: CGFloat
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = maximumMovement
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        context.coordinator.recognizer = recognizer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        context.coordinator.recognizer?.minimumPressDuration = minimumDuration
        context.coordinator.recognizer?.allowableMovement = maximumMovement
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGSize) -> Void
        var onEnded: (CGSize) -> Void
        var onCancelled: () -> Void
        weak var recognizer: UILongPressGestureRecognizer?
        private var startLocation: CGPoint?

        init(
            onChanged: @escaping (CGSize) -> Void,
            onEnded: @escaping (CGSize) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard let view = recognizer.view else {
                return
            }

            let location = recognizer.location(in: view)

            switch recognizer.state {
            case .began:
                startLocation = location
                onChanged(.zero)
            case .changed:
                onChanged(translation(from: location))
            case .ended:
                onEnded(translation(from: location))
                startLocation = nil
            case .cancelled, .failed:
                onCancelled()
                startLocation = nil
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func translation(from location: CGPoint) -> CGSize {
            guard let startLocation else {
                return .zero
            }

            return CGSize(
                width: location.x - startLocation.x,
                height: location.y - startLocation.y
            )
        }
    }
}

private struct DashboardGridEditAffordance<MenuContent: View>: View {
    let isVisible: Bool
    let accessibilityLabel: String
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -6)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Shows options")
    }
}

private struct DashboardChipEditAffordance<MenuContent: View>: View {
    let isVisible: Bool
    let accessibilityLabel: String
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -2)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Shows options")
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
