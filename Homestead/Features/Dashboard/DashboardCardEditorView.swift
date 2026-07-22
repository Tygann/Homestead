import SwiftUI

struct DashboardCardEditorView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(HAStateStore.self) private var stateStore
    @FocusState private var isNameFocused: Bool
    @State private var navigationPath: [DashboardCardEditorRoute] = []
    @State private var draft = DashboardCardEditorDraft.empty
    @State private var initialDraft = DashboardCardEditorDraft.empty
    @State private var isLoaded = false
    @State private var isConfirmingRemoval = false

    let reference: DashboardItemReference
    var onEntityReplaced: ((String) -> Void)?

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if currentCardItem == nil {
                    ContentUnavailableView(
                        "Card Unavailable",
                        systemImage: "rectangle.slash",
                        description: Text("This dashboard card was removed or is no longer available.")
                    )
                } else if isLoaded {
                    editorForm
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Edit Card")
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
                    .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Remove Card?",
                isPresented: $isConfirmingRemoval,
                titleVisibility: .visible
            ) {
                Button("Remove Card", role: .destructive) {
                    if dashboardConfiguration.removeItem(for: reference) {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the card from \(dashboardName). It does not remove the entity from Home Assistant.")
            }
            .onAppear(perform: loadDraft)
            .navigationDestination(for: DashboardCardEditorRoute.self) { route in
                switch route {
                case .icon:
                    iconPicker
                case .entity:
                    entityPicker
                case .gauge:
                    gaugeEditor
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    // MARK: - Sections

    private var editorForm: some View {
        Form {
            Section("Preview") {
                identityEditor

                DashboardCardView(
                    entityID: draft.entityID,
                    size: draft.size,
                    presentationKind: draft.presentationKind,
                    displayNameOverride: draftDisplayNameOverride,
                    iconNameOverride: draft.iconNameOverride,
                    gaugeZoneConfiguration: draft.gaugeZoneConfiguration,
                    chartRange: draft.chartConfiguration.range,
                    isPreview: true
                )
                .frame(height: draft.size.renderedHeight(
                    rowSpacing: AppSpacing.medium,
                    cardPadding: AppSpacing.medium
                ))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityLabel("Card preview")
                .accessibilityHint("Updates as you edit this card")
            }

            Section {
                NavigationLink(value: DashboardCardEditorRoute.entity) {
                    LabeledContent("Entity", value: canonicalEntityName)
                }

                Picker("Size", selection: sizeBinding) {
                    ForEach(supportedSizes, id: \.self) { size in
                        Label(size.displayName, systemImage: size.systemImage)
                            .tag(size)
                    }
                }
            } header: {
                Text("Card")
            } footer: {
                Text("Changes apply only to this dashboard card.")
            }

            if isGauge(draft.presentationKind) || draft.presentationKind == .chart {
                Section("Settings") {
                    if draft.presentationKind == .chart {
                        Picker("History Range", selection: chartRangeBinding) {
                            ForEach(HAHistoryRangePreset.dashboardChartPresets) { range in
                                Text(range.accessibilityTitle)
                                    .tag(range)
                            }
                        }
                    }

                    if isGauge(draft.presentationKind) {
                        NavigationLink(value: DashboardCardEditorRoute.gauge) {
                            LabeledContent("Gauge", value: gaugeSettingsSummary)
                        }
                    }
                }
            }

            Section {
                Button("Remove Card", systemImage: "minus.circle", role: .destructive) {
                    isConfirmingRemoval = true
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var identityEditor: some View {
        HStack(spacing: AppSpacing.medium) {
            Button {
                navigationPath.append(.icon)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    HomesteadIconView(icon: draftResolvedIcon, pointSize: 22, weight: .semibold)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 52, height: 52)
                        .background(
                            Color.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                        )

                    Image(systemName: "pencil.circle.fill")
                        .font(.caption.weight(.semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change card icon")

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                TextField("Name", text: displayNameBinding)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit(restoreCanonicalNameIfNeeded)
                    .accessibilityLabel("Card name")

                Text(entitySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
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
        DashboardChangeEntityView(
            context: DashboardChangeEntityContext(item: draft.cardItem(id: reference.itemID)),
            navigationEmbedded: true,
            onDraftSelection: handleEntitySelection
        )
    }

    @ViewBuilder
    private var gaugeEditor: some View {
        if let presentation = draftEntityBox?.sensorEntity?.gaugePresentation {
            let storedConfiguration = draft.gaugeZoneConfiguration.flatMap { $0.isValid ? $0 : nil }
            let context = DashboardGaugeZoneEditorContext(
                id: reference.itemID,
                presentation: presentation,
                kind: draft.presentationKind,
                configuration: storedConfiguration ?? .defaults(for: presentation)
            )

            DashboardGaugeZoneEditorView(
                context: context,
                navigationEmbedded: true,
                onSave: { draft.gaugeZoneConfiguration = $0 },
                onReset: { draft.gaugeZoneConfiguration = nil }
            )
        } else {
            ContentUnavailableView(
                "Gauge Unavailable",
                systemImage: "gauge.with.dots.needle.33percent",
                description: Text("This entity no longer provides a compatible numeric gauge.")
            )
        }
    }

    // MARK: - Actions

    private func loadDraft() {
        guard !isLoaded, let item = currentCardItem else { return }
        let loadedDraft = DashboardCardEditorDraft(
            item: item,
            canonicalName: stateStore.entity(for: item.entityID)?.displayName
        )
        draft = loadedDraft
        initialDraft = loadedDraft
        isLoaded = true
    }

    private func save() {
        guard canSave else { return }
        restoreCanonicalNameIfNeeded()
        let originalEntityID = initialDraft.entityID
        let didSave = dashboardConfiguration.applyCardUpdate(
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

    private func handleEntitySelection(
        _ replacement: HAEntityState,
        preservesGaugeConfiguration: Bool
    ) {
        draft.replaceEntity(
            with: replacement.entityID,
            replacementCanonicalName: replacement.homeEntity.displayName,
            preservesGaugeConfiguration: preservesGaugeConfiguration
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

    private var sizeBinding: Binding<DashboardCardSize> {
        Binding(
            get: { draft.size },
            set: {
                HapticFeedback.selection()
                draft.size = $0
            }
        )
    }

    private var chartRangeBinding: Binding<HAHistoryRangePreset> {
        Binding(
            get: { draft.chartConfiguration.range },
            set: { draft.chartConfiguration.range = $0 }
        )
    }

    // MARK: - Helpers

    private var currentCardItem: DashboardCardItem? {
        guard let item = dashboardConfiguration.item(for: reference),
              let entityID = item.entityID,
              let configuration = item.cardConfiguration else {
            return nil
        }

        return DashboardCardItem(
            id: item.id,
            entityID: entityID,
            configuration: configuration,
            displayNameOverride: item.displayNameOverride,
            iconNameOverride: item.iconNameOverride,
            gaugeZoneConfiguration: item.gaugeZoneConfiguration,
            chartConfiguration: item.chartConfiguration ?? .default
        )
    }

    private var draftEntityBox: HAEntityState? {
        stateStore.entityBox(for: draft.entityID)
    }

    private var canonicalEntityName: String {
        draftEntityBox?.homeEntity.displayName ?? draft.entityID
    }

    private var entitySubtitle: String {
        draftEntityBox.map { EntityDetailPresentationModel(entityBox: $0).subtitle }
            ?? draft.entityID
    }

    private var draftResolvedIcon: ResolvedIcon {
        guard let draftEntityBox else {
            return .sfSymbol("square.grid.2x2", provenance: .fallback)
        }
        return IconResolver.applyingDashboardOverride(
            draft.iconNameOverride,
            to: draftEntityBox.homeEntity.resolvedIcon
        )
    }

    private var defaultIconName: String {
        stateStore.entity(for: draft.entityID)?.iconName ?? "square.grid.2x2"
    }

    private var draftDisplayNameOverride: String? {
        draft.update(canonicalName: canonicalEntityName).displayNameOverride
    }

    private var supportedSizes: [DashboardCardSize] {
        DashboardPresentationCatalog.descriptor(for: draft.presentationKind).supportedLayouts
    }

    private var dashboardName: String {
        dashboardConfiguration.dashboardName(for: reference) ?? "Dashboard"
    }

    private var gaugeSettingsSummary: String {
        guard let gaugeZoneConfiguration = draft.gaugeZoneConfiguration else { return "Automatic" }
        return "\(gaugeZoneConfiguration.colors.count) Zones"
    }

    private var canSave: Bool {
        guard isLoaded,
              currentCardItem != nil,
              let draftEntityBox,
              DashboardPresentationCatalog.isCompatible(draft.configuration, with: draftEntityBox),
              draft.chartConfiguration.isValid,
              draft.gaugeZoneConfiguration?.isValid != false else {
            return false
        }
        return true
    }

    private var hasUnsavedChanges: Bool {
        isLoaded && draft != initialDraft
    }

    private func isGauge(_ kind: DashboardPresentationKind) -> Bool {
        [.circularGauge, .segmentedGauge, .barGauge].contains(kind)
    }
}

private enum DashboardCardEditorRoute: Hashable {
    case icon
    case entity
    case gauge
}

#if DEBUG
@MainActor
struct DashboardCardEditorPreviewScreen: View {
    private let dependencies: PreviewDependencies
    private let reference: DashboardItemReference

    init() {
        let dependencies = PreviewDependencies.sample
        let dashboardID = dependencies.dashboardConfiguration.selectedDashboardID
        let itemID = dependencies.dashboardConfiguration.add(
            source: .entity("sensor.front_door_battery"),
            presentation: .card(.segmentedGauge(layout: .wide))
        ) ?? UUID()
        self.dependencies = dependencies
        reference = DashboardItemReference(dashboardID: dashboardID, itemID: itemID)
    }

    var body: some View {
        DashboardCardEditorView(reference: reference)
            .withPreviewEnvironment(dependencies)
    }
}

#Preview("Card Editor") {
    DashboardCardEditorPreviewScreen()
}
#endif
