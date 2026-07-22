import SwiftUI

struct WeatherForecastPanel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let weather: WeatherEntity
    let entityBox: HAEntityState
    let isConnectionLive: Bool
    @Binding var selectedType: WeatherForecastType
    let retry: () -> Void

    private var supportedTypes: [WeatherForecastType] {
        weather.supportedForecastTypes
    }

    private var snapshot: WeatherForecastSnapshot? {
        entityBox.weatherForecastsByType[selectedType]
    }

    private var entries: [WeatherForecastEntry] {
        Array((snapshot?.entries ?? []).prefix(selectedType.itemLimit))
    }

    private var isLoading: Bool {
        entityBox.loadingWeatherForecastTypes.contains(selectedType)
    }

    private var errorMessage: String? {
        entityBox.weatherForecastErrorsByType[selectedType]
    }

    var body: some View {
        EntityDetailSection(title: "Forecast", systemImage: "calendar") {
            if supportedTypes.count > 1 {
                Picker("Forecast", selection: $selectedType) {
                    ForEach(supportedTypes, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Forecast interval")
            }

            forecastContent
        }
    }

    @ViewBuilder
    private var forecastContent: some View {
        if entries.isEmpty, isLoading {
            loadingContent
        } else if entries.isEmpty, let errorMessage {
            unavailableContent(message: errorMessage, offersRetry: true)
        } else if entries.isEmpty {
            unavailableContent(message: "No forecast is currently available.", offersRetry: false)
        } else {
            forecastEntries

            if isLoading {
                statusLabel("Updating forecast…", systemImage: "arrow.triangle.2.circlepath")
            } else if errorMessage != nil || !isConnectionLive {
                statusLabel("Showing the most recent forecast.", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    @ViewBuilder
    private var forecastEntries: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    WeatherForecastRow(
                        entry: entry,
                        type: selectedType,
                        temperatureUnit: weather.temperatureUnit
                    )

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        } else if selectedType == .daily {
            WeatherDailyForecastList(entries: entries, weather: weather)
        } else if selectedType == .hourly {
            ScrollView(.horizontal) {
                LazyHStack(spacing: AppSpacing.large) {
                    ForEach(entries) { entry in
                        WeatherHourlyForecastItem(entry: entry, weather: weather)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        } else {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    WeatherForecastRow(
                        entry: entry,
                        type: selectedType,
                        temperatureUnit: weather.temperatureUnit
                    )

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var loadingContent: some View {
        HStack(spacing: AppSpacing.medium) {
            ProgressView()
            Text("Loading forecast…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .accessibilityElement(children: .combine)
    }

    private func unavailableContent(message: String, offersRetry: Bool) -> some View {
        VStack(spacing: AppSpacing.small) {
            Image(systemName: "cloud.sun")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if offersRetry {
                Button("Try Again", action: retry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108)
    }

    private func statusLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WeatherDailyForecastList: View {
    let entries: [WeatherForecastEntry]
    let weather: WeatherEntity

    private var temperatureDomain: ClosedRange<Double> {
        WeatherForecastTemperatureScale.domain(for: entries)
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(entries) { entry in
                WeatherDailyForecastRow(
                    entry: entry,
                    weather: weather,
                    temperatureDomain: temperatureDomain
                )

                if entry.id != entries.last?.id {
                    Divider()
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct WeatherDailyForecastRow: View {
    let entry: WeatherForecastEntry
    let weather: WeatherEntity
    let temperatureDomain: ClosedRange<Double>

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Text(entry.forecastTimeTitle(for: .daily))
                .font(.body.weight(.medium))
                .lineLimit(1)
                .frame(width: 46, alignment: .leading)

            VStack(spacing: 1) {
                Image(systemName: entry.condition.systemImage)
                    .font(.title3)
                    .symbolRenderingMode(.multicolor)
                    .frame(height: 24)

                if let precipitationText = entry.precipitationText,
                   (entry.precipitationProbability ?? 0) > 0 {
                    Text(precipitationText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
            .frame(width: 42)

            if let range = WeatherForecastTemperatureScale.range(for: entry) {
                Text(weather.compactTemperatureText(for: range.lowerBound))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)

                WeatherForecastTemperatureRangeBar(
                    range: range,
                    domain: temperatureDomain,
                    temperatureUnit: weather.temperatureUnit
                )
                .frame(maxWidth: .infinity)

                Text(weather.compactTemperatureText(for: range.upperBound))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(width: 38, alignment: .trailing)
            } else {
                Spacer(minLength: 0)

                Text(entry.compactTemperatureSummary(unit: weather.temperatureUnit))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.accessibilitySummary(for: .daily, temperatureUnit: weather.temperatureUnit))
    }
}

private struct WeatherHourlyForecastItem: View {
    let entry: WeatherForecastEntry
    let weather: WeatherEntity

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Text(entry.forecastTimeTitle(for: .hourly))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: entry.condition.systemImage)
                .font(.title2)
                .symbolRenderingMode(.multicolor)
                .frame(height: 30)

            Text(entry.compactTemperatureSummary(unit: weather.temperatureUnit))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)

            if let precipitationText = entry.precipitationText,
               (entry.precipitationProbability ?? 0) > 0 {
                Text(precipitationText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            } else {
                Text(" ")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 60)
        .frame(minHeight: 118)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.accessibilitySummary(for: .hourly, temperatureUnit: weather.temperatureUnit))
    }
}

private struct WeatherForecastRow: View {
    let entry: WeatherForecastEntry
    let type: WeatherForecastType
    let temperatureUnit: String?

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: entry.condition.systemImage)
                .font(.title3)
                .symbolRenderingMode(.multicolor)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.forecastTimeTitle(for: type))
                    .font(.subheadline.weight(.semibold))
                Text(entry.condition.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.small)

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.temperatureSummary(unit: temperatureUnit))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let precipitationText = entry.precipitationText {
                    Label(precipitationText, systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, AppSpacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.accessibilitySummary(for: type, temperatureUnit: temperatureUnit))
    }
}

private extension WeatherForecastEntry {
    func forecastTimeTitle(for type: WeatherForecastType) -> String {
        switch type {
        case .daily:
            return datetime.formatted(.dateTime.weekday(.abbreviated))
        case .hourly:
            return datetime.formatted(date: .omitted, time: .shortened)
        case .twiceDaily:
            let period = isDaytime == false ? "Night" : "Day"
            return "\(datetime.formatted(.dateTime.weekday(.abbreviated))) \(period)"
        }
    }

    func temperatureSummary(unit: String?) -> String {
        let high = formattedTemperature(temperature, unit: unit)
        let low = formattedTemperature(lowTemperature, unit: unit)

        if let high, let low {
            return "\(high) / \(low)"
        }
        return high ?? low ?? "—"
    }

    func compactTemperatureSummary(unit: String?) -> String {
        let high = formattedTemperature(temperature, unit: compactTemperatureUnit(unit))
        let low = formattedTemperature(lowTemperature, unit: compactTemperatureUnit(unit))

        if let high, let low {
            return "\(high) / \(low)"
        }
        return high ?? low ?? "—"
    }

    var precipitationText: String? {
        guard let precipitationProbability else { return nil }
        return "\(Int(precipitationProbability.rounded()))%"
    }

    func accessibilitySummary(for type: WeatherForecastType, temperatureUnit: String?) -> String {
        [
            forecastTimeTitle(for: type),
            condition.displayName,
            temperatureSummary(unit: temperatureUnit),
            precipitationText.map { "\($0) chance of precipitation" }
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func formattedTemperature(_ value: Double?, unit: String?) -> String? {
        guard let value else { return nil }
        let formattedValue = value.formatted(.number.precision(.fractionLength(0...1)))
        guard let unit, !unit.isEmpty else { return formattedValue }
        let displayUnit = unit == "F" || unit == "C" ? "°\(unit)" : unit
        return "\(formattedValue)\(displayUnit.hasPrefix("°") ? "" : " ")\(displayUnit)"
    }

    private func compactTemperatureUnit(_ unit: String?) -> String? {
        guard unit == "F" || unit == "C" || unit == "°F" || unit == "°C" else {
            return unit
        }
        return "°"
    }
}
