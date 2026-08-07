import Foundation

// MARK: - Widget Home Assistant Client

enum HAWidgetActionError: LocalizedError {
    case missingCredentials
    case serverRemoved
    case entityUnavailable
    case invalidURL
    case authenticationFailed
    case unexpectedResponse
    case serviceCallFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Home Assistant credentials are not available to the widget."
        case .serverRemoved:
            "The configured Home Assistant server is no longer available."
        case .entityUnavailable:
            "The configured Home Assistant entity is unavailable."
        case .invalidURL:
            "The Home Assistant URL is invalid."
        case .authenticationFailed:
            "Home Assistant authentication failed."
        case .unexpectedResponse:
            "Home Assistant returned an unexpected WebSocket response."
        case .serviceCallFailed:
            "The Home Assistant service call failed."
        }
    }
}

struct HAWidgetLightState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let brightnessPercentage: Int?
    let icon: ResolvedIcon

    var isOn: Bool { state == "on" }
    var isAvailable: Bool { EntityAvailability.resolve(state: state).isAvailable }
}

struct HAWidgetSwitchState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let icon: ResolvedIcon

    var isOn: Bool { state == "on" }
    var systemImage: String { icon.sfSymbolName }
}

struct HAWidgetCoverState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let statusText: String
    let icon: ResolvedIcon
    let isOpen: Bool
    let isClosed: Bool
    let isMoving: Bool
    let isAvailable: Bool

    var systemImage: String { icon.sfSymbolName }
}

struct HAWidgetFanState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let statusText: String
    let isAvailable: Bool
    let icon: ResolvedIcon

    var isOn: Bool { state == "on" }
}

struct HAWidgetLockState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let statusText: String
    let icon: ResolvedIcon
    let isLocked: Bool
    let isAvailable: Bool

    var systemImage: String { icon.sfSymbolName }
}

struct HAWidgetSensorState: Sendable {
    let entityID: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let icon: ResolvedIcon
    let isAlerting: Bool
    let isAvailable: Bool
    let numericValue: Double?

    var systemImage: String { icon.sfSymbolName }

    var liveReading: WidgetSensorLiveReading {
        WidgetSensorLiveReading(
            entityID: entityID,
            valueText: valueText,
            numericValue: numericValue,
            isAvailable: isAvailable,
            icon: icon
        )
    }
}

struct HAWidgetPresenceState: Sendable {
    let entityID: String
    let displayName: String
    let statusText: String
    let isHome: Bool
    let icon: ResolvedIcon
    let isAvailable: Bool

    var systemImage: String { icon.sfSymbolName }
}

struct HAWidgetSensorHistorySeries: Equatable, Sendable {
    let entityID: String
    let displayName: String
    let unit: String?
    let startDate: Date
    let endDate: Date
    let samples: [HAWidgetHistorySample]

    var latestSample: HAWidgetHistorySample? {
        samples.last
    }

    var minimumValue: Double? {
        samples.map(\.value).min()
    }

    var maximumValue: Double? {
        samples.map(\.value).max()
    }

    var latestValueText: String? {
        latestSample.map { formatValue($0.value) }
    }

    var summaryText: String {
        guard !samples.isEmpty,
              let minimumValue,
              let maximumValue else {
            return "No numeric history"
        }

        return "Low \(formatValue(minimumValue)) • High \(formatValue(maximumValue))"
    }

    func formatValue(_ value: Double) -> String {
        let numberText = EntityPresentationResolver.formattedNumber(
            value,
            displayPrecision: maximumFractionDigits,
            deviceClass: nil
        )
        guard let unit, !unit.isEmpty else {
            return numberText
        }

        let separator = unit.hasPrefix("°") || unit == "%" ? "" : " "
        return "\(numberText)\(separator)\(unit)"
    }

    private var maximumFractionDigits: Int {
        let values = samples.map(\.value)
        guard values.contains(where: { abs($0.rounded() - $0) > 0.001 }) else {
            return 0
        }

        return 2
    }
}

