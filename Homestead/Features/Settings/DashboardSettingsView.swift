import SwiftUI

// MARK: - Dashboard Settings View
struct DashboardSettingsView: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var namingAction: DashboardNamingAction?
    @State private var dashboardNameDraft = ""
    @State private var deletingDashboardID: UUID?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
                ForEach(dashboardConfiguration.dashboards) { dashboard in
                    DashboardSettingsRow(
                        dashboard: dashboard,
                        isSelected: isSelected(dashboard),
                        rename: {
                            beginRenaming(dashboard)
                        },
                        duplicate: {
                            beginDuplicating(dashboard)
                        },
                        reorder: {
                            editMode = .active
                        },
                        delete: {
                            deletingDashboardID = dashboard.id
                        },
                        isReordering: editMode.isEditing,
                        showsReorder: dashboardConfiguration.dashboards.count > 1,
                        detail: {
                            dashboardDetail(for: dashboard.id)
                        }
                    )
                }
                .onMove { source, destination in
                    dashboardConfiguration.moveDashboards(from: source, to: destination)
                }
            } footer: {
                Text(
                    "Dashboard pages and their order sync with iCloud. "
                    + "Which pages appear on this device stays local. "
                    + "At least one dashboard must remain visible."
                )
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Dashboards")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if editMode.isEditing {
                    Button("Done") {
                        editMode = .inactive
                    }
                    .fontWeight(.semibold)
                } else {
                    Button {
                        createDashboard()
                    } label: {
                        Label("New Dashboard", systemImage: "plus")
                    }
                }
            }

            if dashboardConfiguration.dashboards.count > 1, !editMode.isEditing {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        editMode = .active
                    }
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
        dashboardNameDraft = "Dashboard"
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

    @ViewBuilder
    private func dashboardDetail(for dashboardID: UUID) -> some View {
        if let dashboard = dashboardConfiguration.dashboards.first(where: { $0.id == dashboardID }) {
            DashboardDetailSettingsView(
                dashboard: dashboard
            )
        } else {
            ContentUnavailableView("Dashboard Unavailable", systemImage: "rectangle.dashed")
        }
    }

}

