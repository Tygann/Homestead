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
    var openDetails: (() -> Void)?

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
                toggle: isEditing ? nil : primaryAction(
                    presentation.primaryAction,
                    entityID: entityBox.entityID
                ),
                showDetails: isEditing ? nil : detailsAction(
                    entityID: entityBox.entityID,
                    detailKind: presentation.detailKind
                ),
                featureActions: featureActions(for: entityBox),
                isFeatureInteractionEnabled: !isEditing
            )
            .sheet(item: $selectedDetail) { detail in
                if let selectedEntityBox = stateStore.entityBox(for: detail.entityID) {
                    DashboardEntityDetailSheet(entityBox: selectedEntityBox)
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

struct DashboardEntityDetailSheet: View {
    let entityBox: HAEntityState
    var presentationStyle: DashboardDetailPresentationStyle = .sheet

    var body: some View {
        let detailKind = DashboardEntityPresentation(entityBox: entityBox).detailKind

        switch detailKind {
        case .light:
            LightDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .cover:
            CoverDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .climate:
            ClimateDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .fan:
            FanDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .lock:
            LockDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .toggle:
            ToggleEntityDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .action:
            ActionEntityDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .sensor:
            SensorDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .mediaPlayer:
            MediaPlayerDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .camera:
            CameraDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .vacuum:
            VacuumDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        case .entity:
            EntityDetailView(entityBox: entityBox, presentationStyle: presentationStyle)
        }
    }
}

private struct DashboardEntityCard: View {
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

        if shouldUseCameraPreviewCard {
            fullBleedCameraCard
        } else {
            standardCard(visibleFeatures: visibleFeatureSnapshot)
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
        CardContainer(isActive: presentation.isActive, minHeight: cardContainerMinHeight) {
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
                        CardIconView(
                            systemName: presentation.iconName,
                            isActive: presentation.isActive
                        )
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
        let contentModel = DashboardEntityCardContentModel.make(
            presentation: presentation,
            size: size
        )

        return VStack(alignment: .leading, spacing: AppSpacing.large) {
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
                    CardIconView(systemName: presentation.iconName, isActive: presentation.isActive)
                }
            }
    }

    private var iconColor: Color {
        presentation.isActive ? Color.accentColor : Color.primary
    }

    private var iconBackground: Color {
        presentation.isActive ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemGroupedBackground)
    }

    private var cameraCardBackground: Color {
        presentation.isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground)
    }

    private var cameraCardBorder: Color {
        presentation.isActive ? Color.accentColor.opacity(0.22) : Color(.separator).opacity(0.18)
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
