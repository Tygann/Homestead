import Foundation

nonisolated struct HomeAssistantFrontendEntityDestination: Equatable, Identifiable, Sendable {
    enum Action: Equatable, Sendable {
        case open
        case edit

        var title: String {
            switch self {
            case .open:
                "Open in Home Assistant"
            case .edit:
                "Edit in Home Assistant"
            }
        }
    }

    let url: URL
    let action: Action

    var id: String { url.absoluteString }
}

nonisolated enum HomeAssistantFrontendEntityDestinationResolver {
    private static let helperDomains: Set<String> = [
        "counter",
        "input_boolean",
        "input_button",
        "input_datetime",
        "input_number",
        "input_select",
        "input_text",
        "schedule",
        "timer"
    ]

    // MARK: - Public API

    static func destination(
        baseURLString: String,
        entityID: String,
        configurationID: String? = nil,
        registryUniqueID: String? = nil,
        isPersonEditable: Bool = true
    ) -> HomeAssistantFrontendEntityDestination? {
        guard let domain = validatedDomain(from: entityID),
              let baseURL = frontendBaseURL(from: baseURLString) else {
            return nil
        }

        switch domain {
        case "automation", "scene":
            if let configurationID = safePathSegment(configurationID) {
                return editDestination(
                    baseURL: baseURL,
                    domain: domain,
                    identifier: configurationID
                )
            }
            return moreInfoDestination(baseURL: baseURL, entityID: entityID, opensSettings: true)

        case "script":
            if let registryUniqueID = safePathSegment(registryUniqueID) {
                return editDestination(
                    baseURL: baseURL,
                    domain: domain,
                    identifier: registryUniqueID
                )
            }
            return moreInfoDestination(baseURL: baseURL, entityID: entityID, opensSettings: true)

        case "person" where isPersonEditable:
            if let configurationID = safePathSegment(configurationID) {
                return editDestination(
                    baseURL: baseURL,
                    domain: domain,
                    identifier: configurationID
                )
            }
            return moreInfoDestination(baseURL: baseURL, entityID: entityID, opensSettings: true)

        case let helperDomain where helperDomains.contains(helperDomain):
            return moreInfoDestination(baseURL: baseURL, entityID: entityID, opensSettings: true)

        default:
            return moreInfoDestination(baseURL: baseURL, entityID: entityID, opensSettings: false)
        }
    }

    // MARK: - Helpers

    private static func editDestination(
        baseURL: URL,
        domain: String,
        identifier: String
    ) -> HomeAssistantFrontendEntityDestination {
        let url = baseURL
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent(domain, isDirectory: true)
            .appendingPathComponent("edit", isDirectory: true)
            .appendingPathComponent(identifier, isDirectory: false)

        return HomeAssistantFrontendEntityDestination(url: url, action: .edit)
    }

    private static func moreInfoDestination(
        baseURL: URL,
        entityID: String,
        opensSettings: Bool
    ) -> HomeAssistantFrontendEntityDestination? {
        let lovelaceURL = baseURL.appendingPathComponent("lovelace", isDirectory: false)
        guard var components = URLComponents(url: lovelaceURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var queryItems = [
            URLQueryItem(name: "more-info-entity-id", value: entityID)
        ]
        if opensSettings {
            queryItems.append(URLQueryItem(name: "more-info-view", value: "settings"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            return nil
        }

        return HomeAssistantFrontendEntityDestination(
            url: url,
            action: opensSettings ? .edit : .open
        )
    }

    private static func frontendBaseURL(from baseURLString: String) -> URL? {
        guard let url = try? HomeAssistantEndpointBuilder.httpURL(
            from: baseURLString,
            pathOrURL: ""
        ),
        let scheme = url.scheme?.lowercased(),
        ["http", "https"].contains(scheme),
        url.host != nil else {
            return nil
        }

        return url
    }

    private static func validatedDomain(from entityID: String) -> String? {
        let parts = entityID.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts.allSatisfy({ !$0.isEmpty }),
              parts.allSatisfy({ part in
                  part.utf8.allSatisfy { byte in
                      (97...122).contains(byte)
                          || (48...57).contains(byte)
                          || byte == 95
                  }
              }) else {
            return nil
        }

        return String(parts[0])
    }

    private static func safePathSegment(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              value != ".",
              value != "..",
              !value.contains("/"),
              !value.contains("\\"),
              !value.contains("?"),
              !value.contains("#") else {
            return nil
        }

        return value
    }
}
