import Foundation

nonisolated protocol HAWebSocketClientProtocol: AnyObject {
    func setEventHandler(_ handler: (@Sendable (HAEventDTO) async -> Void)?) async
    func setMobileAppPushNotificationHandler(_ handler: (@Sendable (HAMobileAppPushNotificationEventDTO) async -> Void)?) async
    func setDisconnectHandler(_ handler: (@MainActor @Sendable (Error) -> Void)?) async
    func connect(configuration: HAConnectionConfiguration) async throws
    func disconnect() async
    func fetchCurrentUser() async throws -> HACurrentUserDTO
    func fetchStates() async throws -> [HAEntityDTO]
    func fetchEntityRegistryForDisplay() async throws -> HAEntityRegistryDisplayResponseDTO
    func fetchEntityOrganization() async throws -> [HAEntityOrganizationDTO]
    func fetchDeviceRegistry() async throws -> [HADeviceRegistryDTO]
    func fetchAreaRegistry() async throws -> [HAAreaRegistryDTO]
    func fetchFloorRegistry() async throws -> [HAFloorRegistryDTO]
    func fetchLabelRegistry() async throws -> [HALabelRegistryDTO]
    func fetchCategoryRegistry(scope: HAOrganizationScope) async throws -> [HACategoryRegistryDTO]
    func fetchConfig() async throws -> HAConfigDTO
    func updateLocationName(_ locationName: String) async throws
    func fetchStatisticsMetadata(entityID: String) async throws -> [HAStatisticMetadataDTO]
    func fetchStatistics(request: HAStatisticsRequest) async throws -> [String: [HAStatisticRowDTO]]
    func fetchServices() async throws -> HAServiceRegistry
    func fetchServicesForTarget(entityID: String) async throws -> [String]
    func fetchCameraStreamPath(entityID: String) async throws -> String
    func fetchCameraWebRTCConfiguration(entityID: String) async throws -> JSONValue
    func subscribeCameraWebRTC(entityID: String, offer: String, handler: @escaping @Sendable (CameraWebRTCSignal) async -> Void) async throws -> Int
    func sendCameraWebRTCCandidate(entityID: String, sessionID: String, candidate: JSONValue) async throws
    func fetchCameraCapabilities(entityID: String) async throws -> HACameraCapabilities
    func fetchSupervisorApps() async throws -> HASupervisorAppsResponseDTO
    func fetchSupervisorAppInfo(slug: String) async throws -> HASupervisorAppInfoDTO
    func performSupervisorAppLifecycleAction(
        slug: String,
        action: HASupervisorAppLifecycleAction
    ) async throws
    func fetchSupervisorInfo() async throws -> HASupervisorInfoDTO
    func fetchOperatingSystemInfo() async throws -> HAOperatingSystemInfoDTO
    func fetchAutomationConfiguration(entityID: String) async throws -> HAAutomationConfigurationResponseDTO
    func fetchScriptConfiguration(entityID: String) async throws -> HAAutomationConfigurationResponseDTO
    func fetchAutomationTraces(itemID: String) async throws -> [HAAutomationTraceDTO]
    func fetchUpdateReleaseNotes(entityID: String) async throws -> String?
    func subscribeToStateChanges() async throws
    func subscribeToRegistryChanges() async throws
    func unsubscribeFromStateChanges() async throws
    func subscribeToMobileAppPushNotifications(webhookID: String, supportConfirm: Bool) async throws
    func subscribeToWeatherForecast(
        entityID: String,
        forecastType: WeatherForecastType,
        handler: @escaping @Sendable (HAWeatherForecastEventDTO) async -> Void
    ) async throws -> Int
    func unsubscribe(subscriptionID: Int) async throws
    func confirmMobileAppPushNotification(webhookID: String, confirmID: String) async throws
    func callService(
        domain: String,
        service: String,
        entityID: String?,
        serviceData: [String: JSONValue]
    ) async throws
}

nonisolated protocol HAWebSocketTransport: AnyObject, Sendable {
    var closeCode: URLSessionWebSocketTask.CloseCode { get }
    var closeReason: Data? { get }
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func receive() async throws -> URLSessionWebSocketTask.Message
    func send(_ message: URLSessionWebSocketTask.Message) async throws
}

extension URLSessionWebSocketTask: HAWebSocketTransport { }

