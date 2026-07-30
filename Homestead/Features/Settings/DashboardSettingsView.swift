import PhotosUI
import SwiftUI

// MARK: - Dashboard Settings View
struct DashboardSettingsView: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(HomesteadEntitlementStore.self) private var entitlementStore
    @State private var namingAction: DashboardNamingAction?
    @State private var dashboardNameDraft = ""
    @State private var deletingDashboardID: UUID?
    @State private var editMode: EditMode = .inactive
    @State private var isShowingPlus = false
    @State private var pendingPlusNamingAction: DashboardNamingAction?

    var body: some View {
        List {
            Section {
                ForEach(dashboardConfiguration.dashboards) { dashboard in
                    DashboardSettingsRow(
                        dashboard: dashboard,
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
                    "Dashboard pages and order sync with iCloud. "
                    + "Visibility on this device stays local. "
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
                    appearanceSettings.removeDashboardWallpaper(for: deletingDashboardID)
                    dashboardConfiguration.deleteDashboard(id: deletingDashboardID)
                }
                deletingDashboardID = nil
            }

            Button("Cancel", role: .cancel) {
                deletingDashboardID = nil
            }
        }
        .sheet(isPresented: $isShowingPlus, onDismiss: resumePendingPlusAction) {
            HomesteadPlusSheet(context: .additionalDashboard)
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

    private func createDashboard() {
        guard canCreateDashboard else {
            presentPlus(for: .create)
            return
        }
        prepareNaming(.create)
    }

    private func beginDuplicating(_ dashboard: SavedDashboardConfiguration) {
        guard canCreateDashboard else {
            presentPlus(for: .duplicate(dashboard.id))
            return
        }
        prepareNaming(.duplicate(dashboard.id))
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
            guard canCreateDashboard else {
                resetNamingState()
                presentPlus(for: .create)
                return
            }
            dashboardConfiguration.createDashboard(named: dashboardNameDraft)
        case .duplicate(let dashboardID):
            guard canCreateDashboard else {
                resetNamingState()
                presentPlus(for: .duplicate(dashboardID))
                return
            }
            let duplicateID = dashboardConfiguration.duplicateDashboard(
                id: dashboardID,
                named: dashboardNameDraft
            )
            appearanceSettings.copyDashboardBackground(from: dashboardID, to: duplicateID)
        case .rename(let dashboardID):
            dashboardConfiguration.renameDashboard(id: dashboardID, name: dashboardNameDraft)
        }

        resetNamingState()
    }

    private var canCreateDashboard: Bool {
        HomesteadPlusCapabilityPolicy.canCreateDashboard(
            hasPlus: entitlementStore.hasPlus,
            existingDashboardCount: dashboardConfiguration.dashboards.count
        )
    }

    private func presentPlus(for action: DashboardNamingAction) {
        pendingPlusNamingAction = action
        isShowingPlus = true
    }

    private func resumePendingPlusAction() {
        guard let action = HomesteadPlusContinuationPolicy.consume(
            &pendingPlusNamingAction,
            hasPlus: entitlementStore.hasPlus
        ) else { return }
        prepareNaming(action)
    }

    private func prepareNaming(_ action: DashboardNamingAction) {
        switch action {
        case .create:
            dashboardNameDraft = "Dashboard"
        case .duplicate(let dashboardID):
            guard let dashboard = dashboardConfiguration.dashboards.first(where: { $0.id == dashboardID }) else {
                return
            }
            dashboardNameDraft = "Copy of \(dashboard.resolvedName)"
        case .rename(let dashboardID):
            guard let dashboard = dashboardConfiguration.dashboards.first(where: { $0.id == dashboardID }) else {
                return
            }
            dashboardNameDraft = dashboard.resolvedName
        }
        namingAction = action
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
                        name: dashboard.resolvedName
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
                name: dashboard.resolvedName
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

    var body: some View {
        Text(name)
            .foregroundStyle(.primary)
            .padding(.vertical, AppSpacing.xSmall)
    }
}

struct DashboardDetailSettingsView: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(HomesteadEntitlementStore.self) private var entitlementStore

    let dashboard: SavedDashboardConfiguration

    @Environment(\.dismiss) private var dismiss
    @State private var namingAction: DashboardDetailNamingAction?
    @State private var dashboardNameDraft = ""
    @State private var isEditingDashboardTitle = false
    @State private var dashboardTitleDraft = ""
    @State private var isConfirmingDelete = false
    @State private var isShowingPlus = false
    @State private var pendingPlusNamingAction: DashboardDetailNamingAction?
    @State private var selectedWallpaperPhoto: PhotosPickerItem?
    @State private var isShowingWallpaperPicker = false
    @State private var wallpaperChoiceToRestore: DashboardBackgroundChoice?
    @State private var isImportingWallpaper = false
    @State private var wallpaperImportErrorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(spacing: AppSpacing.medium) {
                    SettingsDashboardPhonePreview(
                        width: 178,
                        items: dashboard.items,
                        dashboardTitle: dashboard.resolvedDisplayTitle,
                        wallpaperURL: appearanceSettings.resolvedWallpaperURL(for: dashboard.id),
                        wallpaperRevision: appearanceSettings.wallpaperPresentationRevision(for: dashboard.id),
                        accessibilityLabel: "\(dashboard.resolvedName) Preview"
                    )

                    if dashboardBackgroundChoice == .customWallpaper {
                        dashboardWallpaperActions
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
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

                Picker("Wallpaper", selection: dashboardBackgroundBinding) {
                    ForEach(DashboardBackgroundChoice.allCases) { choice in
                        Text(choice.displayName)
                            .tag(choice)
                    }
                }
                .pickerStyle(.menu)
                .tint(.secondary)

                Toggle(
                    "Show Dashboard on Home",
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
            } footer: {
                if let configurationFooterText {
                    Text(configurationFooterText)
                }
            }

            Section {
                LabeledContent("Cards", value: cardCountText)

                if chipCount > 0 {
                    LabeledContent("Chips", value: chipCount.formatted())
                }
            }

            Section {
                Button {
                    beginDuplicating()
                } label: {
                    Text("Duplicate")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

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
        .task(id: selectedWallpaperPhoto) {
            await importSelectedWallpaper()
        }
        .photosPicker(
            isPresented: $isShowingWallpaperPicker,
            selection: $selectedWallpaperPhoto,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: isShowingWallpaperPicker) { _, isPresented in
            guard !isPresented else { return }
            restoreBackgroundChoiceAfterCancelledPicker()
        }
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
        .alert("Couldn't Use Photo", isPresented: wallpaperImportErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(wallpaperImportErrorMessage ?? "Choose another photo and try again.")
        }
        .confirmationDialog(
            "Delete \(dashboard.resolvedName)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Dashboard", role: .destructive) {
                appearanceSettings.removeDashboardWallpaper(for: dashboard.id)
                dashboardConfiguration.deleteDashboard(id: dashboard.id)
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isShowingPlus, onDismiss: resumePendingPlusAction) {
            HomesteadPlusSheet(context: .additionalDashboard)
        }
    }

    @ViewBuilder
    private var dashboardWallpaperActions: some View {
        if isImportingWallpaper {
            HStack(spacing: AppSpacing.small) {
                ProgressView()
                    .controlSize(.small)
                Text(hasCustomDashboardWallpaper ? "Updating Wallpaper…" : "Adding Wallpaper…")
            }
            .foregroundStyle(.secondary)
        } else {
            if hasCustomDashboardWallpaper {
                Button("Change Wallpaper") {
                    presentWallpaperPicker()
                }
                .buttonStyle(.bordered)

                Button("Remove Wallpaper", role: .destructive) {
                    appearanceSettings.removeDashboardWallpaper(for: dashboard.id)
                }
                .buttonStyle(.bordered)
            } else {
                Button("Choose Wallpaper") {
                    presentWallpaperPicker()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var dashboardBackgroundChoice: DashboardBackgroundChoice {
        appearanceSettings.dashboardBackgroundChoice(for: dashboard.id)
    }

    private var dashboardBackgroundBinding: Binding<DashboardBackgroundChoice> {
        Binding(
            get: { dashboardBackgroundChoice },
            set: { setDashboardBackgroundChoice($0) }
        )
    }

    private var hasCustomDashboardWallpaper: Bool {
        appearanceSettings.hasCustomDashboardWallpaper(for: dashboard.id)
    }

    private var configurationFooterText: String? {
        var messages: [String] = []

        if dashboardBackgroundChoice == .defaultWallpaper {
            messages.append("Uses the wallpaper selected in Appearance.")
        }

        if isEnabled && !dashboardConfiguration.canDisableDashboard(id: dashboard.id) {
            messages.append("At least one dashboard must be shown on Home.")
        }

        return messages.isEmpty ? nil : messages.joined(separator: " ")
    }

    private var wallpaperImportErrorBinding: Binding<Bool> {
        Binding(
            get: { wallpaperImportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    wallpaperImportErrorMessage = nil
                }
            }
        )
    }

    private func importSelectedWallpaper() async {
        guard let selectedWallpaperPhoto else { return }

        isImportingWallpaper = true
        defer {
            isImportingWallpaper = false
            self.selectedWallpaperPhoto = nil
        }

        do {
            guard let data = try await selectedWallpaperPhoto.loadTransferable(type: Data.self) else {
                throw HomesteadAppearanceSettingsError.invalidImage
            }
            try await appearanceSettings.importDashboardWallpaper(from: data, for: dashboard.id)
            wallpaperChoiceToRestore = nil
        } catch {
            restoreBackgroundChoiceAfterFailedImport()
            wallpaperImportErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    private func setDashboardBackgroundChoice(_ choice: DashboardBackgroundChoice) {
        let previousChoice = dashboardBackgroundChoice
        appearanceSettings.setDashboardBackgroundChoice(choice, for: dashboard.id)

        if choice == .customWallpaper, !hasCustomDashboardWallpaper {
            presentWallpaperPicker(restoring: previousChoice)
        } else {
            wallpaperChoiceToRestore = nil
        }
    }

    private func presentWallpaperPicker(restoring choice: DashboardBackgroundChoice? = nil) {
        wallpaperChoiceToRestore = choice
        isShowingWallpaperPicker = true
    }

    private func restoreBackgroundChoiceAfterCancelledPicker() {
        Task { @MainActor in
            await Task.yield()
            guard selectedWallpaperPhoto == nil,
                  !hasCustomDashboardWallpaper,
                  let wallpaperChoiceToRestore else {
                return
            }
            appearanceSettings.setDashboardBackgroundChoice(
                wallpaperChoiceToRestore,
                for: dashboard.id
            )
            self.wallpaperChoiceToRestore = nil
        }
    }

    private func restoreBackgroundChoiceAfterFailedImport() {
        guard !hasCustomDashboardWallpaper, let wallpaperChoiceToRestore else { return }
        appearanceSettings.setDashboardBackgroundChoice(
            wallpaperChoiceToRestore,
            for: dashboard.id
        )
        self.wallpaperChoiceToRestore = nil
    }

    private var cardCountText: String {
        cardCount.formatted()
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
        guard canCreateDashboard else {
            presentPlus(for: .duplicate)
            return
        }
        prepareNaming(.duplicate)
    }

    private func commitDashboardName() {
        guard let namingAction else {
            return
        }

        switch namingAction {
        case .duplicate:
            guard canCreateDashboard else {
                resetNamingState()
                presentPlus(for: .duplicate)
                return
            }
            let duplicateID = dashboardConfiguration.duplicateDashboard(
                id: dashboard.id,
                named: dashboardNameDraft
            )
            appearanceSettings.copyDashboardBackground(from: dashboard.id, to: duplicateID)
        case .rename:
            dashboardConfiguration.renameDashboard(id: dashboard.id, name: dashboardNameDraft)
        }

        resetNamingState()
    }

    private var canCreateDashboard: Bool {
        HomesteadPlusCapabilityPolicy.canCreateDashboard(
            hasPlus: entitlementStore.hasPlus,
            existingDashboardCount: dashboardConfiguration.dashboards.count
        )
    }

    private func presentPlus(for action: DashboardDetailNamingAction) {
        pendingPlusNamingAction = action
        isShowingPlus = true
    }

    private func resumePendingPlusAction() {
        guard let action = HomesteadPlusContinuationPolicy.consume(
            &pendingPlusNamingAction,
            hasPlus: entitlementStore.hasPlus
        ) else { return }
        prepareNaming(action)
    }

    private func prepareNaming(_ action: DashboardDetailNamingAction) {
        switch action {
        case .duplicate:
            dashboardNameDraft = "Copy of \(dashboard.resolvedName)"
        case .rename:
            dashboardNameDraft = dashboard.resolvedName
        }
        namingAction = action
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
