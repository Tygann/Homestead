import Foundation

enum HAWidgetActionError: LocalizedError {
    case missingCredentials
    case invalidURL
    case authenticationFailed
    case unexpectedResponse
    case serviceCallFailed

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Home Assistant credentials are not available to the widget."
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

    var isOn: Bool { state == "on" }
}

struct HAWidgetSwitchState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let systemImage: String

    var isOn: Bool { state == "on" }
}

struct HAWidgetCoverState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let statusText: String
    let systemImage: String
    let isOpen: Bool
    let isClosed: Bool
    let isMoving: Bool
    let isAvailable: Bool
}

struct HAWidgetFanState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let statusText: String
    let isAvailable: Bool

    var isOn: Bool { state == "on" }
}

struct HAWidgetLockState: Sendable {
    let entityID: String
    let state: String
    let displayName: String
    let statusText: String
    let systemImage: String
    let isLocked: Bool
    let isAvailable: Bool
}

struct HAWidgetSensorState: Sendable {
    let entityID: String
    let displayName: String
    let valueText: String
    let subtitle: String
    let systemImage: String
    let isAlerting: Bool
    let isAvailable: Bool
}

struct HAWidgetPresenceState: Sendable {
    let entityID: String
    let displayName: String
    let statusText: String
    let isHome: Bool
    let systemImage: String
    let isAvailable: Bool
}

struct HAWidgetHistorySample: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let value: Double

    init(occurredAt: Date, value: Double) {
        self.id = "\(occurredAt.timeIntervalSince1970)-\(value)"
        self.occurredAt = occurredAt
        self.value = value
    }
}

struct HAWidgetSensorHistorySeries: Equatable, Sendable {
    let entityID: String
    let displayName: String
    let unit: String?
    let startDate: Date
    let endDate: Date
    let samples: [HAWidgetHistorySample]

    var isEmpty: Bool {
        samples.isEmpty
    }

    var latestSample: HAWidgetHistorySample? {
        samples.last
    }

    var minimumValue: Double? {
        samples.map(\.value).min()
    }

    var maximumValue: Double? {
        samples.map(\.value).max()
    }

