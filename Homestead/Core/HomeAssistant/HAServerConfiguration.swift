import Foundation

nonisolated struct HAConfigDTO: Decodable, Equatable, Sendable {
    let version: String?
    let locationName: String?
    let timeZone: String?
    let internalURL: String?
    let externalURL: String?
    let state: String?
    let configSource: String?
    let unitSystem: HAConfigUnitSystemDTO?

    enum CodingKeys: String, CodingKey {
        case version
        case locationName = "location_name"
        case timeZone = "time_zone"
        case internalURL = "internal_url"
        case externalURL = "external_url"
        case state
        case configSource = "config_source"
        case unitSystem = "unit_system"
    }
}

nonisolated struct HAConfigUnitSystemDTO: Decodable, Equatable, Sendable {
    let length: String?
    let mass: String?
    let temperature: String?
    let volume: String?

    enum CodingKeys: String, CodingKey {
        case length
        case mass
        case temperature
        case volume
    }
}

nonisolated struct HAServerConfigurationSnapshot: Equatable, Sendable {
    let homeAssistantVersion: String?
    let locationName: String?
    let timeZone: String?
    let internalURL: String?
    let externalURL: String?
    let state: String?
    let configSource: String?
    let unitSystemSummary: String?
    let loadedAt: Date

    init(dto: HAConfigDTO, loadedAt: Date = Date()) {
        homeAssistantVersion = dto.version?.nonEmptyTrimmed
        locationName = dto.locationName?.nonEmptyTrimmed
        timeZone = dto.timeZone?.nonEmptyTrimmed
        internalURL = dto.internalURL?.nonEmptyTrimmed
        externalURL = dto.externalURL?.nonEmptyTrimmed
        state = dto.state?.nonEmptyTrimmed
        configSource = dto.configSource?.nonEmptyTrimmed
        unitSystemSummary = dto.unitSystem?.summary
        self.loadedAt = loadedAt
    }
}

nonisolated enum HAServerConfigurationStatus: Equatable, Sendable {
    case unavailable
    case loading
    case loaded(Date)
    case failed(String)

    var title: String {
        switch self {
        case .unavailable:
            "Not loaded"
        case .loading:
            "Loading"
        case .loaded:
            "Loaded"
        case .failed:
            "Unavailable"
        }
    }

    var message: String? {
        switch self {
        case .unavailable:
            "Connect to Home Assistant to load server configuration."
        case .loading:
            "Loading Home Assistant server configuration."
        case .loaded(let date):
            "Loaded \(date.formatted(date: .omitted, time: .shortened))."
        case .failed(let message):
            message
        }
    }
}

private extension HAConfigUnitSystemDTO {
    var summary: String? {
        [
            temperature.map { "Temp \($0)" },
            length.map { "Length \($0)" },
            mass.map { "Mass \($0)" },
            volume.map { "Volume \($0)" }
        ]
        .compactMap { $0?.nonEmptyTrimmed }
        .joined(separator: ", ")
        .nonEmptyTrimmed
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