private struct DashboardSettingsRow<Detail: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    let dashboard: SavedDashboardConfiguration
    let isSelected: Bool
    let rename: () -> Void
    let duplicate: () -> Void
    let reorder: () -> Void
    let delete: () -> Void
    let isReordering: Bool
    let showsReorder: Bool
    let detail: () -> Detail

    var body: some View {
        if isReordering {
            rowContent
        } else {
            ZStack(alignment: .trailing) {
                NavigationLink(destination: detail) {
                    DashboardSettingsRowLabel(
                        name: dashboard.resolvedName,
                        isSelected: isSelected
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 64)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens dashboard settings")

                dashboardToggle
                    .zIndex(1)
            }
            .contextMenu {
                dashboardActions
                    .preferredColorScheme(colorScheme)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete")
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.medium) {
            DashboardSettingsRowLabel(
                name: dashboard.resolvedName,
                isSelected: isSelected
            )

            Spacer(minLength: AppSpacing.medium)
            dashboardToggle
        }
    }

    private var dashboardToggle: some View {
        Toggle(
            "Show \(dashboard.resolvedName) on Home",
            isOn: Binding(
                get: { dashboardConfiguration.enabledDashboardIDs.contains(dashboard.id) },
                set: { isEnabled in
                    dashboardConfiguration.setDashboardEnabled(isEnabled, id: dashboard.id)
                }
            )
        )
        .labelsHidden()
        .buttonStyle(.borderless)
        .disabled(isEnabled && !dashboardConfiguration.canDisableDashboard(id: dashboard.id))
        .accessibilityLabel("Show \(dashboard.resolvedName) on Home")
        .accessibilityHint(
            isEnabled && !dashboardConfiguration.canDisableDashboard(id: dashboard.id)
                ? "At least one dashboard must remain visible"
                : "Controls whether this dashboard appears as a Home page"
        )
    }

    private var isEnabled: Bool {
        dashboardConfiguration.enabledDashboardIDs.contains(dashboard.id)
    }

    @ViewBuilder
    private var dashboardActions: some View {
        Section {
            Button(action: rename) {
                Label("Rename", systemImage: "pencil")
            }

            Button(action: duplicate) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
        }

        if showsReorder {
            Section {
                Button(action: reorder) {
                    Label("Reorder Dashboards", systemImage: "line.3.horizontal")
                }
            }
        }

        Section {
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct DashboardSettingsRowLabel: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 22)
                .accessibilityHidden(!isSelected)

            Text(name)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}

struct DashboardDetailSettingsView: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    let dashboard: SavedDashboardConfiguration

    @Environment(\.dismiss) private var dismiss
    @State private var namingAction: DashboardDetailNamingAction?
    @State private var dashboardNameDraft = ""
    @State private var isEditingDashboardTitle = false
    @State private var dashboardTitleDraft = ""
    @State private var isConfirmingDelete = false

    var body: some View {
        List {
            Section {
                SettingsDashboardPhonePreview(
                    width: 178,
                    items: dashboard.items,
                    dashboardTitle: dashboard.resolvedDisplayTitle,
                    wallpaperURL: appearanceSettings.activeWallpaperURL,
                    wallpaperRevision: appearanceSettings.wallpaperRevision,
                    accessibilityLabel: "\(dashboard.resolvedName) Preview"
                )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.large)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section("Names") {
                Button {
                    beginRenaming()
                } label: {
                    DashboardDetailEditableRow(
                        title: "Name",
                        value: dashboard.resolvedName
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dashboardTitleDraft = dashboard.resolvedDisplayTitle
                    isEditingDashboardTitle = true
                } label: {
                    DashboardDetailEditableRow(
                        title: "Dashboard Title",
                        value: dashboard.resolvedDisplayTitle
                    )
                }
                .buttonStyle(.plain)
            }

            Section {
                LabeledContent("Cards", value: cardCountText)

                if chipCount > 0 {
                    LabeledContent("Chips", value: chipCount.formatted())
                }

                if isSelected {
                    LabeledContent("Current Home Page", value: "Visible")
                }

                Toggle(
                    "Show on Home",
                    isOn: Binding(
                        get: { isEnabled },
                        set: { isEnabled in
                            dashboardConfiguration.setDashboardEnabled(isEnabled, id: dashboard.id)
                        }
                    )
                )
                .disabled(isEnabled && !dashboardConfiguration.canDisableDashboard(id: dashboard.id))
                .accessibilityLabel("Show \(dashboard.resolvedName) on Home")
                .accessibilityHint(
                    isEnabled && !dashboardConfiguration.canDisableDashboard(id: dashboard.id)
                        ? "At least one dashboard must remain visible"
                        : "Controls whether this dashboard appears as a Home page"
                )
            }

            Section {
                VStack {
                    Button {
                        beginDuplicating()
                    } label: {
                        Text("Duplicate")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.primary)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Text("Delete Dashboard")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } footer: {
                Text("This permanently deletes this dashboard and its layout.")
            }
        }
        .navigationTitle(dashboard.resolvedName)
        .toolbarTitleDisplayMode(.inline)
        .safeAreaPadding(.bottom, AppSpacing.xLarge)
        .alert("Dashboard Title", isPresented: $isEditingDashboardTitle) {
            TextField("Dashboard Title", text: $dashboardTitleDraft)

            Button("Cancel", role: .cancel) {
                dashboardTitleDraft = ""
            }

            Button("Save", role: .confirm) {
                dashboardConfiguration.setDashboardDisplayTitle(id: dashboard.id, title: dashboardTitleDraft)
                dashboardTitleDraft = ""
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
            "Delete \(dashboard.resolvedName)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Dashboard", role: .destructive) {
                dashboardConfiguration.deleteDashboard(id: dashboard.id)
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    private var cardCountText: String {
        cardCount.formatted()
    }

    private var isSelected: Bool {
        dashboard.id == dashboardConfiguration.selectedDashboardID
    }

    private var isEnabled: Bool {
        dashboardConfiguration.enabledDashboardIDs.contains(dashboard.id)
    }

    private var cardCount: Int {
        dashboard.items.filter { $0.role == .card }.count
    }

    private var chipCount: Int {
        dashboard.items.filter { $0.role == .chip }.count
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
        case .duplicate:
            return "Create"
        case .rename, nil:
            return "Save"
        }
    }

    private func beginRenaming() {
        dashboardNameDraft = dashboard.resolvedName
        namingAction = .rename
    }

    private func beginDuplicating() {
        dashboardNameDraft = "Copy of \(dashboard.resolvedName)"
        namingAction = .duplicate
    }

    private func commitDashboardName() {
        guard let namingAction else {
            return
        }

        switch namingAction {
        case .duplicate:
            dashboardConfiguration.duplicateDashboard(id: dashboard.id, named: dashboardNameDraft)
        case .rename:
            dashboardConfiguration.renameDashboard(id: dashboard.id, name: dashboardNameDraft)
        }

        resetNamingState()
    }

    private func resetNamingState() {
        namingAction = nil
        dashboardNameDraft = ""
    }
}

private struct DashboardDetailEditableRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: AppSpacing.large)

            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private enum DashboardNamingAction: Equatable {
    case create
    case duplicate(UUID)
    case rename(UUID)
}

private enum DashboardDetailNamingAction: Equatable {
    case duplicate
    case rename
}

#if DEBUG
#Preview {
    NavigationStack {
        DashboardSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
