import SwiftUI

// MARK: - Dashboard Settings View
struct DashboardSettingsView: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var namingAction: DashboardNamingAction?
    @State private var dashboardNameDraft = ""
    @State private var deletingDashboardID: UUID?
    @State private var selectedRoute: DashboardSettingsRoute?

    var body: some View {
        List {
            Section {
                ForEach(dashboardConfiguration.dashboards) { dashboard in
                    DashboardSettingsRow(
                        dashboard: dashboard,
                        isSelected: isSelected(dashboard),
                        openDetail: {
                            selectedRoute = .detail(dashboard.id)
                        },
                        useOnThisDevice: {
                            dashboardConfiguration.selectDashboard(id: dashboard.id)
                        },
                        rename: {
                            beginRenaming(dashboard)
                        },
                        duplicate: {
                            beginDuplicating(dashboard)
                        },
                        reorder: {
                            selectedRoute = .reorder
                        },
                        delete: {
                            deletingDashboardID = dashboard.id
                        },
                        showsReorder: dashboardConfiguration.dashboards.count > 1
                    )
                }
            } footer: {
                Text("Dashboards sync with iCloud. This device keeps its own current dashboard.")
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
        .navigationDestination(item: $selectedRoute) { route in
            switch route {
            case .detail(let dashboardID):
                if let dashboard = dashboardConfiguration.dashboards.first(where: { $0.id == dashboardID }) {
                    DashboardDetailSettingsView(
                        dashboard: dashboard,
                        isSelected: dashboard.id == dashboardConfiguration.selectedDashboardID,
                        useOnThisDevice: {
                            dashboardConfiguration.selectDashboard(id: dashboard.id)
                        },
                        rename: {
                            beginRenaming(dashboard)
                        },
                        duplicate: {
                            beginDuplicating(dashboard)
                        },
                        delete: {
                            deletingDashboardID = dashboard.id
                        }
                    )
                } else {
                    ContentUnavailableView("Dashboard Unavailable", systemImage: "rectangle.dashed")
                }
            case .reorder:
                DashboardReorderSettingsView()
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
                get: { deletingDashboardID != nil },
                set: { if !$0 { deletingDashboardID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Dashboard", role: .destructive) {
                if let deletingDashboardID {
                    dashboardConfiguration.deleteDashboard(id: deletingDashboardID)
                }
                deletingDashboardID = nil
            }

            Button("Cancel", role: .cancel) {
                deletingDashboardID = nil
            }
        }
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
        guard let dashboard = deletingDashboard else {
            return "Delete Dashboard?"
        }

        return "Delete \(dashboard.resolvedName)?"
    }

    private var deletingDashboard: SavedDashboardConfiguration? {
        guard let deletingDashboardID else {
            return nil
        }

        return dashboardConfiguration.dashboards.first { $0.id == deletingDashboardID }
    }

    private func isSelected(_ dashboard: SavedDashboardConfiguration) -> Bool {
        dashboard.id == dashboardConfiguration.selectedDashboardID
    }

    private func createDashboard() {
        dashboardNameDraft = "New Dashboard"
        namingAction = .create
    }

    private func beginDuplicating(_ dashboard: SavedDashboardConfiguration) {
        dashboardNameDraft = "Copy of \(dashboard.resolvedName)"
        namingAction = .duplicate(dashboard.id)
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
        case .duplicate(let dashboardID):
            dashboardConfiguration.duplicateDashboard(id: dashboardID, named: dashboardNameDraft)
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
    let openDetail: () -> Void
    let useOnThisDevice: () -> Void
    let rename: () -> Void
    let duplicate: () -> Void
    let reorder: () -> Void
    let delete: () -> Void
    let showsReorder: Bool

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Button(action: openDetail) {
                HStack(spacing: AppSpacing.medium) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(dashboard.resolvedName)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.vertical, AppSpacing.xSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(.plain)

            DashboardActionsMenu(
                isSelected: isSelected,
                useOnThisDevice: useOnThisDevice,
                rename: rename,
                duplicate: duplicate,
                reorder: reorder,
                delete: delete,
                showsReorder: showsReorder
            )
        }
    }
}

private struct DashboardActionsMenu: View {
    let isSelected: Bool
    let useOnThisDevice: () -> Void
    let rename: () -> Void
    let duplicate: () -> Void
    let reorder: () -> Void
    let delete: () -> Void
    let showsReorder: Bool

    var body: some View {
        Menu {
            if !isSelected {
                Button(action: useOnThisDevice) {
                    Label("Use on This Device", systemImage: "checkmark.circle")
                }
            }

            Button(action: rename) {
                Label("Rename", systemImage: "pencil")
            }

            Button(action: duplicate) {
                Label("Duplicate", systemImage: "square.on.square")
            }

            if showsReorder {
                Button(action: reorder) {
                    Label("Reorder Dashboards", systemImage: "line.3.horizontal")
                }
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

private struct DashboardDetailSettingsView: View {
    let dashboard: SavedDashboardConfiguration
    let isSelected: Bool
    let useOnThisDevice: () -> Void
    let rename: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    var body: some View {
        List {
            Section {
                DashboardPhonePreview(dashboard: dashboard)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                LabeledContent("Items", value: itemCountText)

                if isSelected {
                    LabeledContent("This Device", value: "Using")
                }
            }

            Section {
                if !isSelected {
                    Button(action: useOnThisDevice) {
                        Label("Use on This Device", systemImage: "checkmark.circle")
                    }
                }

                Button(action: rename) {
                    Label("Rename", systemImage: "pencil")
                }

                Button(action: duplicate) {
                    Label("Duplicate", systemImage: "square.on.square")
                }

                Button(role: .destructive, action: delete) {
                    Label("Delete Dashboard", systemImage: "trash")
                }
            }
        }
        .navigationTitle(dashboard.resolvedName)
        .toolbarTitleDisplayMode(.inline)
    }

    private var itemCountText: String {
        let count = dashboard.items.count
        return count == 1 ? "1 item" : "\(count) items"
    }
}

private struct DashboardReorderSettingsView: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(dashboardConfiguration.dashboards) { dashboard in
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(dashboard.id == dashboardConfiguration.selectedDashboardID ? Color.accentColor : Color.clear)
                        .frame(width: 24)

                    Text(dashboard.resolvedName)
                }
            }
            .onMove { source, destination in
                dashboardConfiguration.moveDashboards(from: source, to: destination)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Reorder Dashboards")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

private struct DashboardPhonePreview: View {
    let dashboard: SavedDashboardConfiguration

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.small) {
                Capsule()
                    .fill(.secondary.opacity(0.28))
                    .frame(width: 40, height: 5)
                    .padding(.top, AppSpacing.medium)

                HStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.primary.opacity(0.18))
                        .frame(width: 70, height: 8)

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.medium)

                DashboardLayoutPreview(dashboard: dashboard)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.large)
            }
            .frame(width: 176)
            .frame(minHeight: 276, alignment: .top)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.large)
    }
}

private struct DashboardLayoutPreview: View {
    let dashboard: SavedDashboardConfiguration

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 4)

    var body: some View {
        if dashboard.items.isEmpty {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(height: 150)
                .overlay {
                    Text("No Cards")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
                ForEach(dashboard.items.prefix(18)) { item in
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
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 42, height: 5)
                        .padding(.horizontal, 5)
                }
            }
            .frame(height: height)
    }

    private var fillStyle: Color {
        switch item.type {
        case .entity:
            Color.secondary.opacity(0.2)
        case .header:
            Color.clear
        case .chip:
            Color.accentColor.opacity(0.16)
        }
    }

    private var height: CGFloat {
        switch item.type {
        case .entity:
            CGFloat(item.layoutMetadata.rowSpan) * 24
        case .header, .chip:
            18
        }
    }

    private var cornerRadius: CGFloat {
        item.type == .chip ? 9 : 7
    }
}

private enum DashboardSettingsRoute: Hashable, Identifiable {
    case detail(UUID)
    case reorder

    var id: String {
        switch self {
        case .detail(let dashboardID):
            "detail-\(dashboardID.uuidString)"
        case .reorder:
            "reorder"
        }
    }
}

private enum DashboardNamingAction: Equatable {
    case create
    case duplicate(UUID)
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
