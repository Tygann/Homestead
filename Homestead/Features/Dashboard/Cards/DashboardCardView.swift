import Charts
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DashboardCardView: View {
    let entityID: String
    let size: DashboardCardSize
    var displayNameOverride: String?
    var iconNameOverride: String?
    var featureVisibility: DashboardCardFeatureVisibility = .automatic
    var contextualAreaName: String?
    var cameraRefreshGeneration = 0
    var isEditing = false
    var isPreview = false
    var openDetails: (() -> Void)?

    init(
        entityID: String,
        size: DashboardCardSize,
        displayNameOverride: String? = nil,
        iconNameOverride: String? = nil,
        featureVisibility: DashboardCardFeatureVisibility = .automatic,
        contextualAreaName: String? = nil,
        cameraRefreshGeneration: Int = 0,
        isEditing: Bool = false,
        openDetails: (() -> Void)? = nil
    ) {
        self.entityID = entityID
        self.size = size
        self.displayNameOverride = displayNameOverride
        self.iconNameOverride = iconNameOverride
        self.featureVisibility = featureVisibility
        self.contextualAreaName = contextualAreaName
        self.cameraRefreshGeneration = cameraRefreshGeneration
        self.isEditing = isEditing
        self.isPreview = false
        self.openDetails = openDetails
    }

    init(
        entityID: String,
        size: DashboardCardSize,
        displayNameOverride: String? = nil,
        iconNameOverride: String? = nil,
        featureVisibility: DashboardCardFeatureVisibility = .automatic,
        contextualAreaName: String? = nil,
        cameraRefreshGeneration: Int = 0,
        isEditing: Bool = false,
        isPreview: Bool,
        openDetails: (() -> Void)? = nil
    ) {
        self.entityID = entityID
        self.size = size
        self.displayNameOverride = displayNameOverride
        self.iconNameOverride = iconNameOverride
        self.featureVisibility = featureVisibility
        self.contextualAreaName = contextualAreaName
        self.cameraRefreshGeneration = cameraRefreshGeneration
        self.isEditing = isEditing
        self.isPreview = isPreview
        self.openDetails = openDetails
    }

    @Environment(HAStateStore.self) private var stateStore
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedDetail: DashboardCardDetail?

    var body: some View {
        if let entityBox = stateStore.entityBox(for: entityID) {
            let presentation = DashboardEntityPresentation(
                entityBox: entityBox,
                displayNameOverride: resolvedDisplayNameOverride(for: entityBox),
                iconNameOverride: iconNameOverride
            )

            DashboardEntityCard(
                entityBox: entityBox,
                presentation: presentation,
                size: size,
                features: DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation),
                featureVisibility: featureVisibility,
                contextualAreaName: contextualAreaName,
                cameraRefreshGeneration: cameraRefreshGeneration,
                isPending: entityBox.pendingCommand != nil,
                isPrimaryActionAvailable: primaryActionAvailability(
                    primaryAction: presentation.primaryAction,
                    entityID: entityBox.entityID
                ),
                toggle: isEditing || isPreview ? nil : primaryAction(
                    presentation.primaryAction,
                    entityID: entityBox.entityID
                ),
                showDetails: isEditing || isPreview ? nil : detailsAction(
                    entityID: entityBox.entityID,
                    detailKind: presentation.detailKind
                ),
                featureActions: isPreview ? previewFeatureActions(for: entityBox) : featureActions(for: entityBox),
                isFeatureInteractionEnabled: !isEditing && !isPreview
            )
            .sheet(item: $selectedDetail) { detail in
                if let selectedEntityBox = stateStore.entityBox(for: detail.entityID) {
                    EntityDetailSheet(entityBox: selectedEntityBox)
                } else {
                    ContentUnavailableView("Entity Unavailable", systemImage: "questionmark.circle")
                }
            }
        }
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
        entityID: String
    ) -> (() -> Void)? {
        guard let primaryAction else { return nil }

        return {
            HapticFeedback.selection()
            Task {
                await homeAssistantService.perform(primaryAction, entityID: entityID)
            }
        }
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

    private func setClimateTemperatureAction(for entityBox: HAEntityState) -> ((Double) -> Void)? {
        guard entityBox.climateEntity != nil,
              homeAssistantService.serviceActionAvailable(domain: "climate", service: "set_temperature") else {
            return nil
        }

        return { temperature in
            HapticFeedback.selection()
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
            HapticFeedback.selection()
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
            Task {
                await homeAssistantService.openCover(entityID: entityBox.entityID)
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
            Task {
                await homeAssistantService.stopCover(entityID: entityBox.entityID)
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
            Task {
                await homeAssistantService.closeCover(entityID: entityBox.entityID)
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
            Task {
                await homeAssistantService.toggleLock(entityID: entityBox.entityID)
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
            Task {
                await homeAssistantService.toggleLock(entityID: entityBox.entityID)
            }
        }
    }

    private func featureActions(for entityBox: HAEntityState) -> DashboardCardFeatureActions {
        DashboardCardFeatureActions(
            setLightBrightness: setLightBrightnessAction(for: entityBox),
            setClimateTemperature: setClimateTemperatureAction(for: entityBox),
            setClimateTemperatureRange: setClimateTemperatureRangeAction(for: entityBox),
            openCover: openCoverAction(for: entityBox),
            stopCover: stopCoverAction(for: entityBox),
            closeCover: closeCoverAction(for: entityBox),
            setCoverPosition: setCoverPositionAction(for: entityBox),
            lock: lockAction(for: entityBox),
            unlock: unlockAction(for: entityBox)
        )
    }

    private func previewFeatureActions(for entityBox: HAEntityState) -> DashboardCardFeatureActions {
        let noopSingle: (Double) -> Void = { _ in }
        let noopPair: (Double, Double) -> Void = { _, _ in }
        let noopCommand: () -> Void = {}

        return DashboardCardFeatureActions(
            setLightBrightness: entityBox.lightEntity?.supportsBrightness == true ? noopSingle : nil,
            setClimateTemperature: entityBox.climateEntity?.targetTemperature != nil ? noopSingle : nil,
            setClimateTemperatureRange: entityBox.climateEntity?.usesTemperatureRange == true ? noopPair : nil,
            openCover: entityBox.coverEntity != nil ? noopCommand : nil,
            stopCover: entityBox.coverEntity != nil ? noopCommand : nil,
            closeCover: entityBox.coverEntity != nil ? noopCommand : nil,
            setCoverPosition: entityBox.coverEntity?.positionPercentage != nil ? noopSingle : nil,
            lock: entityBox.domain == .lock ? noopCommand : nil,
            unlock: entityBox.domain == .lock ? noopCommand : nil
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

private struct DashboardEntityCard: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var historyPhase: DashboardHistoryCardPhase = .idle

    let entityBox: HAEntityState
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let features: [DashboardCardFeature]
    let featureVisibility: DashboardCardFeatureVisibility
    let contextualAreaName: String?
    let cameraRefreshGeneration: Int
    let isPending: Bool
    let isPrimaryActionAvailable: Bool
    let toggle: (() -> Void)?
    let showDetails: (() -> Void)?
    let featureActions: DashboardCardFeatureActions
    let isFeatureInteractionEnabled: Bool

    var body: some View {
        let visibleFeatureSnapshot = visibleFeatures

        Group {
            if shouldUseCameraPreviewCard {
                fullBleedCameraCard
            } else {
                standardCard(visibleFeatures: visibleFeatureSnapshot)
            }
        }
        .task(id: dashboardHistoryTaskID) {
            await refreshDashboardHistoryIfNeeded()
        }
    }

    private var fullBleedCameraCard: some View {
        let cardShape = RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)

        return Group {
            if let showDetails {
                Button(action: showDetails) {
                    cameraPreviewContent
                        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                }
                .buttonStyle(HomeCardButtonStyle())
                .accessibilityLabel(presentation.accessibilityDetailLabel)
                .accessibilityValue(presentation.accessibilityValue)
                .accessibilityHint(presentation.accessibilityDetailHint)
            } else {
                cameraPreviewContent
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: renderedCardHeight)
        .background(cameraCardBackground, in: cardShape)
        .clipShape(cardShape)
        .overlay {
            cardShape.strokeBorder(cameraCardBorder, lineWidth: 0.5)
        }
        .clipped()
    }

    private func standardCard(visibleFeatures visibleFeatureSnapshot: [DashboardCardFeature]) -> some View {
        CardContainer(
            isActive: presentation.isActive,
            accentColor: presentation.accentColor,
            minHeight: cardContainerMinHeight,
            padding: cardContainerPadding
        ) {
            ZStack(alignment: .topLeading) {
                if !visibleFeatureSnapshot.isEmpty {
                    cardContent(visibleFeatures: visibleFeatureSnapshot)
                        .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                } else if let showDetails {
                    Button(action: showDetails) {
                        cardContent(visibleFeatures: visibleFeatureSnapshot)
                            .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HomeCardButtonStyle())
                    .accessibilityLabel(presentation.accessibilityDetailLabel)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.accessibilityDetailHint)
                } else {
                    cardContent(visibleFeatures: visibleFeatureSnapshot)
                        .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                }

                if let toggle {
                    Button(action: toggle) {
                        interactiveIconView
                    }
                    .buttonStyle(.plain)
                    .disabled(isPending || !isPrimaryActionAvailable)
                    .accessibilityLabel(presentation.primaryActionAccessibilityLabel ?? presentation.title)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.primaryActionAccessibilityHint)
                }

            }
        }
    }

    @ViewBuilder
    private func cardContent(visibleFeatures: [DashboardCardFeature]) -> some View {
        if shouldUseCameraPreviewCard {
            cameraPreviewContent
        } else {
            standardCardContent(visibleFeatures: visibleFeatures)
        }
    }

    @ViewBuilder
    private func standardCardContent(visibleFeatures: [DashboardCardFeature]) -> some View {
        switch size {
        case .mini:
            miniContent
        case .compact:
            compactContent
        case .row:
            if visibleFeatures.isEmpty {
                compactContent
            } else {
                rowFeatureContent(visibleFeatures: visibleFeatures)
            }
        case .square:
            if visibleFeatures.isEmpty {
                largeContent
            } else {
                stackedFeatureContent(visibleFeatures: visibleFeatures)
            }
        case .wide, .large:
            if visibleFeatures.isEmpty {
                largeContent
            } else {
                stackedFeatureContent(visibleFeatures: visibleFeatures)
            }
        }
    }

    private var miniContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            miniIconPlaceholder

            Spacer(minLength: 0)

            Text(miniTitleText)
                .font(.system(size: 12.25, weight: .semibold))
                .foregroundStyle(miniTitleColor)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
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

    @ViewBuilder
    private var largeContent: some View {
        if shouldUseDashboardHistoryCard {
            dashboardHistoryContent
        } else {
            let contentModel = DashboardEntityCardContentModel.make(
                presentation: presentation,
                size: size
            )

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

                if let headline = contentModel.headline {
                    Text(headline)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(presentation.headlineColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if !contentModel.metrics.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        ForEach(contentModel.metrics) { metric in
                            DashboardCardMetricRow(metric: metric)
                        }
                    }
                }
            }
        }
    }

    private var dashboardHistoryContent: some View {
        VStack(alignment: .leading, spacing: dashboardHistoryContentSpacing) {
            cardHeader(subtitle: presentation.subtitle, subtitleFont: .caption.weight(.semibold))

            if size == .large, let headline = presentation.headline {
                Text(headline)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(presentation.headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            dashboardHistoryBody

            dashboardHistoryFooter
        }
    }

    @ViewBuilder
    private var dashboardHistoryBody: some View {
        switch historyPhase {
        case .idle:
            dashboardHistoryEmptyPlaceholder(title: "Recent trend")
        case .loading:
            dashboardHistoryLoadingPlaceholder
        case .loaded(let chartPresentation):
            if chartPresentation.isEmpty {
                dashboardHistoryEmptyPlaceholder(title: "No recent trend")
            } else {
                dashboardHistoryChart(chartPresentation)
            }
        case .failed:
            dashboardHistoryEmptyPlaceholder(title: "Trend unavailable")
        }
    }

    private var dashboardHistoryFooter: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
            Text(dashboardHistoryFooterText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(size == .large ? 2 : 1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: AppSpacing.small)

            Text(DashboardHistoryCardPresentation.defaultRange.title)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func dashboardHistoryChart(_ chartPresentation: DashboardHistoryCardPresentation) -> some View {
        Chart(chartPresentation.samples) { sample in
            LineMark(
                x: .value("Time", sample.occurredAt),
                y: .value("Value", sample.value)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .foregroundStyle(presentation.accentColor)

            AreaMark(
                x: .value("Time", sample.occurredAt),
                yStart: .value("Baseline", chartPresentation.valueDomain.lowerBound),
                yEnd: .value("Value", sample.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        presentation.accentColor.opacity(0.18),
                        presentation.accentColor.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartYScale(domain: chartPresentation.valueDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.clipped()
        }
        .frame(height: dashboardHistoryChartHeight)
        .clipped()
        .accessibilityLabel(chartPresentation.accessibilityLabel)
        .accessibilityValue(chartPresentation.accessibilityValue)
    }

    private var dashboardHistoryLoadingPlaceholder: some View {
        ZStack {
            dashboardHistoryEmptyPlaceholder(title: "Loading trend")

            ProgressView()
                .controlSize(.small)
        }
        .frame(height: dashboardHistoryChartHeight)
    }

    private func dashboardHistoryEmptyPlaceholder(title: String) -> some View {
        VStack(spacing: AppSpacing.xSmall) {
            Spacer(minLength: 0)

            Rectangle()
                .fill(Color.secondary.opacity(0.24))
                .frame(height: 1)
                .overlay(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.secondary.opacity(0.16))
                                .frame(width: 1, height: 6)

                            Spacer(minLength: 0)
                        }
                    }
                }

            Spacer(minLength: 0)
        }
        .frame(height: dashboardHistoryChartHeight)
        .accessibilityLabel(title)
        .accessibilityValue(dashboardHistoryFooterText)
    }

    private var cameraPreviewContent: some View {
        CameraCardPreview(
            entityID: entityBox.entityID,
            isAvailable: entityBox.homeEntity.isAvailable,
            title: cameraPreviewTitle,
            accessibilityTitle: presentation.title,
            fallbackSystemImage: presentation.iconName,
            refreshGeneration: cameraRefreshGeneration,
            height: renderedCardHeight
        )
    }

    private func rowFeatureContent(visibleFeatures: [DashboardCardFeature]) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            featureHeader
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(visibleFeatures) { feature in
                DashboardCardFeatureView(
                    feature: feature,
                    isPending: isPending,
                    isActive: presentation.isActive,
                    fillColor: iconColor,
                    trackColor: iconBackground,
                    isInteractionEnabled: isFeatureInteractionEnabled,
                    actions: featureActions
                )
                .frame(maxWidth: 180)
            }
        }
    }

    private func stackedFeatureContent(visibleFeatures: [DashboardCardFeature]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            featureHeader

            if size == .large {
                largeFeatureContext
            } else {
                Spacer(minLength: AppSpacing.xSmall)
            }

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                ForEach(visibleFeatures) { feature in
                    DashboardCardFeatureView(
                        feature: feature,
                        isPending: isPending,
                        isActive: presentation.isActive,
                        fillColor: iconColor,
                        trackColor: iconBackground,
                        isInteractionEnabled: isFeatureInteractionEnabled,
                        actions: featureActions
                    )
                }
            }
        }
    }

    private var largeFeatureContext: some View {
        let contentModel = DashboardEntityCardContentModel.make(
            presentation: presentation,
            size: size
        )

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if let headline = contentModel.headline {
                Text(headline)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(presentation.headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if !contentModel.metrics.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    ForEach(contentModel.metrics.prefix(2)) { metric in
                        DashboardCardMetricRow(metric: metric)
                    }
                }
            }

            Spacer(minLength: AppSpacing.xSmall)
        }
    }

    private var featureHeader: some View {
        Group {
            if let showDetails {
                Button(action: showDetails) {
                    cardHeader(subtitle: featureHeaderSubtitle, subtitleFont: .caption.weight(.semibold))
                        .contentShape(Rectangle())
                }
                .buttonStyle(HomeCardButtonStyle())
                .accessibilityLabel(presentation.accessibilityDetailLabel)
                .accessibilityValue(presentation.accessibilityValue)
                .accessibilityHint(presentation.accessibilityDetailHint)
            } else {
                cardHeader(subtitle: featureHeaderSubtitle, subtitleFont: .caption.weight(.semibold))
            }
        }
    }

    private func cardHeader(subtitle: String, subtitleFont: Font) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            iconPlaceholder

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitle)
                    .font(subtitleFont)
                    .foregroundStyle(presentation.subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private var featureHeaderSubtitle: String {
        guard let climate = entityBox.climateEntity else {
            return presentation.subtitle
        }

        let mode = climate.displayState
        guard let currentTemperatureText = climate.currentTemperatureText else {
            return mode
        }

        return "\(mode) • \(currentTemperatureText)"
    }

    private var cameraPreviewTitle: String {
        guard presentation.capability.domain == .camera else {
            return presentation.title
        }

        let trimmedTitle = presentation.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard contextualAreaName != nil,
              trimmedTitle.localizedCaseInsensitiveCompare("Camera") == .orderedSame else {
            return presentation.title
        }

        return ""
    }

    private var iconPlaceholder: some View {
        Color.clear
            .frame(width: 44, height: 44)
            .overlay(alignment: .topLeading) {
                if toggle == nil {
                    CardIconView(
                        systemName: presentation.iconName,
                        isActive: presentation.isActive,
                        isAvailable: presentation.isAvailable,
                        accentColor: presentation.accentColor
                    )
                }
            }
    }

    private var interactiveIconView: some View {
        Group {
            if size == .mini {
                miniGlyph
                    .frame(width: 28, height: 24, alignment: .topLeading)
                    .contentShape(Rectangle())
            } else {
                CardIconView(
                    systemName: presentation.iconName,
                    isActive: presentation.isActive,
                    isAvailable: presentation.isAvailable,
                    accentColor: presentation.accentColor
                )
            }
        }
    }

    private var miniIconPlaceholder: some View {
        Color.clear
            .frame(width: 28, height: 22)
            .overlay(alignment: .topLeading) {
                if toggle == nil {
                    miniGlyph
                }
            }
    }

    private var miniGlyph: some View {
        Image(systemName: presentation.iconName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(miniGlyphColor)
            .accessibilityHidden(true)
    }

    private var miniTitleText: String {
        presentation.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var miniTitleColor: Color {
        guard presentation.isAvailable else {
            return .secondary
        }

        return .primary
    }

    private var miniGlyphColor: Color {
        guard presentation.isAvailable else {
            return .secondary
        }

        guard presentation.isActive else {
            return .primary
        }

        return colorScheme == .dark ? .white : presentation.accentColor
    }

    private var iconColor: Color {
        presentation.isActive ? presentation.accentColor : Color.primary
    }

    private var iconBackground: Color {
        presentation.isActive ? presentation.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var cameraCardBackground: Color {
        presentation.isActive ? presentation.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground)
    }

    private var cameraCardBorder: Color {
        presentation.isActive ? presentation.accentColor.opacity(0.22) : Color(.separator).opacity(0.18)
    }
    
    private var cardContentMinHeight: CGFloat {
        max(0, cardContainerMinHeight - (cardContainerPadding * 2))
    }

    private var cardContainerMinHeight: CGFloat {
        max(0, renderedCardHeight - (cardContainerPadding * 2))
    }

    private var cardContainerPadding: CGFloat {
        size == .mini ? AppSpacing.small : AppSpacing.medium
    }

    private var renderedCardHeight: CGFloat {
        size.renderedHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }

    private var visibleFeatures: [DashboardCardFeature] {
        size.visibleFeatures(from: features, visibility: featureVisibility).filter { featureActions.canRender($0) }
    }

    private var shouldUseCameraPreviewCard: Bool {
        guard presentation.capability.domain == .camera else {
            return false
        }

        switch size {
        case .square, .wide, .large:
            return true
        case .mini, .compact, .row:
            return false
        }
    }

    private var shouldUseDashboardHistoryCard: Bool {
        DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: size)
    }

    private var dashboardHistoryTaskID: String {
        guard shouldUseDashboardHistoryCard,
              isFeatureInteractionEnabled,
              scenePhase == .active else {
            return "dashboard-history-disabled-\(entityBox.entityID)-\(size.rawValue)"
        }

        return "dashboard-history-\(entityBox.entityID)-\(size.rawValue)-\(DashboardHistoryCardPresentation.defaultRange.rawValue)"
    }

    private var dashboardHistoryContentSpacing: CGFloat {
        size == .large ? AppSpacing.medium : AppSpacing.small
    }

    private var dashboardHistoryChartHeight: CGFloat {
        size == .large ? 150 : 56
    }

    private var dashboardHistoryFooterText: String {
        switch historyPhase {
        case .idle:
            return "Recent trend"
        case .loading:
            return "Loading recent trend"
        case .loaded(let chartPresentation):
            return chartPresentation.isEmpty ? chartPresentation.accessibilityValue : chartPresentation.summaryText
        case .failed:
            return "Trend unavailable"
        }
    }

    @MainActor
    private func refreshDashboardHistoryIfNeeded() async {
        guard shouldUseDashboardHistoryCard else {
            historyPhase = .idle
            return
        }

        guard isFeatureInteractionEnabled,
              scenePhase == .active else {
            if case .loading = historyPhase {
                historyPhase = .idle
            }
            return
        }

        if case .loaded(let chartPresentation) = historyPhase,
           chartPresentation.entityID == entityBox.entityID,
           chartPresentation.range == DashboardHistoryCardPresentation.defaultRange {
            return
        }

        historyPhase = .loading

        do {
            let series = try await homeAssistantService.fetchDashboardHistory(
                settings: connectionSettings,
                entityID: entityBox.entityID,
                range: DashboardHistoryCardPresentation.defaultRange
            )
            guard !Task.isCancelled else { return }
            historyPhase = .loaded(DashboardHistoryCardPresentation(series: series))
        } catch {
            guard !Task.isCancelled else { return }
            historyPhase = .failed
        }
    }
}

private enum DashboardHistoryCardPhase: Equatable {
    case idle
    case loading
    case loaded(DashboardHistoryCardPresentation)
    case failed
}

private struct CameraCardPreview: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.scenePhase) private var scenePhase
    @State private var snapshotPhase: CameraCardSnapshotPhase = .idle

    let entityID: String
    let isAvailable: Bool
    let title: String
    let accessibilityTitle: String
    let fallbackSystemImage: String
    let refreshGeneration: Int
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                snapshotContent(width: proxy.size.width)
                    .frame(width: proxy.size.width, height: height)
                    .background(Color(.tertiarySystemGroupedBackground))

                LinearGradient(
                    colors: [.clear, .black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: height)

                if shouldShowTextOverlay {
                    ZStack(alignment: .leading) {
                        Color.black.opacity(0.42)

                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, AppSpacing.small)
                    }
                    .frame(width: proxy.size.width, height: footerHeight)
                } else {
                    EmptyView()
                        .frame(width: proxy.size.width, alignment: .bottomLeading)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .task(id: refreshTaskID) {
            await refreshSnapshotsWhileVisible()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(snapshotSubtitle)
    }

    @ViewBuilder
    private func snapshotContent(width: CGFloat) -> some View {
        switch snapshotPhase {
        case .idle, .loading:
            cameraPlaceholder(status: placeholderStatus)
                .frame(width: width, height: height)
        case .loaded(let data):
            #if canImport(UIKit)
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                cameraPlaceholder(status: .failed)
                    .frame(width: width, height: height)
            }
            #else
            cameraPlaceholder(status: .failed)
                .frame(width: width, height: height)
            #endif
        case .failed:
            cameraPlaceholder(status: placeholderStatus)
                .frame(width: width, height: height)
        }
    }

    private var snapshotSubtitle: String {
        guard isAvailable else {
            return "Unavailable"
        }

        switch snapshotPhase {
        case .idle, .loading:
            return "Loading preview"
        case .loaded:
            return ""
        case .failed:
            return "Preview unavailable"
        }
    }

    private var shouldShowTextOverlay: Bool {
        !title.isEmpty
    }

    private var footerHeight: CGFloat {
        min(max(42, height * 0.2), 56)
    }

    private var placeholderStatus: CameraCardPlaceholderStatus {
        guard isAvailable else {
            return .unavailable
        }

        switch snapshotPhase {
        case .idle, .loading:
            return .loading
        case .loaded:
            return .failed
        case .failed:
            return .failed
        }
    }

    private func cameraPlaceholder(status: CameraCardPlaceholderStatus) -> some View {
        ZStack {
            Color(.tertiarySystemGroupedBackground)

            if status == .loading {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Image(systemName: status.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var refreshTaskID: String {
        "\(entityID)-\(isAvailable)-\(scenePhase == .active)-\(refreshGeneration)"
    }

    @MainActor
    private func refreshSnapshotsWhileVisible() async {
        guard isAvailable else {
            snapshotPhase = .failed
            return
        }

        guard scenePhase == .active else {
            return
        }

        await loadSnapshot(useCache: refreshGeneration == 0)

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: refreshIntervalNanoseconds)
            } catch {
                return
            }

            await loadSnapshot(useCache: false)
        }
    }

    @MainActor
    private func loadSnapshot(useCache: Bool) async {
        if useCache,
           let cachedSnapshot = await CameraCardSnapshotCache.shared.snapshot(for: entityID) {
            snapshotPhase = .loaded(cachedSnapshot)
            return
        }

        let shouldShowLoadingState = !snapshotPhase.hasLoadedSnapshot
        if shouldShowLoadingState {
            snapshotPhase = .loading
        }

        do {
            let snapshot = try await homeAssistantService.fetchCameraSnapshot(entityID: entityID)
            await CameraCardSnapshotCache.shared.store(snapshot, for: entityID)
            guard !Task.isCancelled else { return }
            snapshotPhase = .loaded(snapshot)
        } catch {
            guard !Task.isCancelled else { return }
            if shouldShowLoadingState {
                snapshotPhase = .failed
            }
        }
    }

    private var refreshIntervalNanoseconds: UInt64 {
        CameraCardSnapshotCache.baseRefreshIntervalNanoseconds + refreshJitterNanoseconds
    }

    private var refreshJitterNanoseconds: UInt64 {
        UInt64(entityID.hashValue.magnitude % 8) * 1_000_000_000
    }
}

private enum CameraCardSnapshotPhase: Equatable {
    case idle
    case loading
    case loaded(Data)
    case failed

    var hasLoadedSnapshot: Bool {
        if case .loaded = self {
            return true
        }

        return false
    }
}

private enum CameraCardPlaceholderStatus {
    case loading
    case unavailable
    case failed

    var title: String {
        switch self {
        case .loading:
            return "Loading preview"
        case .unavailable:
            return "Unavailable"
        case .failed:
            return "Preview unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .loading:
            return "progress.indicator"
        case .unavailable, .failed:
            return "photo.badge.exclamationmark"
        }
    }
}

private actor CameraCardSnapshotCache {
    static let shared = CameraCardSnapshotCache()
    nonisolated static let baseRefreshIntervalNanoseconds: UInt64 = 45_000_000_000

    private struct Entry {
        let data: Data
        let date: Date
    }

    private var entriesByEntityID: [String: Entry] = [:]
    private let timeToLive: TimeInterval = 45

    func snapshot(for entityID: String, now: Date = Date()) -> Data? {
        guard let entry = entriesByEntityID[entityID] else {
            return nil
        }

        guard now.timeIntervalSince(entry.date) <= timeToLive else {
            entriesByEntityID[entityID] = nil
            return nil
        }

        return entry.data
    }

    func store(_ data: Data, for entityID: String, now: Date = Date()) {
        entriesByEntityID[entityID] = Entry(data: data, date: now)
    }
}

private struct DashboardCardMetricRow: View {
    let metric: DashboardEntityCardMetric

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Image(systemName: metric.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(metric.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: AppSpacing.small)

            Text(metric.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.trailing)
        }
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
