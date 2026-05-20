import SwiftUI

struct DashboardView: View {
    @Environment(HAStateStore.self) private var stateStore
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var isEditingDashboard = false

    private let adaptiveColumns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: AppSpacing.large)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                if stateStore.allEntities.isEmpty {
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await homeAssistantService.connectIfPossible(settings: connectionSettings) }
                } label: {
                    Image(systemName: homeAssistantService.connectionStatus.systemImage)
                }
                .accessibilityLabel(homeAssistantService.connectionStatus.title)
            }
            // Options Button
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
        .onChange(of: stateStore.allEntities) { _, entities in
            dashboardConfiguration.reconcile(with: entities)
        }
    }

    private var visibleEntityIDs: [String] {
        dashboardConfiguration.visibleEntityIDs(from: stateStore.allEntities)
    }

    private var favoritesSection: some View {
        DashboardSection(title: "Favorites", isEmpty: visibleEntityIDs.isEmpty) {
            LazyVGrid(columns: adaptiveColumns, spacing: AppSpacing.large) {
                ForEach(visibleEntityIDs, id: \.self) { entityID in
                    DashboardCardView(entityID: entityID)
                }
            }
        }
    }
    
    // MARK: - Options Menu
    private var optionsMenu: some View {
        Menu {
            Section {
                Button(action: {
                    isEditingDashboard = true
                }) {
                    Label("Edit Home View", systemImage: "square.grid.2x2")
                }

                Button(action: {
                    dashboardConfiguration.reset(using: stateStore.allEntities)
                }) {
                    Label("Reset Home View", systemImage: "arrow.counterclockwise")
                }
                .disabled(stateStore.allEntities.isEmpty)
            }
        } label: {
            Image(systemName: "ellipsis")
                .bold()
        }
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    let isEmpty: Bool
    @ViewBuilder var content: Content

    var body: some View {
        if !isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(title)
                    .font(.title2.bold())

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
