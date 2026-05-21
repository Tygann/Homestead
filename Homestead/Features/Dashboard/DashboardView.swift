import SwiftUI

struct DashboardView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var isEditingDashboard = false

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.medium),
        GridItem(.flexible(), spacing: AppSpacing.medium)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if !stateStore.hasEntities {
                    EmptyDashboardCard()
                } else if visibleEntityIDs.isEmpty {
                    EmptyConfiguredDashboardCard {
                        dashboardConfiguration.reset(using: stateStore.allEntities)
                    }
                } else {
                    favoritesSection
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Homestead")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                optionsMenu
            }
        }
        .sheet(isPresented: $isEditingDashboard) {
            DashboardEditView()
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

    private var favoritesSection: some View {
        DashboardSection(isEmpty: visibleEntityIDs.isEmpty) {
            LazyVGrid(columns: columns, spacing: AppSpacing.medium) {
                ForEach(visibleEntityIDs, id: \.self) { entityID in
                    DashboardCardView(
                        entityID: entityID,
                        size: dashboardConfiguration.cardSize(for: entityID)
                    )
                }
            }
        }
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
    let reset: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                CardIconView(systemName: "square.grid.2x2")
                Text("No cards selected")
                    .font(.headline)
                Text("Add cards from the Home options menu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Restore Suggested Cards", action: reset)
                    .buttonStyle(.borderedProminent)
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