actor HAWebSocketClient: HAWebSocketClientProtocol {
    private let makeTransport: @Sendable (URL) -> any HAWebSocketTransport
    private let requestTimeout: Duration
    private let heartbeatInterval: Duration
    private var webSocketTask: (any HAWebSocketTransport)?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var connectionID = UUID()
    private var serverVersion: String?
    private var hasDeliveredCompactSnapshot = false
    private var usesCompactEntities = false
    private var compactEntities = HACompactEntityStore()
    private var snapshotWaiters: [UUID: CheckedContinuation<[HAEntityDTO], Error>] = [:]
    private var nextID = 1
    private var pendingResults: [Int: CheckedContinuation<HAWebSocketIncomingMessage, Error>] = [:]
    private var pendingPongs: [Int: CheckedContinuation<Void, Error>] = [:]
    private var eventHandler: (@Sendable (HAEventDTO) async -> Void)?
    private var mobileAppPushNotificationHandler: (@Sendable (HAMobileAppPushNotificationEventDTO) async -> Void)?
    private var disconnectHandler: (@MainActor @Sendable (Error) -> Void)?
    private var stateChangeSubscriptionID: Int?
    private var registryChangeSubscriptionIDs: [String: Int] = [:]
    private var mobileAppPushNotificationSubscriptionID: Int?
    private var weatherForecastHandlers: [Int: @Sendable (HAWeatherForecastEventDTO) async -> Void] = [:]
    private var cameraSignalHandlers: [Int: @Sendable (CameraWebRTCSignal) async -> Void] = [:]
    private var isDisconnecting = false

    init(
        session: URLSession = .shared,
        requestTimeout: Duration = .seconds(15),
        heartbeatInterval: Duration = .seconds(30),
        transportFactory: (@Sendable (URL) -> any HAWebSocketTransport)? = nil
    ) {
        self.makeTransport = transportFactory ?? { session.webSocketTask(with: $0) }
        self.requestTimeout = requestTimeout
        self.heartbeatInterval = heartbeatInterval
    }

    func setEventHandler(_ handler: (@Sendable (HAEventDTO) async -> Void)?) async {
        eventHandler = handler
    }

    func setMobileAppPushNotificationHandler(_ handler: (@Sendable (HAMobileAppPushNotificationEventDTO) async -> Void)?) async {
        mobileAppPushNotificationHandler = handler
    }

    func setDisconnectHandler(_ handler: (@MainActor @Sendable (Error) -> Void)?) async {
        disconnectHandler = handler
    }

    func connect(configuration: HAConnectionConfiguration) async throws {
        isDisconnecting = true
        closeCurrentConnection()
        isDisconnecting = false
        let generation = connectionID

        do {
            let url = try HomeAssistantEndpointBuilder.webSocketURL(from: configuration.baseURLString)
            let task = makeTransport(url)
            webSocketTask = task
            task.resume()

            let authRequired = try await receiveIncomingMessage()
            guard generation == connectionID else { throw CancellationError() }
            guard authRequired.type == HAWebSocketMessageType.authRequired else {
                throw HAWebSocketError.unexpectedMessage(authRequired.type)
            }

            try await send(.auth(accessToken: configuration.accessToken))

            let authResponse = try await receiveIncomingMessage()
            guard generation == connectionID else { throw CancellationError() }
            switch authResponse.type {
            case HAWebSocketMessageType.authOK:
                serverVersion = authResponse.haVersion ?? authRequired.haVersion
                startReceiveLoop()
                // HA requires this to be the first command, with id 1.
                if HAWebSocketVersion.supports(serverVersion, year: 2022, month: 9) {
                    // Keep subscription ids unique across reconnects so late cleanup
                    // cannot unsubscribe a replacement camera/weather session.
                    nextID = max(nextID, 2)
                    do { _ = try await sendRequest(.supportedFeatures(id: 1), id: 1) }
                    catch let error as HAWebSocketServerError where error.code == "unknown_command" { }
                }
                guard generation == connectionID else { throw CancellationError() }
                startHeartbeatLoop()
            case HAWebSocketMessageType.authInvalid:
                throw HAWebSocketError.authenticationFailed(authResponse.message)
            default:
                throw HAWebSocketError.unexpectedMessage(authResponse.type)
            }
        } catch {
            guard generation == connectionID else { throw error }
            isDisconnecting = true
            closeCurrentConnection()
            isDisconnecting = false
            throw error
        }
    }

    func disconnect() async {
        isDisconnecting = true
        closeCurrentConnection()
    }

    private func closeCurrentConnection() {
        connectionID = UUID()
        serverVersion = nil
        usesCompactEntities = false
        hasDeliveredCompactSnapshot = false
        compactEntities = HACompactEntityStore()
        let waiters = snapshotWaiters.values
        snapshotWaiters.removeAll()
        for waiter in waiters { waiter.resume(throwing: HAWebSocketError.notConnected) }
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        stateChangeSubscriptionID = nil
        registryChangeSubscriptionIDs.removeAll()
        mobileAppPushNotificationSubscriptionID = nil
        let cameraHandlers = cameraSignalHandlers.values
        cameraSignalHandlers.removeAll()
        for handler in cameraHandlers {
            Task { await handler(.connectionClosed) }
        }
        weatherForecastHandlers.removeAll()
        resumeAllPending(throwing: HAWebSocketError.notConnected)
        resumeAllPongs(throwing: HAWebSocketError.notConnected)
    }

    func fetchStates() async throws -> [HAEntityDTO] {
        if usesCompactEntities {
            if compactEntities.hasInitialSnapshot {
                // A refresh also checks liveness without downloading all states again.
                let generation = connectionID
                if hasDeliveredCompactSnapshot { try await sendPing() }
                guard generation == connectionID else { throw CancellationError() }
                hasDeliveredCompactSnapshot = true
                return Array(compactEntities.entitiesByID.values)
            }
            let waiterID = UUID()
            let generation = connectionID
            return try await withCheckedThrowingContinuation { continuation in
                snapshotWaiters[waiterID] = continuation
                Task {
                    try? await Task.sleep(for: requestTimeout)
                    guard generation == connectionID else { return }
                    snapshotWaiters.removeValue(forKey: waiterID)?.resume(throwing: HAWebSocketError.requestTimedOut)
                }
            }
        }
        let id = makeRequestID()
        let response = try await sendRequest(.getStates(id: id), id: id)

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded([HAEntityDTO].self)
    }

    func fetchCurrentUser() async throws -> HACurrentUserDTO {
        let id = makeRequestID()
        let response = try await sendRequest(.currentUser(id: id), id: id)

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HACurrentUserDTO.self)
    }

    func fetchEntityRegistryForDisplay() async throws -> HAEntityRegistryDisplayResponseDTO {
        let id = makeRequestID()
        let response = try await sendRequest(
            .registryCommand(id: id, type: HAWebSocketMessageType.entityRegistryListForDisplay),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HAEntityRegistryDisplayResponseDTO.self)
    }

    func fetchEntityOrganization() async throws -> [HAEntityOrganizationDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(
            .registryCommand(id: id, type: HAWebSocketMessageType.entityRegistryList),
            id: id
        )
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded([HAEntityOrganizationDTO].self)
    }

    func fetchDeviceRegistry() async throws -> [HADeviceRegistryDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(
            .registryCommand(id: id, type: HAWebSocketMessageType.deviceRegistryList),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded([HADeviceRegistryDTO].self)
    }

    func fetchAreaRegistry() async throws -> [HAAreaRegistryDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(
            .registryCommand(id: id, type: HAWebSocketMessageType.areaRegistryList),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded([HAAreaRegistryDTO].self)
    }

    func fetchFloorRegistry() async throws -> [HAFloorRegistryDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(
            .registryCommand(id: id, type: HAWebSocketMessageType.floorRegistryList),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded([HAFloorRegistryDTO].self)
    }

    func fetchLabelRegistry() async throws -> [HALabelRegistryDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(
            .registryCommand(id: id, type: HAWebSocketMessageType.labelRegistryList),
            id: id
        )
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded([HALabelRegistryDTO].self)
    }

    func fetchCategoryRegistry(scope: HAOrganizationScope) async throws -> [HACategoryRegistryDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(.categoryRegistryList(id: id, scope: scope), id: id)
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded([HACategoryRegistryDTO].self).map { $0.withScope(scope) }
    }

    func fetchConfig() async throws -> HAConfigDTO {
        let id = makeRequestID()
        let response = try await sendRequest(.getConfig(id: id), id: id)

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HAConfigDTO.self)
    }

    func updateLocationName(_ locationName: String) async throws {
        let id = makeRequestID()
        _ = try await sendRequest(.updateCoreConfig(id: id, locationName: locationName), id: id)
    }

    func fetchStatisticsMetadata(entityID: String) async throws -> [HAStatisticMetadataDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(.statisticsCommand(id: id, type: "recorder/get_statistics_metadata",
            fields: ["statistic_ids": .array([.string(entityID)])]), id: id)
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded([HAStatisticMetadataDTO].self)
    }

    func fetchStatistics(request: HAStatisticsRequest) async throws -> [String: [HAStatisticRowDTO]] {
        let id = makeRequestID()
        let response = try await sendRequest(.statisticsCommand(id: id, type: "recorder/statistics_during_period",
            fields: request.fields), id: id)
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded([String: [HAStatisticRowDTO]].self)
    }

    func fetchServices() async throws -> HAServiceRegistry {
        let id = makeRequestID()
        let response = try await sendRequest(.getServices(id: id), id: id)

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HAServiceRegistry.self)
    }

    func fetchServicesForTarget(entityID: String) async throws -> [String] {
        let id = makeRequestID()
        let response = try await sendRequest(.getServicesForTarget(id: id, entityID: entityID), id: id)
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded([String].self)
    }

    func fetchCameraCapabilities(entityID: String) async throws -> HACameraCapabilities {
        let id = makeRequestID()
        let response = try await sendRequest(
            .cameraCapabilities(id: id, entityID: entityID),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HACameraCapabilities.self)
    }

    func fetchSupervisorApps() async throws -> HASupervisorAppsResponseDTO {
        let id = makeRequestID()
        let response = try await sendRequest(
            .supervisorAPI(id: id, endpoint: "/addons", method: "get"),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HASupervisorAppsResponseDTO.self)
    }

    func fetchSupervisorAppInfo(slug: String) async throws -> HASupervisorAppInfoDTO {
        let id = makeRequestID()
        let response = try await sendRequest(
            .supervisorAPI(id: id, endpoint: "/addons/\(slug)/info", method: "get"),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HASupervisorAppInfoDTO.self)
    }

    func performSupervisorAppLifecycleAction(
        slug: String,
        action: HASupervisorAppLifecycleAction
    ) async throws {
        let id = makeRequestID()
        _ = try await sendRequest(
            .supervisorAPI(
                id: id,
                endpoint: "/addons/\(slug)/\(action.rawValue)",
                method: "post"
            ),
            id: id
        )
    }

    func fetchSupervisorInfo() async throws -> HASupervisorInfoDTO {
        let id = makeRequestID()
        let response = try await sendRequest(
            .supervisorAPI(id: id, endpoint: "/supervisor/info", method: "get"),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HASupervisorInfoDTO.self)
    }

    func fetchOperatingSystemInfo() async throws -> HAOperatingSystemInfoDTO {
        let id = makeRequestID()
        let response = try await sendRequest(
            .supervisorAPI(id: id, endpoint: "/os/info", method: "get"),
            id: id
        )

        guard let result = response.result else {
            throw HAWebSocketError.missingResult
        }

        return try result.decoded(HAOperatingSystemInfoDTO.self)
    }

    func fetchAutomationConfiguration(entityID: String) async throws -> HAAutomationConfigurationResponseDTO {
        let id = makeRequestID()
        let response = try await sendRequest(.automationConfig(id: id, entityID: entityID), id: id)
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded(HAAutomationConfigurationResponseDTO.self)
    }

    func fetchScriptConfiguration(entityID: String) async throws -> HAAutomationConfigurationResponseDTO {
        let id = makeRequestID()
        let response = try await sendRequest(.scriptConfig(id: id, entityID: entityID), id: id)
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded(HAAutomationConfigurationResponseDTO.self)
    }

    func fetchAutomationTraces(itemID: String) async throws -> [HAAutomationTraceDTO] {
        let id = makeRequestID()
        let response = try await sendRequest(.traceList(id: id, domain: "automation", itemID: itemID), id: id)
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return try result.decoded([HAAutomationTraceDTO].self)
    }

    func fetchUpdateReleaseNotes(entityID: String) async throws -> String? {
        let id = makeRequestID()
        let response = try await sendRequest(
            .updateReleaseNotes(id: id, entityID: entityID),
            id: id
        )

        guard let result = response.result else {
            return nil
        }

        guard let releaseNotes = result.stringValue else {
            throw HAWebSocketError.requestFailed("Home Assistant returned invalid update release notes.")
        }

        return releaseNotes
    }

    func subscribeToStateChanges() async throws {
        let generation = connectionID
        guard stateChangeSubscriptionID == nil else {
            return
        }

        if HAWebSocketVersion.supports(serverVersion, year: 2022, month: 4) {
            let id = makeRequestID()
            // Install routing before the server can send its initial event.
            stateChangeSubscriptionID = id
            usesCompactEntities = true
            do {
                _ = try await sendRequest(.subscribeEntities(id: id), id: id)
                guard generation == connectionID else { throw CancellationError() }
                return
            } catch let error as HAWebSocketServerError where error.code == "unknown_command" {
                guard generation == connectionID else { throw CancellationError() }
                stateChangeSubscriptionID = nil
                usesCompactEntities = false
                compactEntities = HACompactEntityStore()
            } catch {
                guard generation == connectionID else { throw CancellationError() }
                stateChangeSubscriptionID = nil
                usesCompactEntities = false
                throw error
            }
        }
        let id = makeRequestID()
        _ = try await sendRequest(.subscribeEvents(id: id, eventType: "state_changed"), id: id)
        guard generation == connectionID else { throw CancellationError() }
        stateChangeSubscriptionID = id
    }

    func unsubscribeFromStateChanges() async throws {
        let generation = connectionID
        guard let stateChangeSubscriptionID else {
            return
        }

        let id = makeRequestID()
        _ = try await sendRequest(
            .unsubscribeEvents(id: id, subscription: stateChangeSubscriptionID),
            id: id
        )
        guard generation == connectionID else { throw CancellationError() }
        self.stateChangeSubscriptionID = nil
        usesCompactEntities = false
        compactEntities = HACompactEntityStore()
    }

    func subscribeToRegistryChanges() async throws {
        let generation = connectionID
        let eventTypes = [
            "entity_registry_updated",
            "device_registry_updated",
            "area_registry_updated",
            "floor_registry_updated",
            "label_registry_updated",
            "category_registry_updated",
            "service_registered",
            "service_removed",
            "core_config_updated",
            "component_loaded"
        ]

        for eventType in eventTypes where registryChangeSubscriptionIDs[eventType] == nil {
            let id = makeRequestID()
            do {
                _ = try await sendRequest(.subscribeEvents(id: id, eventType: eventType), id: id)
                guard generation == connectionID else { throw CancellationError() }
                registryChangeSubscriptionIDs[eventType] = id
            } catch let error as HAWebSocketServerError where ["unauthorized", "not_allowed", "unknown_command"].contains(error.code ?? "") {
                guard generation == connectionID else { throw CancellationError() }
                continue
            }
        }
    }

    func subscribeToMobileAppPushNotifications(webhookID: String, supportConfirm: Bool = true) async throws {
        guard mobileAppPushNotificationSubscriptionID == nil else {
            return
        }

        let id = makeRequestID()
        _ = try await sendRequest(
            .mobileAppPushNotificationChannel(id: id, webhookID: webhookID, supportConfirm: supportConfirm),
            id: id
        )
        mobileAppPushNotificationSubscriptionID = id
    }

    func confirmMobileAppPushNotification(webhookID: String, confirmID: String) async throws {
        let id = makeRequestID()
        _ = try await sendRequest(
            .mobileAppPushNotificationConfirm(id: id, webhookID: webhookID, confirmID: confirmID),
            id: id
        )
    }

    func subscribeToWeatherForecast(
        entityID: String,
        forecastType: WeatherForecastType,
        handler: @escaping @Sendable (HAWeatherForecastEventDTO) async -> Void
    ) async throws -> Int {
        let id = makeRequestID()
        weatherForecastHandlers[id] = handler

        do {
            _ = try await sendRequest(
                .subscribeWeatherForecast(id: id, entityID: entityID, forecastType: forecastType),
                id: id
            )
            return id
        } catch {
            weatherForecastHandlers.removeValue(forKey: id)
            throw error
        }
    }

    func fetchCameraStreamPath(entityID: String) async throws -> String {
        let id = makeRequestID()
        let response = try await sendRequest(.cameraCommand(id: id, type: "camera/stream", entityID: entityID, fields: [:]), id: id)
        guard let path = response.result?.objectValue?["url"]?.stringValue, !path.isEmpty else {
            throw HAWebSocketError.missingResult
        }
        return path
    }

    func fetchCameraWebRTCConfiguration(entityID: String) async throws -> JSONValue {
        let id = makeRequestID()
        let response = try await sendRequest(.cameraCommand(id: id, type: "camera/webrtc/get_client_config", entityID: entityID, fields: [:]), id: id)
        guard let result = response.result else { throw HAWebSocketError.missingResult }
        return result
    }

    func subscribeCameraWebRTC(entityID: String, offer: String, handler: @escaping @Sendable (CameraWebRTCSignal) async -> Void) async throws -> Int {
        let id = makeRequestID()
        cameraSignalHandlers[id] = handler
        do {
            _ = try await sendRequest(.cameraCommand(id: id, type: "camera/webrtc/offer", entityID: entityID, fields: ["offer": .string(offer)]), id: id)
            return id
        } catch {
            cameraSignalHandlers.removeValue(forKey: id)
            // The server may have accepted an offer whose acknowledgement arrived too late.
            let cleanupID = makeRequestID()
            try? await send(.unsubscribeEvents(id: cleanupID, subscription: id))
            throw error
        }
    }

    func sendCameraWebRTCCandidate(entityID: String, sessionID: String, candidate: JSONValue) async throws {
        let id = makeRequestID()
        _ = try await sendRequest(.cameraCommand(id: id, type: "camera/webrtc/candidate", entityID: entityID,
            fields: ["session_id": .string(sessionID), "candidate": candidate]), id: id)
    }

    func unsubscribe(subscriptionID: Int) async throws {
        cameraSignalHandlers.removeValue(forKey: subscriptionID)
        weatherForecastHandlers.removeValue(forKey: subscriptionID)
        let id = makeRequestID()
        _ = try await sendRequest(
            .unsubscribeEvents(id: id, subscription: subscriptionID),
            id: id
        )
    }

    func callService(
        domain: String,
        service: String,
        entityID: String?,
        serviceData: [String: JSONValue] = [:]
    ) async throws {
        let id = makeRequestID()
        let target = entityID.map { ["entity_id": JSONValue.string($0)] }
        _ = try await sendRequest(
            .callService(
                id: id,
                domain: domain,
                service: service,
                target: target,
                serviceData: serviceData.isEmpty ? nil : serviceData
            ),
            id: id
        )
    }

    private func makeRequestID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func sendRequest(_ request: HAWebSocketRequest, id: Int) async throws -> HAWebSocketIncomingMessage {
        let generation = connectionID
        return try await withCheckedThrowingContinuation { continuation in
            pendingResults[id] = continuation

            Task {
                guard generation == self.connectionID else { return }
                do {
                    try await self.send(request)
                } catch {
                    guard generation == self.connectionID else { return }
                    self.resumePendingResult(id: id, throwing: error)
                }
            }

            Task {
                do {
                    try await Task.sleep(for: requestTimeout)
                    guard generation == self.connectionID else { return }
                    self.resumePendingResult(id: id, throwing: HAWebSocketError.requestTimedOut)
                } catch {
                    return
                }
            }
        }
    }

    private func sendPing() async throws {
        let id = makeRequestID()

        let generation = connectionID
        try await withCheckedThrowingContinuation { continuation in
            pendingPongs[id] = continuation

            Task {
                do {
                    guard generation == self.connectionID else { return }
                    try await self.send(.ping(id: id))
                } catch {
                    guard generation == self.connectionID else { return }
                    self.resumePendingPong(id: id, throwing: error)
                }
            }

            Task {
                do {
                    try await Task.sleep(for: requestTimeout)
                    guard generation == self.connectionID else { return }
                    self.resumePendingPong(id: id, throwing: HAWebSocketError.requestTimedOut)
                } catch {
                    return
                }
            }
        }
    }

    private func send(_ request: HAWebSocketRequest) async throws {
        guard let webSocketTask else {
            throw HAWebSocketError.notConnected
        }

        let data = try JSONEncoder().encode(request)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw HAWebSocketError.requestFailed("Could not encode Home Assistant request.")
        }

        try await webSocketTask.send(.string(payload))
    }

    private func receiveIncomingMessage() async throws -> HAWebSocketIncomingMessage {
        guard let task = webSocketTask else { throw HAWebSocketError.notConnected }
        let messages = try await receiveIncomingMessages(from: task)
        guard messages.count == 1, let message = messages.first else {
            throw HAWebSocketError.unexpectedMessage("Invalid authentication frame")
        }
        return message
    }

    private func receiveIncomingMessages(from task: any HAWebSocketTransport) async throws -> [HAWebSocketIncomingMessage] {
        let webSocketTask = task
        guard self.webSocketTask != nil else {
            throw HAWebSocketError.notConnected
        }

        let message: URLSessionWebSocketTask.Message

        do {
            message = try await webSocketTask.receive()
        } catch {
            throw transportError(from: error, task: webSocketTask)
        }
        let data: Data

        switch message {
        case .data(let payload):
            data = payload
        case .string(let payload):
            data = Data(payload.utf8)
        @unknown default:
            throw HAWebSocketError.unexpectedMessage("unknown payload")
        }

        return try HAWebSocketFrame.decode(data)
    }

    private func transportError(
        from error: Error,
        task: any HAWebSocketTransport
    ) -> HAWebSocketError {
        let nsError = error as NSError
        var details = [error.localizedDescription]

        if !nsError.domain.isEmpty {
            details.append("\(nsError.domain) \(nsError.code)")
        }

        if task.closeCode != .invalid {
            details.append("WebSocket closed with \(task.closeCode.diagnosticDescription)")
        }

        if let reason = task.closeReason,
           let reasonText = String(data: reason, encoding: .utf8),
           !reasonText.isEmpty {
            details.append(reasonText)
        }

        return .transportFailure(details.joined(separator: " · "))
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        let generation = connectionID
        guard let socket = webSocketTask else { return }
        receiveTask = Task { [weak self] in
            await self?.receiveLoop(socket: socket, generation: generation)
        }
    }

    private func startHeartbeatLoop() {
        heartbeatTask?.cancel()
        let generation = connectionID
        heartbeatTask = Task { [weak self] in
            await self?.heartbeatLoop(generation: generation)
        }
    }

    private func heartbeatLoop(generation: UUID) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: heartbeatInterval)
                guard generation == connectionID, !Task.isCancelled else { return }
                try await sendPing()
            } catch {
                guard generation == connectionID, !Task.isCancelled, !isDisconnecting else {
                    return
                }

                closeCurrentConnection()
                await disconnectHandler?(error)
                return
            }
        }
    }

    private func receiveLoop(socket: any HAWebSocketTransport, generation: UUID) async {
        do {
            while !Task.isCancelled, generation == connectionID {
                let messages = try await receiveIncomingMessages(from: socket)
                for message in messages {
                    guard generation == connectionID, !Task.isCancelled else { return }
                    try await handle(message)
                }
            }
        } catch {
            guard generation == connectionID, !Task.isCancelled, !isDisconnecting else { return }
            closeCurrentConnection()
            // A missing delta base or malformed frame requires a fresh snapshot,
            // not a permanent command-validation failure.
            if error is DecodingError {
                await disconnectHandler?(HAWebSocketError.transportFailure("Invalid Home Assistant message; reconnecting."))
            } else if case HAWebSocketError.unexpectedMessage(let message) = error {
                await disconnectHandler?(HAWebSocketError.transportFailure(message))
            } else {
                await disconnectHandler?(error)
            }
        }
    }

    private func handle(_ message: HAWebSocketIncomingMessage) async throws {
        switch message.type {
        case HAWebSocketMessageType.result:
            handleResult(message)
        case HAWebSocketMessageType.pong:
            handlePong(message)
        case HAWebSocketMessageType.event:
            if usesCompactEntities, message.id == stateChangeSubscriptionID, let payload = message.eventPayload {
                let changes = try compactEntities.apply(payload)
                if !snapshotWaiters.isEmpty {
                    let snapshot = Array(compactEntities.entitiesByID.values)
                    let waiters = snapshotWaiters.values
                    snapshotWaiters.removeAll()
                    hasDeliveredCompactSnapshot = true
                    for waiter in waiters { waiter.resume(returning: snapshot) }
                }
                let generation = connectionID
                for change in changes {
                    guard generation == connectionID else { return }
                    await eventHandler?(HAEventDTO(stateChange: change))
                }
            } else if let id = message.id, let signal = message.cameraSignal,
               let handler = cameraSignalHandlers[id] {
                await handler(signal)
            } else if let id = message.id,
               let weatherForecastEvent = message.weatherForecastEvent,
               let handler = weatherForecastHandlers[id] {
                await handler(weatherForecastEvent)
            } else if let mobileAppPushNotificationEvent = message.mobileAppPushNotificationEvent {
                await mobileAppPushNotificationHandler?(mobileAppPushNotificationEvent)
            } else if let event = message.event {
                await eventHandler?(event)
            }
        default:
            break
        }
    }

    private func handleResult(_ message: HAWebSocketIncomingMessage) {
        guard let id = message.id, let continuation = pendingResults.removeValue(forKey: id) else {
            return
        }

        if message.success == false {
            continuation.resume(throwing: HAWebSocketServerError(dto: message.error, fallbackMessage: message.message))
        } else {
            continuation.resume(returning: message)
        }
    }

    private func handlePong(_ message: HAWebSocketIncomingMessage) {
        guard let id = message.id, let continuation = pendingPongs.removeValue(forKey: id) else {
            return
        }

        continuation.resume()
    }

    private func resumePendingResult(id: Int, throwing error: Error) {
        guard let continuation = pendingResults.removeValue(forKey: id) else {
            return
        }

        continuation.resume(throwing: error)
    }

    private func resumeAllPending(throwing error: Error) {
        let continuations = pendingResults.values
        pendingResults.removeAll()

        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }

    private func resumePendingPong(id: Int, throwing error: Error) {
        guard let continuation = pendingPongs.removeValue(forKey: id) else {
            return
        }

        continuation.resume(throwing: error)
    }

    private func resumeAllPongs(throwing error: Error) {
        let continuations = pendingPongs.values
        pendingPongs.removeAll()

        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }
}