struct HAWidgetSensorHistoryRequest: Equatable, Sendable {
    let entityID: String
    let displayName: String
    let unit: String?
}

final class HAWidgetActionClient: Sendable {
    private let profileID: UUID
    private let session: URLSession

    init(profileID: UUID, session: URLSession = .shared) {
        self.profileID = profileID
        self.session = session
    }

    func fetchLightState(entityID: String) async throws -> HAWidgetLightState {
        try await withConnectedSocket { task in
            try await sendJSON(["id": 1, "type": "get_states"], over: task)

            let message = try await receiveJSONObject(from: task)
            guard let success = message["success"] as? Bool, success,
                  let states = message["result"] as? [[String: Any]],
                  let state = states.first(where: { $0["entity_id"] as? String == entityID }),
                  let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID

            return HAWidgetLightState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName,
                brightnessPercentage: brightnessPercentage(from: attributes?["brightness"]),
                icon: resolvedIcon(domain: "light", state: stateValue, attributes: attributes)
            )
        }
    }

    func setLight(entityID: String, isOn: Bool) async throws {
        try await callService(
            domain: "light",
            service: isOn ? "turn_on" : "turn_off",
            entityID: entityID
        )
    }

    func fetchSwitchState(entityID: String) async throws -> HAWidgetSwitchState {
        try await withConnectedSocket { task in
            try await sendJSON(["id": 1, "type": "get_states"], over: task)

            let message = try await receiveJSONObject(from: task)
            guard let success = message["success"] as? Bool, success,
                  let states = message["result"] as? [[String: Any]],
                  let state = states.first(where: { $0["entity_id"] as? String == entityID }),
                  let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID

            return HAWidgetSwitchState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName,
                icon: resolvedIcon(domain: "switch", state: stateValue, attributes: attributes)
            )
        }
    }

    func setSwitch(entityID: String, isOn: Bool) async throws {
        try await callService(
            domain: "switch",
            service: isOn ? "turn_on" : "turn_off",
            entityID: entityID
        )
    }

    func fetchCoverState(entityID: String) async throws -> HAWidgetCoverState {
        try await withConnectedSocket { task in
            let state = try await stateObject(entityID: entityID, over: task)
            guard let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID
            let position = intValue(from: attributes?["current_position"])
            let isOpen = stateValue == "open" || stateValue == "opening"
            let isClosed = stateValue == "closed" || stateValue == "closing"
            let isMoving = stateValue == "opening" || stateValue == "closing"

            return HAWidgetCoverState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName,
                statusText: coverStatusText(state: stateValue, position: position),
                icon: resolvedIcon(domain: "cover", state: stateValue, attributes: attributes),
                isOpen: isOpen,
                isClosed: isClosed,
                isMoving: isMoving,
                isAvailable: !["unknown", "unavailable"].contains(stateValue)
            )
        }
    }

    func runCoverService(entityID: String, service: String) async throws {
        guard ["open_cover", "close_cover", "stop_cover"].contains(service) else {
            throw HAWidgetActionError.serviceCallFailed
        }

        try await callService(domain: "cover", service: service, entityID: entityID)
    }

    func fetchFanState(entityID: String) async throws -> HAWidgetFanState {
        try await withConnectedSocket { task in
            let state = try await stateObject(entityID: entityID, over: task)
            guard let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID
            let percentage = intValue(from: attributes?["percentage"])
            let presetMode = attributes?["preset_mode"] as? String

            return HAWidgetFanState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName,
                statusText: fanStatusText(state: stateValue, percentage: percentage, presetMode: presetMode),
                isAvailable: !["unknown", "unavailable"].contains(stateValue),
                icon: resolvedIcon(domain: "fan", state: stateValue, attributes: attributes)
            )
        }
    }

    func setFan(entityID: String, isOn: Bool) async throws {
        try await callService(
            domain: "fan",
            service: isOn ? "turn_on" : "turn_off",
            entityID: entityID
        )
    }

    func fetchLockState(entityID: String) async throws -> HAWidgetLockState {
        try await withConnectedSocket { task in
            let state = try await stateObject(entityID: entityID, over: task)
            guard let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID

            return HAWidgetLockState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName,
                statusText: lockStatusText(for: stateValue),
                icon: resolvedIcon(domain: "lock", state: stateValue, attributes: attributes),
                isLocked: stateValue == "locked",
                isAvailable: !["unknown", "unavailable"].contains(stateValue)
            )
        }
    }

    func lock(entityID: String) async throws {
        try await callService(domain: "lock", service: "lock", entityID: entityID)
    }

    func fetchSensorState(entityID: String) async throws -> HAWidgetSensorState {
        guard let state = try await fetchSensorStates(entityIDs: [entityID])[entityID] else {
            throw HAWidgetActionError.unexpectedResponse
        }
        return state
    }

    func fetchSensorStates(entityIDs: Set<String>) async throws -> [String: HAWidgetSensorState] {
        guard !entityIDs.isEmpty else { return [:] }

        return try await withConnectedSocket { task in
            try await sendJSON(["id": 1, "type": "get_states"], over: task)

            let message = try await receiveJSONObject(from: task)
            guard let success = message["success"] as? Bool, success,
                  let states = message["result"] as? [[String: Any]] else {
                throw HAWidgetActionError.unexpectedResponse
            }

            return states.reduce(into: [:]) { result, state in
                guard let entityID = state["entity_id"] as? String,
                      entityIDs.contains(entityID),
                      let stateValue = state["state"] as? String else { return }

                let attributes = state["attributes"] as? [String: Any]
                let displayName = attributes?["friendly_name"] as? String ?? entityID
                let unit = attributes?["unit_of_measurement"] as? String
                let deviceClass = attributes?["device_class"] as? String
                let displayPrecision = (attributes?["display_precision"] as? NSNumber)?.intValue
                let icon = resolvedIcon(domain: "sensor", state: stateValue, attributes: attributes)
                let semantic = EntityPresentationResolver.resolve(
                    EntityPresentationInput(
                        entityID: entityID,
                        domain: .sensor,
                        state: stateValue,
                        displayName: displayName,
                        deviceClass: deviceClass,
                        stateClass: attributes?["state_class"] as? String,
                        unit: unit,
                        numericValue: Double(stateValue),
                        displayPrecision: displayPrecision,
                        icon: icon
                    )
                )
                let isAvailable = semantic.isAvailable
                let isAlerting = isAvailable && deviceClass == "battery" && (Double(stateValue) ?? 100) <= 20

                result[entityID] = HAWidgetSensorState(
                    entityID: entityID,
                    displayName: displayName,
                    valueText: semantic.valueText,
                    subtitle: sensorSubtitle(value: stateValue, deviceClass: deviceClass, isAlerting: isAlerting),
                    icon: icon,
                    isAlerting: isAlerting,
                    isAvailable: isAvailable,
                    numericValue: Double(stateValue)
                )
            }
        }
    }

    func fetchSemanticPresentation(
        entityID: String,
        domain: String
    ) async throws -> EntitySemanticPresentation {
        try await withConnectedSocket { task in
            let object = try await stateObject(entityID: entityID, over: task)
            guard let state = object["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }
            let attributes = object["attributes"] as? [String: Any]
            let resolvedDomain = EntityDomain(entityID: "\(domain).placeholder")
            return EntityPresentationResolver.resolve(
                EntityPresentationInput(
                    entityID: entityID,
                    domain: resolvedDomain,
                    state: state,
                    displayName: attributes?["friendly_name"] as? String ?? entityID,
                    deviceClass: attributes?["device_class"] as? String,
                    stateClass: attributes?["state_class"] as? String,
                    unit: attributes?["unit_of_measurement"] as? String,
                    numericValue: Double(state),
                    displayPrecision: (attributes?["display_precision"] as? NSNumber)?.intValue,
                    icon: resolvedIcon(domain: domain, state: state, attributes: attributes)
                )
            )
        }
    }

    func fetchPresenceState(entityID: String) async throws -> HAWidgetPresenceState {
        try await withConnectedSocket { task in
            let state = try await stateObject(entityID: entityID, over: task)
            guard let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID

            return HAWidgetPresenceState(
                entityID: entityID,
                displayName: displayName,
                statusText: presenceStatusText(for: stateValue),
                isHome: stateValue == "home",
                icon: resolvedIcon(domain: "person", state: stateValue, attributes: attributes),
                isAvailable: !["unknown", "unavailable"].contains(stateValue)
            )
        }
    }

    func triggerAction(domain: String, entityID: String) async throws {
        let service: String
        switch domain {
        case "scene", "script":
            service = "turn_on"
        case "button":
            service = "press"
        default:
            throw HAWidgetActionError.serviceCallFailed
        }

        try await callService(domain: domain, service: service, entityID: entityID)
    }

    func fetchSensorHistory(
        entityID: String,
        displayName: String,
        unit: String?,
        endingAt endDate: Date = Date()
    ) async throws -> HAWidgetSensorHistorySeries {
        let request = HAWidgetSensorHistoryRequest(
            entityID: entityID,
            displayName: displayName,
            unit: unit
        )
        guard let series = try await fetchSensorHistories(
            [request],
            endingAt: endDate
        )[entityID] else {
            throw HAWidgetActionError.unexpectedResponse
        }
        return series
    }

    func fetchSensorHistories(
        _ requests: [HAWidgetSensorHistoryRequest],
        endingAt endDate: Date = Date()
    ) async throws -> [String: HAWidgetSensorHistorySeries] {
        let uniqueRequests = Dictionary(
            requests.map { ($0.entityID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard !uniqueRequests.isEmpty else { return [:] }
        guard let baseURL = HomesteadWidgetSharedStore.baseURL(profileID: profileID) else {
            throw HAWidgetActionError.missingCredentials
        }

        let token = try await HomesteadWidgetSharedStore.validAccessToken(profileID: profileID)
        let startDate = endDate.addingTimeInterval(-(6 * 60 * 60))
        guard let url = WidgetHistoryRequest.url(
            baseURLString: baseURL,
            entityIDs: uniqueRequests.keys.sorted(),
            startDate: startDate,
            endDate: endDate
        ) else {
            throw HAWidgetActionError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw HAWidgetActionError.unexpectedResponse
        }

        let historyResponse = try JSONDecoder().decode(HAWidgetHistoryResponse.self, from: data)
        let interval = DateInterval(start: startDate, end: endDate)
        return historyResponse.series.reduce(into: [:]) { result, states in
            guard let entityID = states.compactMap(\.entityID).first,
                  let request = uniqueRequests[entityID] else {
                return
            }
            let samples = states
                .enumerated()
                .compactMap { index, state -> HAWidgetHistorySample? in
                    guard let occurredAt = WidgetHistoryRequest.sampleDate(
                        lastChanged: state.lastChanged,
                        isFirstResponseState: index == states.startIndex,
                        interval: interval
                    ),
                          let value = Double(state.state),
                          value.isFinite else {
                        return nil
                    }
                    return HAWidgetHistorySample(occurredAt: occurredAt, value: value)
                }
                .sorted { $0.occurredAt < $1.occurredAt }
                .extendingLastKnownValue(to: interval.end)
                .cappedForWidget(maximumCount: 240)

            result[entityID] = HAWidgetSensorHistorySeries(
                entityID: entityID,
                displayName: request.displayName,
                unit: request.unit,
                startDate: startDate,
                endDate: endDate,
                samples: samples
            )
        }
    }

    private func callService(domain: String, service: String, entityID: String) async throws {
        try await withConnectedSocket { task in
            try await sendJSON([
                "id": 1,
                "type": "call_service",
                "domain": domain,
                "service": service,
                "target": ["entity_id": entityID]
            ], over: task)

            let message = try await receiveJSONObject(from: task)
            guard let success = message["success"] as? Bool, success else {
                throw HAWidgetActionError.serviceCallFailed
            }
        }
    }

    private func stateObject(
        entityID: String,
        over task: URLSessionWebSocketTask
    ) async throws -> [String: Any] {
        try await sendJSON(["id": 1, "type": "get_states"], over: task)

        let message = try await receiveJSONObject(from: task)
        guard let success = message["success"] as? Bool, success,
              let states = message["result"] as? [[String: Any]],
              let state = states.first(where: { $0["entity_id"] as? String == entityID }) else {
            throw HAWidgetActionError.unexpectedResponse
        }

        return state
    }

    private func resolvedIcon(
        domain: String,
        state: String,
        attributes: [String: Any]?
    ) -> ResolvedIcon {
        IconResolver.resolveEntity(
            EntityIconResolutionInput(
                domain: domain,
                deviceClass: attributes?["device_class"] as? String,
                state: state,
                explicitIcon: attributes?["icon"] as? String
            )
        )
    }

    private func withConnectedSocket<T>(
        _ operation: (URLSessionWebSocketTask) async throws -> T
    ) async throws -> T {
        guard let baseURL = HomesteadWidgetSharedStore.baseURL(profileID: profileID) else {
            throw HAWidgetActionError.missingCredentials
        }
        let token = try await HomesteadWidgetSharedStore.validAccessToken(profileID: profileID)

        let url = try webSocketURL(from: baseURL)
        let task = session.webSocketTask(with: url)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }

        let authRequired = try await receiveJSONObject(from: task)
        guard authRequired["type"] as? String == "auth_required" else {
            throw HAWidgetActionError.unexpectedResponse
        }

        try await sendJSON(["type": "auth", "access_token": token], over: task)

        let authResponse = try await receiveJSONObject(from: task)
        guard authResponse["type"] as? String == "auth_ok" else {
            throw HAWidgetActionError.authenticationFailed
        }

        return try await operation(task)
    }

    private func sendJSON(_ object: [String: Any], over task: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let string = String(data: data, encoding: .utf8) else {
            throw HAWidgetActionError.unexpectedResponse
        }

        try await task.send(.string(string))
    }

    private func receiveJSONObject(from task: URLSessionWebSocketTask) async throws -> [String: Any] {
        let message = try await task.receive()
        let data: Data

        switch message {
        case .string(let string):
            data = Data(string.utf8)
        case .data(let receivedData):
            data = receivedData
        @unknown default:
            throw HAWidgetActionError.unexpectedResponse
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HAWidgetActionError.unexpectedResponse
        }

        return object
    }

    private func webSocketURL(from baseURLString: String) throws -> URL {
        let trimmedString = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedString = trimmedString.contains("://") ? trimmedString : "\(defaultScheme(forHostOnlyBaseURL: trimmedString))://\(trimmedString)"

        guard var components = URLComponents(string: normalizedString),
              let scheme = components.scheme,
              let host = components.host?.lowercased() else {
            throw HAWidgetActionError.invalidURL
        }

        switch normalizedScheme(scheme, host: host) {
        case "http", "ws":
            components.scheme = "ws"
        case "https", "wss":
            components.scheme = "wss"
        default:
            throw HAWidgetActionError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "websocket"].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw HAWidgetActionError.invalidURL
        }

        return url
    }

    private func normalizedScheme(_ scheme: String, host: String) -> String {
        let lowercasedScheme = scheme.lowercased()
        guard !isLocalHost(host) else {
            return lowercasedScheme
        }

        switch lowercasedScheme {
        case "http":
            return "https"
        case "ws":
            return "wss"
        default:
            return lowercasedScheme
        }
    }

    private func defaultScheme(forHostOnlyBaseURL baseURLString: String) -> String {
        guard let host = URLComponents(string: "https://\(baseURLString)")?.host?.lowercased() else {
            return "https"
        }

        return isLocalHost(host) ? "http" : "https"
    }

    private func isLocalHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".local") || host == "::1" {
            return true
        }

        if host.hasPrefix("fe80:") || host.hasPrefix("fc") || host.hasPrefix("fd") {
            return true
        }

        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else {
            return false
        }

        switch parts[0] {
        case 10, 127:
            return true
        case 172:
            return (16...31).contains(parts[1])
        case 192:
            return parts[1] == 168
        case 169:
            return parts[1] == 254
        default:
            return false
        }
    }

    private func brightnessPercentage(from value: Any?) -> Int? {
        let brightness = intValue(from: value)

        guard let brightness else {
            return nil
        }

        let percentage = Int((Double(brightness) / 255.0) * 100.0)
        return min(max(percentage, 1), 100)
    }

    private func intValue(from value: Any?) -> Int? {
        switch value {
        case let intValue as Int:
            intValue
        case let doubleValue as Double:
            Int(doubleValue)
        case let numberValue as NSNumber:
            numberValue.intValue
        default:
            nil
        }
    }

    private func coverStatusText(state: String, position: Int?) -> String {
        let displayState: String
        switch state {
        case "open":
            displayState = "Open"
        case "closed":
            displayState = "Closed"
        case "opening":
            displayState = "Opening"
        case "closing":
            displayState = "Closing"
        case "unknown":
            displayState = "Unknown"
        case "unavailable":
            displayState = "Unavailable"
        default:
            displayState = state.replacingOccurrences(of: "_", with: " ").capitalized
        }

        guard let position, position > 0 else {
            return displayState
        }

        return "\(displayState) • \(min(max(position, 0), 100))%"
    }

    private func fanStatusText(state: String, percentage: Int?, presetMode: String?) -> String {
        switch state {
        case "on":
            if let percentage {
                return "On • \(percentage)%"
            }

            if let presetMode, !presetMode.isEmpty {
                return "On • \(presetMode.replacingOccurrences(of: "_", with: " ").capitalized)"
            }

            return "On"
        case "off":
            return "Off"
        case "unknown":
            return "Unknown"
        case "unavailable":
            return "Unavailable"
        default:
            return state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func lockStatusText(for state: String) -> String {
        switch state {
        case "locked":
            "Locked"
        case "unlocked":
            "Unlocked"
        case "locking":
            "Locking"
        case "unlocking":
            "Unlocking"
        case "jammed":
            "Jammed"
        case "unknown":
            "Unknown"
        case "unavailable":
            "Unavailable"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func sensorSubtitle(value: String, deviceClass: String?, isAlerting: Bool) -> String {
        guard !["unknown", "unavailable"].contains(value) else {
            return "Sensor unavailable"
        }

        if isAlerting {
            return "Low Battery"
        }

        guard let deviceClass, !deviceClass.isEmpty else {
            return "Sensor"
        }

        if deviceClass == "battery", Double(value) != nil {
            return "Battery"
        }

        return deviceClass.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func presenceStatusText(for state: String) -> String {
        switch state {
        case "home":
            "Home"
        case "not_home":
            "Away"
        case "unknown":
            "Unknown"
        case "unavailable":
            "Unavailable"
        default:
            state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

}

private struct HAWidgetHistoryResponse: Decodable {
    let series: [[HAWidgetHistoryState]]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        series = try container.decode([[HAWidgetHistoryState]].self)
    }
}

private struct HAWidgetHistoryState: Decodable {
    let entityID: String?
    let state: String
    let lastChanged: Date

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case state
        case lastChanged = "last_changed"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lastChangedString = try container.decode(String.self, forKey: .lastChanged)
        guard let lastChanged = Self.date(from: lastChangedString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .lastChanged,
                in: container,
                debugDescription: "Expected Home Assistant history last_changed timestamp."
            )
        }

        entityID = try container.decodeIfPresent(String.self, forKey: .entityID)
        state = try container.decode(String.self, forKey: .state)
        self.lastChanged = lastChanged
    }

    private static func date(from value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        return fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }
}

private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private extension Array where Element == HAWidgetHistorySample {
    func cappedForWidget(maximumCount: Int) -> [Element] {
        guard maximumCount > 2, count > maximumCount else { return self }
        let stride = Double(count - 1) / Double(maximumCount - 1)
        return (0..<maximumCount).map { index in
            self[Int((Double(index) * stride).rounded())]
        }
    }
}
