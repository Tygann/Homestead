import SwiftUI

struct DashboardEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HAStateStore.self) private var stateStore
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var searchText = ""
    @State private var editMode: EditMode = .active
    @State private var isShowingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                summarySection
                selectedSection
                availableSection
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .navigationTitle("Edit Home")
            .toolbarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isShowingResetConfirmation = true
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!stateStore.hasEntities)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("Done")
                }
            }
            .confirmationDialog(
                "Reset Home View?",
                isPresented: $isShowingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore Suggested Cards", role: .destructive) {
                    dashboardConfiguration.reset(using: stateStore.allEntities)
                }
            } message: {
                Text("This replaces your selected Home cards with the suggested default layout.")
            }
        }
    }

    private var selectedEntities: [HomeEntity] {
        dashboardConfiguration
            .visibleEntityIDs(fromAvailableEntityIDs: stateStore.availableEntityIDs)
            .compactMap { stateStore.entity(for: $0) }
    }

    private var matchingEntityGroups: [(domain: EntityDomain, entities: [HomeEntity])] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return stateStore.entitiesByDomain
        }

        return stateStore.entitiesByDomain.compactMap { group in
            let entities = group.entities.filter { entity in
                entity.displayName.localizedCaseInsensitiveContains(query) ||
                    entity.entityID.localizedCaseInsensitiveContains(query)
            }

            guard !entities.isEmpty else {
                return nil
            }

            return (domain: group.domain, entities: entities)
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: AppSpacing.medium) {
                EditSummaryMetric(
                    value: "\(selectedEntities.count)",
                    label: "Home cards",
                    systemImage: "square.grid.2x2.fill"
                )

                EditSummaryMetric(
                    value: "\(stateStore.allEntities.count)",
                    label: "Available",
                    systemImage: "sensor"
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var selectedSection: some View {
        Section {
            if selectedEntities.isEmpty {
                ContentUnavailableView(
                    "No Cards Selected",
                    systemImage: "square.grid.2x2",
                    description: Text("Add entities below to build your Home view.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(selectedEntities) { entity in
                    DashboardEntityRow(
                        entity: entity,
                        status: .remove,
                        cardSize: dashboardConfiguration.cardSize(for: entity.entityID),
                        setCardSize: { size in
                            dashboardConfiguration.setCardSize(size, for: entity.entityID)
                        }
                    ) {
                        dashboardConfiguration.remove(entity.entityID)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        if index >= 0 && index < selectedEntities.count {
                            let id = selectedEntities[index].entityID
                            dashboardConfiguration.remove(id)
                        }
                    }
                }
                .onMove { source, destination in
                    dashboardConfiguration.move(from: source, to: destination)
                }
            }
        } header: {
            Text("Home Cards")
        } footer: {
            Text("Drag selected cards to change the order on the Home tab.")
        }
    }

    private var availableSection: some View {
        Section {
            if matchingEntityGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            }

            ForEach(matchingEntityGroups, id: \.domain) { group in
                DisclosureGroup {
                    ForEach(group.entities) { entity in
                        DashboardEntityRow(
                            entity: entity,
                            status: dashboardConfiguration.contains(entity.entityID) ? .selected : .add
                        ) {
                            dashboardConfiguration.setEntity(
                                entity.entityID,
                                isVisible: !dashboardConfiguration.contains(entity.entityID)
                            )
                        }
                    }
                } label: {
                    Label(group.domain.displayName, systemImage: group.domain.systemImage)
                }
            }
        } header: {
            Text("Available Entities")
        }
    }
}

private struct DashboardEntityRow: View {
    let entity: HomeEntity
    let status: SelectionStatus
    var cardSize: DashboardCardSize?
    var setCardSize: ((DashboardCardSize) -> Void)?
    let action: () -> Void

    var body: some View {
        if status == .remove {
            selectedRow
        } else {
            selectionRow
        }
    }

    private var selectionRow: some View {
        Button(action: action) {
            Label {
                rowContent
            } icon: {
                icon
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entity.displayName), \(status.accessibilityAction)")
    }

    private var selectedRow: some View {
        Label {
            rowContent
        } icon: {
            icon
        }
        .accessibilityElement(children: .combine)
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(entity.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(entity.entityID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: AppSpacing.medium)

            if status == .remove {
                sizeMenu

                Button(action: action) {
                    Image(systemName: status.actionSystemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(status.actionColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(entity.displayName)")
            } else {
                Image(systemName: status.actionSystemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(status.actionColor)
            }
        }
    }

    @ViewBuilder
    private var sizeMenu: some View {
        if let cardSize, let setCardSize {
            Menu {
                ForEach(DashboardCardSize.allCases, id: \.self) { size in
                    Button {
                        setCardSize(size)
                    } label: {
                        Label(size.displayName, systemImage: cardSize == size ? "checkmark" : size.systemImage)
                    }
                }
            } label: {
                Label(cardSize.displayName, systemImage: cardSize.systemImage)
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Card size")
        }
    }

    private var icon: some View {
        Image(systemName: entity.iconName)
            .foregroundStyle(entity.isAvailable ? Color.accentColor : Color.secondary)
    }

    enum SelectionStatus: Equatable {
        case add
        case selected
        case remove

        var actionSystemImage: String {
            switch self {
            case .add:
                "plus.circle"
            case .selected:
                "checkmark.circle.fill"
            case .remove:
                "minus.circle.fill"
            }
        }

        var actionColor: Color {
            switch self {
            case .add:
                .accentColor
            case .selected:
                .green
            case .remove:
                .red
            }
        }

        var accessibilityAction: String {
            switch self {
            case .add:
                "add to Home"
            case .selected:
                "selected"
            case .remove:
                "remove from Home"
            }
        }
    }
}

private struct EditSummaryMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

#if DEBUG
#Preview {
    DashboardEditView()
        .withPreviewEnvironment()
}
#endif
