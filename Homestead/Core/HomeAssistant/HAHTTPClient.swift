import Foundation

protocol HAHTTPClientProtocol: Sendable {
    func fetchCameraSnapshot(configuration: HAConnectionConfiguration, entityID: String) async throws -> Data
    func fetchLogbook(configuration: HAConnectionConfiguration, request: HALogbookRequest) async throws -> [HALogbookEntryDTO]
    func fetchHistory(configuration: HAConnectionConfiguration, request: HAHistoryRequest) async throws -> HAHistoryResponseDTO
    func fetchSupervisorApps(configuration: HAConnectionConfiguration) async throws -> HASupervisorAppsResponseDTO
}

actor HAHTTPClient: HAHTTPClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCameraSnapshot(configuration: HAConnectionConfiguration, entityID: String) async throws -> Data {
        let url = try HomeAssistantEndpointBuilder.cameraSnapshotURL(
            from: configuration.baseURLString,
            entityID: entityID,
            cacheBuster: String(Int(Date().timeIntervalSince1970))
        )
        var request = URLRequest(url: url)
        request.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAWebSocketError.transportFailure("Home Assistant returned an invalid camera response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HAWebSocketError.requestFailed("Home Assistant camera snapshot failed with status \(httpResponse.statusCode).")
        }

        guard !data.isEmpty else {
            throw HAWebSocketError.missingResult
        }

        return data
    }

    func fetchLogbook(configuration: HAConnectionConfiguration, request: HALogbookRequest) async throws -> [HALogbookEntryDTO] {
        let url = try HomeAssistantEndpointBuilder.logbookURL(
            from: configuration.baseURLString,
            startDate: request.startDate,
            endDate: request.endDate,
            entityID: request.entityID
        )
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAWebSocketError.transportFailure("Home Assistant returned an invalid logbook response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HAWebSocketError.requestFailed("Home Assistant logbook failed with status \(httpResponse.statusCode).")
        }

        return try JSONDecoder().decode([HALogbookEntryDTO].self, from: data)
    }

    func fetchHistory(configuration: HAConnectionConfiguration, request: HAHistoryRequest) async throws -> HAHistoryResponseDTO {
        let url = try HomeAssistantEndpointBuilder.historyURL(
            from: configuration.baseURLString,
            request: request
        )
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAWebSocketError.transportFailure("Home Assistant returned an invalid history response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HAWebSocketError.requestFailed("Home Assistant history failed with status \(httpResponse.statusCode).")
        }

        return try JSONDecoder().decode(HAHistoryResponseDTO.self, from: data)
    }

    func fetchSupervisorApps(configuration: HAConnectionConfiguration) async throws -> HASupervisorAppsResponseDTO {
        let url = try HomeAssistantEndpointBuilder.supervisorAppsURL(
            from: configuration.baseURLString
        )
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(configuration.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HAWebSocketError.transportFailure("Home Assistant returned an invalid Supervisor apps response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw HASupervisorAppsHTTPError.unavailable(statusCode: httpResponse.statusCode)
            }

            throw HAWebSocketError.requestFailed("Home Assistant Supervisor apps failed with status \(httpResponse.statusCode).")
        }

        return try JSONDecoder().decode(HASupervisorAppsResponseDTO.self, from: data)
    }
}
