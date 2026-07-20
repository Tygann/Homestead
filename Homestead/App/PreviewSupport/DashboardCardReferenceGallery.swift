#if DEBUG
import SwiftUI

@MainActor
struct DashboardCardReferenceGallery: View {
    private let dependencies: PreviewDependencies

    init() {
        let dependencies = PreviewDependencies.sample
        Self.seedWeatherForecast(in: dependencies.stateStore)
        self.dependencies = dependencies
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    cardSection("Compact", size: .compact)
                    cardSection("Square", size: .square)
                    cardSection("Wide", size: .wide)
                    cardSection("Large", size: .large)
                }
                .padding(AppSpacing.large)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard Cards")
        }
        .withPreviewEnvironment(dependencies)
    }

    private func cardSection(_ title: String, size: DashboardCardSize) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(title)
                .font(.title2.weight(.bold))

            CardGrid {
                referenceCard(
                    title: "Graph",
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
}

#Preview("Dashboard Card Reference Gallery") {
    DashboardCardReferenceGallery()
}
#endif
