import SwiftUI

struct WeatherDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService
    @State private var selectedForecastType: WeatherForecastType = .daily

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet
    var automaticallyLoadsForecast = true

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var weather: WeatherEntity? {
        entityBox.weatherEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    private var detailState: EntityDetailStatePresentation {
        EntityDetailStatePresentation.resolve(entityBox: entityBox, service: homeAssistantService)
    }

    private var features: EntityDetailFeatureSet {
        EntityDetailFeatureProvider.features(for: entityBox)
    }

    var body: some View {
        if let weather {
            EntityDetailScaffold(title: weather.displayName, presentationStyle: presentationStyle) {
                hero(weather)
                if features.supports(.forecast) {
                    WeatherForecastPanel(
                        weather: weather,
                        entityBox: entityBox,
                        isConnectionLive: homeAssistantService.connectionStatus == .connected,
                        selectedType: $selectedForecastType,
                        retry: retryForecast
                    )
                }
                if !weatherRows(weather).isEmpty {
                    weatherDetails(weather)
                }
                if weather.attributionText != nil {
                    sourceDetails(weather)
                }
                contextDetails
            }
            .task(id: weather.supportedForecastTypes) {
                if !weather.supportedForecastTypes.contains(selectedForecastType),
                   let defaultType = weather.defaultForecastType {
                    selectedForecastType = defaultType
                }
            }
            .task(id: homeAssistantService.connectionStatus) {
                guard automaticallyLoadsForecast else { return }

                if homeAssistantService.connectionStatus == .connected {
                    await homeAssistantService.startWeatherForecastUpdates(for: entityBox)
                } else {
                    await homeAssistantService.stopWeatherForecastUpdates(entityID: entityBox.entityID)
                }
            }
            .onDisappear {
                guard automaticallyLoadsForecast else { return }
                Task {
                    await homeAssistantService.stopWeatherForecastUpdates(entityID: entityBox.entityID)
                }
            }
        } else {
            EntityUnavailableDetailView(
                title: entityBox.homeEntity.displayName,
                systemImage: "cloud.sun.fill",
                presentationStyle: presentationStyle
            )
        }
    }

    private func hero(_ weather: WeatherEntity) -> some View {
        EntityDetailHeroCard(
            icon: presentation.icon,
            title: "Weather",
            subtitle: EntityDetailHeroSubtitle.updated(entity),
            status: weather.isAvailable ? nil : "Unavailable",
            iconColor: iconColor(weather),
            statusColor: weather.isAvailable ? presentation.accentColor : .red,
            iconBackground: iconBackground(weather),
            statusBackground: weather.isAvailable ? nil : Color.red.opacity(0.12),
            statePresentation: detailState
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(weather.primaryReadingText)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(statusColor(weather))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(weather.displaySubtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func weatherDetails(_ weather: WeatherEntity) -> some View {
        DashboardEntityContextPanel(
            title: "Details",
            systemImage: "thermometer.medium",
            rows: weatherRows(weather)
        )
    }

    private func sourceDetails(_ weather: WeatherEntity) -> some View {
        DashboardEntityContextPanel(
            title: "Weather Provider",
            systemImage: "cloud.bolt.rain.fill",
            rows: sourceRows(weather)
        )
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: contextRows
        )
    }

    private func weatherRows(_ weather: WeatherEntity) -> [EntityMetadataRow] {
        var rows: [EntityMetadataRow] = []

        if let humidityText = weather.humidityText {
            rows.append(EntityMetadataRow(title: "Humidity", value: humidityText))
        }

        if let windText = weather.windText {
            rows.append(EntityMetadataRow(title: "Wind", value: windText))
        }

        return rows
    }

    private func sourceRows(_ weather: WeatherEntity) -> [EntityMetadataRow] {
        var rows: [EntityMetadataRow] = []

        if let providerName = weather.providerName {
            rows.append(EntityMetadataRow(title: "Provider", value: providerName, layout: .stacked))
        }

        if let attributionText = weather.attributionText {
            rows.append(EntityMetadataRow(title: "Attribution", value: attributionText, layout: .stacked))
        }

        return rows
    }

    private var contextRows: [EntityMetadataRow] {
        var rows = [
            EntityMetadataRow(title: "Entity ID", value: entity.entityID),
            EntityMetadataRow(title: "Domain", value: entity.domain.displayName)
        ]

        if let lastUpdated = entity.lastUpdated {
            rows.append(EntityMetadataRow(title: "Last Updated", value: lastUpdated.formatted(date: .abbreviated, time: .shortened)))
        }

        return rows
    }

    private func iconColor(_ weather: WeatherEntity) -> Color {
        guard weather.isAvailable else { return .secondary }
        return presentation.accentColor
    }

    private func statusColor(_ weather: WeatherEntity) -> Color {
        weather.isAvailable ? presentation.accentColor : .red
    }

    private func iconBackground(_ weather: WeatherEntity) -> Color {
        guard weather.isAvailable else { return Color(.tertiarySystemGroupedBackground) }
        return presentation.accentColor.opacity(0.12)
    }

    private func retryForecast() {
        Task {
            await homeAssistantService.restartWeatherForecastUpdates(for: entityBox)
        }
    }

}

#if DEBUG
#Preview("Weather") {
    weatherDetailPreview()
}

@MainActor
private func weatherDetailPreview() -> some View {
    let dependencies = PreviewDependencies.entityDetailSample(connectionStatus: .disconnected)
    let entityBox = dependencies.stateStore.entityBox(for: "weather.home")!
    entityBox.applyWeatherForecast(
        WeatherForecastSnapshot(
            type: .daily,
            entries: [
                WeatherForecastEntry(
                    datetime: .now,
                    condition: .partlyCloudy,
                    temperature: 83,
                    lowTemperature: 68,
                    precipitation: nil,
                    precipitationProbability: 20,
                    humidity: 58,
                    isDaytime: true,
                    windSpeed: 8,
                    windBearing: 225
                ),
                WeatherForecastEntry(
                    datetime: .now.addingTimeInterval(86_400),
                    condition: .rainy,
                    temperature: 76,
                    lowTemperature: 65,
                    precipitation: nil,
                    precipitationProbability: 70,
                    humidity: 72,
                    isDaytime: true,
                    windSpeed: 11,
                    windBearing: 180
                ),
                WeatherForecastEntry(
                    datetime: .now.addingTimeInterval(172_800),
                    condition: .sunny,
                    temperature: 86,
                    lowTemperature: 69,
                    precipitation: nil,
                    precipitationProbability: 5,
                    humidity: 45,
                    isDaytime: true,
                    windSpeed: 6,
                    windBearing: 270
                )
            ],
            receivedAt: .now
        )
    )
    return WeatherDetailView(entityBox: entityBox)
        .withPreviewEnvironment(dependencies)
}
#endif
