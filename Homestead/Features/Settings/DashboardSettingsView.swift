import SwiftUI

// MARK: - Dashboard Settings View
struct DashboardSettingsView: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var renamingDashboardID: UUID?
    @State private var dashboardNameDraft = ""
    @State private var deletingDashboard: SavedDashboardConfiguration?

    var body: some View {
        Form {
            Section {
                Picker("Current Dashboard", selection: selectedDashboardBinding) {
                    ForEach(dashboardConfiguration.dashboards) { dashboard in
                        Text(dashboard.resolvedName).tag(dashboard.id)
                    }
                }
                .pickerStyle(.navigationLink)

                Button {
                    duplicateCurrentDashboard()
                } label: {
                    Label("Duplicate Current Dashboard", systemImage: "square.on.square")
                }
            }

            Section("Saved Dashboards") {
                ForEach(dashboardConfiguration.dashboards) { dashboard in
                    DashboardSettingsRow(
                        dashboard: dashboard,
                        isSelected: dashboard.id == dashboardConfiguration.selectedDashboardID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dashboardConfiguration.selectDashboard(id: dashboard.id)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            deletingDashboard = dashboard
                        }

                        Button("Rename") {
                            beginRenaming(dashboard)
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            dashboardConfiguration.selectDashboard(id: dashboard.id)
                        } label: {
                            Label("Make Current", systemImage: "checkmark.circle")
                        }

                        Button {
                            beginRenaming(dashboard)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            deletingDashboard = dashboard
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Dashboards")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createDashboard()
                } label: {
                    Label("New Dashboard", systemImage: "plus")
                }
            }
        }
        .alert("Dashboard Name", isPresented: isRenamingDashboard) {
            TextField("Name", text: $dashboardNameDraft)

            Button("Cancel", role: .cancel) {
                renamingDashboardID = nil
                dashboardNameDraft = ""
            }

            Button("Save", role: .confirm) {
                saveDashboardName()
            }
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { deletingDashboard != nil },
                set: { if !$0 { deletingDashboard = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Dashboard", role: .destructive) {
                if let deletingDashboard {
                    dashboardConfiguration.deleteDashboard(id: deletingDashboard.id)
                }
                deletingDashboard = nil
            }

            Button("Cancel", role: .cancel) {
                deletingDashboard = nil
            }
        }
    }

    private var selectedDashboardBinding: Binding<UUID> {
        Binding(
            get: { dashboardConfiguration.selectedDashboardID },
            set: { dashboardConfiguration.selectDashboard(id: $0) }
        )
    }

    private var isRenamingDashboard: Binding<Bool> {
        Binding(
            get: { renamingDashboardID != nil },
            set: { isPresented in
                if !isPresented {
                    renamingDashboardID = nil
                    dashboardNameDraft = ""
                }
            }
        )
    }

    private var deleteDialogTitle: String {
        guard let deletingDashboard else {
            return "Delete Dashboard?"
        }

        return "Delete \(deletingDashboard.resolvedName)?"
    }

    private func createDashboard() {
        let dashboardID = dashboardConfiguration.createDashboard()
        renamingDashboardID = dashboardID
        dashboardNameDraft = "New Dashboard"
    }

    private func duplicateCurrentDashboard() {
        let dashboardID = dashboardConfiguration.duplicateSelectedDashboard()
        if let dashboard = dashboardConfiguration.dashboards.first(where: { $0.id == dashboardID }) {
            dashboardNameDraft = dashboard.resolvedName
        }
        renamingDashboardID = dashboardID
    }

    private func beginRenaming(_ dashboard: SavedDashboardConfiguration) {
        renamingDashboardID = dashboard.id
        dashboardNameDraft = dashboard.resolvedName
    }

    private func saveDashboardName() {
        guard let renamingDashboardID else {
            return
        }

        dashboardConfiguration.renameDashboard(id: renamingDashboardID, name: dashboardNameDraft)
        self.renamingDashboardID = nil
        dashboardNameDraft = ""
    }
}

private struct DashboardSettingsRow: View {
    let dashboard: SavedDashboardConfiguration
    let isSelected: Bool

    var body: some View {
        Label {
            HStack(spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(dashboard.resolvedName)
                        .foregroundStyle(.primary)

                    Text(itemCountText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: "rectangle.grid.2x2")
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }

    private var itemCountText: String {
        let count = dashboard.items.count
        return count == 1 ? "1 item" : "\(count) items"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DashboardSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
