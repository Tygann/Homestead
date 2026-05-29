import SwiftUI

struct DashboardCardView: View {
    let entityID: String
    let size: DashboardCardSize
    var displayNameOverride: String?
    var isEditing = false
    var setSize: ((DashboardCardSize) -> Void)?
    var rename: (() -> Void)?
    var remove: (() -> Void)?

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedDetail: DashboardCardDetail?

    var body: some View {
        if let entityBox = stateStore.entityBox(for: entityID) {
            let presentation = DashboardEntityPresentation(
                entityBox: entityBox,
                displayNameOverride: displayNameOverride
            )

            DashboardEntityCard(
                presentation: presentation,
                size: size,
                isPending: entityBox.pendingCommand != nil,
                isEditing: isEditing,
                toggle: isEditing ? nil : primaryAction(for: entityBox),
                showDetails: isEditing ? nil : detailsAction(for: entityBox),
                setSize: isEditing ? setSize : nil,
                rename: isEditing ? rename : nil,
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
                    case .fan:
                        FanDetailView(entityBox: selectedEntityBox)
                    case .lock:
                        LockDetailView(entityBox: selectedEntityBox)
                    case .toggle:
                        ToggleEntityDetailView(entityBox: selectedEntityBox)
                    case .action:
                        ActionEntityDetailView(entityBox: selectedEntityBox)
                    case .sensor:
                        SensorDetailView(entityBox: selectedEntityBox)
                    case .mediaPlayer:
                        MediaPlayerDetailView(entityBox: selectedEntityBox)
                    case .camera:
                        CameraDetailView(entityBox: selectedEntityBox)
                    case .vacuum:
                        VacuumDetailView(entityBox: selectedEntityBox)
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

        if let primaryAction = presentation.primaryAction {
            return {
                HapticFeedback.selection()
                Task {
                    await homeAssistantService.perform(primaryAction, entityID: entityBox.entityID)
                }
            }
        }

        return nil
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
        case .fan:
            .fan
        case .lock:
            .lock
        case .toggle:
            .toggle
        case .action:
            .action
        case .sensor:
            .sensor
        case .mediaPlayer:
            .mediaPlayer
        case .camera:
            .camera
        case .vacuum:
            .vacuum
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
        case fan
        case lock
        case toggle
        case action
        case sensor
        case mediaPlayer
        case camera
        case vacuum
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
    let rename: (() -> Void)?
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
                    .accessibilityLabel(presentation.accessibilityDetailLabel)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.accessibilityDetailHint)
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
                    .accessibilityLabel(presentation.primaryActionAccessibilityLabel ?? presentation.title)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.primaryActionAccessibilityHint)
                }

            }
        }
        .overlay(alignment: .topLeading) {
            if isEditing {
                removeButton
                    .offset(x: -8, y: -8)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditing {
                renameButton
                    .offset(x: 6, y: -8)
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
        case .mini:
            miniContent
        case .compact, .row:
            compactContent
        case .square, .wide, .large:
            largeContent
        }
    }

    private var miniContent: some View {
        iconPlaceholder
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
                    .minimumScaleFactor(0.7)
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

    @ViewBuilder
    private var renameButton: some View {
        if let rename {
            Button(action: rename) {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .accessibilityLabel("Rename \(presentation.title)")
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
                DashboardCardView(entityID: "light.living_room_lamps", size: .mini)
                    .frame(width: 82)

                DashboardCardView(entityID: "light.living_room_lamps", size: .compact)
                    .frame(width: 180)

                DashboardCardView(entityID: "sensor.hallway_temperature", size: .square)
                    .frame(width: 180)
            }

            DashboardCardView(entityID: "sensor.hallway_temperature", size: .row)
                .frame(width: 376)

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
    @State private var size: DashboardCardSize = .square

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
        switch size {
        case .mini:
            82
        case .compact, .square:
            180
        case .row, .wide, .large:
            376
        }
    }
}

#Preview("Edit Mode") {
    DashboardCardEditModePreview()
        .withPreviewEnvironment()
}
#endif
