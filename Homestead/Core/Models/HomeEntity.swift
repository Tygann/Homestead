import Foundation

struct HomeEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let domain: EntityDomain
    let displayName: String
    let state: String
    let resolvedIcon: ResolvedIcon
    let isAvailable: Bool
    let lastUpdated: Date?

    var id: String { entityID }
    var iconName: String { resolvedIcon.sfSymbolName }

    init(
        entityID: String,
        domain: EntityDomain,
        displayName: String,
        state: String,
        resolvedIcon: ResolvedIcon,
        isAvailable: Bool,
        lastUpdated: Date?
    ) {
        self.entityID = entityID
        self.domain = domain
        self.displayName = displayName
        self.state = state
        self.resolvedIcon = resolvedIcon
        self.isAvailable = isAvailable
        self.lastUpdated = lastUpdated
    }

    init(
        entityID: String,
        domain: EntityDomain,
        displayName: String,
        state: String,
        iconName: String,
        isAvailable: Bool,
        lastUpdated: Date?
    ) {
        self.init(
            entityID: entityID,
            domain: domain,
            displayName: displayName,
            state: state,
            resolvedIcon: .sfSymbol(iconName, provenance: .homesteadSemanticMapping),
            isAvailable: isAvailable,
            lastUpdated: lastUpdated
        )
    }
}
