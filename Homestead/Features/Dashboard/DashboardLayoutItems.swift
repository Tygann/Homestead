import SwiftUI

struct DashboardCardItem: Identifiable, Equatable {
    let id: UUID
    let entityID: String
    let size: DashboardCardSize
    let displayNameOverride: String?
    let iconNameOverride: String?
    let featureVisibility: DashboardCardFeatureVisibility
}

struct DashboardChipItem: Identifiable, Equatable {
    let id: UUID
    let chipKind: DashboardChipKind
    let entityID: String?
    let summaryKind: DashboardSummaryKind?
    let displayNameOverride: String?
    let iconNameOverride: String?
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

struct DashboardEntityDetailRoute: Identifiable, Equatable, Hashable {
    let entityID: String
    let sourceID: String

    var id: String {
        "\(sourceID)-\(entityID)"
    }
}

enum DashboardLayoutItemBuilder {
    static func makeItems(from configurationItems: [DashboardItemConfiguration]) -> [DashboardLayoutItem] {
        return configurationItems.compactMap { configurationItem in
            switch configurationItem.type {
            case .header:
                return DashboardLayoutItem(
                    kind: .header(configurationItem),
                    layoutMetadata: configurationItem.layoutMetadata
                )
            case .entity:
                guard let entityID = configurationItem.entityID else {
                    return nil
                }

                let configuredSize = configurationItem.resolvedCardSize
                let cardItem = DashboardCardItem(
                    id: configurationItem.id,
                    entityID: entityID,
                    size: configuredSize,
                    displayNameOverride: configurationItem.displayNameOverride,
                    iconNameOverride: configurationItem.iconNameOverride,
                    featureVisibility: configurationItem.resolvedFeatureVisibility
                )
                return DashboardLayoutItem(
                    kind: .card(cardItem),
                    layoutMetadata: configuredSize.layoutMetadata
                )
            case .chip:
                let chipKind = configurationItem.chipKind ?? .summary
                let chipItem = DashboardChipItem(
                    id: configurationItem.id,
                    chipKind: chipKind,
                    entityID: configurationItem.entityID,
                    summaryKind: configurationItem.summaryKind,
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
