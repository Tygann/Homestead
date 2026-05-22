import SwiftUI

struct DashboardView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var isEditingDashboard = false
    @State private var isShowingAddCardSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if !stateStore.hasEntities {
                    EmptyDashboardCard()
                } else if visibleEntityIDs.isEmpty {
                    EmptyConfiguredDashboardCard(
                        isEditing: isEditingDashboard,
                        addCards: {
                            isShowingAddCardSheet = true
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
                        isShowingAddCardSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(availableEntityIDsToAdd.isEmpty)
                    .accessibilityLabel("Add dashboard card")

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
        .onAppear {
            dashboardConfiguration.reconcile(with: stateStore.allEntities)
        }
        .onChange(of: stateStore.entityCatalogSignature) { _, _ in
            dashboardConfiguration.reconcile(with: stateStore.allEntities)
        }
    }

    private var visibleEntityIDs: [String] {
        dashboardConfiguration.visibleEntityIDs(fromAvailableEntityIDs: stateStore.availableEntityIDs)
    }

    private var availableEntityIDsToAdd: Set<String> {
        dashboardConfiguration.addableEntityIDs(fromAvailableEntityIDs: stateStore.availableEntityIDs)
    }

    private var favoritesSection: some View {
        DashboardSection(isEmpty: visibleEntityIDs.isEmpty) {
            LazyVStack(spacing: AppSpacing.medium) {
                ForEach(cardRows) { row in
                    if row.isWide {
                        dashboardCard(row.items[0])
                    } else {
                        HStack(spacing: AppSpacing.medium) {
                            ForEach(row.items) { item in
                                dashboardCard(item)
                            }

                            if row.items.count == 1 {
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardRows: [DashboardCardRow] {
        var rows: [DashboardCardRow] = []
        var pendingHalfWidthItems: [DashboardCardItem] = []

        for entityID in visibleEntityIDs {
            let item = DashboardCardItem(
                entityID: entityID,
                size: dashboardConfiguration.cardSize(for: entityID)
            )

            if item.size == .wide {
                if !pendingHalfWidthItems.isEmpty {
                    rows.append(DashboardCardRow(items: pendingHalfWidthItems))
                    pendingHalfWidthItems.removeAll()
                }

                rows.append(DashboardCardRow(items: [item]))
            } else {
                pendingHalfWidthItems.append(item)

                if pendingHalfWidthItems.count == 2 {
                    rows.append(DashboardCardRow(items: pendingHalfWidthItems))
                    pendingHalfWidthItems.removeAll()
                }
            }
        }

        if !pendingHalfWidthItems.isEmpty {
            rows.append(DashboardCardRow(items: pendingHalfWidthItems))
        }

        return rows
    }

    private func dashboardCard(_ item: DashboardCardItem) -> some View {
        DashboardCardView(
            entityID: item.entityID,
            size: item.size,
            isEditing: isEditingDashboard,
            setSize: isEditingDashboard ? { size in
                dashboardConfiguration.setCardSize(size, for: item.entityID)
            } : nil,
            remove: isEditingDashboard ? {
                dashboardConfiguration.remove(item.entityID)
            } : nil
        )
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Options Menu
    private var optionsMenu: some View {
        Menu {
            Section {
                Label(homeAssistantService.connectionStatus.title, systemImage: homeAssistantService.connectionStatus.systemImage)

                Button(action: {
                    Task { await homeAssistantService.connectIfPossible(settings: connectionSettings) }
                }) {
                    Label("Reconnect", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!connectionSettings.hasCredentials || homeAssistantService.connectionStatus == .connected)
            }

            Section {
                Button(action: {
                    isEditingDashboard = true
                }) {
                    Label("Edit Home View", systemImage: "square.grid.2x2")
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

private struct DashboardCardRow: Identifiable {
    let items: [DashboardCardItem]

    var id: String {
        items.map(\.entityID).joined(separator: "|")
    }

    var isWide: Bool {
        items.count == 1 && items[0].size == .wide
    }
}

private struct DashboardCardItem: Identifiable {
    let entityID: String
    let size: DashboardCardSize

    var id: String {
        entityID
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

private struct EmptyDashboardCard: View {
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "house")
                Text("No Home Assistant entities yet")
                    .font(.headline)
                Text("Add your server URL and token in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EmptyConfiguredDashboardCard: View {
    let isEditing: Bool
    let addCards: () -> Void
    let reset: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "square.grid.2x2")
                Text("No cards selected")
                    .font(.headline)
                Text(isEditing ? "Use the plus button to add cards." : "Choose Edit Home View to add cards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: AppSpacing.small) {
                    if isEditing {
                        Button("Add Cards", systemImage: "plus", action: addCards)
                            .buttonStyle(.borderedProminent)

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
