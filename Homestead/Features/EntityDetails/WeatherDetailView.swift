import SwiftUI

struct WeatherDetailView: View {
    let entityBox: HAEntityState
    var presentationStyle: EntityDetailPresentationStyle = .sheet

    private var entity: HomeEntity {
        entityBox.homeEntity
    }

    private var weather: WeatherEntity? {
        entityBox.weatherEntity
    }

    private var presentation: DashboardEntityPresentation {
        DashboardEntityPresentation(entityBox: entityBox)
    }

    var body: some View {
        if let weather {
            EntityDetailScaffold(title: weather.displayName, presentationStyle: presentationStyle) {
                hero(weather)
                if !weatherRows(weather).isEmpty {
                    weatherDetails(weather)
                }
                sourceDetails(weather)
                contextDetails
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
            statusBackground: weather.isAvailable ? nil : Color.red.opacity(0.12)
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(weather.primaryReadingText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
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
            title: "Source",
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
        var rows = [
            EntityMetadataRow(title: "Forecast", value: weather.forecastAvailabilityText)
        ]

        if let attribution = weather.attributionText {
            rows.append(EntityMetadataRow(title: "Attribution", value: attribution))
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

}

#if DEBUG
#Preview("Weather") {
    if let entityBox = PreviewDependencies.sample.stateStore.entityBox(for: "weather.home") {
        WeatherDetailView(entityBox: entityBox)
            .withPreviewEnvironment()
    }
}
#endif
