import SwiftUI

struct DashboardCardEditorView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @Environment(HAStateStore.self) private var stateStore
    @State private var displayNameDraft = ""
    @State private var presentedEditor: DashboardCardEditorDestination?
    @State private var isConfirmingRemoval = false

    let reference: DashboardItemReference
    var onEntityReplaced: ((String) -> Void)?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if let item = currentCardItem {
                    editorForm(item: item)
                } else {
                    ContentUnavailableView(
                        "Card Unavailable",
                        systemImage: "rectangle.slash",
                        description: Text("This dashboard card was removed or is no longer available.")
                    )
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) {
                        saveDisplayName()
                        dismiss()
                    }
                }
            }
            .sheet(item: $presentedEditor) { destination in
                editor(destination)
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
            .onAppear(perform: loadDisplayName)
            .onDisappear(perform: saveDisplayName)
        }
    }

    // MARK: - Sections

    private func editorForm(item: DashboardCardItem) -> some View {
        Form {
            Section("Preview") {
                DashboardCardView(
                    entityID: item.entityID,
                    size: item.size,
                    presentationKind: item.presentationKind,
                    displayNameOverride: normalizedDisplayNameDraft,
                    iconNameOverride: item.iconNameOverride,
                    gaugeZoneConfiguration: item.gaugeZoneConfiguration,
                    chartRange: item.chartConfiguration.range,
                    isPreview: true
                )
                .frame(height: item.size.renderedHeight(
                    rowSpacing: AppSpacing.medium,
                    cardPadding: AppSpacing.medium
                ))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityLabel("Card preview")
            }

            Section("Card") {
                TextField("Name", text: $displayNameDraft)
                    .textInputAutocapitalization(.words)
                    .onSubmit(saveDisplayName)

                LabeledContent("Type", value: presentationTitle(for: item.presentationKind))

                Picker("Size", selection: sizeBinding(for: item)) {
                    ForEach(
                        DashboardPresentationCatalog.descriptor(for: item.presentationKind).supportedLayouts,
                        id: \.self
                    ) { size in
                        Label(size.displayName, systemImage: size.systemImage)
                            .tag(size)
                    }
                }

                Button {
                    saveDisplayName()
                    presentedEditor = .entity
                } label: {
                    Label("Change Entity", systemImage: "arrow.triangle.swap")
                }

                Button {
                    saveDisplayName()
                    presentedEditor = .icon
                } label: {
                    Label("Change Icon", systemImage: "circle.grid.2x2")
                }
            }

            if isGauge(item.presentationKind) || item.presentationKind == .chart {
                Section("Card Settings") {
                    if isGauge(item.presentationKind) {
                        Button {
                            saveDisplayName()
                            presentedEditor = .gauge
                        } label: {
                            Label("Gauge Settings", systemImage: "dial.medium")
                        }
                    }

                    if item.presentationKind == .chart {
                        Button {
                            saveDisplayName()
                            presentedEditor = .chart
                        } label: {
                            LabeledContent {
                                Text(item.chartConfiguration.range.accessibilityTitle)
                                    .foregroundStyle(.secondary)
                            } label: {
                                Label("Chart Settings", systemImage: "chart.xyaxis.line")
                            }
                        }
                    }
                }
            }

            Section {
                LabeledContent("Dashboard", value: dashboardName)
                LabeledContent("Entity", value: item.entityID)
            } header: {
                Text("Context")
            } footer: {
                Text("These settings affect only this dashboard card. Home Assistant and the entity detail remain unchanged.")
            }

            Section {
                Button("Remove Card", systemImage: "minus.circle", role: .destructive) {
                    isConfirmingRemoval = true
                }
            }
        }
    }

    // MARK: - Editor Destinations

    @ViewBuilder
    private func editor(_ destination: DashboardCardEditorDestination) -> some View {
        if let item = currentCardItem {
            switch destination {
            case .entity:
                DashboardChangeEntityView(
                    context: DashboardChangeEntityContext(item: item, reference: reference),
                    onEntityReplaced: handleEntityReplacement
                )
            case .icon:
                DashboardIconPickerView(
                    defaultSystemName: stateStore.entity(for: item.entityID)?.iconName ?? "square.grid.2x2",
                    selectedSystemName: item.iconNameOverride,
                    recommendation: .domain(stateStore.entity(for: item.entityID)?.domain ?? .other),
                    onSelectionChange: { iconName in
                        dashboardConfiguration.setIconNameOverride(iconName, for: reference)
                    }
                )
            case .gauge:
                gaugeEditor(for: item)
            case .chart:
                DashboardChartSettingsView(
                    context: DashboardChartSettingsContext(item: item),
                    onSave: { configuration in
                        dashboardConfiguration.setChartConfiguration(configuration, for: reference)
                    }
                )
            }
        } else {
            ContentUnavailableView("Card Unavailable", systemImage: "rectangle.slash")
        }
    }

    @ViewBuilder
    private func gaugeEditor(for item: DashboardCardItem) -> some View {
        if let presentation = stateStore.entityBox(for: item.entityID)?.sensorEntity?.gaugePresentation {
            let storedConfiguration = item.gaugeZoneConfiguration.flatMap { $0.isValid ? $0 : nil }
            let context = DashboardGaugeZoneEditorContext(
                id: item.id,
                presentation: presentation,
                kind: item.presentationKind,
                configuration: storedConfiguration ?? .defaults(for: presentation)
            )

            DashboardGaugeZoneEditorView(context: context) { configuration in
                dashboardConfiguration.setGaugeZoneConfiguration(configuration, for: reference)
            } onReset: {
                dashboardConfiguration.setGaugeZoneConfiguration(nil, for: reference)
            }
        } else {
            ContentUnavailableView(
                "Gauge Unavailable",
                systemImage: "gauge.with.dots.needle.33percent",
                description: Text("This entity no longer provides a compatible numeric gauge.")
            )
        }
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

    private var dashboardName: String {
        dashboardConfiguration.dashboardName(for: reference) ?? "Dashboard"
    }

    private var normalizedDisplayNameDraft: String? {
        let trimmed = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let canonicalName = currentCardItem
            .flatMap { stateStore.entity(for: $0.entityID)?.displayName }
        return trimmed == canonicalName ? nil : trimmed
    }

    private func loadDisplayName() {
        guard displayNameDraft.isEmpty, let item = currentCardItem else { return }
        displayNameDraft = item.displayNameOverride
            ?? stateStore.entity(for: item.entityID)?.displayName
            ?? ""
    }

    private func saveDisplayName() {
        guard currentCardItem != nil else { return }
        dashboardConfiguration.renameDisplayItem(
            reference,
            displayNameOverride: normalizedDisplayNameDraft
        )
    }

    private func handleEntityReplacement(_ entityID: String) {
        displayNameDraft = DashboardCardEditorNamePolicy.draft(
            displayNameOverride: currentCardItem?.displayNameOverride,
            replacementCanonicalName: stateStore.entity(for: entityID)?.displayName
        )
        onEntityReplaced?(entityID)
    }

    private func sizeBinding(for item: DashboardCardItem) -> Binding<DashboardCardSize> {
        Binding(
            get: { currentCardItem?.size ?? item.size },
            set: { size in
                HapticFeedback.selection()
                dashboardConfiguration.setCardLayout(size, for: reference)
            }
        )
    }

    private func isGauge(_ kind: DashboardPresentationKind) -> Bool {
        [.circularGauge, .segmentedGauge, .barGauge].contains(kind)
    }

    private func presentationTitle(for kind: DashboardPresentationKind) -> String {
        DashboardPresentationCatalog.descriptor(for: kind).title
    }
}

enum DashboardCardEditorNamePolicy {
    static func draft(
        displayNameOverride: String?,
        replacementCanonicalName: String?
    ) -> String {
        displayNameOverride ?? replacementCanonicalName ?? ""
    }
}

private enum DashboardCardEditorDestination: String, Identifiable {
    case entity
    case icon
    case gauge
    case chart

    var id: String { rawValue }
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
