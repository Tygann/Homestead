import SwiftUI

struct WeatherDetailView: View {
    @Environment(HomeAssistantService.self) private var homeAssistantService

    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet
    var automaticallyLoadsForecast = true

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var weather: WeatherEntity? {
        entityBox.weatherEntity
    }

    private var presentation: EntityDetailPresentationModel {
        EntityDetailPresentationModel(entityBox: entityBox)
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
                currentConditions(weather)
                if features.supports(.forecast) {
                    WeatherForecastPanel(
                        weather: weather,
                        entityBox: entityBox,
                        isConnectionLive: homeAssistantService.connectionStatus == .connected,
                        retry: retryForecast
                    )
                }
                if weather.attributionText != nil {
                    attributionFooter(weather)
                }
                contextDetails
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
            statePresentation: detailState,
            accessory: {
                Text(weather.primaryReadingText)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(statusColor(weather))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        ) {
            EmptyView()
        }
    }

    private func currentConditions(_ weather: WeatherEntity) -> some View {
        EntityDetailSection(title: "Conditions", systemImage: "cloud.sun.fill") {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(weather.displaySubtitle)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if weather.humidityText != nil || weather.windText != nil {
                    Divider()
                        .padding(.vertical, AppSpacing.xSmall)

                    HStack(alignment: .top, spacing: AppSpacing.large) {
                        if let humidity = weather.humidityText {
                            supportingMetric(
                                title: "Humidity",
                                value: humidity,
                                systemImage: "humidity.fill"
                            )
                        }

                        if let wind = weather.windText {
                            supportingMetric(
                                title: "Wind",
                                value: wind,
                                systemImage: "wind"
                            )
                        }
                    }
                }
            }
        }
    }

    private func supportingMetric(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func attributionFooter(_ weather: WeatherEntity) -> some View {
        Text(weather.attributionText ?? "")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppSpacing.small)
    }

    private var contextDetails: some View {
        EntityMetadataDisclosure(
            entityBox: entityBox,
            title: "Home Assistant",
            systemImage: "house.and.flag",
            rows: contextRows
        )
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
    let hourlyEntries: [WeatherForecastEntry] = (0..<8).map { hour in
        let offset = TimeInterval(hour * 3_600)
        return WeatherForecastEntry(
            datetime: Date.now.addingTimeInterval(offset),
            condition: hour < 3 ? .partlyCloudy : .sunny,
            temperature: 73 + Double(hour),
            lowTemperature: nil,
            precipitation: nil,
            precipitationProbability: hour == 2 ? 20 : 0,
            humidity: 56,
            isDaytime: true,
            windSpeed: 8,
            windBearing: 225
        )
    }
    let hourlySnapshot = WeatherForecastSnapshot(
        type: .hourly,
        entries: hourlyEntries,
        receivedAt: .now
    )
    entityBox.applyWeatherForecast(hourlySnapshot)
    return WeatherDetailView(entityBox: entityBox)
        .withPreviewEnvironment(dependencies)
}
#endif
