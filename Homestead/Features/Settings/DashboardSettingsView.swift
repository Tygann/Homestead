import SwiftUI

// MARK: - Dashboard Settings View
struct DashboardSettingsView: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var namingAction: DashboardNamingAction?
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
                    Label("Duplicate Dashboard", systemImage: "square.on.square")
                }
            } footer: {
                Text("Dashboards sync with iCloud. This device keeps its own current dashboard.")
            }

            Section("Saved Dashboards") {
                ForEach(dashboardConfiguration.dashboards) { dashboard in
                    DashboardSettingsRow(
                        dashboard: dashboard,
                        isSelected: dashboard.id == dashboardConfiguration.selectedDashboardID,
                        select: {
                            dashboardConfiguration.selectDashboard(id: dashboard.id)
                        },
                        rename: {
                            beginRenaming(dashboard)
                        },
                        delete: {
                            deletingDashboard = dashboard
                        }
                    )
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
        .alert(namingDialogTitle, isPresented: isNamingDashboard) {
            TextField("Name", text: $dashboardNameDraft)

            Button("Cancel", role: .cancel) {
                resetNamingState()
            }

            Button(namingDialogPrimaryActionTitle, role: .confirm) {
                commitDashboardName()
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

    private var isNamingDashboard: Binding<Bool> {
        Binding(
            get: { namingAction != nil },
            set: { isPresented in
                if !isPresented {
                    resetNamingState()
                }
            }
        )
    }

    private var namingDialogTitle: String {
        switch namingAction {
        case .create:
            return "New Dashboard"
        case .duplicate:
            return "Duplicate Dashboard"
        case .rename:
            return "Rename Dashboard"
        case nil:
            return "Dashboard Name"
        }
    }

    private var namingDialogPrimaryActionTitle: String {
        switch namingAction {
        case .create, .duplicate:
            return "Create"
        case .rename:
            return "Save"
        case nil:
            return "Save"
        }
    }

    private var deleteDialogTitle: String {
        guard let deletingDashboard else {
            return "Delete Dashboard?"
        }

        return "Delete \(deletingDashboard.resolvedName)?"
    }

    private func createDashboard() {
        dashboardNameDraft = "New Dashboard"
        namingAction = .create
    }

    private func duplicateCurrentDashboard() {
        dashboardNameDraft = "Copy of \(dashboardConfiguration.selectedDashboard.resolvedName)"
        namingAction = .duplicate
    }

    private func beginRenaming(_ dashboard: SavedDashboardConfiguration) {
        dashboardNameDraft = dashboard.resolvedName
        namingAction = .rename(dashboard.id)
    }

    private func commitDashboardName() {
        guard let namingAction else {
            return
        }

        switch namingAction {
        case .create:
            dashboardConfiguration.createDashboard(named: dashboardNameDraft)
        case .duplicate:
            let dashboardID = dashboardConfiguration.duplicateSelectedDashboard()
            dashboardConfiguration.renameDashboard(id: dashboardID, name: dashboardNameDraft)
        case .rename(let dashboardID):
            dashboardConfiguration.renameDashboard(id: dashboardID, name: dashboardNameDraft)
        }

        resetNamingState()
    }

    private func resetNamingState() {
        namingAction = nil
        dashboardNameDraft = ""
    }
}

private struct DashboardSettingsRow: View {
    let dashboard: SavedDashboardConfiguration
    let isSelected: Bool
    let select: () -> Void
    let rename: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Button(action: select) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)

            Menu {
                Button(action: select) {
                    Label("Make Current", systemImage: "checkmark.circle")
                }

                Button(action: rename) {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive, action: delete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Dashboard Options")
        }
    }

    private var itemCountText: String {
        let count = dashboard.items.count
        return count == 1 ? "1 item" : "\(count) items"
    }
}

private enum DashboardNamingAction: Equatable {
    case create
    case duplicate
    case rename(UUID)
}

#if DEBUG
#Preview {
    NavigationStack {
        DashboardSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
