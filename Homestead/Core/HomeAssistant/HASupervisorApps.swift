import Foundation

nonisolated struct HASupervisorAppsResponseDTO: Decodable, Equatable, Sendable {
    let addons: [HASupervisorAppDTO]
}

nonisolated struct HASupervisorAppDTO: Decodable, Equatable, Sendable {
    let name: String
    let slug: String
    let description: String?
    let version: String?
    let versionLatest: String?
    let updateAvailable: Bool?
    let installed: Bool?
    let available: Bool?
    let icon: Bool?
    let logo: Bool?
    let state: String?

    enum CodingKeys: String, CodingKey {
        case name
        case slug
        case description
        case version
        case versionLatest = "version_latest"
        case updateAvailable = "update_available"
        case installed
        case available
        case icon
        case logo
        case state
    }
}

nonisolated struct HASupervisorAppInfoDTO: Decodable, Equatable, Sendable {
    let name: String
    let slug: String
    let description: String?
    let longDescription: String?
    let version: String?
    let versionLatest: String?
    let updateAvailable: Bool?
    let icon: Bool?
    let logo: Bool?
    let state: String?
    let repository: String?
    let url: String?
    let rating: Int?
    let stage: String?
    let autoUpdate: Bool?
    let homeAssistant: String?
    let architectures: [String]?

    enum CodingKeys: String, CodingKey {
        case name
        case slug
        case description
        case longDescription = "long_description"
        case version
        case versionLatest = "version_latest"
        case updateAvailable = "update_available"
        case icon
        case logo
        case state
        case repository
        case url
        case rating
        case stage
        case autoUpdate = "auto_update"
        case homeAssistant = "homeassistant"
        case architectures = "arch"
    }
}

nonisolated struct HASupervisorApp: Identifiable, Equatable, Sendable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let installedVersion: String?
    let latestVersion: String?
    let updateAvailable: Bool
    let hasIcon: Bool
    let hasLogo: Bool
    let status: HASupervisorAppStatus

    init(
        id: String,
        slug: String,
        name: String,
        description: String?,
        installedVersion: String?,
        latestVersion: String?,
        updateAvailable: Bool,
        hasIcon: Bool = false,
        hasLogo: Bool = false,
        status: HASupervisorAppStatus
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.description = description
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.updateAvailable = updateAvailable
        self.hasIcon = hasIcon
        self.hasLogo = hasLogo
        self.status = status
    }

    var iconPath: String? {
        hasIcon ? "/api/hassio/addons/\(slug)/icon" : nil
    }

    var logoPath: String? {
        hasLogo ? "/api/hassio/addons/\(slug)/logo" : nil
    }

    var versionSummary: String? {
        guard let installedVersion = installedVersion?.nonEmptyValue else {
            return nil
        }

        guard updateAvailable,
              let latestVersion = latestVersion?.nonEmptyValue,
              latestVersion != installedVersion else {
            return installedVersion
        }

        return "\(installedVersion) → \(latestVersion)"
    }

    static func installedApps(from response: HASupervisorAppsResponseDTO) -> [HASupervisorApp] {
        response.addons
            .filter { dto in
                dto.installed == true || (dto.installed == nil && dto.version?.nonEmptyValue != nil)
            }
            .map(HASupervisorApp.init(dto:))
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private init(dto: HASupervisorAppDTO) {
        let slug = dto.slug.nonEmptyValue ?? dto.name.nonEmptyValue ?? "unknown"

        self.init(
            id: slug,
            slug: slug,
            name: dto.name.nonEmptyValue ?? slug,
            description: dto.description?.nonEmptyValue,
            installedVersion: dto.version?.nonEmptyValue,
            latestVersion: dto.versionLatest?.nonEmptyValue,
            updateAvailable: dto.updateAvailable == true,
            hasIcon: dto.icon == true,
            hasLogo: dto.logo == true,
            status: HASupervisorAppStatus(supervisorState: dto.state)
        )
    }

    fileprivate init(infoDTO: HASupervisorAppInfoDTO) {
        let slug = infoDTO.slug.nonEmptyValue ?? infoDTO.name.nonEmptyValue ?? "unknown"

        self.init(
            id: slug,
            slug: slug,
            name: infoDTO.name.nonEmptyValue ?? slug,
            description: infoDTO.description?.nonEmptyValue,
            installedVersion: infoDTO.version?.nonEmptyValue,
            latestVersion: infoDTO.versionLatest?.nonEmptyValue,
            updateAvailable: infoDTO.updateAvailable == true,
            hasIcon: infoDTO.icon == true,
            hasLogo: infoDTO.logo == true,
            status: HASupervisorAppStatus(supervisorState: infoDTO.state)
        )
    }
}

