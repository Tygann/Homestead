import SwiftUI

struct DashboardCardView: View {
    let entityID: String
    let size: DashboardCardSize
    var presentationKind: DashboardPresentationKind?
    var displayNameOverride: String?
    var iconNameOverride: String?
    var gaugeZoneConfiguration: GaugeZoneConfiguration?
    var chartRange: HAHistoryRangePreset = DashboardHistoryCardPresentation.defaultRange
    var contextualAreaName: String?
    var cameraRefreshGeneration = 0
    var isEditing = false
    var isPreview = false
    var usesPreviewProfilePicture = false
    var detailDestination: EntityDetailDestination?
    var openDetails: ((EntityDetailDestination) -> Void)?

    init(
        entityID: String,
        size: DashboardCardSize,
        presentationKind: DashboardPresentationKind? = nil,
        displayNameOverride: String? = nil,
        iconNameOverride: String? = nil,
        gaugeZoneConfiguration: GaugeZoneConfiguration? = nil,
        chartRange: HAHistoryRangePreset = DashboardHistoryCardPresentation.defaultRange,
        contextualAreaName: String? = nil,
        cameraRefreshGeneration: Int = 0,
        isEditing: Bool = false,
        usesPreviewProfilePicture: Bool = false,
        detailDestination: EntityDetailDestination? = nil,
        openDetails: ((EntityDetailDestination) -> Void)? = nil
    ) {
        self.entityID = entityID
        self.size = size
        self.presentationKind = presentationKind
        self.displayNameOverride = displayNameOverride
        self.iconNameOverride = iconNameOverride
        self.gaugeZoneConfiguration = gaugeZoneConfiguration
        self.chartRange = chartRange
        self.contextualAreaName = contextualAreaName
        self.cameraRefreshGeneration = cameraRefreshGeneration
        self.isEditing = isEditing
        self.isPreview = false
        self.usesPreviewProfilePicture = usesPreviewProfilePicture
        self.detailDestination = detailDestination
        self.openDetails = openDetails
    }

    init(
        entityID: String,
        size: DashboardCardSize,
        presentationKind: DashboardPresentationKind? = nil,
        displayNameOverride: String? = nil,
        iconNameOverride: String? = nil,
        gaugeZoneConfiguration: GaugeZoneConfiguration? = nil,
        chartRange: HAHistoryRangePreset = DashboardHistoryCardPresentation.defaultRange,
        contextualAreaName: String? = nil,
        cameraRefreshGeneration: Int = 0,
        isEditing: Bool = false,
        isPreview: Bool,
        usesPreviewProfilePicture: Bool = false,
        detailDestination: EntityDetailDestination? = nil,
        openDetails: ((EntityDetailDestination) -> Void)? = nil
    ) {
        self.entityID = entityID
        self.size = size
        self.presentationKind = presentationKind
        self.displayNameOverride = displayNameOverride
        self.iconNameOverride = iconNameOverride
        self.gaugeZoneConfiguration = gaugeZoneConfiguration
        self.chartRange = chartRange
        self.contextualAreaName = contextualAreaName
        self.cameraRefreshGeneration = cameraRefreshGeneration
        self.isEditing = isEditing
        self.isPreview = isPreview
        self.usesPreviewProfilePicture = usesPreviewProfilePicture
        self.detailDestination = detailDestination
        self.openDetails = openDetails
    }

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(ActionConfirmationSettings.self) private var actionConfirmationSettings
    @State private var confirmationRequest: ActionConfirmationRequest?

