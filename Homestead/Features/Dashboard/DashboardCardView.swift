import SwiftUI

struct DashboardCardView: View {
    let entityID: String
    let size: DashboardCardSize
    var isEditing = false
    var setSize: ((DashboardCardSize) -> Void)?
    var remove: (() -> Void)?

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedDetail: DashboardCardDetail?

    var body: some View {
        if let entityBox = stateStore.entityBox(for: entityID) {
            let presentation = DashboardEntityPresentation(entityBox: entityBox)

            DashboardEntityCard(
                presentation: presentation,
                size: size,
                isPending: entityBox.pendingCommand != nil,
                isEditing: isEditing,
                toggle: isEditing ? nil : primaryAction(for: entityBox),
                showDetails: isEditing ? nil : detailsAction(for: entityBox),
                setSize: isEditing ? setSize : nil,
                remove: isEditing ? remove : nil
            )
            .sheet(item: $selectedDetail) { detail in
                if let selectedEntityBox = stateStore.entityBox(for: detail.entityID) {
                    switch detail.kind {
                    case .light:
                        LightDetailView(entityBox: selectedEntityBox)
                    case .cover:
                        CoverDetailView(entityBox: selectedEntityBox)
                    case .climate:
                        ClimateDetailView(entityBox: selectedEntityBox)
                    case .toggle:
                        ToggleEntityDetailView(entityBox: selectedEntityBox)
                    case .lock:
                        ToggleEntityDetailView(entityBox: selectedEntityBox)
                    case .action:
                        ActionEntityDetailView(entityBox: selectedEntityBox)
                    case .entity:
                        EntityDetailView(entityBox: selectedEntityBox)
                    }
                } else {
                    ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                }
            }
        }
    }

    private func primaryAction(for entityBox: HAEntityState) -> (() -> Void)? {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)

        switch presentation.primaryAction {
        case .toggleLight:
            return {
                Task { await homeAssistantService.toggleLight(entityID: entityBox.entityID) }
            }
        case .activateScene:
            return {
                Task { await homeAssistantService.activateScene(entityID: entityBox.entityID) }
            }
        case .runScript:
            return {
                Task { await homeAssistantService.runScript(entityID: entityBox.entityID) }
            }
        case .toggleCover:
            return {
                Task { await homeAssistantService.toggleCover(entityID: entityBox.entityID) }
            }
        case .toggleSwitch:
            return {
                Task { await homeAssistantService.toggleSwitch(entityID: entityBox.entityID) }
            }
        case .toggleFan:
            return {
                Task { await homeAssistantService.toggleFan(entityID: entityBox.entityID) }
            }
        case .toggleLock:
            return {
                Task { await homeAssistantService.toggleLock(entityID: entityBox.entityID) }
            }
        case nil:
            return nil
        }
    }

    private func detailsAction(for entityBox: HAEntityState) -> (() -> Void)? {
        return {
            selectedDetail = DashboardCardDetail(
                entityID: entityBox.entityID,
                kind: detailKind(for: entityBox)
            )
        }
    }

    private func detailKind(for entityBox: HAEntityState) -> DashboardCardDetail.Kind {
        switch DashboardEntityPresentation(entityBox: entityBox).detailKind {
        case .light:
            .light
        case .cover:
            .cover
        case .climate:
            .climate
        case .toggle:
            .toggle
        case .lock:
            .lock
        case .action:
            .action
        case .entity:
            .entity
        }
    }
}

private struct DashboardCardDetail: Identifiable {
    enum Kind {
        case light
        case cover
        case climate
        case toggle
        case lock
        case action
        case entity
    }

    let entityID: String
    let kind: Kind

    var id: String {
        "\(kind)-\(entityID)"
    }
}

private struct DashboardEntityCard: View {
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let isPending: Bool
    let isEditing: Bool
    let toggle: (() -> Void)?
    let showDetails: (() -> Void)?
    let setSize: ((DashboardCardSize) -> Void)?
    let remove: (() -> Void)?

