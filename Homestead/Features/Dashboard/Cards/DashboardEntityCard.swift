import Charts
import SwiftUI

struct DashboardEntityCard: View {
    @Environment(HAConnectionSettings.self) private var connectionSettings
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive
    @Environment(\.scenePhase) private var scenePhase
    @State private var historyPhase: DashboardHistoryCardPhase = .idle

    let entityBox: HAEntityState
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let presentationKind: DashboardPresentationKind
    let presentationStyle: DashboardPresentationStyle?
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
            minHeight: cardContainerMinHeight,
            padding: cardContainerPadding
        ) {
            ZStack(alignment: .topLeading) {
                if !visibleFeatureSnapshot.isEmpty {
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
                .transaction { transaction in
                    transaction.animation = nil
                }

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
        dashboardHistoryEmptyPlaceholder(title: "Loading recent trend")
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
        if presentationStyle == .gauge(.bar) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                featureHeader

                Spacer(minLength: AppSpacing.xSmall)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(gauge.valueText)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    if let unitText = gauge.unitText {
                        Text(unitText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                GaugePresentationView(
                    presentation: gauge,
                    style: .row,
                    tint: iconColor
                )
                .frame(height: 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            GaugePresentationView(
                presentation: gauge,
                style: .instrument,
                tint: iconColor,
                title: presentation.title,
                icon: presentation.icon
            )
        }
    }

    private func gaugeFirstPresentation(from visibleFeatures: [DashboardCardFeature]) -> GaugePresentation? {
        guard visibleFeatures.count == 1,
              size == .square || size == .wide || size == .large,
              case .gauge(let gauge) = visibleFeatures[0].content else {
            return nil
        }

        return gauge.presentation
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
        case .gauge:
            compatibleFeatures = features.filter { $0.key == .sensorGauge }
        default:
            compatibleFeatures = []
        }
        return size.visibleFeatures(from: compatibleFeatures, visibility: featureVisibility).filter { featureActions.canRender($0) }
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

    private var shouldUseDashboardHistoryCard: Bool {
        presentationKind == .graph && DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: size)
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
