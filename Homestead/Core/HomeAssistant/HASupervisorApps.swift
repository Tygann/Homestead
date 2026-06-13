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

nonisolated struct HASupervisorApp: Identifiable, Equatable, Sendable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let installedVersion: String?
    let latestVersion: String?
    let updateAvailable: Bool
    let status: HASupervisorAppStatus

    init(
        id: String,
        slug: String,
        name: String,
        description: String?,
        installedVersion: String?,
        latestVersion: String?,
        updateAvailable: Bool,
        status: HASupervisorAppStatus
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.description = description
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.updateAvailable = updateAvailable
        self.status = status
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
            status: HASupervisorAppStatus(supervisorState: dto.state)
        )
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
