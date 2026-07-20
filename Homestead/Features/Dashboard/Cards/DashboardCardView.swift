import SwiftUI

struct DashboardCardView: View {
    let entityID: String
    let size: DashboardCardSize
    var presentationKind: DashboardPresentationKind?
    var displayNameOverride: String?
    var iconNameOverride: String?
    var gaugeZoneConfiguration: GaugeZoneConfiguration?
    var contextualAreaName: String?
    var cameraRefreshGeneration = 0
    var isEditing = false
    var isPreview = false
    var openDetails: (() -> Void)?

    init(
        entityID: String,
        size: DashboardCardSize,
        presentationKind: DashboardPresentationKind? = nil,
        displayNameOverride: String? = nil,
        iconNameOverride: String? = nil,
        gaugeZoneConfiguration: GaugeZoneConfiguration? = nil,
        contextualAreaName: String? = nil,
        cameraRefreshGeneration: Int = 0,
        isEditing: Bool = false,
        openDetails: (() -> Void)? = nil
    ) {
        self.entityID = entityID
        self.size = size
        self.presentationKind = presentationKind
        self.displayNameOverride = displayNameOverride
        self.iconNameOverride = iconNameOverride
        self.gaugeZoneConfiguration = gaugeZoneConfiguration
        self.contextualAreaName = contextualAreaName
        self.cameraRefreshGeneration = cameraRefreshGeneration
        self.isEditing = isEditing
        self.isPreview = false
        self.openDetails = openDetails
    }

    init(
        entityID: String,
        size: DashboardCardSize,
        presentationKind: DashboardPresentationKind? = nil,
        displayNameOverride: String? = nil,
        iconNameOverride: String? = nil,
        gaugeZoneConfiguration: GaugeZoneConfiguration? = nil,
        contextualAreaName: String? = nil,
        cameraRefreshGeneration: Int = 0,
        isEditing: Bool = false,
        isPreview: Bool,
        openDetails: (() -> Void)? = nil
    ) {
        self.entityID = entityID
        self.size = size
        self.presentationKind = presentationKind
        self.displayNameOverride = displayNameOverride
        self.iconNameOverride = iconNameOverride
        self.gaugeZoneConfiguration = gaugeZoneConfiguration
        self.contextualAreaName = contextualAreaName
        self.cameraRefreshGeneration = cameraRefreshGeneration
        self.isEditing = isEditing
        self.isPreview = isPreview
        self.openDetails = openDetails
    }

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var selectedDetail: DashboardCardDetail?
    @State private var confirmationRequest: ActionConfirmationRequest?

