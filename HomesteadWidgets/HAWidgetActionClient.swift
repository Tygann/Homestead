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

    private func switchSystemImage(deviceClass: String?, isOn: Bool) -> String {
        switch deviceClass {
        case "outlet":
            "poweroutlet.type.b.fill"
        default:
            isOn ? "lightswitch.on.fill" : "lightswitch.off.fill"
        }
    }

    private func brightnessPercentage(from value: Any?) -> Int? {
        let brightness: Int?

        switch value {
        case let intValue as Int:
            brightness = intValue
        case let doubleValue as Double:
            brightness = Int(doubleValue)
        case let numberValue as NSNumber:
            brightness = numberValue.intValue
        default:
            brightness = nil
        }

        guard let brightness else {
            return nil
        }

        let percentage = Int((Double(brightness) / 255.0) * 100.0)
        return min(max(percentage, 1), 100)
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
}
