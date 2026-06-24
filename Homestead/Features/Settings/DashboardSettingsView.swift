import SwiftUI

// MARK: - Dashboard Settings View
struct DashboardSettingsView: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var namingAction: DashboardNamingAction?
    @State private var dashboardNameDraft = ""
    @State private var deletingDashboard: SavedDashboardConfiguration?
    @State private var previewingDashboardID: UUID?

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
                        preview: {
                            previewingDashboardID = dashboard.id
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
                            previewingDashboardID = dashboard.id
                        } label: {
                            Label("Preview", systemImage: "rectangle.inset.filled")
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
                .onMove { source, destination in
                    dashboardConfiguration.moveDashboards(from: source, to: destination)
                }
            }
        }
        .navigationTitle("Dashboards")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()

                Button {
                    createDashboard()
                } label: {
                    Label("New Dashboard", systemImage: "plus")
                }
            }
        }
        .navigationDestination(item: $previewingDashboardID) { dashboardID in
            if let dashboard = dashboardConfiguration.dashboards.first(where: { $0.id == dashboardID }) {
                DashboardPreviewDetailView(dashboard: dashboard)
            } else {
                ContentUnavailableView("Dashboard Unavailable", systemImage: "rectangle.dashed")
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
    let preview: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Button(action: select) {
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.clear)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(dashboard.resolvedName)
                            .foregroundStyle(.primary)

                        Text(itemCountText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, AppSpacing.xSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)

            Menu {
                Button(action: select) {
                    Label("Make Current", systemImage: "checkmark.circle")
                }

                Button(action: preview) {
                    Label("Preview", systemImage: "rectangle.inset.filled")
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

private struct DashboardPreviewDetailView: View {
    let dashboard: SavedDashboardConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                DashboardLayoutPreview(dashboard: dashboard)
                    .padding(AppSpacing.large)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(dashboard.resolvedName)
                        .font(.headline)

                    Text(itemCountText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppSpacing.large)
            }
            .padding(AppSpacing.large)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Preview")
        .toolbarTitleDisplayMode(.inline)
    }

    private var itemCountText: String {
        let count = dashboard.items.count
        return count == 1 ? "1 item" : "\(count) items"
    }
}

private struct DashboardLayoutPreview: View {
    let dashboard: SavedDashboardConfiguration

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        if dashboard.items.isEmpty {
            ContentUnavailableView("No Cards", systemImage: "rectangle.dashed")
                .frame(minHeight: 180)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(dashboard.items) { item in
                    DashboardLayoutPreviewTile(item: item)
                        .gridCellColumns(item.layoutMetadata.columnSpan)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Dashboard layout preview")
        }
    }
}

private struct DashboardLayoutPreviewTile: View {
    let item: DashboardItemConfiguration

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fillStyle)
            .overlay(alignment: .leading) {
                if item.type == .header {
                    Capsule()
                        .fill(.secondary.opacity(0.45))
                        .frame(width: 70, height: 6)
                        .padding(.horizontal, AppSpacing.small)
                }
            }
            .frame(height: height)
    }

    private var fillStyle: Color {
        switch item.type {
        case .entity:
            Color.secondary.opacity(0.22)
        case .header:
            Color.clear
        case .chip:
            Color.accentColor.opacity(0.18)
        }
    }

    private var height: CGFloat {
        switch item.type {
        case .entity:
            CGFloat(item.layoutMetadata.rowSpan) * 32
        case .header, .chip:
            24
        }
    }

    private var cornerRadius: CGFloat {
        item.type == .chip ? 12 : 8
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