    var body: some View {
        CardContainer(isActive: presentation.isActive, minHeight: cardContainerMinHeight) {
            ZStack(alignment: .topLeading) {
                if let showDetails {
                    Button(action: showDetails) {
                        cardContent
                            .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HomeCardButtonStyle())
                    .accessibilityLabel(presentation.title)
                    .accessibilityValue(presentation.accessibilityValue)
                } else {
                    cardContent
                        .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                }

                if let toggle {
                    Button(action: toggle) {
                        CardIconView(
                            systemName: presentation.iconName,
                            isActive: presentation.isActive
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending)
                    .accessibilityLabel("Toggle \(presentation.title)")
                    .accessibilityValue(presentation.accessibilityValue)
                }

            }
        }
        .overlay(alignment: .topLeading) {
            if isEditing {
                removeButton
                    .offset(x: -8, y: -8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isEditing {
                sizeMenu
                    .offset(x: 6, y: 6)
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch size {
        case .compact:
            compactContent
        case .large, .wide:
            largeContent
        }
    }

    private var compactContent: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            iconPlaceholder

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(presentation.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(presentation.subtitleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let headline = presentation.headline {
                Text(headline)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(presentation.headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: 86, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
    }

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                iconPlaceholder
                
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(presentation.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(presentation.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(presentation.subtitleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            if let headline = presentation.headline {
                Text(headline)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(presentation.headlineColor)
                    .lineLimit(1)
            }
        }
    }

    private var iconPlaceholder: some View {
        Color.clear
            .frame(width: 44, height: 44)
            .overlay(alignment: .topLeading) {
                if toggle == nil {
                    CardIconView(systemName: presentation.iconName, isActive: presentation.isActive)
                }
            }
    }
    
    @ViewBuilder
    private var sizeMenu: some View {
        if let setSize {
            Menu {
                Picker("", selection: Binding(
                    get: { size },
                    set: { setSize($0) }
                )) {
                    ForEach(DashboardCardSize.allCases, id: \.self) { option in
                        Label(option.displayName, systemImage: option.systemImage)
                            .tag(option)
                            .tint(size == option ? .primary : .gray)
                    }
                }
                .pickerStyle(.segmented)
            } label: {
                Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .accessibilityLabel("Card size")
        }
    }

    @ViewBuilder
    private var removeButton: some View {
        if let remove {
            Button(action: remove) {
                Image(systemName: "minus")
                    .font(.subheadline.weight(.bold))
//                    .foregroundStyle(.secondary)
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .accessibilityLabel("Remove \(presentation.title)")
        }
    }
    
    private var cardContentMinHeight: CGFloat {
        max(0, cardContainerMinHeight - (AppSpacing.medium * 2))
    }

    private var cardContainerMinHeight: CGFloat {
        size.contentMinHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }
}

#if DEBUG
private struct DashboardCardDisplaySizesPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                DashboardCardView(entityID: "light.living_room_lamps", size: .compact)
                    .frame(width: 180)

                DashboardCardView(entityID: "sensor.hallway_temperature", size: .large)
                    .frame(width: 180)
            }

            DashboardCardView(entityID: "sensor.hallway_temperature", size: .wide)
                .frame(width: 376)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Display Sizes") {
    DashboardCardDisplaySizesPreview()
        .withPreviewEnvironment()
}

private struct DashboardCardEditModePreview: View {
    @State private var size: DashboardCardSize = .large

    var body: some View {
        DashboardCardView(
            entityID: "light.living_room_lamps",
            size: size,
            isEditing: true,
            setSize: { size = $0 },
            remove: {}
        )
        .frame(width: previewWidth)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private var previewWidth: CGFloat {
        size == .wide ? 376 : 180
    }
}

#Preview("Edit Mode") {
    DashboardCardEditModePreview()
        .withPreviewEnvironment()
}
#endif
