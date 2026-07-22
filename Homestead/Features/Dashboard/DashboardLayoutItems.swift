import SwiftUI

struct DashboardCardItem: Identifiable, Equatable {
    let id: UUID
    let entityID: String
    let configuration: DashboardCardConfiguration
    let displayNameOverride: String?
    let iconNameOverride: String?
    let gaugeZoneConfiguration: GaugeZoneConfiguration?
    let chartConfiguration: DashboardChartConfiguration

    var size: DashboardCardSize { configuration.layout }
    var presentationKind: DashboardPresentationKind { configuration.kind }
}

struct DashboardChipItem: Identifiable, Equatable {
    let id: UUID
    let source: DashboardSourceReference
    let displayNameOverride: String?
    let iconNameOverride: String?

    var entityID: String? {
        guard case .entity(let entityID) = source else { return nil }
        return entityID
    }

    var summaryKind: DashboardSummaryKind? {
        guard case .summary(let kind) = source else { return nil }
        return kind
    }
}

enum DashboardLayoutItemKind: Equatable {
    case header(DashboardItemConfiguration)
    case card(DashboardCardItem)
    case chip(DashboardChipItem)
}

struct DashboardLayoutItem: Identifiable, Equatable {
    let kind: DashboardLayoutItemKind
    let layoutMetadata: DashboardCardLayoutMetadata

    var configurationItemID: UUID {
        switch kind {
        case .header(let item):
            item.id
        case .card(let item):
            item.id
        case .chip(let item):
            item.id
        }
    }

    var id: String {
        switch kind {
        case .header(let item):
            "header-\(item.id)"
        case .card(let item):
            "card-\(item.id)"
        case .chip(let item):
            "chip-\(item.id)"
        }
    }
}

enum DashboardLayoutItemBuilder {
    static func makeItems(from configurationItems: [DashboardItemConfiguration]) -> [DashboardLayoutItem] {
        return configurationItems.compactMap { configurationItem in
            switch configurationItem.content {
            case .heading:
                return DashboardLayoutItem(
                    kind: .header(configurationItem),
                    layoutMetadata: configurationItem.layoutMetadata
                )
            case .sourced(let sourced):
                switch sourced.presentation {
                case .card(let cardConfiguration):
                    guard case .entity(let entityID) = sourced.source else {
                        return nil
                    }
                    let cardItem = DashboardCardItem(
                        id: configurationItem.id,
                        entityID: entityID,
                        configuration: cardConfiguration,
                        displayNameOverride: configurationItem.displayNameOverride,
                        iconNameOverride: configurationItem.iconNameOverride,
                        gaugeZoneConfiguration: configurationItem.gaugeZoneConfiguration,
                        chartConfiguration: configurationItem.chartConfiguration ?? .default
                    )
                    return DashboardLayoutItem(
                        kind: .card(cardItem),
                        layoutMetadata: cardConfiguration.layout.layoutMetadata
                    )
                case .chip:
                    let chipItem = DashboardChipItem(
                        id: configurationItem.id,
                        source: sourced.source,
                        displayNameOverride: configurationItem.displayNameOverride,
                        iconNameOverride: configurationItem.iconNameOverride
                    )
                    return DashboardLayoutItem(
                        kind: .chip(chipItem),
                        layoutMetadata: configurationItem.layoutMetadata
                    )
                }
            }
        }
    }
}
