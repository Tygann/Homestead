#if DEBUG
import SwiftUI

@MainActor
struct DashboardCardReferenceGallery: View {
    private let dependencies: PreviewDependencies

    init() {
        var entityOverrides = [
            HAEntityDTO(
                entityID: "climate.downstairs",
                state: "heat_cool",
                attributes: [
                    "friendly_name": .string("Downstairs Thermostat"),
                    "current_temperature": .number(68),
                    "target_temp_low": .number(66),
                    "target_temp_high": .number(67),
                    "temperature_unit": .string("°F"),
                    "min_temp": .number(50),
                    "max_temp": .number(90),
                    "target_temp_step": .number(1),
                    "hvac_modes": .array([
                        .string("off"),
                        .string("heat"),
                        .string("cool"),
                        .string("heat_cool")
                    ]),
                    "fan_mode": .string("auto"),
                    "fan_modes": .array([.string("auto"), .string("low"), .string("high")]),
                    "preset_mode": .string("home"),
                    "preset_modes": .array([.string("home"), .string("away"), .string("sleep")])
                ]
            ),
            HAEntityDTO(
                entityID: "person.tyler",
                state: "home",
                attributes: [
                    "friendly_name": .string("Tyler"),
                    "entity_picture": .string("/api/image/preview-person"),
                    "source": .string("device_tracker.tylers_iphone")
                ]
            ),
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
        ]
        entityOverrides.append(Self.sunFixture(
            referenceState: RuntimeEnvironment.dashboardCardReferenceState
        ))

        let dependencies = PreviewDependencies.entityDetailSample(entityOverrides: entityOverrides)
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
            .background {
                if usesWallpaperReference {
                    LinearGradient(
                        colors: [.indigo.opacity(0.8), .purple.opacity(0.65), .orange.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                } else {
                    Color(.systemGroupedBackground)
                }
            }
            .navigationTitle("Dashboard Cards")
        }
        .environment(\.homesteadWallpaperSurfaceActive, usesWallpaperReference)
        .withPreviewEnvironment(dependencies)
    }

    @ViewBuilder
    private var galleryContent: some View {
        if RuntimeEnvironment.dashboardCardReferenceState == "unavailable" {
            unavailableSection
        } else if RuntimeEnvironment.dashboardCardReferenceState == "transient" {
            transientSection
        } else if RuntimeEnvironment.dashboardCardReferenceState == "wallpaper" {
            cardSection("Wallpaper", size: .large)
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
                    kind: .chart,
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

                if size == .large {
                    referenceCard(
                        title: "Large Thermostat",
                        entityID: "climate.downstairs",
                        kind: .control,
                        size: size
                    )
                    referenceCard(
                        title: "Person Profile Picture",
                        entityID: "person.tyler",
                        kind: .control,
                        size: size
                    )
                    referenceCard(
                        title: "Person Icon Override",
                        entityID: "person.tyler",
                        kind: .control,
                        size: size,
                        iconNameOverride: "star.fill"
                    )
                }

                if size == .mini {
                    referenceCard(
                        title: "Person Profile Picture",
                        entityID: "person.tyler",
                        kind: .control,
                        size: size
                    )
                }
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
                    kind: .chart,
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
                   let recordedChart = DashboardHistoryCardPresentation.preview(entityBox: historyBox) {
                    let unavailableRecordedChart = DashboardHistoryCardPresentation(series: HAHistoryChartSeries(
                        entityID: unavailableBox.entityID,
                        displayName: unavailableSensor.displayName,
                        unit: unavailableSensor.unit,
                        range: recordedChart.range,
                        samples: recordedChart.samples
                    ))
                    chartStateCard(
                        title: "Unavailable Chart With Recorded Chart",
                        presentation: DashboardEntityPresentation(entityBox: unavailableBox),
                        sensor: unavailableSensor,
                        state: .loaded(unavailableRecordedChart)
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
        size: DashboardCardSize,
        iconNameOverride: String? = nil
    ) -> some View {
        if kind.supportedLayouts.contains(size) {
            DashboardCardView(
                entityID: entityID,
                size: size,
                presentationKind: kind,
                iconNameOverride: iconNameOverride,
                isPreview: true,
                usesPreviewProfilePicture: entityID.hasPrefix("person.")
                    && iconNameOverride == nil
            )
            .accessibilityLabel(title)
            .cardGridSpan(size.layoutMetadata)
        }
    }

    private var usesWallpaperReference: Bool {
        RuntimeEnvironment.dashboardCardReferenceState == "wallpaper"
    }

    private static func seedWeatherForecast(in store: HAStateStore) {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let dailyDates = (0...5).map { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
                ?? today.addingTimeInterval(Double(offset) * 86_400)
        }
        store.entityBox(for: "weather.home")?.applyWeatherForecast(WeatherForecastSnapshot(
            type: .daily,
            entries: [
                forecastEntry(date: dailyDates[0], condition: .partlyCloudy, high: 81, low: 68, rain: 20),
                forecastEntry(date: dailyDates[1], condition: .rainy, high: 76, low: 65, rain: 70),
                forecastEntry(date: dailyDates[2], condition: .sunny, high: 84, low: 67, rain: 5),
                forecastEntry(date: dailyDates[3], condition: .cloudy, high: 79, low: 66, rain: 30),
                forecastEntry(date: dailyDates[4], condition: .sunny, high: 86, low: 69, rain: 10),
                forecastEntry(date: dailyDates[5], condition: .partlyCloudy, high: 83, low: 70, rain: 15)
            ],
            receivedAt: now
        ))
        store.entityBox(for: "weather.home")?.applyWeatherForecast(WeatherForecastSnapshot(
            type: .hourly,
            entries: (0..<6).map { offset in
                hourlyForecastEntry(
                    date: currentHour.addingTimeInterval(Double(offset) * 3_600),
                    condition: offset < 4 ? .sunny : .partlyCloudy,
                    temperature: 73 + Double(offset)
                )
            },
            receivedAt: now
        ))
    }

    private static func sunFixture(referenceState: String?) -> HAEntityDTO {
        let elevation: Double
        switch referenceState {
        case "weather-twilight":
            elevation = -3
        case "weather-night":
            elevation = -14
        default:
            elevation = 24
        }

        return HAEntityDTO(
            entityID: "sun.sun",
            state: elevation >= 0 ? "above_horizon" : "below_horizon",
            attributes: [
                "friendly_name": .string("Sun"),
                "elevation": .number(elevation)
            ]
        )
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
