import Foundation

struct DashboardCardEditorDraft: Equatable {
    var entityID: String
    var configuration: DashboardCardConfiguration
    var displayName: String
    var usesCustomDisplayName: Bool
    var iconNameOverride: String?
    var gaugeZoneConfiguration: GaugeZoneConfiguration?
    var chartConfiguration: DashboardChartConfiguration

    static let empty = DashboardCardEditorDraft(
        entityID: "",
        configuration: .status(layout: .compact),
        displayName: "",
        usesCustomDisplayName: false,
        iconNameOverride: nil,
        gaugeZoneConfiguration: nil,
        chartConfiguration: .default
    )

    init(item: DashboardCardItem, canonicalName: String?) {
        entityID = item.entityID
        configuration = item.configuration
        displayName = item.displayNameOverride ?? canonicalName ?? ""
        usesCustomDisplayName = item.displayNameOverride != nil
        iconNameOverride = item.iconNameOverride
        gaugeZoneConfiguration = item.gaugeZoneConfiguration
        chartConfiguration = item.chartConfiguration
    }

    private init(
        entityID: String,
        configuration: DashboardCardConfiguration,
        displayName: String,
        usesCustomDisplayName: Bool,
        iconNameOverride: String?,
        gaugeZoneConfiguration: GaugeZoneConfiguration?,
        chartConfiguration: DashboardChartConfiguration
    ) {
        self.entityID = entityID
        self.configuration = configuration
        self.displayName = displayName
        self.usesCustomDisplayName = usesCustomDisplayName
        self.iconNameOverride = iconNameOverride
        self.gaugeZoneConfiguration = gaugeZoneConfiguration
        self.chartConfiguration = chartConfiguration
    }

    var size: DashboardCardSize {
        get { configuration.layout }
        set { configuration = configuration.withLayout(newValue) }
    }

    var presentationKind: DashboardPresentationKind { configuration.kind }

    mutating func replaceEntity(
        with replacementEntityID: String,
        replacementCanonicalName: String?,
        preservesGaugeConfiguration: Bool
    ) {
        entityID = replacementEntityID
        if !usesCustomDisplayName {
            displayName = replacementCanonicalName ?? ""
        }
        if !preservesGaugeConfiguration {
            gaugeZoneConfiguration = nil
        }
    }

    func cardItem(id: UUID) -> DashboardCardItem {
        DashboardCardItem(
            id: id,
            entityID: entityID,
            configuration: configuration,
            displayNameOverride: usesCustomDisplayName ? normalizedDisplayNameOverride : nil,
            iconNameOverride: iconNameOverride,
            gaugeZoneConfiguration: gaugeZoneConfiguration,
            chartConfiguration: chartConfiguration
        )
    }

    func update(canonicalName: String?) -> DashboardCardUpdate {
        DashboardCardUpdate(
            entityID: entityID,
            configuration: configuration,
            displayNameOverride: usesCustomDisplayName
                ? normalizedDisplayNameOverride(canonicalName: canonicalName)
                : nil,
            iconNameOverride: iconNameOverride,
            gaugeZoneConfiguration: gaugeZoneConfiguration,
            chartConfiguration: chartConfiguration
        )
    }

    mutating func setDisplayName(_ value: String, canonicalName: String?) {
        displayName = value
        usesCustomDisplayName = normalizedDisplayNameOverride(canonicalName: canonicalName) != nil
    }

    private var normalizedDisplayNameOverride: String? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedDisplayNameOverride(canonicalName: String?) -> String? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != canonicalName else { return nil }
        return trimmed
    }
}