nonisolated struct HASupervisorAppDetails: Equatable, Sendable {
    let app: HASupervisorApp
    let longDescription: String?
    let repositoryURLString: String?
    let websiteURLString: String?
    let rating: Int?
    let stage: String?
    let autoUpdate: Bool?
    let minimumHomeAssistantVersion: String?
    let supportedArchitectures: [String]

    init(dto: HASupervisorAppInfoDTO) {
        app = HASupervisorApp(infoDTO: dto)
        longDescription = dto.longDescription?
            .supervisorAppDescription(appName: app.name)
            .nonEmptyValue
        repositoryURLString = dto.repository?.nonEmptyValue
        websiteURLString = dto.url?.nonEmptyValue
        rating = dto.rating
        stage = dto.stage?.nonEmptyValue
        autoUpdate = dto.autoUpdate
        minimumHomeAssistantVersion = dto.homeAssistant?.nonEmptyValue
        supportedArchitectures = dto.architectures ?? []
    }
}

nonisolated enum HASupervisorAppStatus: Equatable, Sendable {
    case running
    case stopped
    case unknown

    init(supervisorState: String?) {
        switch supervisorState?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "started":
            self = .running
        case "stopped":
            self = .stopped
        default:
            self = .unknown
        }
    }

    var title: String {
        switch self {
        case .running:
            return "Running"
        case .stopped:
            return "Stopped"
        case .unknown:
            return "Unknown"
        }
    }
}

nonisolated enum HASupervisorAppLifecycleAction: String, Equatable, Sendable {
    case start
    case stop
    case restart

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .start:
            return "play.fill"
        case .stop:
            return "stop.fill"
        case .restart:
            return "arrow.clockwise"
        }
    }
}

nonisolated enum HASupervisorAppsUnavailableReason: Equatable, Sendable {
    case notConfigured
    case unsupported
    case connectionUnavailable

    var title: String {
        switch self {
        case .notConfigured:
            return "Connect to Home Assistant"
        case .unsupported:
            return "Apps Unavailable"
        case .connectionUnavailable:
            return "Unable to Load Apps"
        }
    }

    var message: String {
        switch self {
        case .notConfigured:
            return "Add your Home Assistant server and sign in to view Supervisor apps."
        case .unsupported:
            return "Supervisor apps are available only on Home Assistant Supervisor installations."
        case .connectionUnavailable:
            return "Homestead could not reach Home Assistant. Check the connection and try again."
        }
    }
}

nonisolated enum HASupervisorAppsFetchResult: Equatable, Sendable {
    case available([HASupervisorApp])
    case unavailable(HASupervisorAppsUnavailableReason)
    case failed(String)
}

nonisolated private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    func supervisorAppDescription(appName: String) -> String {
        let lines = components(separatedBy: .newlines)
        var references: [String: String] = [:]
        for (identifier, url) in lines.compactMap(\.markdownReferenceDefinition) {
            references[identifier] = url
        }
        let normalizedAppName = appName.lowercased()
        var omittedAboutHeading = false
        var renderedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let normalized = trimmed.lowercased()
            let headingText = trimmed
                .drop(while: { $0 == "#" || $0.isWhitespace })
                .lowercased()

            if headingText == normalizedAppName ||
                headingText == "home assistant app: \(normalizedAppName)" {
                continue
            }

            if !omittedAboutHeading, normalized == "## about" {
                omittedAboutHeading = true
                continue
            }

            if line.markdownReferenceDefinition != nil {
                continue
            }

            if trimmed.contains("![") || normalized.contains("<img") {
                continue
            }

            var renderedLine = line
            for (identifier, url) in references {
                renderedLine = renderedLine.replacingOccurrences(
                    of: "[\(identifier)]",
                    with: "(\(url))",
                    options: .caseInsensitive
                )
            }

            renderedLine = renderedLine.removingHTMLTags

            if renderedLine.trimmingCharacters(in: .whitespaces).isEmpty,
               renderedLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                continue
            }

            renderedLines.append(renderedLine)
        }

        return renderedLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var markdownReferenceDefinition: (String, String)? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["),
              let closingBracket = trimmed.firstIndex(of: "]"),
              closingBracket < trimmed.endIndex,
              trimmed.index(after: closingBracket) < trimmed.endIndex,
              trimmed[trimmed.index(after: closingBracket)] == ":" else {
            return nil
        }

        let identifier = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracket])
        let valueStart = trimmed.index(closingBracket, offsetBy: 2)
        let value = trimmed[valueStart...].trimmingCharacters(in: .whitespaces)
        let url = value.split(whereSeparator: \.isWhitespace).first.map(String.init)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))

        guard !identifier.isEmpty, let url, !url.isEmpty else { return nil }
        return (identifier, url)
    }

    var removingHTMLTags: String {
        replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
    }
}

nonisolated extension HAWebSocketError {
    var isSupervisorAppsUnsupported: Bool {
        guard case .requestFailed(let message) = self else {
            return false
        }

        let normalizedMessage = message?.lowercased() ?? ""
        return normalizedMessage.contains("unknown command") ||
            normalizedMessage.contains("supervisor") ||
            normalizedMessage.contains("hassio") ||
            normalizedMessage.contains("not found")
    }
}