    var body: some View {
        if let entityBox = stateStore.entityBox(for: entityID) {
            let resolvedPresentationKind = presentationKind ?? DashboardPresentationCatalog.recommendation(for: entityBox).kind
            let sharedFeaturePresentation = DashboardFeaturePresentationAdapter.presentation(
                for: entityBox,
                titleOverride: resolvedDisplayNameOverride(for: entityBox)
            )
            let presentation = DashboardEntityPresentation(
                entityBox: entityBox,
                displayNameOverride: resolvedDisplayNameOverride(for: entityBox),
                iconNameOverride: iconNameOverride,
                sharedFeaturePresentation: sharedFeaturePresentation
            )

            DashboardEntityCard(
                entityBox: entityBox,
                presentation: presentation,
                size: size,
                presentationKind: resolvedPresentationKind,
                gaugeZoneConfiguration: gaugeZoneConfiguration,
                features: DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation),
                contextualAreaName: contextualAreaName,
                cameraRefreshGeneration: cameraRefreshGeneration,
                isPending: entityBox.pendingCommand != nil,
                isPrimaryActionAvailable: primaryActionAvailability(
                    primaryAction: presentation.primaryAction,
                    entityID: entityBox.entityID
                ),
                toggle: isEditing || !allowsPrimaryAction(resolvedPresentationKind)
                    ? nil
                    : isPreview
                        ? previewPrimaryAction(presentation.primaryAction)
                        : primaryAction(presentation.primaryAction, entityBox: entityBox),
                showDetails: isEditing || isPreview ? nil : detailsAction(
                    entityID: entityBox.entityID,
                    detailKind: presentation.detailKind
                ),
                featureActions: isPreview ? previewFeatureActions(for: entityBox) : featureActions(for: entityBox),
                isFeatureInteractionEnabled: !isEditing && !isPreview,
                isPreview: isPreview
            )
            .sheet(item: $selectedDetail) { detail in
                if let selectedEntityBox = stateStore.entityBox(for: detail.entityID) {
                    EntityDetailSheet(entityBox: selectedEntityBox)
                } else {
                    ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                }
            }
            .actionConfirmationDialog(request: $confirmationRequest)
        }
    }

    private func allowsPrimaryAction(_ kind: DashboardPresentationKind) -> Bool {
        [.control, .media, .action].contains(kind)
    }

    private func resolvedDisplayNameOverride(for entityBox: HAEntityState) -> String? {
        let resolvedName = EntityDisplayNameResolver.displayName(
            canonicalName: entityBox.homeEntity.displayName,
            overrideName: displayNameOverride,
            contextualAreaName: contextualAreaName
        ) ?? entityBox.homeEntity.displayName

        let displayName = entityBox.domain == .camera
            ? EntityDisplayNameResolver.cameraDisplayName(resolvedName)
            : resolvedName

        return displayName == entityBox.homeEntity.displayName ? nil : displayName
    }

    private func primaryAction(
        _ primaryAction: DashboardEntityPrimaryAction?,
        entityBox: HAEntityState
    ) -> (() -> Void)? {
        guard let primaryAction else { return nil }

        return {
            HapticFeedback.selection()
            guard let serviceCall = resolvedServiceCall(for: primaryAction, entityBox: entityBox) else {
                Task { await homeAssistantService.perform(primaryAction, entityID: entityBox.entityID) }
                return
            }

            confirmOrPerform(entityBox: entityBox, domain: serviceCall.domain, service: serviceCall.service) {
                Task { await homeAssistantService.perform(primaryAction, entityID: entityBox.entityID) }
            }
        }
    }

    private func previewPrimaryAction(_ primaryAction: DashboardEntityPrimaryAction?) -> (() -> Void)? {
        primaryAction == nil ? nil : {}
    }

    private func primaryActionAvailability(
        primaryAction: DashboardEntityPrimaryAction?,
        entityID: String
    ) -> Bool {
        guard let primaryAction else {
            return true
        }

        return homeAssistantService.serviceActionAvailable(primaryAction, entityID: entityID)
    }

    private func detailsAction(
        entityID: String,
        detailKind: DashboardEntityDetailKind
    ) -> (() -> Void)? {
        if let openDetails {
            return openDetails
        }

        return {
            selectedDetail = DashboardCardDetail(
                entityID: entityID,
                kind: cardDetailKind(for: detailKind)
            )
        }
    }

    private func setLightBrightnessAction(for entityBox: HAEntityState) -> ((Double) -> Void)? {
        guard entityBox.lightEntity?.supportsBrightness == true,
              homeAssistantService.serviceActionAvailable(domain: "light", service: "turn_on") else {
            return nil
        }

        return { brightnessPercentage in
            HapticFeedback.selection()
            Task {
                await homeAssistantService.setLightBrightness(
                    entityID: entityBox.entityID,
                    brightnessPercentage: brightnessPercentage
                )
            }
        }
    }

    private func setFanPercentageAction(for entityBox: HAEntityState) -> ((Double) -> Void)? {
        guard entityBox.fanEntity?.supportsPercentageControl == true,
              homeAssistantService.serviceActionAvailable(domain: "fan", service: "set_percentage") else {
            return nil
        }

        return { percentage in
            HapticFeedback.selection()
            Task {
                await homeAssistantService.setFanPercentage(
                    entityID: entityBox.entityID,
                    percentage: percentage
                )
            }
        }
    }

    private func setClimateTemperatureAction(for entityBox: HAEntityState) -> ((Double) -> Void)? {
        guard entityBox.climateEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_temperature") else {
            return nil
        }

        return { temperature in
            Task {
                await homeAssistantService.setClimateTemperature(
                    entityID: entityBox.entityID,
                    temperature: temperature
                )
            }
        }
    }

    private func setClimateTemperatureRangeAction(for entityBox: HAEntityState) -> ((Double, Double) -> Void)? {
        guard entityBox.climateEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_temperature") else {
            return nil
        }

        return { lowTemperature, highTemperature in
            Task {
                await homeAssistantService.setClimateTemperatureRange(
                    entityID: entityBox.entityID,
                    lowTemperature: lowTemperature,
                    highTemperature: highTemperature
                )
            }
        }
    }

    private func openCoverAction(for entityBox: HAEntityState) -> (() -> Void)? {
        guard entityBox.coverEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "cover", service: "open_cover") else {
            return nil
        }

        return {
            HapticFeedback.selection()
            confirmOrPerform(entityBox: entityBox, domain: "cover", service: "open_cover") {
                Task {
                    await homeAssistantService.openCover(entityID: entityBox.entityID)
                }
            }
        }
    }

    private func stopCoverAction(for entityBox: HAEntityState) -> (() -> Void)? {
        guard entityBox.coverEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "cover", service: "stop_cover") else {
            return nil
        }

        return {
            HapticFeedback.selection()
            confirmOrPerform(entityBox: entityBox, domain: "cover", service: "stop_cover") {
                Task {
                    await homeAssistantService.stopCover(entityID: entityBox.entityID)
                }
            }
        }
    }

    private func closeCoverAction(for entityBox: HAEntityState) -> (() -> Void)? {
        guard entityBox.coverEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "cover", service: "close_cover") else {
            return nil
        }

        return {
            HapticFeedback.selection()
            confirmOrPerform(entityBox: entityBox, domain: "cover", service: "close_cover") {
                Task {
                    await homeAssistantService.closeCover(entityID: entityBox.entityID)
                }
            }
        }
    }

    private func setCoverPositionAction(for entityBox: HAEntityState) -> ((Double) -> Void)? {
        guard entityBox.coverEntity?.positionPercentage != nil,
              homeAssistantService.serviceActionAvailable(domain: "cover", service: "set_cover_position") else {
            return nil
        }

        return { position in
            HapticFeedback.selection()
            Task {
                await homeAssistantService.setCoverPosition(
                    entityID: entityBox.entityID,
                    position: position
                )
            }
        }
    }

    private func lockAction(for entityBox: HAEntityState) -> (() -> Void)? {
        guard entityBox.homeEntity.domain == .lock,
              homeAssistantService.serviceActionAvailable(domain: "lock", service: "lock") else {
            return nil
        }

        return {
            HapticFeedback.selection()
            confirmOrPerform(entityBox: entityBox, domain: "lock", service: "lock") {
                Task {
                    await homeAssistantService.toggleLock(entityID: entityBox.entityID)
                }
            }
        }
    }

    private func unlockAction(for entityBox: HAEntityState) -> (() -> Void)? {
        guard entityBox.homeEntity.domain == .lock,
              homeAssistantService.serviceActionAvailable(domain: "lock", service: "unlock") else {
            return nil
        }

        return {
            HapticFeedback.selection()
            confirmOrPerform(entityBox: entityBox, domain: "lock", service: "unlock") {
                Task {
                    await homeAssistantService.toggleLock(entityID: entityBox.entityID)
                }
            }
        }
    }

    private func selectOptionAction(for entityBox: HAEntityState) -> ((String) -> Void)? {
        guard entityBox.selectEntity?.options.isEmpty == false,
              homeAssistantService.serviceActionAvailable(
                domain: HomeAssistantService.selectServiceDomain(for: entityBox.entityID),
                service: "select_option"
              ) else {
            return nil
        }

        return { option in
            Task {
                await homeAssistantService.selectOption(entityID: entityBox.entityID, option: option)
            }
        }
    }

    private func featureActions(for entityBox: HAEntityState) -> DashboardCardFeatureActions {
        DashboardCardFeatureActions(
            setLightBrightness: setLightBrightnessAction(for: entityBox),
            setFanPercentage: setFanPercentageAction(for: entityBox),
            setClimateTemperature: setClimateTemperatureAction(for: entityBox),
            setClimateTemperatureRange: setClimateTemperatureRangeAction(for: entityBox),
            openCover: openCoverAction(for: entityBox),
            stopCover: stopCoverAction(for: entityBox),
            closeCover: closeCoverAction(for: entityBox),
            setCoverPosition: setCoverPositionAction(for: entityBox),
            lock: lockAction(for: entityBox),
            unlock: unlockAction(for: entityBox),
            selectOption: selectOptionAction(for: entityBox),
            playPauseMedia: playPauseMediaAction(for: entityBox),
            setMediaVolume: setMediaVolumeAction(for: entityBox),
            selectMediaSource: selectMediaSourceAction(for: entityBox)
        )
    }

    private func playPauseMediaAction(for entityBox: HAEntityState) -> (() -> Void)? {
        guard entityBox.mediaPlayerEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "media_player", service: "media_play_pause") else {
            return nil
        }

        return {
            HapticFeedback.selection()
            Task { await homeAssistantService.playPauseMedia(entityID: entityBox.entityID) }
        }
    }

    private func setMediaVolumeAction(for entityBox: HAEntityState) -> ((Double) -> Void)? {
        guard entityBox.mediaPlayerEntity?.volumeLevel != nil,
              homeAssistantService.serviceActionAvailable(domain: "media_player", service: "volume_set") else {
            return nil
        }

        return { volume in
            Task {
                await homeAssistantService.setMediaVolume(
                    entityID: entityBox.entityID,
                    volumePercentage: volume
                )
            }
        }
    }

    private func selectMediaSourceAction(for entityBox: HAEntityState) -> ((String) -> Void)? {
        guard entityBox.mediaPlayerEntity?.sourceList.isEmpty == false,
              homeAssistantService.serviceActionAvailable(domain: "media_player", service: "select_source") else {
            return nil
        }

        return { source in
            Task { await homeAssistantService.selectMediaSource(entityID: entityBox.entityID, source: source) }
        }
    }

    private func confirmOrPerform(
        entityBox: HAEntityState,
        domain: String,
        service: String,
        perform: @escaping () -> Void
    ) {
        guard let presentation = ActionConfirmationPolicy.confirmation(
            for: entityBox,
            domain: domain,
            service: service,
            settings: actionConfirmationSettings.snapshot
        ) else {
            perform()
            return
        }

        confirmationRequest = ActionConfirmationRequest(
            presentation: presentation,
            perform: perform
        )
    }

    private func resolvedServiceCall(
        for action: DashboardEntityPrimaryAction,
        entityBox: HAEntityState
    ) -> DashboardServiceCall? {
        switch action {
        case .toggleLight:
            let service = entityBox.lightEntity?.isOn == true ? "turn_off" : "turn_on"
            return DashboardServiceCall(domain: "light", service: service)
        case .toggleCover:
            let service = entityBox.coverEntity?.isOpen == true ? "close_cover" : "open_cover"
            return DashboardServiceCall(domain: "cover", service: service)
        case .toggleSwitch:
            let service = entityBox.homeEntity.state == "on" ? "turn_off" : "turn_on"
            return DashboardServiceCall(domain: "switch", service: service)
        case .toggleFan:
            let service = entityBox.homeEntity.state == "on" ? "turn_off" : "turn_on"
            return DashboardServiceCall(domain: "fan", service: service)
        case .toggleLock:
            let service = entityBox.homeEntity.state == "locked" ? "unlock" : "lock"
            return DashboardServiceCall(domain: "lock", service: service)
        case .toggleAutomation:
            let service = entityBox.homeEntity.state == "on" ? "turn_off" : "turn_on"
            return DashboardServiceCall(domain: "automation", service: service)
        case .activateScene:
            return DashboardServiceCall(domain: "scene", service: "turn_on")
        case .runScript:
            return DashboardServiceCall(domain: "script", service: "turn_on")
        case .pressButton:
            return DashboardServiceCall(domain: "button", service: "press")
        }
    }

    private func previewFeatureActions(for entityBox: HAEntityState) -> DashboardCardFeatureActions {
        let noopSingle: (Double) -> Void = { _ in }
        let noopPair: (Double, Double) -> Void = { _, _ in }
        let noopCommand: () -> Void = {}

        return DashboardCardFeatureActions(
            setLightBrightness: entityBox.lightEntity?.supportsBrightness == true ? noopSingle : nil,
            setFanPercentage: entityBox.fanEntity?.supportsPercentageControl == true ? noopSingle : nil,
            setClimateTemperature: entityBox.climateEntity?.targetTemperature != nil ? noopSingle : nil,
            setClimateTemperatureRange: entityBox.climateEntity?.usesTemperatureRange == true ? noopPair : nil,
            openCover: entityBox.coverEntity != nil ? noopCommand : nil,
            stopCover: entityBox.coverEntity != nil ? noopCommand : nil,
            closeCover: entityBox.coverEntity != nil ? noopCommand : nil,
            setCoverPosition: entityBox.coverEntity?.positionPercentage != nil ? noopSingle : nil,
            lock: entityBox.domain == .lock ? noopCommand : nil,
            unlock: entityBox.domain == .lock ? noopCommand : nil,
            selectOption: entityBox.selectEntity?.options.isEmpty == false ? { _ in } : nil,
            playPauseMedia: entityBox.mediaPlayerEntity == nil ? nil : noopCommand,
            setMediaVolume: entityBox.mediaPlayerEntity?.volumeLevel == nil ? nil : noopSingle,
            selectMediaSource: entityBox.mediaPlayerEntity?.sourceList.isEmpty == false ? { _ in } : nil
        )
    }

    private func cardDetailKind(for detailKind: DashboardEntityDetailKind) -> DashboardCardDetail.Kind {
        switch detailKind {
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
        case .weather:
            .weather
        case .alarmControlPanel:
            .alarmControlPanel
        case .button:
            .button
        case .select:
            .select
        case .number:
            .number
        case .entity:
            .entity
        }
    }
}

