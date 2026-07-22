import SwiftUI

struct DashboardChangeEntityContext: Identifiable, Equatable {
    let item: DashboardCardItem
    let reference: DashboardItemReference?

    init(item: DashboardCardItem, reference: DashboardItemReference? = nil) {
        self.item = item
        self.reference = reference
    }

    var id: UUID { item.id }
}

struct DashboardChangeEntityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var selectedEntityID: String
    @State private var searchText = ""

    let context: DashboardChangeEntityContext
    let navigationEmbedded: Bool
    var onEntityReplaced: ((String) -> Void)?
    var onDraftSelection: ((HAEntityState, Bool) -> Void)?

    init(
        context: DashboardChangeEntityContext,
        navigationEmbedded: Bool = false,
        onEntityReplaced: ((String) -> Void)? = nil,
        onDraftSelection: ((HAEntityState, Bool) -> Void)? = nil
    ) {
        self.context = context
        self.navigationEmbedded = navigationEmbedded
        self.onEntityReplaced = onEntityReplaced
        self.onDraftSelection = onDraftSelection
        _selectedEntityID = State(initialValue: context.item.entityID)
    }

    var body: some View {
        Group {
            if navigationEmbedded {
                pickerContent
            } else {
                NavigationStack {
                    pickerContent
                }
            }
        }
    }

    private var pickerContent: some View {
        List {
                Section("Preview") {
                    preview
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if resetsGaugeConfiguration {
                    Section {
                        Label(
                            "Gauge settings will reset because this sensor uses a different measurement type or unit.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
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
            if !navigationEmbedded {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", role: .confirm) {
                    saveReplacement()
                }
                .disabled(!canSave)
            }
        }
    }

    private var preview: some View {
        DashboardAddPresentationPreview(
            source: .entity(selectedEntityID),
            presentation: .card(context.item.configuration),
            displayNameOverride: context.item.displayNameOverride,
            iconNameOverride: context.item.iconNameOverride,
            gaugeZoneConfiguration: resetsGaugeConfiguration ? nil : context.item.gaugeZoneConfiguration
        )
    }

    private var filteredEntities: [HAEntityState] {
        stateStore.allEntityBoxes()
            .filter { entityBox in
                guard entityBox.homeEntity.isAvailable,
                      DashboardPresentationCatalog.isCompatible(context.item.configuration, with: entityBox) else {
                    return false
                }

                let query = normalizedSearch
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

    private var currentEntity: HAEntityState? {
        stateStore.entityBox(for: context.item.entityID)
    }

    private var preservesGaugeConfiguration: Bool {
        guard context.item.gaugeZoneConfiguration != nil,
              let currentEntity,
              let selectedEntity else {
            return true
        }

        return DashboardEntityReplacementPolicy.preservesGaugeCustomization(
            from: currentEntity,
            to: selectedEntity
        )
    }

    private var resetsGaugeConfiguration: Bool {
        context.item.gaugeZoneConfiguration != nil
            && selectedEntityID != context.item.entityID
            && !preservesGaugeConfiguration
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        selectedEntityID != context.item.entityID && selectedEntity != nil
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
        .accessibilityHint("Uses this entity for the card preview")
    }

    private func saveReplacement() {
        guard let selectedEntity else { return }
        if let onDraftSelection {
            onDraftSelection(selectedEntity, preservesGaugeConfiguration)
            HapticFeedback.impact(.light)
            dismiss()
            return
        }

        let replaced: Bool
        if let reference = context.reference {
            replaced = dashboardConfiguration.replaceEntity(
                for: reference,
                with: selectedEntity,
                preserveGaugeZoneConfiguration: preservesGaugeConfiguration
            )
        } else {
            replaced = dashboardConfiguration.replaceEntity(
                forItemID: context.item.id,
                with: selectedEntity,
                preserveGaugeZoneConfiguration: preservesGaugeConfiguration
            )
        }
        guard replaced else { return }
        onEntityReplaced?(selectedEntity.entityID)
        HapticFeedback.impact(.light)
        dismiss()
    }
}

#if DEBUG
private struct DashboardChangeEntityPreviewSample {
    let stateStore: HAStateStore
    let dashboardConfiguration: DashboardConfiguration
    let context: DashboardChangeEntityContext

    @MainActor
    static func make() -> Self {
        let stateStore = HAStateStore()
        stateStore.applyInitialStates([
            HAEntityDTO(
                entityID: "sensor.hall_temperature",
                state: "71.8",
                attributes: [
                    "friendly_name": .string("Hall Temperature"),
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.bedroom_temperature",
                state: "69.4",
                attributes: [
                    "friendly_name": .string("Bedroom Temperature"),
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "sensor.living_room_humidity",
                state: "46",
                attributes: [
                    "friendly_name": .string("Living Room Humidity"),
                    "device_class": .string("humidity"),
                    "unit_of_measurement": .string("%")
                ]
            )
        ])

        let suiteName = "com.tyler.Homestead.preview.dashboard-change-entity"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let dashboardConfiguration = DashboardConfiguration(defaults: defaults)
        let itemID = dashboardConfiguration.add(
            source: .entity("sensor.hall_temperature"),
            presentation: .card(.segmentedGauge(layout: .wide))
        )!
        dashboardConfiguration.setGaugeZoneConfiguration(
            GaugeZoneConfiguration(
                lowerBound: 50,
                upperBound: 90,
                boundaries: [68, 76],
                colors: [
                    .standard(for: .low),
                    .standard(for: .nominal),
                    .standard(for: .high)
                ]
            ),
            forItemID: itemID
        )
        let item = DashboardCardItem(
            id: itemID,
            entityID: "sensor.hall_temperature",
            configuration: .segmentedGauge(layout: .wide),
            displayNameOverride: nil,
            iconNameOverride: nil,
            gaugeZoneConfiguration: dashboardConfiguration.items.first?.gaugeZoneConfiguration,
            chartConfiguration: .default
        )

        return Self(
            stateStore: stateStore,
            dashboardConfiguration: dashboardConfiguration,
            context: DashboardChangeEntityContext(item: item)
        )
    }
}

struct DashboardChangeEntityPreviewScreen: View {
    private let sample = DashboardChangeEntityPreviewSample.make()

    var body: some View {
        DashboardChangeEntityView(context: sample.context)
            .environment(sample.stateStore)
            .environment(sample.dashboardConfiguration)
    }
}
#endif
