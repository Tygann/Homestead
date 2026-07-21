import Accessibility
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
            chartPlaceholder(label: "Loading recent trend")
        case .empty:
            chartPlaceholder(label: "No recent trend")
        case .failed:
            chartPlaceholder(label: "Trend unavailable")
        }
    }

    private func chart(_ chartPresentation: DashboardHistoryCardPresentation) -> some View {
        let displayDomain = chartDisplayDomain(chartPresentation)

        return Chart(chartPresentation.samples) { sample in
            AreaMark(
                x: .value("Time", sample.occurredAt),
                yStart: .value("Baseline", displayDomain.lowerBound),
                yEnd: .value("Value", sample.value)
            )
            .interpolationMethod(chartInterpolationMethod)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        presentation.accentColor.opacity(0.16),
                        presentation.accentColor.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Time", sample.occurredAt),
                y: .value("Value", sample.value)
            )
            .interpolationMethod(chartInterpolationMethod)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .foregroundStyle(presentation.accentColor)
        }
        .chartYScale(domain: displayDomain)
        .chartXScale(range: .plotDimension(startPadding: 0, endPadding: 0))
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

    private var chartInterpolationMethod: InterpolationMethod {
        sensor?.dashboardHistoryInterpolationStyle == .smooth ? .catmullRom : .linear
    }

    private var contextSummaryText: String {
        if !presentation.isAvailable {
            if case .loaded = state {
                return "Unavailable · Last recorded trend"
            }
            return "Unavailable"
        }

        return switch state {
        case .loaded(let chartPresentation):
            chartPresentation.rangeSummaryText
        case .loading:
            "\(measurementTitle) · Loading recent trend"
        case .empty:
            "\(measurementTitle) · No recent trend"
        case .failed:
            "\(measurementTitle) · Trend unavailable"
        }
    }

    private var contextSummaryColor: Color {
        presentation.isAvailable ? .secondary : .orange
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

    private func chartDisplayDomain(
        _ chartPresentation: DashboardHistoryCardPresentation
    ) -> ClosedRange<Double> {
        let domain = chartPresentation.valueDomain
        let headroom = (domain.upperBound - domain.lowerBound) * 0.04
        return (domain.lowerBound - headroom)...(domain.upperBound + headroom)
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

    let weather: WeatherEntity
    let forecastsByType: [WeatherForecastType: WeatherForecastSnapshot]
    let loadingForecastTypes: Set<WeatherForecastType>
    let forecastErrorsByType: [WeatherForecastType: String]
    let size: DashboardCardSize

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                DashboardWeatherCardBackground(condition: weather.condition)

                LinearGradient(
                    colors: [Color.black.opacity(0.28), Color.black.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .accessibilityHidden(true)

                cardContent(availableWidth: proxy.size.width)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func cardContent(availableWidth: CGFloat) -> some View {
        if size == .large {
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
                    if let highLowText {
                        Text(highLowText)
                    }
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
                    if let highLowText {
                        Text(highLowText)
                    }
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
        GeometryReader { proxy in
            let domainSpan = max(domain.upperBound - domain.lowerBound, 1)
            let start = min(max((range.lowerBound - domain.lowerBound) / domainSpan, 0), 1)
            let end = min(max((range.upperBound - domain.lowerBound) / domainSpan, start), 1)
            let startX = proxy.size.width * start
            let rangeWidth = max(proxy.size.width * (end - start), 6)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 5)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                dailyTemperatureColor(for: range.lowerBound),
                                dailyTemperatureColor(for: range.upperBound)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: min(rangeWidth, max(proxy.size.width - startX, 0)), height: 5)
                    .offset(x: startX)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(minWidth: 70)
        .accessibilityHidden(true)
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
        if !loadingForecastTypes.isEmpty {
            HStack(spacing: AppSpacing.small) {
                ForEach(0..<placeholderCount, id: \.self) { _ in
                    VStack(spacing: AppSpacing.xSmall) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(0.20))
                            .frame(width: 30, height: 8)
                        Circle()
                            .fill(Color.white.opacity(0.24))
                            .frame(width: 16, height: 16)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 24, height: 9)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Updating forecast")
        } else {
            Text(forecastErrorsByType.isEmpty ? "Forecast unavailable" : "Couldn’t update forecast")
                .font(.caption.weight(.medium))
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
        guard let first = entry.lowTemperature ?? entry.temperature,
              let second = entry.temperature ?? entry.lowTemperature else {
            return nil
        }
        return min(first, second)...max(first, second)
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

    private func dailyTemperatureColor(for temperature: Double) -> Color {
        let fahrenheitTemperature: Double
        if weather.temperatureUnit == "C" || weather.temperatureUnit == "°C" {
            fahrenheitTemperature = (temperature * 9 / 5) + 32
        } else {
            fahrenheitTemperature = temperature
        }

        return switch fahrenheitTemperature {
        case ..<50:
            Color(red: 0.04, green: 0.52, blue: 1.00)
        case 50..<60:
            temperatureColor(
                progress: (fahrenheitTemperature - 50) / 10,
                from: (0.04, 0.52, 1.00),
                to: (0.39, 0.82, 1.00)
            )
        case 60..<68:
            temperatureColor(
                progress: (fahrenheitTemperature - 60) / 8,
                from: (0.39, 0.82, 1.00),
                to: (1.00, 0.84, 0.04)
            )
        case 68..<76:
            temperatureColor(
                progress: (fahrenheitTemperature - 68) / 8,
                from: (1.00, 0.84, 0.04),
                to: (1.00, 0.62, 0.04)
            )
        case 76..<100:
            temperatureColor(
                progress: (fahrenheitTemperature - 76) / 24,
                from: (1.00, 0.62, 0.04),
                to: (1.00, 0.27, 0.23)
            )
        default:
            Color(red: 1.00, green: 0.27, blue: 0.23)
        }
    }

    private func temperatureColor(
        progress: Double,
        from start: (red: Double, green: Double, blue: Double),
        to end: (red: Double, green: Double, blue: Double)
    ) -> Color {
        let progress = min(max(progress, 0), 1)
        return Color(
            red: start.red + ((end.red - start.red) * progress),
            green: start.green + ((end.green - start.green) * progress),
            blue: start.blue + ((end.blue - start.blue) * progress)
        )
    }

    private func dailyTemperatureDomain(
        for entries: [WeatherForecastEntry]
    ) -> ClosedRange<Double> {
        let ranges = entries.compactMap(dailyTemperatureRange(for:))
        guard let minimum = ranges.map(\.lowerBound).min(),
              let maximum = ranges.map(\.upperBound).max() else {
            return 0...1
        }
        guard minimum < maximum else {
            return (minimum - 1)...(maximum + 1)
        }
        return minimum...maximum
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

    private var forecastEdgeColumnWidth: CGFloat {
        dynamicTypeSize >= .xxLarge ? 64 : 24
    }

    private var dailyTemperatureLabelWidth: CGFloat {
        dynamicTypeSize >= .xxLarge ? 64 : 44
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
