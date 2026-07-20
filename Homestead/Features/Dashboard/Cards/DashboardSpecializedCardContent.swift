import SwiftUI

// MARK: - Weather

struct DashboardWeatherCardContent: View {
    let weather: WeatherEntity
    let forecast: WeatherForecastSnapshot?
    let isLoadingForecast: Bool
    let forecastError: String?
    let presentation: DashboardEntityPresentation
    let size: DashboardCardSize
    let showDetails: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: size == .large ? AppSpacing.medium : AppSpacing.xSmall) {
            DashboardSpecializedCardHeader(
                presentation: presentation,
                subtitle: weather.displaySubtitle,
                showDetails: showDetails
            )

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                Text(weather.primaryReadingText)
                    .font(.system(size: size == .large ? 42 : 34, weight: .bold, design: .rounded))
                    .foregroundStyle(presentation.headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()

                Spacer(minLength: 0)

                if size == .large {
                    weatherContext
                }
            }

            forecastContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var forecastContent: some View {
        if let forecast, !forecast.entries.isEmpty {
            HStack(spacing: AppSpacing.small) {
                ForEach(Array(forecast.entries.prefix(forecastLimit))) { entry in
                    forecastItem(entry)
                }
            }
            .accessibilityElement(children: .contain)
        } else if isLoadingForecast {
            HStack(spacing: AppSpacing.small) {
                ProgressView()
                    .controlSize(.small)
                Text("Updating forecast")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        } else {
            Text(forecastError == nil ? "Forecast unavailable" : "Couldn’t update forecast")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        }
    }

    private func forecastItem(_ entry: WeatherForecastEntry) -> some View {
        VStack(spacing: 3) {
            Text(forecastDate(entry.datetime))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: entry.condition.systemImage)
                .symbolRenderingMode(.multicolor)
                .font(.subheadline)
                .frame(height: 16)
                .accessibilityHidden(true)

            Text(forecastTemperature(entry))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(forecastDate(entry.datetime)), \(entry.condition.displayName)")
        .accessibilityValue(forecastTemperature(entry))
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
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    private var forecastLimit: Int {
        switch size {
        case .large: 5
        case .wide: 3
        default: 2
        }
    }

    private func forecastDate(_ date: Date) -> String {
        switch forecast?.type {
        case .hourly:
            date.formatted(date: .omitted, time: .shortened)
        case .daily, .twiceDaily, .none:
            date.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    private func forecastTemperature(_ entry: WeatherForecastEntry) -> String {
        let high = entry.temperature.map(weather.temperatureText(for:))
        let low = entry.lowTemperature.map(weather.temperatureText(for:))
        return switch (high, low) {
        case let (high?, low?): "\(high) / \(low)"
        case let (high?, nil): high
        case let (nil, low?): low
        case (nil, nil): entry.condition.displayName
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
