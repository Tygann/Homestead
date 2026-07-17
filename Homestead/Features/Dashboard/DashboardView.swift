import SwiftUI

struct DashboardView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isEditingDashboard = false
    @State private var addSheetMode: DashboardAddItemMode?
    @State private var iconPickerContext: DashboardIconPickerContext?
    @State private var gaugeZoneEditorContext: DashboardGaugeZoneEditorContext?
    @State private var selectedEntityDetailRoute: DashboardEntityDetailRoute?
    @State private var renamingHeaderID: UUID?
    @State private var renamingDisplayItemID: UUID?
    @State private var headerTitleDraft = ""
    @State private var displayTitleDraft = ""
    @State private var cameraRefreshGeneration = 0
    @State private var dashboardReconciliationGeneration = 0
    @State private var highlightedDashboardItemID: UUID?
    @State private var pendingScrollDashboardItemID: UUID?
    @State private var isConfirmingSuggestedSetup = false
    @State private var gridDragState = DashboardEditDragState()
    @State private var gridDragCleanupTask: Task<Void, Never>?
    @State private var chipDragState = DashboardEditDragState()
    @State private var chipDragCleanupTask: Task<Void, Never>?
    @Namespace private var cardTransitionNamespace
    @Namespace private var summaryTransitionNamespace
    
    var body: some View {
        let _ = dashboardReconciliationGeneration
        let visibleItemsSnapshot = visibleDashboardItems

        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    if !hasHomeAssistantSession {
                        EmptyView()
                    } else if !stateStore.hasLoadedInitialSnapshot {
                        if showsInitialSnapshotFailure {
                            DashboardInitialSyncView(
                                connectionStatus: homeAssistantService.connectionStatus,
                                errorMessage: homeAssistantService.lastErrorMessage,
                                reconnect: {
                                    Task { await homeAssistantService.connectIfPossible(settings: connectionSettings) }
                                }
                            )
                        } else {
                            DashboardRestoringSnapshotView()
                        }
                    } else if !stateStore.hasEntities {
                        EmptyDashboardCard()
                    } else if visibleItemsSnapshot.isEmpty {
                        DashboardEmptyStateView(
                            suggestedSetupActionTitle: dashboardConfiguration.setupState == .notChosen
                                ? "Use Suggested Setup"
                                : "Restore Suggested Setup",
                            addToDashboard: {
                                addSheetMode = .items
                            },
                            useSuggestedSetup: {
                                requestSuggestedSetup()
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
            .homesteadWallpaperBackground()
            .navigationTitle(dashboardConfiguration.selectedDashboard.resolvedDisplayTitle)
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
                    if dashboardConfiguration.setupState != .notChosen {
                        ToolbarItem(placement: .topBarTrailing) {
                            optionsMenu
                        }

                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        SettingsAccountButton()
                    }
                }
            }
            .sheet(item: $addSheetMode) { mode in
                DashboardAddItemView(initialMode: mode, onAddItem: dashboardItemWasAdded)
            }
            .sheet(item: $iconPickerContext) { context in
                DashboardIconPickerView(
                    defaultSystemName: context.defaultSystemName,
                    selectedSystemName: context.selectedSystemName,
                    recommendation: context.recommendation,
                    onSelectionChange: { iconName in
                        dashboardConfiguration.setIconNameOverride(iconName, forItemID: context.id)
                    }
                )
            }
            .sheet(item: $gaugeZoneEditorContext) { context in
                DashboardGaugeZoneEditorView(context: context) { configuration in
                    dashboardConfiguration.setGaugeZoneConfiguration(configuration, forItemID: context.id)
                } onReset: {
                    dashboardConfiguration.setGaugeZoneConfiguration(nil, forItemID: context.id)
                }
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
            .confirmationDialog(
                "Replace Dashboard?",
                isPresented: $isConfirmingSuggestedSetup,
                titleVisibility: .visible
            ) {
                Button("Use Suggested Setup", role: .destructive) {
                    applySuggestedSetup()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This replaces the cards currently saved to this dashboard.")
            }
            .onAppear {
                reconcileDashboardConfigurationIfReady()
            }
            .onChange(of: stateStore.entityCatalogSignature) { _, _ in
                reconcileDashboardConfigurationIfReady()
            }
            .onChange(of: stateStore.hasLoadedInitialSnapshot) { _, _ in
                reconcileDashboardConfigurationIfReady()
            }
            .onChange(of: stateStore.hasEntities) { _, _ in
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

    private var hasHomeAssistantSession: Bool {
        connectionSettings.hasServerURL && homeAssistantService.authState.isSignedIn
    }

    private var showsInitialSnapshotFailure: Bool {
        guard case .failed = homeAssistantService.connectionStatus else {
            return false
        }

        return homeAssistantService.hasCompletedInitialCacheLoad
            && !homeAssistantService.isLoadingCachedStates
    }
    
    private var visibleDashboardItems: [DashboardItemConfiguration] {
        return dashboardConfiguration
            .visibleItems(fromAvailableEntityIDs: stateStore.availableEntityIDs)
            .compactMap { item in
                guard item.role == .card, let entityID = item.entityID else {
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
            item.role == .chip ? nil : item.id
        }
    }

    private var activeDashboardGridItemIDs: [UUID] {
        gridDragState.previewItemIDs ?? visibleDashboardGridItemIDs
    }

    private var visibleDashboardChipItemIDs: [UUID] {
        visibleDashboardItems.compactMap { item in
            item.role == .chip ? item.id : nil
        }
    }

    private var activeDashboardChipItemIDs: [UUID] {
        chipDragState.previewItemIDs ?? visibleDashboardChipItemIDs
    }

    private func reconcileDashboardConfigurationIfReady() {
        guard stateStore.hasEntities else {
            return
        }
        
        dashboardConfiguration.reconcile(with: stateStore.allEntityBoxes())
        dashboardReconciliationGeneration &+= 1
    }

    private func requestSuggestedSetup() {
        if dashboardConfiguration.items.isEmpty {
            applySuggestedSetup()
        } else {
            isConfirmingSuggestedSetup = true
        }
    }

    private func applySuggestedSetup() {
        let applied = dashboardConfiguration.applySuggestedSetup(
            using: stateStore.dashboardSuggestionCandidates()
        )
        if !applied {
            addSheetMode = .items
        }
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
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.32)) {
                scrollProxy.scrollTo(dashboardScrollID(for: itemID), anchor: .center)
            }
            pendingScrollDashboardItemID = nil
        }
    }

    private func dashboardScrollID(for itemID: UUID) -> String {
        switch dashboardConfiguration.itemRole(for: itemID) {
        case .heading:
            "header-\(itemID)"
        case .card:
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

        displayTitleDraft = item.displayNameOverride
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

        dashboardConfiguration.renameDisplayItem(
            id: renamingDisplayItemID,
            displayNameOverride: displayTitleDraft
        )
        self.renamingDisplayItemID = nil
        displayTitleDraft = ""
    }

    private func resetEntityRename() {
        guard let renamingDisplayItemID else {
            return
        }

        dashboardConfiguration.renameDisplayItem(id: renamingDisplayItemID, displayNameOverride: nil)
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
                        gridDragState.itemFrames = frames
                    }
                    .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: activeDashboardGridItemIDs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func orderedGridItems(_ gridItems: [DashboardLayoutItem]) -> [DashboardLayoutItem] {
        guard let previewGridItemIDs = gridDragState.previewItemIDs else {
            return gridItems
        }

        let itemsByID = Dictionary(uniqueKeysWithValues: gridItems.map { ($0.configurationItemID, $0) })
        let previewItems = previewGridItemIDs.compactMap { itemsByID[$0] }
        let previewIDSet = Set(previewGridItemIDs)
        let remainingItems = gridItems.filter { !previewIDSet.contains($0.configurationItemID) }
        return previewItems + remainingItems
    }

    private func orderedChipItems(_ chipItems: [DashboardChipItem]) -> [DashboardChipItem] {
        guard let previewChipItemIDs = chipDragState.previewItemIDs else {
            return chipItems
        }

        let itemsByID = Dictionary(uniqueKeysWithValues: chipItems.map { ($0.id, $0) })
        let previewItems = previewChipItemIDs.compactMap { itemsByID[$0] }
        let previewIDSet = Set(previewChipItemIDs)
        let remainingItems = chipItems.filter { !previewIDSet.contains($0.id) }
        return previewItems + remainingItems
    }

    private func draggedGridItem(from gridItems: [DashboardLayoutItem]) -> DashboardLayoutItem? {
        guard let draggingGridItemID = gridDragState.draggingItemID else {
            return nil
        }

        return gridItems.first { $0.configurationItemID == draggingGridItemID }
    }

    private func draggedChipItem(from chipItems: [DashboardChipItem]) -> DashboardChipItem? {
        guard let draggingChipItemID = chipDragState.draggingItemID else {
            return nil
        }

        return chipItems.first { $0.id == draggingChipItemID }
    }

    private func dashboardChipSummaryRow(items: [DashboardChipItem]) -> some View {
        let renderedChipItems = orderedChipItems(items)
        let summaryWorkspace = stateStore.dashboardSummaryWorkspace()

        return ScrollView(.horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                ForEach(renderedChipItems) { chipItem in
                    dashboardChip(chipItem, summaryWorkspace: summaryWorkspace)
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .coordinateSpace(name: DashboardChipCoordinateSpace.name)
            .overlay(alignment: .topLeading) {
                if let draggedChipItem = draggedChipItem(from: items) {
                    dashboardChipDragPreview(draggedChipItem)
                }
            }
            .onPreferenceChange(DashboardChipItemFramePreferenceKey.self) { frames in
                chipDragState.itemFrames = frames
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: activeDashboardChipItemIDs)
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -AppSpacing.large)
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
                    presentationKind: item.presentationKind,
                    displayNameOverride: currentCardDisplayNameOverride(for: item),
                    iconNameOverride: item.iconNameOverride,
                    gaugeZoneConfiguration: item.gaugeZoneConfiguration,
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
                presentationKind: item.presentationKind,
                displayNameOverride: currentCardDisplayNameOverride(for: item),
                iconNameOverride: item.iconNameOverride,
                gaugeZoneConfiguration: item.gaugeZoneConfiguration,
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
        let isDragging = gridDragState.draggingItemID == itemID
        return content()
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .dashboardGridItemFrame(id: itemID)
            .dashboardHighlightBorder(isHighlighted: highlightedDashboardItemID == itemID)
            .opacity(isDragging ? 0 : 1)
            .dashboardLongPressDragSurface(
                isEnabled: gridDragState.draggingItemID.map { $0 == itemID } ?? true,
                autoScrollAxes: .vertical,
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
        if let dragStartFrame = gridDragState.dragStartFrame {
            dashboardGridPreviewContent(for: item)
                .frame(width: dragStartFrame.width, height: dragStartFrame.height)
                .scaleEffect(gridDragScale)
                .offset(
                    x: dragStartFrame.minX + gridDragState.activeTranslation.width,
                    y: dragStartFrame.minY + gridDragState.activeTranslation.height
                )
                .shadow(
                    color: Color.black.opacity(gridDragShadowOpacity),
                    radius: reduceMotion ? 0 : 16,
                    x: 0,
                    y: reduceMotion ? 0 : 8
                )
                .allowsHitTesting(false)
                .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: gridDragState.phase)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(20)
        }
    }

    private var gridDragScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return gridDragState.phase == .dragging ? 1.035 : 1
    }

    private var gridDragShadowOpacity: Double {
        guard !reduceMotion else { return 0 }
        return gridDragState.phase == .dragging ? 0.18 : 0.04
    }

    @ViewBuilder
    private func dashboardGridPreviewContent(for item: DashboardLayoutItem) -> some View {
        switch item.kind {
        case .header(let configurationItem):
            DashboardHeaderCardView(title: configurationItem.resolvedTitle)
                .frame(maxWidth: .infinity)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.16), lineWidth: 0.5)
                }
        case .card(let cardItem):
            DashboardCardView(
                entityID: cardItem.entityID,
                size: cardItem.size,
                presentationKind: cardItem.presentationKind,
                displayNameOverride: currentCardDisplayNameOverride(for: cardItem),
                iconNameOverride: cardItem.iconNameOverride,
                gaugeZoneConfiguration: cardItem.gaugeZoneConfiguration,
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
        if gridDragState.draggingItemID != itemID {
            gridDragCleanupTask?.cancel()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                gridDragState.beginDragging(
                    itemID: itemID,
                    itemIDs: visibleDashboardGridItemIDs,
                    frame: gridDragState.itemFrames[itemID]
                )
            }
            HapticFeedback.impact(.light)
        }

        withTransaction(Transaction(animation: nil)) {
            gridDragState.activeTranslation = translation
        }

        let targetItemID = dashboardGridInsertionTargetID(
            for: itemID,
            translation: translation,
            sourceFrame: gridDragState.dragStartFrame
        )

        let baseItemIDs = gridDragState.dragStartItemIDs.isEmpty ? visibleDashboardGridItemIDs : gridDragState.dragStartItemIDs
        let updatedPreviewItemIDs = reorderedGridItemIDs(
            moving: itemID,
            before: targetItemID,
            in: baseItemIDs
        )

        guard updatedPreviewItemIDs != gridDragState.previewItemIDs else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            gridDragState.previewItemIDs = updatedPreviewItemIDs
        }
    }

    private func dashboardGridInsertionTargetID(
        for movingItemID: UUID,
        translation: CGSize,
        sourceFrame: CGRect?
    ) -> UUID? {
        guard let movingFrame = sourceFrame ?? gridDragState.itemFrames[movingItemID] else {
            return nil
        }

        let dragCenter = CGPoint(
            x: movingFrame.midX + translation.width,
            y: movingFrame.midY + translation.height
        )
        let candidates = activeDashboardGridItemIDs.compactMap { itemID -> (id: UUID, frame: CGRect)? in
            guard itemID != movingItemID,
                  let frame = gridDragState.itemFrames[itemID] else {
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
            sourceFrame: gridDragState.dragStartFrame
        )
        let visibleItemIDs = gridDragState.dragStartItemIDs.isEmpty ? visibleDashboardGridItemIDs : gridDragState.dragStartItemIDs

        let dropTranslation = dashboardGridDropTranslation(
            for: itemID,
            fallback: translation
        )

        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            gridDragState.activeTranslation = dropTranslation
            gridDragState.phase = .dropping
            dashboardConfiguration.moveVisibleGridItem(
                id: itemID,
                before: targetItemID,
                visibleGridItemIDs: visibleItemIDs
            )
        }

        HapticFeedback.selection()
        scheduleDashboardGridDragCleanup()
    }

    private func endDashboardGridDrag() {
        gridDragCleanupTask?.cancel()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
            gridDragState.reset()
        }
    }

    private func dashboardGridDropTranslation(
        for itemID: UUID,
        fallback translation: CGSize
    ) -> CGSize {
        guard let dragStartFrame = gridDragState.dragStartFrame,
              let targetFrame = gridDragState.itemFrames[itemID] else {
            return translation
        }

        return CGSize(
            width: targetFrame.minX - dragStartFrame.minX,
            height: targetFrame.minY - dragStartFrame.minY
        )
    }

    private func scheduleDashboardGridDragCleanup() {
        gridDragCleanupTask?.cancel()
        gridDragCleanupTask = Task { @MainActor in
            try? await Task.sleep(
                for: reduceMotion
                    ? DashboardDragTiming.reducedMotionCleanupDelay
                    : DashboardDragTiming.cleanupDelay
            )
            guard !Task.isCancelled else { return }
            gridDragState.reset()
        }
    }

    @ViewBuilder
    private func dashboardChipDragPreview(_ item: DashboardChipItem) -> some View {
        let summaryWorkspace = stateStore.dashboardSummaryWorkspace()

        if let dragStartChipFrame = chipDragState.dragStartFrame,
           let presentation = chipPresentation(for: item, summaryWorkspace: summaryWorkspace) {
            DashboardChipView(presentation: presentation)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .frame(width: dragStartChipFrame.width, height: dragStartChipFrame.height)
                .scaleEffect(chipDragScale)
                .offset(
                    x: dragStartChipFrame.minX + chipDragState.activeTranslation.width,
                    y: dragStartChipFrame.minY
                )
                .shadow(
                    color: Color.black.opacity(chipDragShadowOpacity),
                    radius: reduceMotion ? 0 : 10,
                    x: 0,
                    y: reduceMotion ? 0 : 5
                )
                .allowsHitTesting(false)
                .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: chipDragState.phase)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(20)
        }
    }

    private var chipDragScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return chipDragState.phase == .dragging ? 1.04 : 1
    }

    private var chipDragShadowOpacity: Double {
        guard !reduceMotion else { return 0 }
        return chipDragState.phase == .dragging ? 0.14 : 0.03
    }

    private func updateDashboardChipDrag(itemID: UUID, translation: CGSize) {
        if chipDragState.draggingItemID != itemID {
            chipDragCleanupTask?.cancel()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                chipDragState.beginDragging(
                    itemID: itemID,
                    itemIDs: visibleDashboardChipItemIDs,
                    frame: chipDragState.itemFrames[itemID]
                )
            }
            HapticFeedback.impact(.light)
        }

        withTransaction(Transaction(animation: nil)) {
            chipDragState.activeTranslation = CGSize(width: translation.width, height: 0)
        }

        let targetItemID = dashboardChipInsertionTargetID(
            for: itemID,
            translation: chipDragState.activeTranslation,
            sourceFrame: chipDragState.dragStartFrame
        )

        let baseItemIDs = chipDragState.dragStartItemIDs.isEmpty ? visibleDashboardChipItemIDs : chipDragState.dragStartItemIDs
        let updatedPreviewItemIDs = reorderedGridItemIDs(
            moving: itemID,
            before: targetItemID,
            in: baseItemIDs
        )

        guard updatedPreviewItemIDs != chipDragState.previewItemIDs else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            chipDragState.previewItemIDs = updatedPreviewItemIDs
        }
    }

    private func dashboardChipInsertionTargetID(
        for movingItemID: UUID,
        translation: CGSize,
        sourceFrame: CGRect?
    ) -> UUID? {
        guard let movingFrame = sourceFrame ?? chipDragState.itemFrames[movingItemID] else {
            return nil
        }

        let dragCenterX = movingFrame.midX + translation.width
        let candidates = activeDashboardChipItemIDs.compactMap { itemID -> (id: UUID, frame: CGRect)? in
            guard itemID != movingItemID,
                  let frame = chipDragState.itemFrames[itemID] else {
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
            sourceFrame: chipDragState.dragStartFrame
        )
        let visibleItemIDs = chipDragState.dragStartItemIDs.isEmpty ? visibleDashboardChipItemIDs : chipDragState.dragStartItemIDs

        let dropTranslation = dashboardChipDropTranslation(
            for: itemID,
            fallback: horizontalTranslation
        )

        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            chipDragState.activeTranslation = dropTranslation
            chipDragState.phase = .dropping
            dashboardConfiguration.moveVisibleChipItem(
                id: itemID,
                before: targetItemID,
                visibleChipItemIDs: visibleItemIDs
            )
        }

        HapticFeedback.selection()
        scheduleDashboardChipDragCleanup()
    }

    private func endDashboardChipDrag() {
        chipDragCleanupTask?.cancel()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
            chipDragState.reset()
        }
    }

    private func dashboardChipDropTranslation(
        for itemID: UUID,
        fallback translation: CGSize
    ) -> CGSize {
        guard let dragStartChipFrame = chipDragState.dragStartFrame,
              let targetFrame = chipDragState.itemFrames[itemID] else {
            return translation
        }

        return CGSize(width: targetFrame.minX - dragStartChipFrame.minX, height: 0)
    }

    private func scheduleDashboardChipDragCleanup() {
        chipDragCleanupTask?.cancel()
        chipDragCleanupTask = Task { @MainActor in
            try? await Task.sleep(
                for: reduceMotion
                    ? DashboardDragTiming.reducedMotionCleanupDelay
                    : DashboardDragTiming.cleanupDelay
            )
            guard !Task.isCancelled else { return }
            chipDragState.reset()
        }
    }

    @ViewBuilder
    private func dashboardChip(
        _ item: DashboardChipItem,
        summaryWorkspace: DashboardSummaryWorkspace
    ) -> some View {
        let presentation = chipPresentation(for: item, summaryWorkspace: summaryWorkspace)

        if let presentation {
            if isEditingDashboard {
                editableDashboardChip(item: item, presentation: presentation)
            } else {
                switch item.source {
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
                            chipEditMenuContent(for: item)
                        }
                    }
                case .entity:
                    DashboardChipView(presentation: presentation)
                        .contextMenu {
                            chipEditMenuContent(for: item)
                        }
                }
            }
        }
    }

    private func editableDashboardChip(
        item: DashboardChipItem,
        presentation: DashboardChipPresentation
    ) -> some View {
        let isDragging = chipDragState.draggingItemID == item.id
        return DashboardChipView(presentation: presentation)
            .contentShape(Capsule())
            .dashboardChipItemFrame(id: item.id)
            .opacity(isDragging ? 0 : 1)
            .dashboardLongPressDragSurface(
                isEnabled: chipDragState.draggingItemID.map { $0 == item.id } ?? true,
                autoScrollAxes: .horizontal,
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
                chipEditMenuContent(for: item)
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
            get: { dashboardConfiguration.cardConfiguration(forItemID: item.id)?.layout ?? item.size },
            set: { size in
                HapticFeedback.selection()
                dashboardConfiguration.setCardLayout(size, forItemID: item.id)
            }
        )) {
            ForEach(DashboardPresentationCatalog.descriptor(for: item.presentationKind).supportedLayouts, id: \.self) { option in
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

        if [.circularGauge, .segmentedGauge, .barGauge].contains(item.presentationKind) {
            Button {
                presentGaugeZoneEditor(for: item)
            } label: {
                Label("Gauge Setup", systemImage: "dial.medium")
            }
        }

        Button {
            presentIconPicker(for: item)
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
    private func chipEditMenuContent(for item: DashboardChipItem) -> some View {
        Button {
            beginRenamingChip(item)
        } label: {
            Label("Rename Chip", systemImage: "pencil")
        }

        Button {
            presentIconPicker(for: item)
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

    private func presentIconPicker(for item: DashboardCardItem) {
        let entity = stateStore.entity(for: item.entityID)
        iconPickerContext = DashboardIconPickerContext(
            id: item.id,
            defaultSystemName: entity?.iconName ?? "square.grid.2x2",
            selectedSystemName: item.iconNameOverride,
            recommendation: .domain(entity?.domain ?? EntityDomain(entityID: item.entityID))
        )
    }

    private func presentGaugeZoneEditor(for item: DashboardCardItem) {
        guard let presentation = stateStore.entityBox(for: item.entityID)?.sensorEntity?.gaugePresentation else { return }
        let storedConfiguration = item.gaugeZoneConfiguration.flatMap { $0.isValid ? $0 : nil }
        gaugeZoneEditorContext = DashboardGaugeZoneEditorContext(
            id: item.id,
            presentation: presentation,
            kind: item.presentationKind,
            configuration: storedConfiguration ?? .defaults(for: presentation)
        )
    }

    private func presentIconPicker(for item: DashboardChipItem) {
        switch item.source {
        case .summary:
            guard let summaryKind = item.summaryKind else { return }
            iconPickerContext = DashboardIconPickerContext(
                id: item.id,
                defaultSystemName: summaryKind.systemImage,
                selectedSystemName: item.iconNameOverride,
                recommendation: .summary(summaryKind)
            )
        case .entity:
            guard let entityID = item.entityID else { return }
            let entity = stateStore.entity(for: entityID)
            iconPickerContext = DashboardIconPickerContext(
                id: item.id,
                defaultSystemName: entity?.iconName ?? "square.grid.2x2",
                selectedSystemName: item.iconNameOverride,
                recommendation: .domain(entity?.domain ?? EntityDomain(entityID: entityID))
            )
        }
    }

    private func currentCardDisplayNameOverride(for item: DashboardCardItem) -> String? {
        item.displayNameOverride
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

    private func chipPresentation(
        for item: DashboardChipItem,
        summaryWorkspace: DashboardSummaryWorkspace
    ) -> DashboardChipPresentation? {
        switch item.source {
        case .summary:
            guard let summaryKind = item.summaryKind else { return nil }
            return DashboardSummaryProvider.makeSummary(
                kind: summaryKind,
                workspace: summaryWorkspace,
                titleOverride: item.displayNameOverride,
                iconNameOverride: item.iconNameOverride
            )
        case .entity:
            guard let entityID = item.entityID,
                  let entityBox = stateStore.entityBox(for: entityID) else {
                return nil
            }

            return DashboardSummaryProvider.makeEntityChip(
                entityBox: entityBox,
                titleOverride: item.displayNameOverride,
                iconNameOverride: item.iconNameOverride
            )
        }
    }

    private func defaultChipTitle(for item: DashboardChipItem) -> String {
        switch item.source {
        case .summary:
            item.summaryKind?.title ?? "Chip"
        case .entity:
            item.entityID.flatMap { entityID in
                stateStore.entity(for: entityID)?.displayName
            } ?? "Chip"
        }
    }
    
    // MARK: - Toolbar Menus

    private var optionsMenu: some View {
        Menu {
            Button {
                addSheetMode = .items
            } label: {
                Label("Add to Dashboard", systemImage: "rectangle.stack.badge.plus")
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

#if DEBUG
#Preview {
    NavigationStack {
        DashboardView()
    }
    .withPreviewEnvironment()
}
#endif
