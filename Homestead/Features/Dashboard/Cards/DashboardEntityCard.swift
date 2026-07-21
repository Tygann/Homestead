import SwiftUI

struct DashboardEntityCard: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive
    @Environment(\.scenePhase) private var scenePhase
    @State private var historyPhase: DashboardHistoryCardPhase = .idle
    @State private var weatherForecastConsumerID = UUID().uuidString

    let entityBox: HAEntityState
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let presentationKind: DashboardPresentationKind
    let gaugeZoneConfiguration: GaugeZoneConfiguration?
    let chartRange: HAHistoryRangePreset
    let features: [DashboardCardFeature]
    let contextualAreaName: String?
    let cameraRefreshGeneration: Int
    let isPending: Bool
    let isPrimaryActionAvailable: Bool
    let toggle: (() -> Void)?
    let showDetails: (() -> Void)?
    let featureActions: DashboardCardFeatureActions
    let isFeatureInteractionEnabled: Bool
    let isPreview: Bool

    var body: some View {
        let visibleFeatureSnapshot = visibleFeatures

        Group {
            if shouldUseCameraPreviewCard {
                fullBleedCameraCard
            } else if shouldUseImmersiveCard {
                fullBleedSpecializedCard
            } else {
                standardCard(visibleFeatures: visibleFeatureSnapshot)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .task(id: dashboardHistoryTaskID) {
            await refreshDashboardHistoryIfNeeded()
        }
        .task(id: weatherForecastTaskID) {
            await updateWeatherForecastSubscription()
        }
        .onDisappear {
            guard presentationKind == .weather, !isPreview else { return }
            Task {
                await homeAssistantService.stopWeatherForecastUpdates(
                    entityID: entityBox.entityID,
                    consumerID: weatherForecastConsumerID
                )
            }
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

    private var fullBleedSpecializedCard: some View {
        let cardShape = RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)

        return Group {
            if let showDetails {
                Button(action: showDetails) {
                    specializedCardVisual
                        .contentShape(cardShape)
                }
                .buttonStyle(HomeCardButtonStyle())
                .accessibilityHint(presentation.accessibilityDetailHint)
            } else {
                specializedCardVisual
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: renderedCardHeight)
        .background(cameraCardBackground, in: cardShape)
        .clipShape(cardShape)
        .overlay {
            cardShape.strokeBorder(specializedCardBorder, lineWidth: 0.5)
        }
        .clipped()
    }

    @ViewBuilder
    private var specializedCardVisual: some View {
        if presentationKind == .weather, let weather = entityBox.weatherEntity {
            DashboardWeatherCardContent(
                weather: weather,
                forecastsByType: entityBox.weatherForecastsByType,
                loadingForecastTypes: entityBox.loadingWeatherForecastTypes,
                forecastErrorsByType: entityBox.weatherForecastErrorsByType,
                size: size
            )
        } else {
            DashboardChartCardContent(
                presentation: presentation,
                sensor: entityBox.sensorEntity,
                state: chartCardState,
                size: size
            )
        }
    }

    private func standardCard(visibleFeatures visibleFeatureSnapshot: [DashboardCardFeature]) -> some View {
        CardContainer(
            minHeight: cardContainerMinHeight,
            padding: cardContainerPadding
        ) {
            ZStack(alignment: .topLeading) {
                if usesEmbeddedCardInteractions {
                    cardContent(visibleFeatures: visibleFeatureSnapshot)
                        .frame(maxWidth: .infinity)
                        .frame(height: cardContentMinHeight, alignment: .topLeading)
                } else if !visibleFeatureSnapshot.isEmpty {
                    if gaugeFirstPresentation(from: visibleFeatureSnapshot) != nil {
                        cardContent(visibleFeatures: visibleFeatureSnapshot)
                            .frame(maxWidth: .infinity)
                            .frame(height: cardContainerMinHeight, alignment: .topLeading)
                    } else {
                        cardContent(visibleFeatures: visibleFeatureSnapshot)
                            .frame(maxWidth: .infinity, minHeight: cardContentMinHeight, alignment: .topLeading)
                    }
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

                if let toggle, !usesEmbeddedCardInteractions {
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
        if presentationKind == .media, let media = entityBox.mediaPlayerEntity {
            DashboardMediaCardContent(
                media: media,
                presentation: presentation,
                size: size,
                isPending: isPending,
                playPause: featureActions.playPauseMedia,
                setVolume: featureActions.setMediaVolume,
                selectSource: featureActions.selectMediaSource,
                showDetails: showDetails
            )
        } else if presentationKind == .action {
            DashboardActionCardContent(
                presentation: presentation,
                size: size,
                isPending: isPending,
                trigger: toggle,
                showDetails: showDetails
            )
        } else {
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
    }

    private var miniContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            miniIconPlaceholder

            Text(miniTitleText)
                .font(.caption.weight(.medium))
                .foregroundStyle(miniTitleColor)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, miniContentHorizontalInset)
        .padding(.vertical, miniContentVerticalInset)
        .frame(maxWidth: .infinity, minHeight: cardContainerMinHeight, alignment: .topLeading)
    }

    private var compactContent: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            iconPlaceholder

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .truncationMode(.tail)

                Text(presentation.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(presentation.subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        }
    }

    @ViewBuilder
    private var largeContent: some View {
        let contentModel = DashboardEntityCardContentModel.make(
            presentation: presentation,
            size: size
        )

        VStack(alignment: .leading, spacing: AppSpacing.large) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                iconPlaceholder

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(presentation.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .truncationMode(.tail)

                    Text(presentation.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(presentation.subtitleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
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

    private var cameraPreviewContent: some View {
        CameraCardPreview(
            entityID: entityBox.entityID,
            isAvailable: entityBox.homeEntity.isAvailable,
            title: cameraPreviewTitle,
            accessibilityTitle: presentation.title,
            refreshGeneration: cameraRefreshGeneration,
            height: renderedCardHeight,
            loadsSnapshots: isFeatureInteractionEnabled
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
                    gaugeStyle: .row,
                    isInteractionEnabled: isFeatureInteractionEnabled,
                    actions: featureActions
                )
                .frame(maxWidth: 154)
            }
        }
    }

    @ViewBuilder
    private func stackedFeatureContent(visibleFeatures: [DashboardCardFeature]) -> some View {
        if let gauge = gaugeFirstPresentation(from: visibleFeatures) {
            gaugeFirstContent(gauge)
        } else {
            let showsGauge = visibleFeatures.contains { feature in
                if case .gauge = feature.content {
                    return true
                }
                return false
            }

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                featureHeader

                if size == .large {
                    largeFeatureContext(visibleFeatures: visibleFeatures)
                } else if !showsGauge {
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
                            gaugeStyle: .arc,
                            isInteractionEnabled: isFeatureInteractionEnabled,
                            actions: featureActions
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func gaugeFirstContent(_ gauge: GaugePresentation) -> some View {
        if let showDetails {
            Button(action: showDetails) {
                gaugeFirstVisual(gauge)
                    .contentShape(Rectangle())
            }
            .buttonStyle(HomeCardButtonStyle())
            .accessibilityLabel(presentation.accessibilityDetailLabel)
            .accessibilityValue(gauge.accessibilityValue)
            .accessibilityHint(presentation.accessibilityDetailHint)
        } else {
            gaugeFirstVisual(gauge)
        }
    }

    @ViewBuilder
    private func gaugeFirstVisual(_ gauge: GaugePresentation) -> some View {
        if presentationKind == .barGauge {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                gaugeFeatureHeader(gauge)

                Spacer(minLength: AppSpacing.xSmall)

                gaugeBarReadout(gauge)

                GaugePresentationView(
                    presentation: gauge,
                    style: .row,
                    tint: iconColor
                )
                .frame(height: GaugeVisualMetrics.barTotalHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            GaugePresentationView(
                presentation: gauge,
                style: presentationKind == .segmentedGauge ? .segmentedInstrument : .instrument,
                tint: iconColor,
                title: presentation.title,
                icon: gaugeIcon(for: gauge)
            )
        }
    }

    private func gaugeBarReadout(_ gauge: GaugePresentation) -> some View {
        let parts = gaugeValueParts(from: gauge.valueText, unitText: gauge.unitText)

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.value)
                .font(.system(.title, design: .rounded, weight: .bold))

            if let unitText = parts.unit {
                Text(unitText)
                    .font(.subheadline.weight(.semibold))
                    .baselineOffset(2)
                    .padding(.leading, -1)
            }
        }
        .foregroundStyle(gaugeStatusColor(for: gauge.status))
        .lineLimit(1)
        .minimumScaleFactor(0.58)
        .monospacedDigit()
    }

    private func gaugeFirstPresentation(from visibleFeatures: [DashboardCardFeature]) -> GaugePresentation? {
        guard visibleFeatures.count == 1,
              size == .square || size == .wide || size == .large,
              case .gauge(let gauge) = visibleFeatures[0].content else {
            return nil
        }

        return gauge.presentation.applying(zoneConfiguration: gaugeZoneConfiguration)
    }

    private func largeFeatureContext(visibleFeatures: [DashboardCardFeature]) -> some View {
        let contentModel = DashboardEntityCardContentModel.make(
            presentation: presentation,
            size: size
        )
        let showsGauge = visibleFeatures.contains { feature in
            if case .gauge = feature.content {
                return true
            }
            return false
        }

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if !showsGauge, let headline = contentModel.headline {
                Text(headline)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(presentation.headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if !showsGauge, !contentModel.metrics.isEmpty {
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

    private func gaugeFeatureHeader(_ gauge: GaugePresentation) -> some View {
        Group {
            if let showDetails {
                Button(action: showDetails) {
                    gaugeHeaderContent(gauge)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HomeCardButtonStyle())
                .accessibilityLabel(presentation.accessibilityDetailLabel)
                .accessibilityValue(gauge.accessibilityValue)
                .accessibilityHint(presentation.accessibilityDetailHint)
            } else {
                gaugeHeaderContent(gauge)
            }
        }
    }

    private func gaugeHeaderContent(_ gauge: GaugePresentation) -> some View {
        HStack(alignment: .center, spacing: GaugeVisualMetrics.compactHeaderSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: GaugeVisualMetrics.compactHeaderIconCornerRadius, style: .continuous)
                    .fill(iconBackground)

                HomesteadIconView(icon: gaugeIcon(for: gauge), pointSize: GaugeVisualMetrics.compactHeaderIconPointSize, weight: .semibold)
                    .foregroundStyle(gaugeStatusColor(for: gauge.status))
                    .accessibilityHidden(true)
            }
            .frame(width: GaugeVisualMetrics.compactHeaderIconSize, height: GaugeVisualMetrics.compactHeaderIconSize)

            VStack(alignment: .leading, spacing: GaugeVisualMetrics.compactHeaderTextSpacing) {
                Text(presentation.title)
                    .font(GaugeVisualMetrics.compactHeaderTitleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(GaugeVisualMetrics.compactHeaderTitleMinimumScale)
                    .truncationMode(.tail)

                Text(gauge.statusDisplayText)
                    .font(GaugeVisualMetrics.compactHeaderStatusFont)
                    .foregroundStyle(gaugeStatusColor(for: gauge.status))
                    .lineLimit(1)
                    .minimumScaleFactor(GaugeVisualMetrics.compactHeaderStatusMinimumScale)
            }
        }
    }

    private func gaugeIcon(for gauge: GaugePresentation) -> ResolvedIcon {
        gaugeDisplayIcon(base: presentation.icon, value: gauge.value, status: gauge.status.visualStatus)
    }

    private func cardHeader(subtitle: String, subtitleFont: Font) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            iconPlaceholder

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(size == .row ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .truncationMode(.tail)

                Text(subtitle)
                    .font(subtitleFont)
                    .foregroundStyle(presentation.subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
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
                        icon: presentation.icon,
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
                Color.clear
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .topLeading) {
                        miniGlyph
                            .frame(width: miniIconSize, height: miniIconSize)
                            .offset(x: miniContentHorizontalInset, y: miniContentVerticalInset)
                    }
                    .contentShape(Rectangle())
            } else {
                cardIconView
            }
        }
    }

    private var miniIconPlaceholder: some View {
        Color.clear
            .frame(width: miniIconSize, height: miniIconSize)
            .overlay {
                if toggle == nil {
                    miniGlyph
                }
            }
    }

    private var miniGlyph: some View {
        HomesteadIconView(icon: presentation.icon, pointSize: 16)
            .foregroundStyle(miniIconColor)
            .accessibilityHidden(true)
    }

    private var cardIconView: some View {
        CardIconView(
            icon: presentation.icon,
            isActive: presentation.isActive,
            isAvailable: presentation.isAvailable,
            accentColor: presentation.accentColor
        )
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

    private var miniIconColor: Color {
        HomesteadSurfaceStyle.iconForeground(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: presentation.isActive,
            isAvailable: presentation.isAvailable,
            accentColor: presentation.accentColor
        )
    }

    private var iconColor: Color {
        presentation.isActive ? presentation.accentColor : Color.primary
    }

    private func gaugeStatusColor(for status: GaugePresentationStatus) -> Color {
        gaugeVisualStatusColor(for: status.visualStatus)
    }

    private var iconBackground: Color {
        HomesteadSurfaceStyle.iconBackground(
            isWallpaperActive: isWallpaperSurfaceActive,
            isActive: presentation.isActive,
            isAvailable: presentation.isAvailable,
            accentColor: presentation.accentColor
        )
    }

    private var cameraCardBackground: some ShapeStyle {
        HomesteadSurfaceStyle.cardBackground(isWallpaperActive: isWallpaperSurfaceActive)
    }

    private var cameraCardBorder: Color {
        HomesteadSurfaceStyle.cardBorder(isWallpaperActive: isWallpaperSurfaceActive)
    }

    private var specializedCardBorder: Color {
        if presentationKind == .weather {
            return Color.white.opacity(0.18)
        }
        return cameraCardBorder
    }

    private var cardContentMinHeight: CGFloat {
        max(0, cardContainerMinHeight - (cardContainerPadding * 2))
    }

    private var cardContainerMinHeight: CGFloat {
        max(0, renderedCardHeight - (cardContainerPadding * 2))
    }

    private var cardContainerPadding: CGFloat {
        if gaugeFirstPresentation(from: visibleFeatures) != nil {
            return AppSpacing.small
        }

        return size == .mini ? 0 : AppSpacing.medium
    }

    private var miniContentHorizontalInset: CGFloat {
        10
    }

    private var miniContentVerticalInset: CGFloat {
        6
    }

    private var miniIconSize: CGFloat {
        22
    }

    private var renderedCardHeight: CGFloat {
        size.renderedHeight(
            rowSpacing: AppSpacing.medium,
            cardPadding: AppSpacing.medium
        )
    }

    private var visibleFeatures: [DashboardCardFeature] {
        let compatibleFeatures: [DashboardCardFeature]
        switch presentationKind {
        case .control, .media:
            compatibleFeatures = features
        case .circularGauge, .segmentedGauge, .barGauge:
            compatibleFeatures = features.filter { $0.key == .sensorGauge }
        default:
            compatibleFeatures = []
        }
        return size.visibleFeatures(from: compatibleFeatures).filter { featureActions.canRender($0) }
    }

    private var usesEmbeddedCardInteractions: Bool {
        presentationKind == .media || presentationKind == .action
    }

    private var weatherForecastTaskID: String {
        guard presentationKind == .weather,
              !isPreview,
              isFeatureInteractionEnabled,
              scenePhase == .active,
              homeAssistantService.connectionStatus == .connected else {
            return "weather-card-disabled-\(entityBox.entityID)-\(weatherForecastConsumerID)"
        }

        return "weather-card-active-\(entityBox.entityID)-\(weatherForecastConsumerID)"
    }

    @MainActor
    private func updateWeatherForecastSubscription() async {
        guard presentationKind == .weather, !isPreview else { return }

        if isFeatureInteractionEnabled,
           scenePhase == .active,
           homeAssistantService.connectionStatus == .connected {
            await homeAssistantService.startWeatherForecastUpdates(
                for: entityBox,
                consumerID: weatherForecastConsumerID
            )
        } else {
            await homeAssistantService.stopWeatherForecastUpdates(
                entityID: entityBox.entityID,
                consumerID: weatherForecastConsumerID
            )
        }
    }

    private var shouldUseCameraPreviewCard: Bool {
        guard presentationKind == .camera, presentation.capability.domain == .camera else {
            return false
        }

        switch size {
        case .square, .wide, .large:
            return true
        case .mini, .compact, .row:
            return false
        }
    }

    private var shouldUseImmersiveCard: Bool {
        if presentationKind == .weather,
           entityBox.weatherEntity != nil,
           [.square, .wide, .large].contains(size) {
            return true
        }

        return presentationKind == .chart
            && entityBox.domain == .sensor
            && size.supportsDashboardHistoryChart
    }

    private var shouldLoadDashboardHistory: Bool {
        presentationKind == .chart && DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: size)
    }

    private var dashboardHistoryTaskID: String {
        guard shouldLoadDashboardHistory,
              isFeatureInteractionEnabled,
              scenePhase == .active else {
            return "dashboard-history-disabled-\(entityBox.entityID)-\(size.rawValue)"
        }

        return "dashboard-history-\(entityBox.entityID)-\(size.rawValue)-\(chartRange.rawValue)"
    }

    private var resolvedHistoryPhase: DashboardHistoryCardPhase {
        if isPreview, let preview = DashboardHistoryCardPresentation.preview(entityBox: entityBox, range: chartRange) {
            return .loaded(preview)
        }
        return historyPhase
    }

    private var chartCardState: DashboardChartCardState {
        switch resolvedHistoryPhase {
        case .idle, .loading:
            return presentation.isAvailable ? .loading : .failed
        case .loaded(let chartPresentation):
            guard !chartPresentation.isEmpty else { return .empty }
            let currentPresentation = chartPresentation.includingCurrentSample(
                value: entityBox.sensorEntity?.numericValue,
                occurredAt: entityBox.sensorEntity?.lastUpdated
            )
            return .loaded(currentPresentation)
        case .failed:
            return .failed
        }
    }

    @MainActor
    private func refreshDashboardHistoryIfNeeded() async {
        guard shouldLoadDashboardHistory else {
            if case .loaded = historyPhase {
                return
            }
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
           chartPresentation.range == chartRange {
            return
        }

        historyPhase = .loading

        do {
            let series = try await homeAssistantService.fetchDashboardHistory(
                settings: connectionSettings,
                entityID: entityBox.entityID,
                range: chartRange
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
