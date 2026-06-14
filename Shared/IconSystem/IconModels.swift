import Foundation

nonisolated enum IconAsset: Codable, Equatable, Hashable, Sendable {
    case sfSymbol(String)
    case materialDesign(String)
    case unsupportedHomeAssistant(String)
}

nonisolated enum IconProvenance: String, Codable, Equatable, Hashable, Sendable {
    case dashboardOverride
    case appOverride
    case haRegistryIcon
    case haExplicitIcon
    case haSemanticMapping
    case homesteadSemanticMapping
    case fallback
}

nonisolated struct ResolvedIcon: Codable, Equatable, Hashable, Sendable {
    let asset: IconAsset
    let fallbackSFSymbol: String
    let provenance: IconProvenance
    let sourceIdentifier: String?

    static func sfSymbol(
        _ systemName: String,
        provenance: IconProvenance,
        sourceIdentifier: String? = nil
    ) -> ResolvedIcon {
        ResolvedIcon(
            asset: .sfSymbol(systemName),
            fallbackSFSymbol: systemName,
            provenance: provenance,
            sourceIdentifier: sourceIdentifier ?? systemName
        )
    }

    var sfSymbolName: String {
        switch asset {
        case .sfSymbol(let systemName):
            systemName
        case .materialDesign, .unsupportedHomeAssistant:
            fallbackSFSymbol
        }
    }
}

nonisolated struct EntityIconResolutionInput: Equatable, Hashable, Sendable {
    let domain: String
    let deviceClass: String?
    let semanticState: String?
    let registryIcon: String?
    let explicitIcon: String?
    let presentationOverride: String?
    let appOverride: String?

    init(
        domain: String,
        deviceClass: String? = nil,
        state: String,
        registryIcon: String? = nil,
        explicitIcon: String? = nil,
        presentationOverride: String? = nil,
        appOverride: String? = nil
    ) {
        self.domain = domain
        self.deviceClass = deviceClass?.iconNonEmptyValue
        self.semanticState = IconResolver.iconSemanticState(
            domain: domain,
            deviceClass: deviceClass,
            state: state
        )
        self.registryIcon = registryIcon?.iconNonEmptyValue
        self.explicitIcon = explicitIcon?.iconNonEmptyValue
        self.presentationOverride = presentationOverride?.iconNonEmptyValue
        self.appOverride = appOverride?.iconNonEmptyValue
    }
}

nonisolated struct AreaIconResolutionInput: Equatable, Hashable, Sendable {
    let name: String
    let registryIcon: String?
    let presentationOverride: String?
    let appOverride: String?

    init(
        name: String,
        registryIcon: String? = nil,
        presentationOverride: String? = nil,
        appOverride: String? = nil
    ) {
        self.name = name
        self.registryIcon = registryIcon?.iconNonEmptyValue
        self.presentationOverride = presentationOverride?.iconNonEmptyValue
        self.appOverride = appOverride?.iconNonEmptyValue
    }
}

nonisolated private extension String {
    var iconNonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