    var valueDomain: ClosedRange<Double> {
        guard let minimumValue, let maximumValue else {
            return 0...1
        }

        guard minimumValue != maximumValue else {
            let padding = max(abs(minimumValue) * 0.05, 1)
            return (minimumValue - padding)...(maximumValue + padding)
        }

        let padding = (maximumValue - minimumValue) * 0.12
        return (minimumValue - padding)...(maximumValue + padding)
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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

final class HAWidgetActionClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
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
                brightnessPercentage: brightnessPercentage(from: attributes?["brightness"])
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
            let deviceClass = attributes?["device_class"] as? String

            return HAWidgetSwitchState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName,
                systemImage: switchSystemImage(deviceClass: deviceClass, isOn: stateValue == "on")
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
            let deviceClass = attributes?["device_class"] as? String
            let position = intValue(from: attributes?["current_position"])
            let isOpen = stateValue == "open" || stateValue == "opening"
            let isClosed = stateValue == "closed" || stateValue == "closing"
            let isMoving = stateValue == "opening" || stateValue == "closing"

            return HAWidgetCoverState(
                entityID: entityID,
                state: stateValue,
                displayName: displayName,
                statusText: coverStatusText(state: stateValue, position: position),
                systemImage: coverSystemImage(deviceClass: deviceClass, state: stateValue),
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
                isAvailable: !["unknown", "unavailable"].contains(stateValue)
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
                systemImage: lockSystemImage(for: stateValue),
                isLocked: stateValue == "locked",
                isAvailable: !["unknown", "unavailable"].contains(stateValue)
            )
        }
    }

    func lock(entityID: String) async throws {
        try await callService(domain: "lock", service: "lock", entityID: entityID)
    }

    func fetchSensorState(entityID: String) async throws -> HAWidgetSensorState {
        try await withConnectedSocket { task in
            let state = try await stateObject(entityID: entityID, over: task)
            guard let stateValue = state["state"] as? String else {
                throw HAWidgetActionError.unexpectedResponse
            }

            let attributes = state["attributes"] as? [String: Any]
            let displayName = attributes?["friendly_name"] as? String ?? entityID
            let unit = attributes?["unit_of_measurement"] as? String
            let deviceClass = attributes?["device_class"] as? String
            let isAvailable = !["unknown", "unavailable"].contains(stateValue)
            let isAlerting = isAvailable && deviceClass == "battery" && (Double(stateValue) ?? 100) <= 20

            return HAWidgetSensorState(
                entityID: entityID,
                displayName: displayName,
                valueText: sensorValueText(value: stateValue, unit: unit, deviceClass: deviceClass),
                subtitle: sensorSubtitle(value: stateValue, deviceClass: deviceClass, isAlerting: isAlerting),
                systemImage: sensorSystemImage(deviceClass: deviceClass),
                isAlerting: isAlerting,
                isAvailable: isAvailable
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
                systemImage: stateValue == "home" ? "person.fill" : "person",
                isAvailable: !["unknown", "unavailable"].contains(stateValue)
            )
        }
    }

    func triggerAction(domain: String, entityID: String) async throws {
        guard domain == "scene" || domain == "script" else {
            throw HAWidgetActionError.serviceCallFailed
        }

        try await callService(domain: domain, service: "turn_on", entityID: entityID)
    }

    func fetchSensorHistory(
        entityID: String,
        displayName: String,
        unit: String?,
        endingAt endDate: Date = Date()
    ) async throws -> HAWidgetSensorHistorySeries {
        guard let baseURL = HomesteadWidgetSharedStore.baseURL else {
            throw HAWidgetActionError.missingCredentials
        }

        let token = try await HomesteadWidgetSharedStore.validAccessToken()
        let startDate = endDate.addingTimeInterval(-(6 * 60 * 60))
        let url = try historyURL(
            from: baseURL,
            entityID: entityID,
            startDate: startDate,
            endDate: endDate
        )
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
        let samples = historyResponse.series
            .flatMap { $0 }
            .compactMap { state -> HAWidgetHistorySample? in
                let resolvedEntityID = state.entityID?.nonEmptyValue ?? entityID
                guard resolvedEntityID == entityID,
                      interval.contains(state.lastChanged) || state.lastChanged == interval.end,
                      let value = Double(state.state),
                      value.isFinite else {
                    return nil
                }

                return HAWidgetHistorySample(occurredAt: state.lastChanged, value: value)
            }
            .sorted { lhs, rhs in
                lhs.occurredAt < rhs.occurredAt
            }

        return HAWidgetSensorHistorySeries(
            entityID: entityID,
            displayName: displayName,
            unit: unit,
            startDate: startDate,
            endDate: endDate,
            samples: samples
        )
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

    private func withConnectedSocket<T>(
        _ operation: (URLSessionWebSocketTask) async throws -> T
    ) async throws -> T {
        guard let baseURL = HomesteadWidgetSharedStore.baseURL else {
            throw HAWidgetActionError.missingCredentials
        }
        let token = try await HomesteadWidgetSharedStore.validAccessToken()

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
        let normalizedString = baseURLString.contains("://") ? baseURLString : "http://\(baseURLString)"

        guard var components = URLComponents(string: normalizedString),
              let scheme = components.scheme,
              components.host != nil else {
            throw HAWidgetActionError.invalidURL
        }

        switch scheme.lowercased() {
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

    private func historyURL(
        from baseURLString: String,
        entityID: String,
        startDate: Date,
        endDate: Date
    ) throws -> URL {
        let normalizedString = baseURLString.contains("://") ? baseURLString : "http://\(baseURLString)"

        guard var components = URLComponents(string: normalizedString),
              let scheme = components.scheme,
              components.host != nil,
              !entityID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HAWidgetActionError.invalidURL
        }

        switch scheme.lowercased() {
        case "http", "ws":
            components.scheme = "http"
        case "https", "wss":
            components.scheme = "https"
        default:
            throw HAWidgetActionError.invalidURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathParts = [basePath, "api", "history", "period", historyTimestamp(from: startDate)].filter { !$0.isEmpty }
        components.path = "/" + pathParts.joined(separator: "/")
        components.queryItems = [
            URLQueryItem(name: "filter_entity_id", value: entityID),
            URLQueryItem(name: "end_time", value: historyTimestamp(from: endDate)),
            URLQueryItem(name: "minimal_response", value: nil),
            URLQueryItem(name: "no_attributes", value: nil)
        ]
        components.fragment = nil

        guard let url = components.url else {
            throw HAWidgetActionError.invalidURL
        }

        return url
    }

    private func switchSystemImage(deviceClass: String?, isOn: Bool) -> String {
        switch deviceClass {
        case "outlet":
            "poweroutlet.type.b.fill"
        default:
            isOn ? "lightswitch.on.fill" : "lightswitch.off.fill"
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

    private func coverSystemImage(deviceClass: String?, state: String) -> String {
        let isOpen = state == "open" || state == "opening"

        switch deviceClass {
        case "garage":
            return isOpen ? "door.garage.open" : "door.garage.closed"
        case "gate":
            return isOpen ? "pedestrian.gate.open" : "pedestrian.gate.closed"
        case "door":
            return isOpen ? "door.left.hand.open" : "door.left.hand.closed"
        case "window":
            return isOpen ? "window.vertical.open" : "window.vertical.closed"
        case "curtain":
            return isOpen ? "curtains.open" : "curtains.closed"
        case "awning":
            return isOpen ? "window.awning" : "window.awning.closed"
        case "blind":
            return isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        case "shade":
            return isOpen ? "window.shade.open" : "window.shade.closed"
        case "shutter":
            return isOpen ? "blinds.vertical.open" : "blinds.vertical.closed"
        case "damper":
            return isOpen ? "rectangle.portrait.tophalf.inset.filled" : "rectangle.portrait.bottomhalf.inset.filled"
        default:
            return isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        }
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

    private func lockSystemImage(for state: String) -> String {
        switch state {
        case "locked", "locking":
            "lock.fill"
        case "jammed":
            "exclamationmark.lock.fill"
        default:
            "lock.open.fill"
        }
    }

    private func sensorValueText(value: String, unit: String?, deviceClass: String?) -> String {
        switch value {
        case "unknown":
            return "Unknown"
        case "unavailable":
            return "Unavailable"
        default:
            break
        }

        let formattedValue = formattedSensorNumber(value, deviceClass: deviceClass)
            ?? value.replacingOccurrences(of: "_", with: " ").capitalized
        guard let unitText = sensorDisplayUnit(unit, deviceClass: deviceClass), !unitText.isEmpty else {
            return formattedValue
        }

        let separator = unitText.hasPrefix("°") || unitText == "%" ? "" : " "
        return "\(formattedValue)\(separator)\(unitText)"
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

    private func formattedSensorNumber(_ value: String, deviceClass: String?) -> String? {
        guard let number = Double(value) else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumSensorFractionDigits(deviceClass: deviceClass)
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number))
    }

    private func maximumSensorFractionDigits(deviceClass: String?) -> Int {
        switch deviceClass {
        case "humidity", "battery", "illuminance", "signal_strength":
            0
        case "temperature":
            1
        case "energy", "energy_distance", "energy_storage", "power", "apparent_power", "reactive_power", "reactive_energy", "gas", "water", "moisture", "carbon_dioxide", "carbon_monoxide", "pm1", "pm10", "pm25", "pm4", "volatile_organic_compounds", "volatile_organic_compounds_parts":
            2
        default:
            1
        }
    }

    private func sensorDisplayUnit(_ unit: String?, deviceClass: String?) -> String? {
        switch (deviceClass, unit) {
        case ("temperature", "F"):
            "°F"
        case ("temperature", "C"):
            "°C"
        default:
            unit
        }
    }

    private func sensorSystemImage(deviceClass: String?) -> String {
        switch deviceClass {
        case "temperature":
            "thermometer.medium"
        case "humidity", "absolute_humidity":
            "humidity.fill"
        case "battery":
            "battery.75percent"
        case "power", "apparent_power", "reactive_power":
            "bolt.fill"
        case "energy", "reactive_energy":
            "bolt.circle.fill"
        case "illuminance":
            "sun.max.fill"
        case "pressure", "atmospheric_pressure":
            "barometer"
        case "signal_strength":
            "wifi"
        case "carbon_dioxide":
            "carbon.dioxide.cloud.fill"
        case "carbon_monoxide":
            "carbon.monoxide.cloud.fill"
        case "moisture", "water":
            "drop.fill"
        default:
            "gauge.medium"
        }
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

    private func historyTimestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
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
