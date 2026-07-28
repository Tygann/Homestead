import Accessibility
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
    let sensor: SensorEntity?
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

                        Text(presentation.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Spacer(minLength: AppSpacing.small)

                        if showsTrailingSummary {
                            HStack(spacing: 3) {
                                Text(loadedRangeTitle)

                                if let compactChangeSummaryText {
                                    Text("·")
                                    Text(compactChangeSummaryText)
                                }
                            }
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(displayValueText)
                            .font(.system(size: valueFontSize, weight: .regular, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .monospacedDigit()

                        if let displayUnitText {
                            Text(displayUnitText)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: AppSpacing.small)
                    }

                    if showsContextSummary {
                        Text(contextSummaryText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(contextSummaryColor)
                            .lineLimit(1)
                    }
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .modifier(DashboardChartAccessibilityModifier(state: state))
    }

    private var loadedRangeTitle: String {
        if case .loaded(let chartPresentation) = state {
            return chartPresentation.range.title
        }
        return DashboardHistoryCardPresentation.defaultRange.title
    }

    @ViewBuilder
    private var chartLayer: some View {
        switch state {
        case .loaded(let chartPresentation):
            chart(chartPresentation)
        case .loading:
            chartPlaceholder(label: "Loading recent chart")
        case .empty:
            chartPlaceholder(label: "No recent chart")
        case .failed:
            chartPlaceholder(label: "Chart unavailable")
        }
    }

    private func chart(_ chartPresentation: DashboardHistoryCardPresentation) -> some View {
        HomesteadChartPlot(
            samples: chartPresentation.chartSamples,
            valueDomain: chartPresentation.valueDomain,
            accentColor: presentation.accentColor,
            interpolationStyle: sensor?.historyChartInterpolationStyle ?? .linear
        )
    }

    private func chartPlaceholder(label: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            if presentation.isAvailable {
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
    }

    private var measurementTitle: String {
        presentation.subtitle == "Sensor unavailable" ? "Sensor" : presentation.subtitle
    }

    private var displayValueText: String {
        guard presentation.isAvailable else { return "—" }
        return sensor?.valueText ?? presentation.headline ?? presentation.subtitle
    }

    private var displayUnitText: String? {
        guard presentation.isAvailable else { return nil }
        return sensor?.unitText
    }

    private var changeSummaryText: String? {
        guard case .loaded(let chartPresentation) = state else { return nil }
        return chartPresentation.changeSummaryText
    }

    private var compactChangeSummaryText: String? {
        guard let changeSummaryText else { return nil }
        if changeSummaryText.hasPrefix("Up ") {
            return "↑ \(changeSummaryText.dropFirst(3))"
        }
        if changeSummaryText.hasPrefix("Down ") {
            return "↓ \(changeSummaryText.dropFirst(5))"
        }
        return changeSummaryText
    }

    private var contextSummaryText: String {
        if !presentation.isAvailable {
            if case .loaded = state {
                return "Last recorded"
            }
            return "Unavailable"
        }

        return switch state {
        case .loaded(let chartPresentation):
            chartPresentation.rangeSummaryText
        case .loading:
            "\(measurementTitle) · Loading recent chart"
        case .empty:
            "\(measurementTitle) · No recent chart"
        case .failed:
            "\(measurementTitle) · Chart unavailable"
        }
    }

    private var contextSummaryColor: Color {
        .secondary
    }

    private var showsTrailingSummary: Bool {
        (size == .wide || size == .large) && dynamicTypeSize < .xxxLarge
    }

    private var showsContextSummary: Bool {
        if !presentation.isAvailable {
            return dynamicTypeSize < .xxLarge
        }
        return size == .large && dynamicTypeSize < .xxxLarge
    }

    private var chartHeaderSpacing: CGFloat {
        size == .square ? 2 : AppSpacing.xSmall
    }

    private var valueFontSize: CGFloat {
        38
    }

    private func chartHeight(for availableHeight: CGFloat) -> CGFloat {
        switch size {
        case .large:
            availableHeight * 0.60
        case .wide:
            availableHeight * 0.48
        case .square:
            availableHeight * 0.35
        default:
            availableHeight * 0.34
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
        case .loading: "Loading recent chart. Current value \(presentation.headline ?? presentation.subtitle)."
        case .empty: "No recent chart. Current value \(presentation.headline ?? presentation.subtitle)."
        case .failed: "Chart unavailable. Current value \(presentation.headline ?? presentation.subtitle)."
        }
    }
}

private struct DashboardChartAccessibilityModifier: ViewModifier {
    let state: DashboardChartCardState

    @ViewBuilder
    func body(content: Content) -> some View {
        if case .loaded(let presentation) = state {
            content.accessibilityChartDescriptor(DashboardHistoryChartDescriptor(presentation: presentation))
        } else {
            content
        }
    }
}

private struct DashboardHistoryChartDescriptor: AXChartDescriptorRepresentable {
    let presentation: DashboardHistoryCardPresentation

    func makeChartDescriptor() -> AXChartDescriptor {
        let firstTimestamp = presentation.samples.first?.occurredAt.timeIntervalSince1970 ?? 0
        let lastTimestamp = presentation.samples.last?.occurredAt.timeIntervalSince1970 ?? firstTimestamp + 1
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Time",
            range: firstTimestamp...max(lastTimestamp, firstTimestamp + 1),
            gridlinePositions: []
        ) { timestamp in
            Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened)
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: presentation.unit.map { "Value in \($0)" } ?? "Value",
            range: presentation.valueDomain,
            gridlinePositions: []
        ) { value in
            presentation.formatValue(value)
        }
        let dataPoints = presentation.samples.map { sample in
            AXDataPoint(
                x: sample.occurredAt.timeIntervalSince1970,
                y: sample.value,
                label: presentation.formatValue(sample.value)
            )
        }

        return AXChartDescriptor(
            title: "\(presentation.displayName) history",
            summary: presentation.summaryText,
            xAxis: xAxis,
            yAxis: yAxis,
            series: [
                AXDataSeriesDescriptor(
                    name: presentation.displayName,
                    isContinuous: true,
                    dataPoints: dataPoints
                )
            ]
        )
    }
}

// MARK: - Weather

struct DashboardWeatherCardContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.homesteadWallpaperSurfaceActive) private var isWallpaperSurfaceActive

    let weather: WeatherEntity
    let forecastsByType: [WeatherForecastType: WeatherForecastSnapshot]
    let loadingForecastTypes: Set<WeatherForecastType>
    let forecastErrorsByType: [WeatherForecastType: String]
    var solarPhase: WeatherSolarPhase? = nil
    var expectsForecastHydration = true
    let size: DashboardCardSize

    var body: some View {
        let palette = DashboardWeatherPaletteResolver.resolve(
            condition: weather.condition,
            solarPhase: solarPhase
        )

        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if weather.isAvailable {
                    DashboardWeatherCardBackground(colors: palette.colors)
                        .opacity(isWallpaperSurfaceActive ? 0.48 : 1)

                    LinearGradient(
                        colors: legibilityOverlayColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .accessibilityHidden(true)
                } else {
                    Color(.secondarySystemGroupedBackground)
                }

                cardContent(availableWidth: proxy.size.width)
            }
        }
        .foregroundStyle(weather.isAvailable ? Color.white : Color.primary)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func cardContent(availableWidth: CGFloat) -> some View {
        if !weather.isAvailable {
            unavailableContent
        } else if size == .large {
            VStack(alignment: .leading, spacing: 10) {
                largeCurrentConditions
                largeForecastContent(availableWidth: availableWidth)
            }
            .padding(AppSpacing.medium)
        } else if size == .wide {
            VStack(alignment: .leading, spacing: 0) {
                wideCurrentConditions

                Spacer(minLength: AppSpacing.xSmall)

                forecastContent(availableWidth: availableWidth)
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.top, 10)
            .padding(.bottom, 14)
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                standardCurrentConditions

                Spacer(minLength: 0)

                forecastContent(availableWidth: availableWidth)
            }
            .padding(AppSpacing.medium)
        }
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: "cloud.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .accessibilityHidden(true)

                Text(weather.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)

            Text("—")
                .font(.system(size: currentTemperatureFontSize, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)

            Text("Unavailable")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weather.displayName)
        .accessibilityValue("Unavailable")
    }

    private var standardCurrentConditions: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xSmall) {
                    Text(weather.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    forecastUpdateIndicator
                }

                Text(weatherReadingText)
                    .font(.system(size: currentTemperatureFontSize, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .monospacedDigit()

                Text(weather.displaySubtitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                highLowContent
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Spacer(minLength: 0)

            Image(systemName: weather.iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 18, weight: .medium))
                .accessibilityHidden(true)

        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weather.displayName)
        .accessibilityValue(currentConditionsAccessibilityValue)
    }

    private var largeCurrentConditions: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: AppSpacing.xSmall) {
                Text(weather.displayName)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                forecastUpdateIndicator

                Spacer(minLength: AppSpacing.small)

                Image(systemName: weather.iconName)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 18, weight: .medium))
                    .accessibilityHidden(true)
            }

            HStack(alignment: .bottom, spacing: AppSpacing.medium) {
                Text(weatherReadingText)
                    .font(.system(size: currentTemperatureFontSize, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .monospacedDigit()

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(weather.displaySubtitle)
                    highLowContent
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .offset(y: -8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weather.displayName)
        .accessibilityValue(currentConditionsAccessibilityValue)
    }

    private var wideCurrentConditions: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: AppSpacing.xSmall) {
                Text(weather.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                forecastUpdateIndicator

                Spacer(minLength: AppSpacing.small)
            }
            .padding(.trailing, 32)

            HStack(alignment: .bottom, spacing: AppSpacing.medium) {
                Text(weatherReadingText)
                    .font(.system(size: currentTemperatureFontSize, weight: .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .monospacedDigit()

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(weather.displaySubtitle)
                    highLowContent
                }
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .offset(y: -8)
            }
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: weather.iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 18, weight: .medium))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weather.displayName)
        .accessibilityValue(currentConditionsAccessibilityValue)
    }

    @ViewBuilder
    private func forecastContent(availableWidth: CGFloat) -> some View {
        if size == .square || (size == .wide && dynamicTypeSize >= .xxxLarge) {
            EmptyView()
        } else if forecastPhase == .loading {
            forecastPlaceholder(
                count: forecastLimit(for: .hourly, availableWidth: availableWidth)
            )
        } else if let wideForecast {
            forecastStrip(
                wideForecast,
                limit: forecastLimit(for: wideForecast.type, availableWidth: availableWidth)
            )
        } else {
            forecastStatus(placeholderCount: forecastLimit(for: .hourly, availableWidth: availableWidth))
        }
    }

    @ViewBuilder
    private func largeForecastContent(availableWidth: CGFloat) -> some View {
        let hourly = hourlyForecast
        let daily = dailyForecast
        let fallback = fallbackForecast

        VStack(alignment: .leading, spacing: 9) {
            Divider()
                .overlay(Color.white.opacity(0.16))

            if forecastPhase == .loading {
                largeForecastPlaceholder(availableWidth: availableWidth)
            } else {
                if let hourly {
                    forecastStrip(
                        hourly,
                        limit: forecastLimit(for: hourly.type, availableWidth: availableWidth)
                    )
                }

                if hourly != nil, let daily {
                    Divider()
                        .overlay(Color.white.opacity(0.16))
                    dailyForecastList(daily)
                } else if hourly == nil, let daily {
                    dailyForecastList(daily)
                } else if hourly == nil, daily == nil, let fallback {
                    if fallback.type == .hourly {
                        forecastStrip(
                            fallback,
                            limit: forecastLimit(for: fallback.type, availableWidth: availableWidth)
                        )
                    } else {
                        dailyForecastList(fallback)
                    }
                }

                if hourly == nil && daily == nil && fallback == nil {
                    forecastStatus(placeholderCount: forecastLimit(for: .hourly, availableWidth: availableWidth))
                }
            }
        }
    }

    private func dailyForecastList(_ forecast: WeatherForecastSnapshot) -> some View {
        let limit = dynamicTypeSize >= .xxLarge ? 3 : 4
        let entries = Array(futureDailyEntries(from: forecast).prefix(limit))
        let domain = dailyTemperatureDomain(for: entries)

        return VStack(spacing: 5) {
            ForEach(entries) { entry in
                dailyForecastRow(entry, type: forecast.type, domain: domain)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func dailyForecastRow(
        _ entry: WeatherForecastEntry,
        type: WeatherForecastType,
        domain: ClosedRange<Double>
    ) -> some View {
        GeometryReader { proxy in
            let grid = forecastGridMetrics(availableWidth: proxy.size.width)

            ZStack(alignment: .leading) {
                Text(forecastDate(entry.datetime, type: type))
                    .frame(
                        width: grid.columnStride - (grid.columnWidth / 2),
                        alignment: .leading
                    )

                Image(systemName: entry.condition.systemImage)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: grid.columnWidth, height: 20)
                    .offset(x: grid.columnStride)
                    .accessibilityHidden(true)

                if let range = dailyTemperatureRange(for: entry) {
                    Text(weather.compactTemperatureText(for: range.lowerBound))
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(width: dailyTemperatureLabelWidth, alignment: .center)
                        .offset(
                            x: (grid.columnStride * 2)
                                + ((grid.columnWidth - dailyTemperatureLabelWidth) / 2)
                        )

                    dailyTemperatureBar(range: range, domain: domain)
                        .frame(width: grid.columnStride * 2)
                        .offset(x: (grid.columnWidth / 2) + (grid.columnStride * 2.5))

                    Text(weather.compactTemperatureText(for: range.upperBound))
                        .frame(width: dailyTemperatureLabelWidth, alignment: .trailing)
                        .offset(x: proxy.size.width - dailyTemperatureLabelWidth)
                } else {
                    Text(forecastTemperature(entry))
                        .frame(width: dailyTemperatureLabelWidth, alignment: .trailing)
                        .offset(x: proxy.size.width - dailyTemperatureLabelWidth)
                }
            }
        }
        .font(.caption.monospacedDigit().weight(.semibold))
        .frame(height: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(forecastDate(entry.datetime, type: type)), \(entry.condition.displayName)")
        .accessibilityValue(accessibilityForecastTemperature(entry))
    }

    private func dailyTemperatureBar(
        range: ClosedRange<Double>,
        domain: ClosedRange<Double>
    ) -> some View {
        WeatherForecastTemperatureRangeBar(
            range: range,
            domain: domain,
            temperatureUnit: weather.temperatureUnit,
            trackColor: Color.white.opacity(0.10),
            height: 5
        )
        .frame(minWidth: 70)
    }

    private func forecastStrip(_ forecast: WeatherForecastSnapshot, limit: Int) -> some View {
        let entries = Array(forecast.entries.prefix(limit))

        return HStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                forecastItem(entry, type: forecast.type)

                if index < entries.count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: forecastStripHeight, alignment: .bottom)
        .accessibilityElement(children: .contain)
    }

    private func forecastItem(
        _ entry: WeatherForecastEntry,
        type: WeatherForecastType
    ) -> some View {
        VStack(spacing: size == .wide ? 1 : 3) {
            Text(forecastDate(entry.datetime, type: type))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .center)

            Image(systemName: entry.condition.systemImage)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 18, weight: .medium))
                .frame(height: 20)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Text(forecastTemperature(entry))
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: forecastEdgeColumnWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(forecastDate(entry.datetime, type: type)), \(entry.condition.displayName)")
        .accessibilityValue(accessibilityForecastTemperature(entry))
    }

    @ViewBuilder
    private func forecastStatus(placeholderCount: Int) -> some View {
        if forecastPhase == .loading {
            forecastPlaceholder(count: placeholderCount)
        } else {
            Text(forecastErrorsByType.isEmpty ? "Forecast unavailable" : "Couldn’t update forecast")
                .font(.caption.weight(.medium))
                .frame(height: forecastStripHeight, alignment: .center)
        }
    }

    private func forecastPlaceholder(count: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                forecastPlaceholderItem

                if index < count - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: forecastStripHeight, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Updating forecast")
    }

    private var forecastPlaceholderItem: some View {
        VStack(spacing: size == .wide ? 1 : 3) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.20))
                .frame(width: 22, height: 8)
                .frame(height: 12)

            Circle()
                .fill(Color.white.opacity(0.24))
                .frame(width: 16, height: 16)
                .frame(height: 20)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .frame(width: 24, height: 9)
                .frame(height: 12)
        }
        .frame(width: forecastEdgeColumnWidth)
    }

    private func largeForecastPlaceholder(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if weather.supportedForecastTypes.contains(.hourly) {
                forecastPlaceholder(
                    count: forecastLimit(for: .hourly, availableWidth: availableWidth)
                )
            }

            if weather.supportedForecastTypes.contains(.daily)
                || weather.supportedForecastTypes.contains(.twiceDaily) {
                if weather.supportedForecastTypes.contains(.hourly) {
                    Divider()
                        .overlay(Color.white.opacity(0.16))
                }

                VStack(spacing: 5) {
                    ForEach(0..<(dynamicTypeSize >= .xxLarge ? 3 : 4), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 24)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var forecastUpdateIndicator: some View {
        if hasForecastData, !forecastErrorsByType.isEmpty {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .accessibilityLabel("Forecast update failed. Showing the last forecast.")
        } else if !loadingForecastTypes.isEmpty {
            ProgressView()
                .controlSize(.mini)
                .tint(.white)
                .accessibilityLabel("Updating forecast")
        }
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

    private var hasForecastData: Bool {
        forecastsByType.values.contains { !$0.entries.isEmpty }
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

    private func dailyTemperatureRange(for entry: WeatherForecastEntry) -> ClosedRange<Double>? {
        WeatherForecastTemperatureScale.range(for: entry)
    }

    private func futureDailyEntries(
        from forecast: WeatherForecastSnapshot,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeatherForecastEntry] {
        let today = calendar.startOfDay(for: now)
        var representedDays = Set<Date>()

        let futureEntries = forecast.entries.filter { entry in
            let day = calendar.startOfDay(for: entry.datetime)
            guard day > today, representedDays.insert(day).inserted else { return false }
            return true
        }
        return futureEntries.isEmpty ? forecast.entries : futureEntries
    }

    private func dailyTemperatureDomain(
        for entries: [WeatherForecastEntry]
    ) -> ClosedRange<Double> {
        WeatherForecastTemperatureScale.domain(for: entries)
    }

    private func forecastGridMetrics(
        availableWidth: CGFloat
    ) -> (columnWidth: CGFloat, columnStride: CGFloat) {
        let columnWidth = min(forecastEdgeColumnWidth, availableWidth / 6)
        let columnStride = max((availableWidth - columnWidth) / 5, 0)
        return (columnWidth, columnStride)
    }

    private func forecastDate(_ date: Date, type: WeatherForecastType) -> String {
        switch type {
        case .hourly:
            if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .hour) {
                "Now"
            } else {
                date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            }
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

    private func accessibilityForecastTemperature(_ entry: WeatherForecastEntry) -> String {
        let high = entry.temperature.map(weather.temperatureText(for:))
        let low = entry.lowTemperature.map(weather.temperatureText(for:))
        return switch (high, low) {
        case let (high?, low?): "High \(high), low \(low)"
        case let (high?, nil): high
        case let (nil, low?): low
        case (nil, nil): entry.condition.displayName
        }
    }

    private var currentConditionsAccessibilityValue: String {
        var components = [weather.temperatureText ?? weather.primaryReadingText, weather.displaySubtitle]
        if let accessibilityHighLowText {
            components.append(accessibilityHighLowText)
        }
        if hasForecastData, !forecastErrorsByType.isEmpty {
            components.append("Forecast update failed. Showing the last forecast.")
        } else if !loadingForecastTypes.isEmpty {
            components.append("Updating forecast")
        }
        return components.joined(separator: ", ")
    }

    private var accessibilityHighLowText: String? {
        guard let entry = dailyForecast?.entries.first else { return nil }
        return accessibilityForecastTemperature(entry)
    }

    private func forecastLimit(for type: WeatherForecastType, availableWidth: CGFloat) -> Int {
        let preferredLimit = type == .hourly ? 6 : 5
        if dynamicTypeSize >= .xxLarge { return min(preferredLimit, 3) }
        if type != .hourly, availableWidth < 350 { return min(preferredLimit, 4) }
        return preferredLimit
    }

    private var currentTemperatureFontSize: CGFloat {
        38
    }

    @ViewBuilder
    private var highLowContent: some View {
        if let highLowText {
            Text(highLowText)
        } else if forecastPhase == .loading {
            Text("H:88° L:66°")
                .hidden()
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 48, height: 7)
                        .accessibilityHidden(true)
                }
        }
    }

    private var forecastPhase: DashboardWeatherForecastPhase {
        DashboardWeatherForecastPhase.resolve(
            supportedTypes: Set(weather.supportedForecastTypes),
            availableTypes: Set(
                forecastsByType.compactMap { type, forecast in
                    forecast.entries.isEmpty ? nil : type
                }
            ),
            loadingTypes: loadingForecastTypes,
            failedTypes: Set(forecastErrorsByType.keys),
            expectsHydration: expectsForecastHydration
        )
    }

    private var forecastStripHeight: CGFloat {
        50
    }

    private var legibilityOverlayColors: [Color] {
        if isWallpaperSurfaceActive {
            return [Color.black.opacity(0.18), Color.black.opacity(0.10)]
        }

        return [Color.black.opacity(0.28), Color.black.opacity(0.18)]
    }

    private var forecastEdgeColumnWidth: CGFloat {
        dynamicTypeSize >= .xxLarge ? 64 : 24
    }

    private var dailyTemperatureLabelWidth: CGFloat {
        dynamicTypeSize >= .xxLarge ? 64 : 44
    }

}

private struct DashboardWeatherCardBackground: View {
    let colors: [Color]

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
            switch size {
            case .mini:
                EmptyView()
            case .compact:
                compactContent
            case .row:
                rowContent
            case .square:
                squareContent
            case .wide:
                wideContent
            case .large:
                largeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: media.volumePercentage) { _, value in
            localVolume = Double(value ?? 0)
        }
    }

    private var compactContent: some View {
        HStack(spacing: AppSpacing.small) {
            playPauseIconButton

            Group {
                if let showDetails {
                    Button(action: showDetails) { compactIdentity }
                        .buttonStyle(.plain)
                } else {
                    compactIdentity
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var compactIdentity: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(presentation.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(compactSubtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.medium) {
            DashboardSpecializedCardHeader(
                presentation: presentation,
                subtitle: compactSubtitle,
                showDetails: showDetails
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            playPauseButton
        }
    }

    private var squareContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            DashboardSpecializedCardHeader(
                presentation: presentation,
                subtitle: media.displayState,
                showDetails: showDetails
            )

            nowPlayingContent(titleFont: .headline.weight(.bold), titleLineLimit: 2)

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)
                playPauseButton
                Spacer(minLength: 0)
            }
        }
    }

    private var wideContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .top, spacing: AppSpacing.large) {
                DashboardSpecializedCardHeader(
                    presentation: presentation,
                    subtitle: media.displayState,
                    showDetails: showDetails
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                nowPlayingContent(titleFont: .headline.weight(.bold), titleLineLimit: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            controls
        }
    }

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            DashboardSpecializedCardHeader(
                presentation: presentation,
                subtitle: media.displayState,
                showDetails: showDetails
            )

            Spacer(minLength: 0)

            nowPlayingContent(titleFont: .largeTitle.weight(.bold), titleLineLimit: 2)

            Spacer(minLength: 0)

            controls
        }
    }

    @ViewBuilder
    private func nowPlayingContent(titleFont: Font, titleLineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            if let nowPlayingTitle {
                Text(nowPlayingTitle)
                    .font(titleFont)
                    .foregroundStyle(media.isAvailable ? Color.primary : Color.secondary)
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(0.78)
            } else {
                Text(media.isAvailable ? media.displayState : "Unavailable")
                    .font(titleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let context = nowPlayingContext {
                Text(context)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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

    private var playPauseIconButton: some View {
        Button(action: { playPause?() }) {
            DashboardCardIconView(
                presentation: presentation.iconPresentation,
                isActive: presentation.isActive,
                isAvailable: presentation.isAvailable,
                accentColor: presentation.accentColor
            )
        }
        .buttonStyle(.plain)
        .disabled(isPending || !media.isAvailable || playPause == nil)
        .accessibilityLabel(media.isPlaying ? "Pause \(presentation.title)" : "Play \(presentation.title)")
    }

    private var compactSubtitle: String {
        guard media.isAvailable else { return "Unavailable" }
        if let nowPlayingTitle {
            return "\(media.displayState) · \(nowPlayingTitle)"
        }
        return media.displayState
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
            if size == .compact {
                compactContent
            } else if size == .row || size == .wide {
                horizontalContent
            } else if size == .large {
                largeContent
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
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
            actionIconButton

            Group {
                if let showDetails {
                    Button(action: showDetails) { compactIdentity }
                        .buttonStyle(.plain)
                } else {
                    compactIdentity
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var compactIdentity: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(presentation.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(presentation.isAvailable ? actionKind : "Unavailable")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var horizontalContent: some View {
        HStack(spacing: AppSpacing.large) {
            DashboardSpecializedCardHeader(
                presentation: presentation,
                subtitle: actionKind,
                showDetails: showDetails
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            compactActionButton
        }
    }

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            DashboardSpecializedCardHeader(
                presentation: presentation,
                subtitle: actionKind,
                showDetails: showDetails
            )

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                DashboardCardIconView(
                    presentation: presentation.iconPresentation,
                    isActive: presentation.isActive,
                    isAvailable: presentation.isAvailable,
                    accentColor: presentation.accentColor,
                    size: 72,
                    symbolSize: 32
                )
            }

            Spacer(minLength: 0)
            actionButton
        }
    }

    private var actionIconButton: some View {
        Button(action: { trigger?() }) {
            DashboardCardIconView(
                presentation: presentation.iconPresentation,
                isActive: presentation.isActive,
                isAvailable: presentation.isAvailable,
                accentColor: presentation.accentColor
            )
        }
        .buttonStyle(.plain)
        .disabled(isPending || !presentation.isAvailable || trigger == nil)
        .accessibilityLabel("\(actionTitle) \(presentation.title)")
    }

    private var compactActionButton: some View {
        Button(action: { trigger?() }) {
            Label(isPending ? "Working…" : actionTitle, systemImage: actionSystemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, AppSpacing.medium)
                .frame(height: 40)
                .background(
                    presentation.accentColor,
                    in: RoundedRectangle(cornerRadius: AppRadius.icon, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(isPending || !presentation.isAvailable || trigger == nil)
        .opacity(trigger == nil || !presentation.isAvailable ? 0.48 : 1)
        .accessibilityLabel("\(actionTitle) \(presentation.title)")
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
            DashboardCardIconView(
                presentation: presentation.iconPresentation,
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