private struct DashboardServiceCall {
    let domain: String
    let service: String
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
        case weather
        case alarmControlPanel
        case button
        case select
        case number
        case entity
    }

    let entityID: String
    let kind: Kind

    var id: String {
        "\(kind)-\(entityID)"
    }
}

#if DEBUG
private struct DashboardCardDisplaySizesPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
//            HStack(alignment: .top, spacing: AppSpacing.medium) {/
                DashboardCardView(entityID: "light.living_room_lamps", size: .mini)
                    .frame(width: 82)

                DashboardCardView(entityID: "light.living_room_lamps", size: .compact)
                    .frame(width: 180)

                DashboardCardView(entityID: "sensor.hallway_temperature", size: .square)
                    .frame(width: 180)
//            }

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

private struct DashboardGaugeCardsPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                DashboardCardView(entityID: "sensor.front_door_battery", size: .square, isPreview: true)
                    .frame(width: 180)

                DashboardCardView(entityID: "sensor.front_door_battery", size: .wide, isPreview: true)
                    .frame(width: 376)

                DashboardCardView(entityID: "sensor.front_door_battery", size: .large, isPreview: true)
                    .frame(width: 376)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Gauge Cards — Dark") {
    DashboardGaugeCardsPreview()
        .withPreviewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("Gauge Cards — Light") {
    DashboardGaugeCardsPreview()
        .withPreviewEnvironment()
        .preferredColorScheme(.light)
}

private struct DashboardCardEditModePreview: View {
    @State private var size: DashboardCardSize = .square

    var body: some View {
        DashboardCardView(
            entityID: "light.living_room_lamps",
            size: size,
            isEditing: true
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
