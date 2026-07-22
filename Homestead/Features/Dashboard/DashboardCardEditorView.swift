import SwiftUI

struct DashboardCardEditorView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(HAStateStore.self) private var stateStore
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
                Text("This removes the card from \(dashboardName). It does not remove the entity from Home Assistant.")
            }
            .onAppear(perform: loadDraft)
            .navigationDestination(for: DashboardCardEditorRoute.self) { route in
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
                DashboardCardEditorPreviewStage(
                    size: draft.size,
                    accessibilityValue: previewAccessibilityValue
                ) {
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
                }
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
                        .accessibilityLabel("Card name")
                }

                NavigationLink(value: DashboardCardEditorRoute.icon) {
                    HStack {
                        Text("Icon")

                        Spacer()

                        CardIconView(
                            icon: draftResolvedIcon,
                            accentColor: .accentColor,
                            size: 32,
                            symbolSize: 15
                        )
                    }
                }
                .accessibilityLabel("Icon")
                .accessibilityValue(draft.iconNameOverride == nil ? "Default" : "Custom")

                NavigationLink(value: DashboardCardEditorRoute.entity) {
                    LabeledContent {
                        Text(canonicalEntityName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } label: {
                        Text("Entity")
                    }
                }

                Picker("Size", selection: sizeBinding) {
                    ForEach(supportedSizes, id: \.self) { size in
                        Label {
                            Text(size.displayName)
                        } icon: {
                            if let customResizeIconName = size.customResizeIconName {
                                Image(customResizeIconName)
                            } else {
                                Image(systemName: size.systemImage)
                            }
                        }
                            .tag(size)
                    }
                }
            } header: {
                Text("Card")
            }

            if !editorSettings.isEmpty {
                ForEach(editorSettings, id: \.self) { setting in
                    editorSettingSections(setting)
                }
            }

            Section {
                Button("Remove from Dashboard", role: .destructive) {
                    isConfirmingRemoval = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func editorSettingSections(_ setting: DashboardCardEditorSetting) -> some View {
        switch setting {
        case .historyRange:
            Section("Chart Settings") {
                Picker("History Range", selection: chartRangeBinding) {
                    ForEach(HAHistoryRangePreset.dashboardChartPresets) { range in
                        Text(range.accessibilityTitle)
                            .tag(range)
                    }
                }
            }
        case .gaugeZones:
            if let presentation = draftEntityBox?.sensorEntity?.gaugePresentation {
                DashboardGaugeInlineSettings(
                    presentation: presentation,
                    configurationOverride: $draft.gaugeZoneConfiguration
                )
            } else {
                Section("Gauge Settings") {
                    LabeledContent("Configuration", value: "Unavailable")
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
        DashboardChangeEntityView(
            context: DashboardChangeEntityContext(item: draft.cardItem(id: reference.itemID)),
            navigationEmbedded: true,
            onDraftSelection: handleEntitySelection
        )
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

    private var defaultIconName: String {
        stateStore.entity(for: draft.entityID)?.iconName ?? "square.grid.2x2"
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

    private var draftDisplayNameOverride: String? {
        draft.update(canonicalName: canonicalEntityName).displayNameOverride
    }

    private var supportedSizes: [DashboardCardSize] {
        presentationDescriptor.supportedLayouts
    }

    private var editorSettings: [DashboardCardEditorSetting] {
        presentationDescriptor.editorSettings
    }

    private var presentationDescriptor: DashboardPresentationDescriptor {
        DashboardPresentationCatalog.descriptor(for: draft.presentationKind)
    }

    private var previewAccessibilityValue: String {
        "\(draft.displayName), \(presentationDescriptor.title), \(draft.size.displayName)"
    }

    private var dashboardName: String {
        dashboardConfiguration.dashboardName(for: reference) ?? "Dashboard"
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

}

private enum DashboardCardEditorRoute: Hashable {
    case icon
    case entity
}

#if DEBUG
@MainActor
struct DashboardCardEditorPreviewScreen: View {
    private let dependencies: PreviewDependencies
    private let reference: DashboardItemReference

    init() {
        let requestedEntityID = RuntimeEnvironment.livePreviewEntityID
        let dependencies = requestedEntityID == Self.thermostatEntityID
            ? PreviewDependencies.entityDetailSample(entityOverrides: [Self.thermostatFixture])
            : PreviewDependencies.sample
        let dashboardID = dependencies.dashboardConfiguration.selectedDashboardID
        let fixture = Self.fixture(
            for: RuntimeEnvironment.livePreviewPresentationKind,
            requestedSize: RuntimeEnvironment.requestedPreviewCardSize,
            requestedEntityID: requestedEntityID
        )
        let itemID = dependencies.dashboardConfiguration.add(
            source: .entity(fixture.entityID),
            presentation: .card(fixture.configuration)
        ) ?? UUID()
        dependencies.dashboardConfiguration.renameDisplayItem(
            DashboardItemReference(dashboardID: dashboardID, itemID: itemID),
            displayNameOverride: fixture.displayNameOverride
        )
        self.dependencies = dependencies
        reference = DashboardItemReference(dashboardID: dashboardID, itemID: itemID)
    }

    var body: some View {
        DashboardCardEditorView(reference: reference)
            .withPreviewEnvironment(dependencies)
    }

    private static func fixture(
        for requestedKind: DashboardPresentationKind?,
        requestedSize: DashboardCardSize?,
        requestedEntityID: String?
    ) -> (entityID: String, configuration: DashboardCardConfiguration, displayNameOverride: String?) {
        switch requestedKind {
        case .control:
            return fixture(
                entityID: requestedEntityID ?? "light.living_room_lamps",
                kind: .control,
                requestedSize: requestedSize
            )
        case .status:
            return fixture(entityID: "lock.front_door", kind: .status, requestedSize: requestedSize)
        case .circularGauge:
            return fixture(
                entityID: "sensor.front_door_battery",
                kind: .circularGauge,
                requestedSize: requestedSize
            )
        case .segmentedGauge:
            return fixture(
                entityID: "sensor.front_door_battery",
                kind: .segmentedGauge,
                requestedSize: requestedSize
            )
        case .barGauge:
            return fixture(
                entityID: "sensor.front_door_battery",
                kind: .barGauge,
                requestedSize: requestedSize
            )
        case .chart:
            return fixture(entityID: "sensor.hallway_temperature", kind: .chart, requestedSize: requestedSize)
        case .camera:
            return fixture(entityID: "camera.driveway", kind: .camera, requestedSize: requestedSize)
        case .weather:
            return fixture(entityID: "weather.home", kind: .weather, requestedSize: requestedSize)
        case .media:
            return fixture(entityID: "media_player.living_room", kind: .media, requestedSize: requestedSize)
        case .action:
            return fixture(entityID: "scene.movie_night", kind: .action, requestedSize: requestedSize)
        case .chip:
            fallthrough
        default:
            let entityID = requestedEntityID ?? "light.living_room_lamps"
            return (
                entityID,
                .control(layout: supportedSize(requestedSize, for: .control) ?? .compact),
                entityID == thermostatEntityID
                    ? "Thermostat"
                    : requestedEntityID == nil ? "Back Yard Lights" : nil
            )
        }
    }

    private static func fixture(
        entityID: String,
        kind: DashboardPresentationKind,
        requestedSize: DashboardCardSize?
    ) -> (entityID: String, configuration: DashboardCardConfiguration, displayNameOverride: String?) {
        let layout = supportedSize(requestedSize, for: kind) ?? kind.defaultLayout ?? .compact
        let configuration = DashboardPresentationCatalog.cardConfiguration(kind: kind, layout: layout)
            ?? .control(layout: .compact)
        return (entityID, configuration, nil)
    }

    private static let thermostatEntityID = "climate.editor_thermostat"

    private static let thermostatFixture = HAEntityDTO(
        entityID: thermostatEntityID,
        state: "heat_cool",
        attributes: [
            "friendly_name": .string("Thermostat"),
            "current_temperature": .number(72),
            "target_temp_low": .number(70),
            "target_temp_high": .number(75),
            "temperature_unit": .string("°F"),
            "min_temp": .number(50),
            "max_temp": .number(90),
            "target_temp_step": .number(1),
            "hvac_modes": .array([
                .string("off"),
                .string("heat"),
                .string("cool"),
                .string("heat_cool")
            ])
        ],
        lastUpdated: .now
    )

    private static func supportedSize(
        _ requestedSize: DashboardCardSize?,
        for kind: DashboardPresentationKind
    ) -> DashboardCardSize? {
        requestedSize.flatMap { kind.supportedLayouts.contains($0) ? $0 : nil }
    }
}

#Preview("Card Editor") {
    DashboardCardEditorPreviewScreen()
}
#endif
