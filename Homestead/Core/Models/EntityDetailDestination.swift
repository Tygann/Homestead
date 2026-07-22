import Foundation

nonisolated enum EntityDetailInitialSection: Equatable, Hashable, Sendable {
    case overview
    case history(initialRange: HAHistoryRangePreset)
}

nonisolated struct DashboardItemReference: Identifiable, Equatable, Hashable, Sendable {
    let dashboardID: UUID
    let itemID: UUID

    var id: String { "\(dashboardID.uuidString)-\(itemID.uuidString)" }
}

nonisolated struct EntityDetailDestination: Identifiable, Equatable, Hashable, Sendable {
    let entityID: String
    let initialSection: EntityDetailInitialSection
    let dashboardItemReference: DashboardItemReference?
    let transitionSourceID: String?

    init(
        entityID: String,
        initialSection: EntityDetailInitialSection = .overview,
        dashboardItemReference: DashboardItemReference? = nil,
        transitionSourceID: String? = nil
    ) {
        self.entityID = entityID
        self.initialSection = initialSection
        self.dashboardItemReference = dashboardItemReference
        self.transitionSourceID = transitionSourceID
    }

    var id: String {
        let dashboardIdentity = dashboardItemReference.map {
            "\($0.dashboardID.uuidString)-\($0.itemID.uuidString)"
        } ?? "entity"
        return "\(dashboardIdentity)-\(entityID)-\(transitionSourceID ?? "detail")"
    }

    func focusing(_ section: EntityDetailInitialSection) -> Self {
        Self(
            entityID: entityID,
            initialSection: section,
            dashboardItemReference: dashboardItemReference,
            transitionSourceID: transitionSourceID
        )
    }
}
