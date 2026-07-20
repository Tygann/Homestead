import Charts
import SwiftUI

// MARK: - Chart

enum DashboardChartCardState: Equatable {
    case loading
    case loaded(DashboardHistoryCardPresentation)
    case empty
    case failed
}

struct DashboardChartCardContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: DashboardEntityPresentation
    let state: DashboardChartCardState
    let size: DashboardCardSize

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                chartLayer
                    .frame(height: chartHeight(for: proxy.size.height))

                VStack(alignment: .leading, spacing: chartHeaderSpacing) {
                    HStack(spacing: AppSpacing.small) {
                        HomesteadIconView(icon: presentation.icon, pointSize: 18, weight: .semibold)
                            .foregroundStyle(presentation.accentColor)
                            .accessibilityHidden(true)

                        Text(measurementTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(presentation.accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Spacer(minLength: AppSpacing.small)

                        if dynamicTypeSize < .xxxLarge {
                            Text(DashboardHistoryCardPresentation.defaultRange.title)
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let headline = displayHeadline {
                        Text(headline)
                            .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .monospacedDigit()
                    }

                    Text(presentation.title)
                        .font(size == .large ? .subheadline.weight(.medium) : .caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var chartLayer: some View {
        switch state {
        case .loaded(let chartPresentation):
            chart(chartPresentation)
        case .loading:
            chartPlaceholder(label: "Loading recent trend")
        case .empty:
            chartPlaceholder(label: "No recent trend")
        case .failed:
            chartPlaceholder(label: "Trend unavailable")
        }
    }

    private func chart(_ chartPresentation: DashboardHistoryCardPresentation) -> some View {
        Chart(chartPresentation.samples) { sample in
            AreaMark(
                x: .value("Time", sample.occurredAt),
                yStart: .value("Baseline", chartPresentation.valueDomain.lowerBound),
                yEnd: .value("Value", sample.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        presentation.accentColor.opacity(0.42),
                        presentation.accentColor.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", sample.occurredAt),
                y: .value("Value", sample.value)
            )
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(presentation.accentColor)

            if sample.id == chartPresentation.samples.last?.id {
                PointMark(
                    x: .value("Time", sample.occurredAt),
                    y: .value("Value", sample.value)
                )
                .symbolSize(size == .large ? 52 : 38)
                .foregroundStyle(presentation.accentColor)
            }
        }
        .chartYScale(domain: chartPresentation.valueDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.clipped()
        }
        .clipped()
    }

    private func chartPlaceholder(label: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    presentation.accentColor.opacity(0.12),
                    presentation.accentColor.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(presentation.accentColor.opacity(0.36))
                .frame(height: 2)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppSpacing.medium)
                .padding(.bottom, AppSpacing.small)
        }
    }

    private var measurementTitle: String {
        presentation.subtitle == "Sensor unavailable" ? "Sensor" : presentation.subtitle
    }

    private var displayHeadline: String? {
        presentation.isAvailable ? presentation.headline : "—"
    }

    private var valueFontSize: CGFloat {
        size == .large ? 48 : 36
    }

    private var chartHeaderSpacing: CGFloat {
        size == .large ? AppSpacing.small : AppSpacing.xSmall
    }

    private func chartHeight(for availableHeight: CGFloat) -> CGFloat {
        switch size {
        case .large:
            availableHeight * 0.52
        case .square, .wide:
            availableHeight * 0.45
        default:
            availableHeight * 0.4
        }
    }

    private var accessibilityLabel: String {
        if case .loaded(let chartPresentation) = state {
            return chartPresentation.accessibilityLabel
        }
        return "\(presentation.title) dashboard history"
    }

    private var accessibilityValue: String {
        switch state {
        case .loaded(let chartPresentation): chartPresentation.accessibilityValue
        case .loading: "Loading recent trend. Current value \(presentation.headline ?? presentation.subtitle)."
        case .empty: "No recent trend. Current value \(presentation.headline ?? presentation.subtitle)."
        case .failed: "Trend unavailable. Current value \(presentation.headline ?? presentation.subtitle)."
        }
    }
}

// MARK: - Weather

struct DashboardWeatherCardContent: View {
    let weather: WeatherEntity
    let forecastsByType: [WeatherForecastType: WeatherForecastSnapshot]
    let loadingForecastTypes: Set<WeatherForecastType>
    let forecastErrorsByType: [WeatherForecastType: String]
    let size: DashboardCardSize

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                DashboardWeatherCardBackground(condition: weather.condition)

                Image(systemName: weather.iconName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: decorativeIconSize(for: proxy.size), weight: .regular))
                    .foregroundStyle(.white.opacity(0.10))
                    .offset(x: proxy.size.width * 0.56, y: proxy.size.height * 0.16)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: size == .large ? AppSpacing.medium : AppSpacing.small) {
                    currentConditions

                    Spacer(minLength: 0)

                    forecastContent
                }
                .padding(AppSpacing.medium)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var currentConditions: some View {
        if size == .wide {
            wideCurrentConditions
        } else {
            standardCurrentConditions
        }
    }

    private var standardCurrentConditions: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(weather.displayName)
                    .font(size == .large ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(weatherReadingText)
                    .font(.system(size: currentTemperatureFontSize, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .monospacedDigit()

                Text(weather.displaySubtitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let highLowText {
                    Text(highLowText)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: weather.iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: size == .large ? 42 : 30, weight: .medium))
                .accessibilityHidden(true)

            if size == .large {
                weatherContext
            }
        }
    }

    private var wideCurrentConditions: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: AppSpacing.small) {
                Text(weather.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: AppSpacing.small)

                Image(systemName: weather.iconName)
                    .symbolRenderingMode(.multicolor)
                    .font(.title3.weight(.medium))
                    .accessibilityHidden(true)
            }

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                Text(weatherReadingText)
                    .font(.system(size: currentTemperatureFontSize, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .monospacedDigit()

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(weather.displaySubtitle)
                    if let highLowText {
                        Text(highLowText)
                    }
                }
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var forecastContent: some View {
        if size == .square {
            EmptyView()
        } else if size == .large {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                if let hourlyForecast {
                    forecastSection(hourlyForecast, limit: 6)
                }

                if let dailyForecast,
                   dailyForecast.type != hourlyForecast?.type {
                    forecastSection(dailyForecast, limit: 5)
                } else if hourlyForecast == nil, let fallbackForecast {
                    forecastSection(fallbackForecast, limit: 5)
                }

                if hourlyForecast == nil && dailyForecast == nil && fallbackForecast == nil {
                    forecastStatus
                }
            }
        } else if let wideForecast {
            forecastStrip(wideForecast, limit: wideForecast.type == .hourly ? 6 : 5)
        } else {
            forecastStatus
        }
    }

    private func forecastSection(_ forecast: WeatherForecastSnapshot, limit: Int) -> some View {
        VStack(spacing: 3) {
            Text(forecast.type.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)

            forecastStrip(forecast, limit: limit)
        }
    }

    private func forecastStrip(_ forecast: WeatherForecastSnapshot, limit: Int) -> some View {
        HStack(spacing: AppSpacing.small) {
            ForEach(Array(forecast.entries.prefix(limit))) { entry in
                forecastItem(entry, type: forecast.type)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func forecastItem(_ entry: WeatherForecastEntry, type: WeatherForecastType) -> some View {
        VStack(spacing: size == .wide ? 1 : 3) {
            Text(forecastDate(entry.datetime, type: type))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)

            Image(systemName: entry.condition.systemImage)
                .symbolRenderingMode(.multicolor)
                .font(size == .large ? .subheadline : .caption)
                .frame(height: size == .large ? 18 : 13)
                .accessibilityHidden(true)

            Text(forecastTemperature(entry))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(forecastDate(entry.datetime, type: type)), \(entry.condition.displayName)")
        .accessibilityValue(forecastTemperature(entry))
    }

    @ViewBuilder
    private var forecastStatus: some View {
        if !loadingForecastTypes.isEmpty {
            HStack(spacing: AppSpacing.small) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text("Updating forecast")
            }
            .font(.caption.weight(.medium))
        } else {
            Text(forecastErrorsByType.isEmpty ? "Forecast unavailable" : "Couldn’t update forecast")
                .font(.caption.weight(.medium))
        }
    }

    private var weatherContext: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xSmall) {
            if let humidity = weather.humidityText {
                Label(humidity, systemImage: "humidity.fill")
            }
            if let wind = weather.windText {
                Label(wind, systemImage: "wind")
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.84))
        .labelStyle(.titleAndIcon)
    }

    private var hourlyForecast: WeatherForecastSnapshot? {
        guard let forecast = forecastsByType[.hourly], !forecast.entries.isEmpty else { return nil }
        return forecast
    }

    private var weatherReadingText: String {
        weather.isAvailable ? (weather.compactTemperatureText ?? weather.primaryReadingText) : "—"
    }

    private var dailyForecast: WeatherForecastSnapshot? {
        if let daily = forecastsByType[.daily], !daily.entries.isEmpty {
            return daily
        }
        guard let twiceDaily = forecastsByType[.twiceDaily], !twiceDaily.entries.isEmpty else { return nil }
        return twiceDaily
    }

    private var fallbackForecast: WeatherForecastSnapshot? {
        WeatherForecastType.allCases.lazy
            .compactMap { forecastsByType[$0] }
            .first { !$0.entries.isEmpty }
    }

    private var wideForecast: WeatherForecastSnapshot? {
        hourlyForecast ?? dailyForecast ?? fallbackForecast
    }

    private var highLowText: String? {
        guard let entry = dailyForecast?.entries.first else { return nil }
        let high = entry.temperature.map(weather.compactTemperatureText(for:))
        let low = entry.lowTemperature.map(weather.compactTemperatureText(for:))

        return switch (high, low) {
        case let (high?, low?): "H:\(high)  L:\(low)"
        case let (high?, nil): "H:\(high)"
        case let (nil, low?): "L:\(low)"
        case (nil, nil): nil
        }
    }

    private func forecastDate(_ date: Date, type: WeatherForecastType) -> String {
        switch type {
        case .hourly:
            date.formatted(date: .omitted, time: .shortened)
        case .daily, .twiceDaily:
            date.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    private func forecastTemperature(_ entry: WeatherForecastEntry) -> String {
        let high = entry.temperature.map(weather.compactTemperatureText(for:))
        let low = entry.lowTemperature.map(weather.compactTemperatureText(for:))
        return switch (high, low) {
        case let (high?, low?): "\(high) / \(low)"
        case let (high?, nil): high
        case let (nil, low?): low
        case (nil, nil): entry.condition.displayName
        }
    }

    private var currentTemperatureFontSize: CGFloat {
        switch size {
        case .large: 58
        case .wide: 38
        default: 42
        }
    }

    private func decorativeIconSize(for availableSize: CGSize) -> CGFloat {
        min(availableSize.width, availableSize.height) * (size == .large ? 0.72 : 0.62)
    }
}

private struct DashboardWeatherCardBackground: View {
    let condition: WeatherCondition

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colors: [Color] {
        switch condition {
        case .sunny, .partlyCloudy:
            [Color(red: 0.25, green: 0.63, blue: 0.93), Color(red: 0.08, green: 0.35, blue: 0.68)]
        case .clearNight:
            [Color(red: 0.19, green: 0.29, blue: 0.55), Color(red: 0.05, green: 0.09, blue: 0.24)]
        case .rainy, .pouring, .hail:
            [Color(red: 0.30, green: 0.51, blue: 0.66), Color(red: 0.10, green: 0.22, blue: 0.32)]
        case .lightning, .lightningRainy:
            [Color(red: 0.34, green: 0.34, blue: 0.55), Color(red: 0.12, green: 0.12, blue: 0.25)]
        case .snowy, .snowyRainy:
            [Color(red: 0.56, green: 0.72, blue: 0.82), Color(red: 0.27, green: 0.43, blue: 0.55)]
        case .cloudy, .fog:
            [Color(red: 0.43, green: 0.52, blue: 0.61), Color(red: 0.21, green: 0.29, blue: 0.37)]
        case .windy, .windyVariant:
            [Color(red: 0.34, green: 0.58, blue: 0.61), Color(red: 0.17, green: 0.34, blue: 0.38)]
        case .exceptional:
            [Color(red: 0.69, green: 0.37, blue: 0.31), Color(red: 0.36, green: 0.16, blue: 0.18)]
        case .unavailable, .unknown, .other:
            [Color(red: 0.38, green: 0.41, blue: 0.45), Color(red: 0.19, green: 0.21, blue: 0.24)]
        }
    }
}

// MARK: - Media

struct DashboardMediaCardContent: View {
    @State private var localVolume: Double

    let media: MediaPlayerEntity
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let isPending: Bool
    let playPause: (() -> Void)?
    let setVolume: ((Double) -> Void)?
    let selectSource: ((String) -> Void)?
    let showDetails: (() -> Void)?

    init(
        media: MediaPlayerEntity,
        presentation: DashboardEntityPresentation,
        size: DashboardCardSize,
        isPending: Bool,
        playPause: (() -> Void)?,
        setVolume: ((Double) -> Void)?,
        selectSource: ((String) -> Void)?,
        showDetails: (() -> Void)?
    ) {
        self.media = media
        self.presentation = presentation
        self.size = size
        self.isPending = isPending
        self.playPause = playPause
        self.setVolume = setVolume
        self.selectSource = selectSource
        self.showDetails = showDetails
        _localVolume = State(initialValue: Double(media.volumePercentage ?? 0))
    }

    var body: some View {
        Group {
            if size == .compact || size == .row {
                compactContent
            } else {
                VStack(alignment: .leading, spacing: size == .large ? AppSpacing.medium : AppSpacing.small) {
                    DashboardSpecializedCardHeader(
                        presentation: presentation,
                        subtitle: media.displayState,
                        showDetails: showDetails
                    )

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        if let nowPlayingTitle {
                            Text(nowPlayingTitle)
                                .font(size == .large ? .title2.weight(.bold) : .headline.weight(.bold))
                                .foregroundStyle(media.isAvailable ? Color.primary : Color.secondary)
                                .lineLimit(size == .large ? 2 : 1)
                                .minimumScaleFactor(0.78)
                        }

                        if let context = nowPlayingContext {
                            Text(context)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    controls
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: media.volumePercentage) { _, value in
            localVolume = Double(value ?? 0)
        }
    }

    private var compactContent: some View {
        HStack(spacing: AppSpacing.small) {
            Group {
                if let showDetails {
                    Button(action: showDetails) { compactIdentity }
                        .buttonStyle(.plain)
                } else {
                    compactIdentity
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            playPauseButton
        }
    }

    private var compactIdentity: some View {
        HStack(spacing: AppSpacing.small) {
            CardIconView(
                icon: presentation.icon,
                isActive: presentation.isActive,
                isAvailable: presentation.isAvailable,
                accentColor: presentation.accentColor
            )

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(nowPlayingTitle ?? media.displayState)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }

    private var controls: some View {
        HStack(spacing: AppSpacing.small) {
            playPauseButton

            if size == .wide || size == .large {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Slider(
                    value: $localVolume,
                    in: 0...100,
                    step: 1,
                    onEditingChanged: { isEditing in
                        guard !isEditing else { return }
                        setVolume?(localVolume)
                    }
                )
                .tint(presentation.accentColor)
                .disabled(isPending || setVolume == nil)
                .accessibilityLabel("Volume")
                .accessibilityValue("\(Int(localVolume.rounded())) percent")
            }

            if size == .large,
               !media.sourceList.isEmpty,
               selectSource != nil {
                Menu {
                    ForEach(media.sourceList, id: \.self) { source in
                        Button(source) { selectSource?(source) }
                    }
                } label: {
                    Image(systemName: "airplayaudio")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose source")
            }
        }
    }

    private var mediaControlSize: CGFloat {
        size == .large ? 40 : 34
    }

    private var playPauseButton: some View {
        Button(action: { playPause?() }) {
            Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                .font(.headline.weight(.semibold))
                .frame(width: mediaControlSize, height: mediaControlSize)
        }
        .buttonStyle(.plain)
        .foregroundStyle(media.isPlaying ? Color.white : Color.primary)
        .background(
            media.isPlaying ? presentation.accentColor : Color(.tertiarySystemFill),
            in: Circle()
        )
        .disabled(isPending || !media.isAvailable || playPause == nil)
        .accessibilityLabel(media.isPlaying ? "Pause" : "Play")
    }

    private var nowPlayingTitle: String? {
        media.mediaTitle?.nonEmptyDashboardValue ?? media.source?.nonEmptyDashboardValue
    }

    private var nowPlayingContext: String? {
        if let artist = media.mediaArtist?.nonEmptyDashboardValue {
            return artist
        }
        guard media.mediaTitle?.nonEmptyDashboardValue != nil else { return nil }
        return media.source?.nonEmptyDashboardValue
    }
}

// MARK: - Action

struct DashboardActionCardContent: View {
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let isPending: Bool
    let trigger: (() -> Void)?
    let showDetails: (() -> Void)?

    var body: some View {
        Group {
            if size == .compact || size == .row {
                compactContent
            } else {
                VStack(alignment: .leading, spacing: size == .square ? AppSpacing.small : AppSpacing.medium) {
                    DashboardSpecializedCardHeader(
                        presentation: presentation,
                        subtitle: actionKind,
                        showDetails: showDetails
                    )

                    Spacer(minLength: 0)
                    actionButton
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var compactContent: some View {
        HStack(spacing: AppSpacing.small) {
            Group {
                if let showDetails {
                    Button(action: showDetails) { compactIdentity }
                        .buttonStyle(.plain)
                } else {
                    compactIdentity
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button(action: { trigger?() }) {
                Image(systemName: actionSystemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(presentation.accentColor, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isPending || !presentation.isAvailable || trigger == nil)
            .opacity(trigger == nil || !presentation.isAvailable ? 0.48 : 1)
            .accessibilityLabel("\(actionTitle) \(presentation.title)")
        }
    }

    private var compactIdentity: some View {
        HStack(spacing: AppSpacing.small) {
            CardIconView(
                icon: presentation.icon,
                isActive: presentation.isActive,
                isAvailable: presentation.isAvailable,
                accentColor: presentation.accentColor
            )

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(actionKind)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }

    private var actionButton: some View {
        Button(action: { trigger?() }) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: actionSystemImage)
                    .accessibilityHidden(true)
                Text(isPending ? "Working…" : actionTitle)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.bold))
                    .opacity(0.72)
                    .accessibilityHidden(true)
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, AppSpacing.medium)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(presentation.accentColor, in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPending || !presentation.isAvailable || trigger == nil)
        .opacity(trigger == nil || !presentation.isAvailable ? 0.48 : 1)
        .accessibilityLabel("\(actionTitle) \(presentation.title)")
        .accessibilityHint("Sends the action to Home Assistant.")
    }

    private var actionKind: String {
        switch presentation.capability.domain {
        case .scene: "Scene"
        case .script: "Script"
        case .button: "Button"
        default: "Action"
        }
    }

    private var actionTitle: String {
        switch presentation.capability.domain {
        case .scene: "Activate"
        case .script: "Run"
        case .button: "Press"
        default: "Run"
        }
    }

    private var actionSystemImage: String {
        switch presentation.capability.domain {
        case .scene: "sparkles"
        case .script: "play.fill"
        case .button: "button.programmable"
        default: "bolt.fill"
        }
    }
}

// MARK: - Shared Header

private struct DashboardSpecializedCardHeader: View {
    let presentation: DashboardEntityPresentation
    let subtitle: String
    let showDetails: (() -> Void)?

    var body: some View {
        Group {
            if let showDetails {
                Button(action: showDetails) { content }
                    .buttonStyle(.plain)
                    .accessibilityLabel(presentation.accessibilityDetailLabel)
                    .accessibilityValue(presentation.accessibilityValue)
                    .accessibilityHint(presentation.accessibilityDetailHint)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            CardIconView(
                icon: presentation.icon,
                isActive: presentation.isActive,
                isAvailable: presentation.isAvailable,
                accentColor: presentation.accentColor
            )

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(presentation.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(presentation.isAvailable ? Color.secondary : Color.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private extension String {
    var nonEmptyDashboardValue: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
