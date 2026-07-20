#if DEBUG
import SwiftUI

@MainActor
struct DashboardCardReferenceGallery: View {
    private let dependencies: PreviewDependencies

    init() {
        let dependencies = PreviewDependencies.entityDetailSample(entityOverrides: [
            HAEntityDTO(
                entityID: "sensor.chart_unavailable",
                state: "unavailable",
                attributes: [
                    "friendly_name": .string("Patio Temperature"),
                    "device_class": .string("temperature"),
                    "unit_of_measurement": .string("°F")
                ]
            ),
            HAEntityDTO(
                entityID: "weather.unavailable",
                state: "unavailable",
                attributes: [
                    "friendly_name": .string("Outdoor Weather"),
                    "temperature_unit": .string("°F"),
                    "supported_features": .number(3)
                ]
            )
        ])
        Self.seedWeatherForecast(in: dependencies.stateStore)
        self.dependencies = dependencies
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    galleryContent
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard Cards")
        }
        .withPreviewEnvironment(dependencies)
    }

    @ViewBuilder
    private var galleryContent: some View {
        if RuntimeEnvironment.dashboardCardReferenceState == "unavailable" {
            unavailableSection
        } else if RuntimeEnvironment.dashboardCardReferenceState == "transient" {
            transientSection
        } else if let requestedSize = RuntimeEnvironment.requestedPreviewCardSize {
            cardSection(requestedSize.displayName, size: requestedSize)
        } else {
            cardSection("Compact", size: .compact)
            cardSection("Square", size: .square)
            cardSection("Wide", size: .wide)
            cardSection("Large", size: .large)
            unavailableSection
        }
    }

    private func cardSection(_ title: String, size: DashboardCardSize) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(title)
                .font(.title2.weight(.bold))

            CardGrid {
                referenceCard(
                    title: "Chart",
                    entityID: "sensor.hallway_temperature",
                    kind: .graph,
                    size: size
                )
                referenceCard(
                    title: "Weather",
                    entityID: "weather.home",
                    kind: .weather,
                    size: size
                )
                referenceCard(
                    title: "Media",
                    entityID: "media_player.living_room",
                    kind: .media,
                    size: size
                )
                referenceCard(
                    title: "Action",
                    entityID: "scene.movie_night",
                    kind: .action,
                    size: size
                )
            }
        }
    }

    private var unavailableSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Unavailable")
                .font(.title2.weight(.bold))

            CardGrid {
                referenceCard(
                    title: "Unavailable Chart",
                    entityID: "sensor.chart_unavailable",
                    kind: .graph,
                    size: .square
                )
                referenceCard(
                    title: "Unavailable Weather",
                    entityID: "weather.unavailable",
                    kind: .weather,
                    size: .square
                )

                if let unavailableBox = dependencies.stateStore.entityBox(for: "sensor.chart_unavailable"),
                   let historyBox = dependencies.stateStore.entityBox(for: "sensor.hallway_temperature"),
                   let unavailableSensor = unavailableBox.sensorEntity,
                   let recordedTrend = DashboardHistoryCardPresentation.preview(entityBox: historyBox) {
                    let unavailableRecordedTrend = DashboardHistoryCardPresentation(series: HAHistoryChartSeries(
                        entityID: unavailableBox.entityID,
                        displayName: unavailableSensor.displayName,
                        unit: unavailableSensor.unit,
                        range: recordedTrend.range,
                        samples: recordedTrend.samples
                    ))
                    chartStateCard(
                        title: "Unavailable Chart With Recorded Trend",
                        presentation: DashboardEntityPresentation(entityBox: unavailableBox),
                        sensor: unavailableSensor,
                        state: .loaded(unavailableRecordedTrend)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var transientSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Transient States")
                .font(.title2.weight(.bold))

            CardGrid {
                if let entityBox = dependencies.stateStore.entityBox(for: "sensor.hallway_temperature") {
                    chartStateCard(
                        title: "Loading Chart",
                        presentation: DashboardEntityPresentation(entityBox: entityBox),
                        sensor: entityBox.sensorEntity,
                        state: .loading
                    )
                    chartStateCard(
                        title: "Empty Chart",
                        presentation: DashboardEntityPresentation(entityBox: entityBox),
                        sensor: entityBox.sensorEntity,
                        state: .empty
                    )
                }

                if let weatherBox = dependencies.stateStore.entityBox(for: "weather.home"),
                   let weather = weatherBox.weatherEntity {
                    specializedStateCard(size: .wide) {
                        DashboardWeatherCardContent(
                            weather: weather,
                            forecastsByType: [:],
                            loadingForecastTypes: [.hourly],
                            forecastErrorsByType: [:],
                            size: .wide
                        )
                    }
                    .accessibilityLabel("Loading Weather")

                    specializedStateCard(size: .wide) {
                        DashboardWeatherCardContent(
                            weather: weather,
                            forecastsByType: weatherBox.weatherForecastsByType,
                            loadingForecastTypes: [],
                            forecastErrorsByType: [.hourly: "Preview refresh failed"],
                            size: .wide
                        )
                    }
                    .accessibilityLabel("Weather showing the last forecast")
                }
            }
        }
    }

    private func chartStateCard(
        title: String,
        presentation: DashboardEntityPresentation,
        sensor: SensorEntity?,
        state: DashboardChartCardState
    ) -> some View {
        specializedStateCard(size: .square) {
            DashboardChartCardContent(
                presentation: presentation,
                sensor: sensor,
                state: state,
                size: .square
            )
        }
        .accessibilityLabel(title)
    }

    private func specializedStateCard<Content: View>(
        size: DashboardCardSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let cardShape = RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)

        return content()
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(height: size.renderedHeight(rowSpacing: AppSpacing.medium, cardPadding: AppSpacing.medium))
            .background(Color(.secondarySystemGroupedBackground), in: cardShape)
            .clipShape(cardShape)
            .overlay {
                cardShape.strokeBorder(Color(.separator).opacity(0.16), lineWidth: 0.5)
            }
            .cardGridSpan(size.layoutMetadata)
    }

    @ViewBuilder
    private func referenceCard(
        title: String,
        entityID: String,
        kind: DashboardPresentationKind,
        size: DashboardCardSize
    ) -> some View {
        if kind.supportedLayouts.contains(size) {
            DashboardCardView(
                entityID: entityID,
                size: size,
                presentationKind: kind,
                isPreview: true
            )
            .accessibilityLabel(title)
            .cardGridSpan(size.layoutMetadata)
        }
    }

    private static func seedWeatherForecast(in store: HAStateStore) {
        let referenceDate = Date(timeIntervalSince1970: 1_784_515_200)
        store.entityBox(for: "weather.home")?.applyWeatherForecast(WeatherForecastSnapshot(
            type: .daily,
            entries: [
                forecastEntry(date: referenceDate, condition: .partlyCloudy, high: 81, low: 68, rain: 20),
                forecastEntry(date: referenceDate.addingTimeInterval(86_400), condition: .rainy, high: 76, low: 65, rain: 70),
                forecastEntry(date: referenceDate.addingTimeInterval(172_800), condition: .sunny, high: 84, low: 67, rain: 5),
                forecastEntry(date: referenceDate.addingTimeInterval(259_200), condition: .cloudy, high: 79, low: 66, rain: 30),
                forecastEntry(date: referenceDate.addingTimeInterval(345_600), condition: .sunny, high: 86, low: 69, rain: 10)
            ],
            receivedAt: referenceDate
        ))
        store.entityBox(for: "weather.home")?.applyWeatherForecast(WeatherForecastSnapshot(
            type: .hourly,
            entries: (0..<6).map { offset in
                hourlyForecastEntry(
                    date: referenceDate.addingTimeInterval(Double(offset) * 3_600),
                    condition: offset < 4 ? .sunny : .partlyCloudy,
                    temperature: 73 + Double(offset)
                )
            },
            receivedAt: referenceDate
        ))
    }

    private static func forecastEntry(
        date: Date,
        condition: WeatherCondition,
        high: Double,
        low: Double,
        rain: Double
    ) -> WeatherForecastEntry {
        WeatherForecastEntry(
            datetime: date,
            condition: condition,
            temperature: high,
            lowTemperature: low,
            precipitation: nil,
            precipitationProbability: rain,
            humidity: nil,
            isDaytime: true,
            windSpeed: nil,
            windBearing: nil
        )
    }

    private static func hourlyForecastEntry(
        date: Date,
        condition: WeatherCondition,
        temperature: Double
    ) -> WeatherForecastEntry {
        WeatherForecastEntry(
            datetime: date,
            condition: condition,
            temperature: temperature,
            lowTemperature: nil,
            precipitation: nil,
            precipitationProbability: nil,
            humidity: nil,
            isDaytime: true,
            windSpeed: nil,
            windBearing: nil
        )
    }
}

#Preview("Dashboard Card Reference Gallery") {
    DashboardCardReferenceGallery()
}
#endif
