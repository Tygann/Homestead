import SwiftUI

struct DashboardView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var isEditingDashboard = false
    @State private var isShowingAddCardSheet = false
    @State private var isShowingReorderSheet = false
    @State private var renamingHeaderID: UUID?
    @State private var headerTitleDraft = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if !connectionSettings.hasCredentials {
                    DashboardSetupCard()
                } else if !stateStore.hasLoadedInitialSnapshot {
                    DashboardInitialSyncView(
                        connectionStatus: homeAssistantService.connectionStatus,
                        errorMessage: homeAssistantService.lastErrorMessage,
                        reconnect: {
                            Task { await homeAssistantService.connectIfPossible(settings: connectionSettings) }
                        }
                    )
                } else if !stateStore.hasEntities {
                    EmptyDashboardCard()
                } else if visibleDashboardItems.isEmpty {
                    EmptyConfiguredDashboardCard(
                        isEditing: isEditingDashboard,
                        addCards: {
                            isShowingAddCardSheet = true
                        },
                        addHeader: {
                            addHeaderAndRename()
                        },
                        reset: {
                            dashboardConfiguration.reset(using: stateStore.allEntities)
                        }
                    )
                } else {
                    favoritesSection
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Homestead")
        //        .navigationSubtitle(connectionSettings.baseURL)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            if isEditingDashboard {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        isShowingReorderSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .disabled(dashboardConfiguration.items.count < 2)
                    .accessibilityLabel("Reorder dashboard")

                    Menu {
                        Button {
                            isShowingAddCardSheet = true
                        } label: {
                            Label("Add Card", systemImage: "square.grid.2x2")
                        }
                        .disabled(availableEntityIDsToAdd.isEmpty)

                        Button {
                            addHeaderAndRename()
                        } label: {
                            Label("Add Header", systemImage: "textformat.size")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add dashboard item")
                    
                    Button("Done", role: .confirm) {
                        isEditingDashboard = false
                    }
                    .bold()
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    optionsMenu
                }
            }
        }
        .sheet(isPresented: $isShowingAddCardSheet) {
            DashboardAddCardView()
        }
        .sheet(isPresented: $isShowingReorderSheet) {
            DashboardReorderView()
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
        .onAppear {
            reconcileDashboardConfigurationIfReady()
        }
        .onChange(of: stateStore.entityCatalogSignature) { _, _ in
            reconcileDashboardConfigurationIfReady()
        }
    }
    
    private var visibleDashboardItems: [DashboardItemConfiguration] {
        dashboardConfiguration.visibleItems(fromAvailableEntityIDs: stateStore.availableEntityIDs)
    }
    
    private var availableEntityIDsToAdd: Set<String> {
        dashboardConfiguration.addableEntityIDs(fromAvailableEntityIDs: stateStore.availableEntityIDs)
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

    private func saveHeaderRename() {
        guard let renamingHeaderID else {
            return
        }

        dashboardConfiguration.renameHeader(id: renamingHeaderID, title: headerTitleDraft)
        self.renamingHeaderID = nil
        headerTitleDraft = ""
    }
    
    private var favoritesSection: some View {
        DashboardSection(isEmpty: visibleDashboardItems.isEmpty) {
            LazyVStack(spacing: AppSpacing.medium) {
                ForEach(cardLayoutSections) { section in
                    switch section.kind {
                    case .header(let item):
                        dashboardHeader(item)
                    case .wide(let item):
                        dashboardCard(item)
                    case .columns(let columns):
                        HStack(alignment: .top, spacing: AppSpacing.medium) {
                            ForEach(columns) { column in
                                VStack(spacing: AppSpacing.medium) {
                                    ForEach(column.items) { item in
                                        dashboardCard(item)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var cardLayoutSections: [DashboardCardLayoutSection] {
        var sections: [DashboardCardLayoutSection] = []
        var columns = [
            DashboardCardColumn(position: .leading),
            DashboardCardColumn(position: .trailing)
        ]
        
        func flushColumns() {
            guard columns.contains(where: { !$0.items.isEmpty }) else {
                return
            }
            
            sections.append(DashboardCardLayoutSection(kind: .columns(columns)))
            columns = [
                DashboardCardColumn(position: .leading),
                DashboardCardColumn(position: .trailing)
            ]
        }
        
        for configurationItem in visibleDashboardItems {
            switch configurationItem.type {
            case .header:
                flushColumns()
                sections.append(DashboardCardLayoutSection(kind: .header(configurationItem)))
            case .entity:
                guard let entityID = configurationItem.entityID else {
                    continue
                }

                let item = DashboardCardItem(
                    id: configurationItem.id,
                    entityID: entityID,
                    size: configurationItem.resolvedCardSize
                )

                if item.size.columnSpan == 2 {
                    flushColumns()
                    sections.append(DashboardCardLayoutSection(kind: .wide(item)))
                } else {
                    let targetColumnIndex = columns[0].height <= columns[1].height ? 0 : 1
                    columns[targetColumnIndex].append(item)
                }
            }
        }
        
        flushColumns()
        return sections
    }

    private func dashboardHeader(_ item: DashboardItemConfiguration) -> some View {
        DashboardHeaderCardView(
            title: item.resolvedTitle,
            isEditing: isEditingDashboard,
            rename: isEditingDashboard ? {
                beginRenamingHeader(item)
            } : nil,
            remove: isEditingDashboard ? {
                dashboardConfiguration.removeItem(id: item.id)
            } : nil
        )
        .frame(maxWidth: .infinity)
    }
    
    private func dashboardCard(_ item: DashboardCardItem) -> some View {
        DashboardCardView(
            entityID: item.entityID,
            size: item.size,
            isEditing: isEditingDashboard,
            setSize: isEditingDashboard ? { size in
                dashboardConfiguration.setCardSize(size, forItemID: item.id)
            } : nil,
            remove: isEditingDashboard ? {
                dashboardConfiguration.removeItem(id: item.id)
            } : nil
        )
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Options Menu
    private var optionsMenu: some View {
        Menu {
            Section {
                // Status row
                Label(homeAssistantService.connectionStatus.title,
                      systemImage: homeAssistantService.connectionStatus.systemImage)
                
                // Only show "Reconnect" when not connected and credentials exist
                if connectionSettings.hasCredentials && homeAssistantService.connectionStatus != .connected {
                    Button {
                        Task { await homeAssistantService.connectIfPossible(settings: connectionSettings) }
                    } label: {
                        Label("Reconnect", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            
            Section {
                Button {
                    isEditingDashboard = true
                } label: {
                    Label("Edit Dashboard", systemImage: "square.grid.2x2")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .bold()
        }
    }
}

private struct DashboardAddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    var body: some View {
        NavigationStack {
            EntityBrowserList(
                hiddenEntityIDs: selectedEntityIDs,
                emptyTitle: emptyTitle,
                emptySystemImage: emptySystemImage,
                rowAction: { entityBox in
                    dashboardConfiguration.add(entityBox.entityID)
                },
                accessory: { _ in
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            )
            .navigationTitle("Add Card")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private var selectedEntityIDs: Set<String> {
        stateStore.availableEntityIDs.subtracting(
            dashboardConfiguration.addableEntityIDs(fromAvailableEntityIDs: stateStore.availableEntityIDs)
        )
    }

    private var emptyTitle: String {
        stateStore.hasEntities ? "All Cards Added" : "No Devices"
    }

    private var emptySystemImage: String {
        stateStore.hasEntities ? "checkmark.circle" : "square.grid.2x2"
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
                    .bold()
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
            entityBox?.homeEntity.displayName ?? item.entityID ?? "Missing Entity"
        }
    }

    private var subtitle: String {
        switch item.type {
        case .header:
            "Header"
        case .entity:
            entityBox?.homeEntity.entityID ?? item.entityID ?? "Entity"
        }
    }

    private var systemImage: String {
        switch item.type {
        case .header:
            "textformat.size"
        case .entity:
            entityBox?.homeEntity.iconName ?? "square.grid.2x2"
        }
    }
}

private struct DashboardCardLayoutSection: Identifiable {
    enum Kind {
        case header(DashboardItemConfiguration)
        case wide(DashboardCardItem)
        case columns([DashboardCardColumn])
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .header(let item):
            "header-\(item.id)"
        case .wide(let item):
            "wide-\(item.id)"
        case .columns(let columns):
            "columns-\(columns.map(\.id).joined(separator: "|"))"
        }
    }
}

private struct DashboardCardColumn: Identifiable {
    enum Position: String {
        case leading
        case trailing
    }

    let position: Position
    private(set) var items: [DashboardCardItem] = []
    private(set) var height: CGFloat = 0

    var id: String {
        "\(position.rawValue)-\(items.map { $0.id.uuidString }.joined(separator: ","))"
    }

    mutating func append(_ item: DashboardCardItem) {
        if !items.isEmpty {
            height += AppSpacing.medium
        }

        items.append(item)
        height += item.size.renderedHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }
}

private struct DashboardCardItem: Identifiable {
    let id: UUID
    let entityID: String
    let size: DashboardCardSize
}

private struct DashboardHeaderCardView: View {
    let title: String
    let isEditing: Bool
    var rename: (() -> Void)?
    var remove: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: AppSpacing.medium)

            if isEditing {
                editControls
            }
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

    private var editControls: some View {
        HStack(spacing: AppSpacing.small) {
            if let rename {
                Button(action: rename) {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                }
                .glassEffect()
                .accessibilityLabel("Rename \(title)")
            }

            if let remove {
                Button(action: remove) {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                }
                .glassEffect()
                .accessibilityLabel("Remove \(title)")
            }
        }
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
                Text("Add your server URL and token in Settings.")
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

                HStack(alignment: .top, spacing: AppSpacing.medium) {
                    VStack(spacing: AppSpacing.medium) {
                        DashboardSkeletonCard(size: .large)
                        DashboardSkeletonCard(size: .compact)
                        DashboardSkeletonCard(size: .compact)
                    }

                    VStack(spacing: AppSpacing.medium) {
                        DashboardSkeletonCard(size: .large)
                        DashboardSkeletonCard(size: .compact)
                        DashboardSkeletonCard(size: .large)
                    }
                }
            }
            .opacity(isPulsing ? 0.46 : 0.72)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
        }
        .allowsHitTesting(false)
        .task {
            isPulsing = true
        }
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

                if size != .compact {
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
        case .compact:
            86
        case .large:
            112
        case .wide:
            154
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
                Text(isEditing ? "Use the plus button to add cards or headers." : "Choose Edit Home View to add cards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: AppSpacing.small) {
                    if isEditing {
                        Button("Add Cards", systemImage: "plus", action: addCards)
                            .buttonStyle(.borderedProminent)

                        Button("Add Header", systemImage: "textformat.size", action: addHeader)
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

#if DEBUG
#Preview {
    NavigationStack {
        DashboardView()
    }
    .withPreviewEnvironment()
}
#endif