    var body: some View {
        if let entityBox = stateStore.entityBox(for: entityID) {
            let resolvedPresentationKind = presentationKind ?? DashboardPresentationCatalog.recommendation(for: entityBox).kind
            let weatherSolarPhase = resolvedPresentationKind == .weather
                ? stateStore.weatherSolarPhase
                : nil
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
                weatherSolarPhase: weatherSolarPhase,
                gaugeZoneConfiguration: gaugeZoneConfiguration,
                chartRange: chartRange,
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
                    presentationKind: resolvedPresentationKind
                ),
                featureActions: isPreview ? previewFeatureActions(for: entityBox) : featureActions(for: entityBox),
                isFeatureInteractionEnabled: !isEditing && !isPreview,
                isPreview: isPreview,
                usesPreviewProfilePicture: usesPreviewProfilePicture
            )
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
        presentationKind: DashboardPresentationKind
    ) -> (() -> Void)? {
        guard let openDetails,
              let detailDestination else { return nil }

        return {
            openDetails(
                DashboardCardDetailFocusPolicy.destination(
                    from: detailDestination,
                    presentationKind: presentationKind,
                    chartRange: chartRange
                )
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

    private func setClimateHVACModeAction(for entityBox: HAEntityState) -> ((String) -> Void)? {
        guard entityBox.climateEntity?.hvacModes.isEmpty == false,
              homeAssistantService.serviceActionAvailable(
                domain: "climate",
                service: "set_hvac_mode"
              ) else {
            return nil
        }

        return { mode in
            Task {
                await homeAssistantService.setClimateHVACMode(
                    entityID: entityBox.entityID,
                    hvacMode: mode
                )
            }
        }
    }

    private func setClimateFanModeAction(for entityBox: HAEntityState) -> ((String) -> Void)? {
        guard entityBox.climateEntity?.fanModes.isEmpty == false,
              homeAssistantService.serviceActionAvailable(
                domain: "climate",
                service: "set_fan_mode"
              ) else {
            return nil
        }

        return { fanMode in
            Task {
                await homeAssistantService.setClimateFanMode(
                    entityID: entityBox.entityID,
                    fanMode: fanMode
                )
            }
        }
    }

    private func setClimatePresetModeAction(for entityBox: HAEntityState) -> ((String) -> Void)? {
        guard entityBox.climateEntity?.presetModes.isEmpty == false,
              homeAssistantService.serviceActionAvailable(
                domain: "climate",
                service: "set_preset_mode"
              ) else {
            return nil
        }

        return { presetMode in
            Task {
                await homeAssistantService.setClimatePresetMode(
                    entityID: entityBox.entityID,
                    presetMode: presetMode
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
            setClimateHVACMode: setClimateHVACModeAction(for: entityBox),
            setClimateFanMode: setClimateFanModeAction(for: entityBox),
            setClimatePresetMode: setClimatePresetModeAction(for: entityBox),
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
        let noopOption: (String) -> Void = { _ in }
        let noopCommand: () -> Void = {}

        return DashboardCardFeatureActions(
            setLightBrightness: entityBox.lightEntity?.supportsBrightness == true ? noopSingle : nil,
            setFanPercentage: entityBox.fanEntity?.supportsPercentageControl == true ? noopSingle : nil,
            setClimateTemperature: entityBox.climateEntity?.targetTemperature != nil ? noopSingle : nil,
            setClimateTemperatureRange: entityBox.climateEntity?.usesTemperatureRange == true ? noopPair : nil,
            setClimateHVACMode: entityBox.climateEntity?.hvacModes.isEmpty == false ? noopOption : nil,
            setClimateFanMode: entityBox.climateEntity?.fanModes.isEmpty == false ? noopOption : nil,
            setClimatePresetMode: entityBox.climateEntity?.presetModes.isEmpty == false ? noopOption : nil,
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

}

enum DashboardCardDetailFocusPolicy {
    static func destination(
        from destination: EntityDetailDestination,
        presentationKind: DashboardPresentationKind,
        chartRange: HAHistoryRangePreset
    ) -> EntityDetailDestination {
        destination.focusing(
            presentationKind == .chart
                ? .history(initialRange: chartRange)
                : .overview
        )
    }
}

private struct DashboardServiceCall {
    let domain: String
    let service: String
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
