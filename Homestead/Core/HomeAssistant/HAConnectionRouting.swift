import Foundation
@preconcurrency import Network

nonisolated enum HAConnectionRoute: String, Equatable, Sendable {
    case current
    case internalURL
    case externalURL

    var title: String {
        switch self {
        case .current:
            "Saved Address"
        case .internalURL:
            "Local Address"
        case .externalURL:
            "Remote Address"
        }
    }
}

nonisolated struct HAConnectionNetworkContext: Equatable, Sendable {
    var isNetworkAvailable: Bool
    var isLikelyHomeNetwork: Bool
    var currentWiFiSSID: String?

    static let availableExternal = HAConnectionNetworkContext(
        isNetworkAvailable: true,
        isLikelyHomeNetwork: false,
        currentWiFiSSID: nil
    )

    init(isNetworkAvailable: Bool, isLikelyHomeNetwork: Bool, currentWiFiSSID: String? = nil) {
        self.isNetworkAvailable = isNetworkAvailable
        self.isLikelyHomeNetwork = isLikelyHomeNetwork
        self.currentWiFiSSID = currentWiFiSSID
    }

    init(path: NWPath) {
        isNetworkAvailable = path.status == .satisfied
        isLikelyHomeNetwork = path.status == .satisfied &&
            (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet))
        currentWiFiSSID = nil
    }

    func withCurrentWiFiSSID(_ ssid: String?) -> HAConnectionNetworkContext {
        HAConnectionNetworkContext(
            isNetworkAvailable: isNetworkAvailable,
            isLikelyHomeNetwork: isLikelyHomeNetwork,
            currentWiFiSSID: ssid
        )
    }
}

nonisolated struct HAConnectionRoutingSettingsSnapshot: Equatable, Sendable {
    var baseURLString: String
    var internalURLString: String
    var externalURLString: String
    var homeNetworkName: String
    var internalNetworkSSIDs: [String] = []

    var hasServerURL: Bool {
        !baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasAutomaticRouteCandidates: Bool {
        !internalURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !externalURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasInternalNetworkSSIDs: Bool {
        internalNetworkSSIDs.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

nonisolated struct HAConnectionRouteCandidate: Equatable, Sendable {
    var route: HAConnectionRoute
    var baseURLString: String
}

nonisolated struct HAConnectionRouteSelection: Equatable, Sendable {
    var authenticationBaseURLString: String
    var candidates: [HAConnectionRouteCandidate]

    var preferredCandidate: HAConnectionRouteCandidate? {
        candidates.first
    }
}

nonisolated struct HAConnectionRouteSummary: Equatable, Sendable {
    var route: HAConnectionRoute
    var baseURLString: String

    var title: String {
        route.title
    }
}

nonisolated enum HAConnectionRouteResolver {
    // MARK: - Public API

    static func resolve(
        settings: HAConnectionRoutingSettingsSnapshot,
        networkContext: HAConnectionNetworkContext
    ) -> HAConnectionRouteSelection {
        let baseURLString = trimmed(settings.baseURLString)
        let internalURLString = trimmed(settings.internalURLString)
        let externalURLString = trimmed(settings.externalURLString)
        let canUseInternalRoute = canUseInternalRoute(
            settings: settings,
            networkContext: networkContext,
            internalURLString: internalURLString,
            externalURLString: externalURLString
        )

        var candidates: [HAConnectionRouteCandidate] = []

        if canUseInternalRoute {
            candidates.append(HAConnectionRouteCandidate(route: .internalURL, baseURLString: internalURLString))
            appendIfUnique(
                HAConnectionRouteCandidate(route: .externalURL, baseURLString: externalURLString),
                to: &candidates
            )
            appendIfUnique(
                HAConnectionRouteCandidate(route: .current, baseURLString: baseURLString),
                to: &candidates
            )
        } else {
            appendIfUnique(
                HAConnectionRouteCandidate(route: .externalURL, baseURLString: externalURLString),
                to: &candidates
            )
            appendIfUnique(
                HAConnectionRouteCandidate(route: .current, baseURLString: baseURLString),
                to: &candidates
            )
        }

        if candidates.isEmpty, !baseURLString.isEmpty {
            candidates = [HAConnectionRouteCandidate(route: .current, baseURLString: baseURLString)]
        }

        return HAConnectionRouteSelection(
            authenticationBaseURLString: baseURLString,
            candidates: candidates
        )
    }

    static func explicit(baseURLString: String) -> HAConnectionRouteSelection {
        let baseURLString = trimmed(baseURLString)
        return HAConnectionRouteSelection(
            authenticationBaseURLString: baseURLString,
            candidates: [
                HAConnectionRouteCandidate(route: .current, baseURLString: baseURLString)
            ].filter { !$0.baseURLString.isEmpty }
        )
    }

    // MARK: - Helpers

    private static func appendIfUnique(
        _ candidate: HAConnectionRouteCandidate,
        to candidates: inout [HAConnectionRouteCandidate]
    ) {
        guard !candidate.baseURLString.isEmpty,
              !candidates.contains(where: { normalized($0.baseURLString) == normalized(candidate.baseURLString) }) else {
            return
        }

        candidates.append(candidate)
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ value: String) -> String {
        trimmed(value).lowercased()
    }

    private static func canUseInternalRoute(
        settings: HAConnectionRoutingSettingsSnapshot,
        networkContext: HAConnectionNetworkContext,
        internalURLString: String,
        externalURLString: String
    ) -> Bool {
        guard networkContext.isNetworkAvailable,
              networkContext.isLikelyHomeNetwork,
              !internalURLString.isEmpty else {
            return false
        }

        guard !externalURLString.isEmpty else {
            return true
        }

        // Trusted home networks are stored locally because Home Assistant does not
        // expose an official shared SSID/Internal URL settings API for third-party clients.
        let savedSSIDs = settings.internalNetworkSSIDs
            .map(trimmed)
            .filter { !$0.isEmpty }
        guard !savedSSIDs.isEmpty,
              let currentSSID = networkContext.currentWiFiSSID.map(trimmed),
              !currentSSID.isEmpty else {
            return false
        }

        return savedSSIDs.contains { $0.caseInsensitiveCompare(currentSSID) == .orderedSame }
    }
}
