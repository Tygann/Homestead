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
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: AppSpacing.small) {
                    ForEach(entries) { entry in
                        WeatherForecastCard(
                            entry: entry,
                            type: selectedType,
                            temperatureUnit: weather.temperatureUnit
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
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

private struct WeatherForecastCard: View {
    let entry: WeatherForecastEntry
    let type: WeatherForecastType
    let temperatureUnit: String?

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Text(entry.forecastTimeTitle(for: type))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: entry.condition.systemImage)
                .font(.title2)
                .symbolRenderingMode(.multicolor)
                .frame(height: 30)

            Text(entry.temperatureSummary(unit: temperatureUnit))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)

            if let precipitationText = entry.precipitationText {
                Label(precipitationText, systemImage: "drop.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
        }
        .frame(width: 96)
        .frame(minHeight: 126)
        .padding(.vertical, AppSpacing.small)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.accessibilitySummary(for: type, temperatureUnit: temperatureUnit))
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
}
