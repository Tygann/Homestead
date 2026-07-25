import SwiftUI

struct DashboardChipEditorView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(HAStateStore.self) private var stateStore
    @State private var navigationPath: [DashboardChipEditorRoute] = []
    @State private var draft = DashboardChipEditorDraft.empty
    @State private var initialDraft = DashboardChipEditorDraft.empty
    @State private var isLoaded = false
    @State private var isConfirmingRemoval = false

    let reference: DashboardItemReference
    var onEntityReplaced: ((String) -> Void)?

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if currentChipItem == nil {
                    ContentUnavailableView(
                        "Chip Unavailable",
                        systemImage: "capsule",
                        description: Text("This dashboard chip was removed or is no longer available.")
                    )
                } else if isLoaded {
                    editorForm
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Edit Chip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        save()
                    }
                    .disabled(!canSave || !hasUnsavedChanges)
                }
            }
            .confirmationDialog(
                "Remove from Dashboard?",
                isPresented: $isConfirmingRemoval,
                titleVisibility: .visible
            ) {
                Button("Remove from Dashboard", role: .destructive) {
                    if dashboardConfiguration.removeItem(for: reference) {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the chip from \(dashboardName). It does not remove the entity from Home Assistant.")
            }
            .onAppear(perform: loadDraft)
            .navigationDestination(for: DashboardChipEditorRoute.self) { route in
                switch route {
                case .icon:
                    iconPicker
                case .entity:
                    entityPicker
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    // MARK: - Sections

    private var editorForm: some View {
        Form {
            Section {
                HStack {
                    Spacer(minLength: 0)
                    if let chipPresentation {
                        DashboardChipView(
                            presentation: chipPresentation,
                            usesPreviewProfilePicture: usesSyntheticPersonPicture
                        )
                            .allowsHitTesting(false)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, AppSpacing.xLarge)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Name") {
                    TextField(canonicalEntityName, text: displayNameBinding)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(restoreCanonicalNameIfNeeded)
                        .accessibilityLabel("Chip name")
                }

                NavigationLink(value: DashboardChipEditorRoute.icon) {
                    HStack {
                        Text("Icon")

                        Spacer()

                        HomesteadIconView(icon: draftResolvedIcon, pointSize: 18)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                    }
                }
                .accessibilityLabel("Icon")
                .accessibilityValue(draft.iconNameOverride == nil ? "Default" : "Custom")

                NavigationLink(value: DashboardChipEditorRoute.entity) {
                    LabeledContent {
                        Text(canonicalEntityName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } label: {
                        Text("Entity")
                    }
                }
            }

            Section {
                Button("Remove from Dashboard", systemImage: "minus.circle", role: .destructive) {
                    isConfirmingRemoval = true
                }
            }
        }
    }

    // MARK: - Navigation Destinations

    private var iconPicker: some View {
        DashboardIconPickerView(
            defaultSystemName: defaultIconName,
            selectedSystemName: draft.iconNameOverride,
            recommendation: .domain(draftEntityBox?.domain ?? .other),
            navigationEmbedded: true,
            onSelectionChange: { draft.iconNameOverride = $0 }
        )
    }

    private var entityPicker: some View {
        DashboardChangeChipEntityView(
            selectedEntityID: draft.entityID,
            displayNameOverride: draft.displayNameOverride(canonicalName: canonicalEntityName),
            iconNameOverride: draft.iconNameOverride,
            onSelection: handleEntitySelection
        )
    }

    // MARK: - Actions

    private func loadDraft() {
        guard !isLoaded, let item = currentChipItem else { return }
        let loadedDraft = DashboardChipEditorDraft(
            item: item,
            canonicalName: stateStore.entity(for: item.entityID ?? "")?.displayName
        )
        draft = loadedDraft
        initialDraft = loadedDraft
        isLoaded = true
    }

    private func save() {
        guard canSave else { return }
        restoreCanonicalNameIfNeeded()
        let originalEntityID = initialDraft.entityID
        let didSave = dashboardConfiguration.applyChipUpdate(
            draft.update(canonicalName: canonicalEntityName),
            for: reference
        )
        guard didSave else { return }

        if draft.entityID != originalEntityID {
            onEntityReplaced?(draft.entityID)
        }
        HapticFeedback.impact(.light)
        dismiss()
    }

    private func handleEntitySelection(_ replacement: HAEntityState) {
        draft.replaceEntity(
            with: replacement.entityID,
            replacementCanonicalName: replacement.homeEntity.displayName
        )
    }

    private func restoreCanonicalNameIfNeeded() {
        guard draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draft.setDisplayName(canonicalEntityName, canonicalName: canonicalEntityName)
    }

    // MARK: - Bindings

    private var displayNameBinding: Binding<String> {
        Binding(
            get: { draft.displayName },
            set: { draft.setDisplayName($0, canonicalName: canonicalEntityName) }
        )
    }

    // MARK: - Helpers

    private var currentChipItem: DashboardChipItem? {
        guard let item = dashboardConfiguration.item(for: reference),
              item.role == .chip,
              case .entity(let entityID) = item.source else {
            return nil
        }

        return DashboardChipItem(
            id: item.id,
            source: .entity(entityID),
            displayNameOverride: item.displayNameOverride,
            iconNameOverride: item.iconNameOverride
        )
    }

    private var draftEntityBox: HAEntityState? {
        stateStore.entityBox(for: draft.entityID)
    }

    private var canonicalEntityName: String {
        draftEntityBox?.homeEntity.displayName ?? draft.entityID
    }

    private var defaultIconName: String {
        stateStore.entity(for: draft.entityID)?.iconName ?? "square.grid.2x2"
    }

    private var draftResolvedIcon: ResolvedIcon {
        IconResolver.applyingDashboardOverride(
            draft.iconNameOverride,
            to: draftEntityBox?.homeEntity.resolvedIcon
                ?? .sfSymbol("square.grid.2x2", provenance: .fallback)
        )
    }

    private var chipPresentation: DashboardChipPresentation? {
        draftEntityBox.map {
            DashboardSummaryProvider.makeEntityChip(
                entityBox: $0,
                titleOverride: draft.displayNameOverride(canonicalName: canonicalEntityName),
                iconNameOverride: draft.iconNameOverride
            )
        }
    }

    private var dashboardName: String {
        dashboardConfiguration.dashboardName(for: reference) ?? "Dashboard"
    }

    private var canSave: Bool {
        guard isLoaded,
              currentChipItem != nil,
              let draftEntityBox else {
            return false
        }
        return DashboardPresentationCatalog.isCompatible(.chip, with: draftEntityBox)
    }

    private var hasUnsavedChanges: Bool {
        isLoaded && draft != initialDraft
    }

    private var usesSyntheticPersonPicture: Bool {
        #if DEBUG
        RuntimeEnvironment.previewScreen == .home
        #else
        false
        #endif
    }
}

private enum DashboardChipEditorRoute: Hashable {
    case icon
    case entity
}

private struct DashboardChangeChipEntityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @State private var selectedEntityID: String
    @State private var searchText = ""

    let displayNameOverride: String?
    let iconNameOverride: String?
    let onSelection: (HAEntityState) -> Void

    init(
        selectedEntityID: String,
        displayNameOverride: String?,
        iconNameOverride: String?,
        onSelection: @escaping (HAEntityState) -> Void
    ) {
        _selectedEntityID = State(initialValue: selectedEntityID)
        self.displayNameOverride = displayNameOverride
        self.iconNameOverride = iconNameOverride
        self.onSelection = onSelection
    }

    var body: some View {
        List {
            Section("Preview") {
                HStack {
                    Spacer(minLength: 0)
                    if let selectedEntity {
                        DashboardChipView(
                            presentation: DashboardSummaryProvider.makeEntityChip(
                                entityBox: selectedEntity,
                                titleOverride: displayNameOverride,
                                iconNameOverride: iconNameOverride
                            ),
                            usesPreviewProfilePicture: usesSyntheticPersonPicture
                        )
                        .allowsHitTesting(false)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, AppSpacing.large)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Entities") {
                ForEach(filteredEntities, id: \.entityID) { entityBox in
                    entityButton(entityBox)
                }
            }
        }
        .overlay {
            if filteredEntities.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search entities")
        .navigationTitle("Change Entity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", role: .confirm) {
                    guard let selectedEntity else { return }
                    onSelection(selectedEntity)
                    HapticFeedback.impact(.light)
                    dismiss()
                }
                .disabled(selectedEntity == nil)
            }
        }
    }

    private var filteredEntities: [HAEntityState] {
        stateStore.allEntityBoxes()
            .filter { entityBox in
                guard DashboardPresentationCatalog.isCompatible(.chip, with: entityBox) else {
                    return false
                }

                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                return query.isEmpty
                    || entityBox.homeEntity.displayName.localizedCaseInsensitiveContains(query)
                    || entityBox.entityID.localizedCaseInsensitiveContains(query)
                    || entityBox.homeEntity.state.localizedCaseInsensitiveContains(query)
            }
            .sorted { lhs, rhs in
                let nameOrder = lhs.homeEntity.displayName.localizedCaseInsensitiveCompare(rhs.homeEntity.displayName)
                if nameOrder == .orderedSame {
                    return lhs.entityID.localizedCaseInsensitiveCompare(rhs.entityID) == .orderedAscending
                }
                return nameOrder == .orderedAscending
            }
    }

    private var selectedEntity: HAEntityState? {
        stateStore.entityBox(for: selectedEntityID)
    }

    private var usesSyntheticPersonPicture: Bool {
        #if DEBUG
        RuntimeEnvironment.previewScreen == .home
        #else
        false
        #endif
    }

    private func entityButton(_ entityBox: HAEntityState) -> some View {
        Button {
            selectedEntityID = entityBox.entityID
            HapticFeedback.selection()
        } label: {
            HStack(spacing: AppSpacing.medium) {
                HomesteadIconView(icon: entityBox.homeEntity.resolvedIcon, pointSize: 18)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(entityBox.homeEntity.displayName)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(entityBox.entityID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if selectedEntityID == entityBox.entityID {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedEntityID == entityBox.entityID ? "Selected" : "")
        .accessibilityHint("Uses this entity for the chip preview")
    }
}