private extension URLSessionWebSocketTask.CloseCode {
    nonisolated var diagnosticDescription: String {
        switch self {
        case .invalid:
            "invalid close code"
        case .normalClosure:
            "normal closure"
        case .goingAway:
            "going away"
        case .protocolError:
            "protocol error"
        case .unsupportedData:
            "unsupported data"
        case .noStatusReceived:
            "no status received"
        case .abnormalClosure:
            "abnormal closure"
        case .invalidFramePayloadData:
            "invalid frame payload data"
        case .policyViolation:
            "policy violation"
        case .messageTooBig:
            "message too big"
        case .mandatoryExtensionMissing:
            "mandatory extension missing"
        case .internalServerError:
            "internal server error"
        case .tlsHandshakeFailure:
            "TLS handshake failure"
        @unknown default:
            "unknown close code \(rawValue)"
        }
    }
}

// Preview and test clients that do not implement media signaling retain snapshot/HLS behavior.
extension HAWebSocketClientProtocol {
    func fetchCameraStreamPath(entityID: String) async throws -> String { throw HAWebSocketError.requestFailed("HLS unavailable") }
    func fetchCameraWebRTCConfiguration(entityID: String) async throws -> JSONValue { throw HAWebSocketError.requestFailed("WebRTC unavailable") }
    func subscribeCameraWebRTC(entityID: String, offer: String, handler: @escaping @Sendable (CameraWebRTCSignal) async -> Void) async throws -> Int { throw HAWebSocketError.requestFailed("WebRTC unavailable") }
    func sendCameraWebRTCCandidate(entityID: String, sessionID: String, candidate: JSONValue) async throws { throw HAWebSocketError.requestFailed("WebRTC unavailable") }
}

nonisolated extension HAWebSocketClientProtocol {
    func fetchStatisticsMetadata(entityID: String) async throws -> [HAStatisticMetadataDTO] { [] }
    func fetchStatistics(request: HAStatisticsRequest) async throws -> [String: [HAStatisticRowDTO]] { [:] }
}
