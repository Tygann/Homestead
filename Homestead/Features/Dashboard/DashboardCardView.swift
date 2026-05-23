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
        guard entityBox.homeEntity.isAvailable else { return nil }

        switch entityBox.domain {
        case .light:
            return {
                Task { await homeAssistantService.toggleLight(entityID: entityBox.entityID) }
            }
        case .scene:
            return {
                Task { await homeAssistantService.activateScene(entityID: entityBox.entityID) }
            }
        case .script:
            return {
                Task { await homeAssistantService.runScript(entityID: entityBox.entityID) }
            }
        case .climate, .cover, .sensor, .other:
            return nil
        }
    }

    private func detailsAction(for entityBox: HAEntityState) -> (() -> Void)? {
        return {
            selectedDetail = DashboardCardDetail(
                entityID: entityBox.entityID,
                kind: entityBox.lightEntity == nil ? .entity : .light
            )
        }
    }
}

private struct DashboardCardDetail: Identifiable {
    enum Kind {
        case light
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
            .glassEffect()
            .accessibilityLabel("Card size")
        }
    }
    
    @ViewBuilder
    private var sizeMenu_Backup: some View {
        if let setSize {
            Menu {
                ControlGroup {
                    ForEach(DashboardCardSize.allCases, id: \.self) { option in
                        Button {
                            setSize(option)
                        } label: {
//                            Label(option.displayName, systemImage: size == option ? "checkmark" : option.systemImage)
                            Label(option.displayName, systemImage: option.systemImage)
                                .tint(size == option ? .primary : .gray)
                        }
                    }
                }
            } label: {
//                Image(systemName: size.systemImage)
                Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .glassEffect()
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
            .glassEffect()
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

private struct DashboardEntityPresentation {
    let title: String
    let subtitle: String
    let headline: String?
    let iconName: String
    let isActive: Bool
    let isAvailable: Bool
    let accentColor: Color
    let isPending: Bool

    init(entityBox: HAEntityState) {
        let pendingCommand = entityBox.pendingCommand
        isPending = pendingCommand != nil

        if let light = entityBox.lightEntity {
            let effectiveIsOn = pendingCommand?.expectedState.map { $0 == "on" } ?? light.isOn
            let brightnessPercentage = Self.pendingBrightnessPercentage(from: pendingCommand) ?? light.brightnessPercentage

            title = light.displayName
            subtitle = Self.lightSubtitle(
                isOn: effectiveIsOn,
                brightnessPercentage: brightnessPercentage,
                pendingCommand: pendingCommand
            )
            headline = effectiveIsOn ? brightnessPercentage.map { "\($0)%" } : nil
            iconName = light.iconName
            isActive = effectiveIsOn
            isAvailable = true
            accentColor = .accentColor
        } else if let sensor = entityBox.sensorEntity {
            title = sensor.displayName
            subtitle = sensor.displaySubtitle
            headline = sensor.formattedValue
            iconName = sensor.iconName
            isActive = false
            isAvailable = sensor.isAvailable
            accentColor = Self.sensorAccentColor(for: sensor)
        } else {
            let entity = entityBox.homeEntity
            title = entity.displayName
            subtitle = Self.subtitle(for: entity)
            headline = Self.headline(for: entity)
            iconName = entity.iconName
            isActive = Self.isActive(entity)
            isAvailable = entity.isAvailable
            accentColor = Self.accentColor(for: entity)
        }
    }

    var accessibilityValue: String {
        subtitle
    }

    var subtitleColor: Color {
        guard isAvailable else { return .red }
        return .secondary
    }

    var headlineColor: Color {
        guard isAvailable else { return .secondary }
        return accentColor
    }

    private static func lightSubtitle(
        isOn: Bool,
        brightnessPercentage: Int?,
        pendingCommand: HAEntityPendingCommand?
    ) -> String {
        if let pendingCommand {
            if let brightnessPercentage {
                return "Setting \(brightnessPercentage)%..."
            }

            switch pendingCommand.expectedState {
            case "on":
                return "Turning On..."
            case "off":
                return "Turning Off..."
            default:
                return "Updating..."
            }
        }

        guard isOn else { return "Off" }
        guard let brightnessPercentage else { return "On" }

        return "\(brightnessPercentage)%"
    }

    private static func pendingBrightnessPercentage(from pendingCommand: HAEntityPendingCommand?) -> Int? {
        guard let brightness = pendingCommand?.expectedAttributes["brightness"]?.doubleValue else {
            return nil
        }

        let percentage = Int((brightness / 255.0) * 100.0)
        return min(max(percentage, 1), 100)
    }

    private static func subtitle(for entity: HomeEntity) -> String {
        switch entity.domain {
        case .scene:
            entity.isAvailable ? "Scene" : "Scene unavailable"
        case .script:
            if !entity.isAvailable {
                "Script unavailable"
            } else if entity.state == "on" {
                "Running"
            } else {
                "Script"
            }
        case .light, .climate, .cover, .sensor, .other:
            entity.state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func headline(for entity: HomeEntity) -> String? {
        switch entity.domain {
        case .scene, .script:
            entity.isAvailable ? "Run" : nil
        case .light, .climate, .cover, .sensor, .other:
            nil
        }
    }

    private static func isActive(_ entity: HomeEntity) -> Bool {
        switch entity.domain {
        case .script:
            entity.state == "on"
        case .scene:
            false
        case .light, .climate, .cover, .sensor, .other:
            entity.state == "on" || entity.state == "open"
        }
    }

    private static func accentColor(for entity: HomeEntity) -> Color {
        switch entity.domain {
        case .scene:
            .purple
        case .script:
            .accentColor
        case .light, .climate, .cover, .sensor, .other:
            .accentColor
        }
    }

    private static func sensorAccentColor(for sensor: SensorEntity) -> Color {
        guard sensor.isAvailable else { return .secondary }

        switch sensor.displayKind {
        case .temperature:
            return .orange
        case .humidity, .water:
            return .cyan
        case .battery:
            return .green
        case .energy, .power, .voltage, .current, .illuminance:
            return .yellow
        case .pressure:
            return .purple
        case .signal:
            return .blue
        case .gas:
            return .orange
        case .problem:
            return .red
        case .generic:
            return .accentColor
        }
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
