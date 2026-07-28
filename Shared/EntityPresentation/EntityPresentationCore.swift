import Foundation

// MARK: - Identity

nonisolated struct EntityPresentationReference: Codable, Equatable, Hashable, Sendable {
    static let separator = "|"

    let profileID: UUID
    let entityID: String

    var encodedID: String {
        "\(profileID.uuidString.lowercased())\(Self.separator)\(entityID)"
    }

    init(profileID: UUID, entityID: String) {
        self.profileID = profileID
        self.entityID = entityID
    }

    init?(encodedID: String, fallbackProfileID: UUID? = nil) {
        let components = encodedID
            .split(separator: Character(Self.separator), maxSplits: 1)
            .map(String.init)
        if components.count == 2,
           let profileID = UUID(uuidString: components[0]),
           !components[1].isEmpty {
            self.init(profileID: profileID, entityID: components[1])
            return
        }

        guard let fallbackProfileID, !encodedID.isEmpty else { return nil }
        self.init(profileID: fallbackProfileID, entityID: encodedID)
    }
}

// MARK: - Semantic Model

nonisolated enum EntityAvailability: String, Codable, Equatable, Sendable {
    case available
    case unknown
    case unavailable

    var isAvailable: Bool { self == .available }

    static func resolve(state: String) -> Self {
        switch state.lowercased() {
        case "unavailable":
            .unavailable
        case "unknown":
            .unknown
        default:
            .available
        }
    }
}

nonisolated enum EntitySemanticState: String, Codable, Equatable, Sendable {
    case active
    case inactive
    case transitioning
    case unknown
    case unavailable

    var isActive: Bool { self == .active || self == .transitioning }
}

nonisolated enum EntityPresentationAffordance: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case read
    case primaryAction
    case level
    case setpoint
    case options
    case commands
    case numericReading
    case history
    case gauge
    case media
    case camera
    case trigger
}

nonisolated enum EntityPresentationEligibility: Equatable, Sendable {
    case available
    case configurable(reason: String)
    case unavailable(reason: String)

    var isSelectable: Bool {
        switch self {
        case .available, .configurable:
            true
        case .unavailable:
            false
        }
    }
}

nonisolated enum EntityPresentationKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case chip
    case control
    case status
    case circularGauge
    case segmentedGauge
    case barGauge
    case chart
    case camera
    case weather
    case media
    case action
    case sensorReading
}

nonisolated struct EntityPresentationInput: Equatable, Sendable {
    let entityID: String
    let domain: EntityDomain
    let state: String
    let displayName: String
    let deviceClass: String?
    let stateClass: String?
    let unit: String?
    let numericValue: Double?
    let displayPrecision: Int?
    let icon: ResolvedIcon
    let runtimeAffordances: Set<EntityPresentationAffordance>
    let hasGaugeSpecification: Bool

    init(
        entityID: String,
        domain: EntityDomain,
        state: String,
        displayName: String,
        deviceClass: String? = nil,
        stateClass: String? = nil,
        unit: String? = nil,
        numericValue: Double? = nil,
        displayPrecision: Int? = nil,
        icon: ResolvedIcon,
        runtimeAffordances: Set<EntityPresentationAffordance> = [],
        hasGaugeSpecification: Bool = false
    ) {
        self.entityID = entityID
        self.domain = domain
        self.state = state
        self.displayName = displayName
        self.deviceClass = deviceClass
        self.stateClass = stateClass
        self.unit = unit
        self.numericValue = numericValue
        self.displayPrecision = displayPrecision
        self.icon = icon
        self.runtimeAffordances = runtimeAffordances
        self.hasGaugeSpecification = hasGaugeSpecification
    }
}

nonisolated struct EntitySemanticPresentation: Equatable, Sendable {
    let entityID: String
    let domain: EntityDomain
    let title: String
    let valueText: String
    let statusText: String
    let icon: ResolvedIcon
    let availability: EntityAvailability
    let semanticState: EntitySemanticState
    let affordances: Set<EntityPresentationAffordance>

    var isAvailable: Bool { availability.isAvailable }
    var isActive: Bool { semanticState.isActive }
}

// MARK: - Resolver

nonisolated enum EntityPresentationResolver {
    static func resolve(_ input: EntityPresentationInput) -> EntitySemanticPresentation {
        let availability = EntityAvailability.resolve(state: input.state)
        let semanticState = semanticState(
            domain: input.domain,
            state: input.state,
            availability: availability
        )
        let affordances = baseAffordances(for: input)
            .union(input.runtimeAffordances)
        let valueText = valueText(for: input, availability: availability)

        return EntitySemanticPresentation(
            entityID: input.entityID,
            domain: input.domain,
            title: input.displayName,
            valueText: valueText,
            statusText: statusText(
                domain: input.domain,
                state: input.state,
                availability: availability,
                valueText: valueText
            ),
            icon: input.icon,
            availability: availability,
            semanticState: semanticState,
            affordances: affordances
        )
    }

    static func eligibility(
        of presentation: EntityPresentationKind,
        for input: EntityPresentationInput
    ) -> EntityPresentationEligibility {
        let semantic = resolve(input)

        switch presentation {
        case .chip, .status:
            return .available
        case .control:
            let controls: Set<EntityPresentationAffordance> = [
                .primaryAction, .level, .setpoint, .options, .commands
            ]
            return semantic.affordances.isDisjoint(with: controls)
                ? .unavailable(reason: "Entity does not expose a supported control.")
                : .available
        case .circularGauge, .segmentedGauge, .barGauge:
            guard semantic.isAvailable else {
                return .unavailable(reason: "Gauge requires an available entity.")
            }
            guard input.numericValue != nil else {
                return .unavailable(reason: "Gauge requires a numeric reading.")
            }
            return input.hasGaugeSpecification
                ? .available
                : .configurable(reason: "Review the suggested range and zones.")
        case .chart:
            return semantic.affordances.contains(.history) && input.numericValue != nil
                ? .available
                : .unavailable(reason: "Chart requires numeric history.")
        case .camera:
            return input.domain == .camera
                ? .available
                : .unavailable(reason: "Camera presentation requires a camera.")
        case .weather:
            return input.domain == .weather
                ? .available
                : .unavailable(reason: "Weather presentation requires weather data.")
        case .media:
            return input.domain == .mediaPlayer
                ? .available
                : .unavailable(reason: "Media presentation requires a media player.")
        case .action:
            return semantic.affordances.contains(.trigger)
                ? .available
                : .unavailable(reason: "Action requires a scene, script, or button.")
        case .sensorReading:
            return input.domain == .sensor
                ? .available
                : .unavailable(reason: "Reading requires a sensor.")
        }
    }

    static func formattedNumber(
        _ value: Double,
        displayPrecision: Int?,
        deviceClass: String?
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = max(
            displayPrecision ?? defaultPrecision(for: deviceClass),
            0
        )
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func baseAffordances(
        for input: EntityPresentationInput
    ) -> Set<EntityPresentationAffordance> {
        var result: Set<EntityPresentationAffordance> = [.read]

        if input.stateClass != nil, input.numericValue != nil {
            result.insert(.history)
        }
        if input.numericValue != nil {
            result.insert(.numericReading)
        }
        if input.hasGaugeSpecification {
            result.insert(.gauge)
        }
        if input.domain == .mediaPlayer {
            result.insert(.media)
        }
        if input.domain == .camera {
            result.insert(.camera)
        }
        if [.scene, .script, .button].contains(input.domain) {
            result.insert(.trigger)
        }
        return result
    }

    private static func semanticState(
        domain: EntityDomain,
        state: String,
        availability: EntityAvailability
    ) -> EntitySemanticState {
        switch availability {
        case .unavailable:
            return .unavailable
        case .unknown:
            return .unknown
        case .available:
            break
        }

        let normalized = state.lowercased()
        if ["opening", "closing", "locking", "unlocking", "buffering", "cleaning", "returning"].contains(normalized) {
            return .transitioning
        }

        let activeStates: Set<String> = switch domain {
        case .lock:
            ["locked"]
        case .cover:
            ["open", "opening"]
        case .person, .deviceTracker:
            ["home"]
        case .mediaPlayer:
            ["playing", "buffering"]
        case .automation:
            ["on"]
        default:
            ["on", "active", "playing", "open", "home", "heat", "cool"]
        }
        return activeStates.contains(normalized) ? .active : .inactive
    }

    private static func valueText(
        for input: EntityPresentationInput,
        availability: EntityAvailability
    ) -> String {
        switch availability {
        case .unavailable:
            return "Unavailable"
        case .unknown:
            return "Unknown"
        case .available:
            break
        }

        guard let numericValue = input.numericValue else {
            return displayState(input.state)
        }

        let number = formattedNumber(
            numericValue,
            displayPrecision: input.displayPrecision,
            deviceClass: input.deviceClass
        )
        guard let unit = normalizedUnit(input.unit, deviceClass: input.deviceClass), !unit.isEmpty else {
            return number
        }
        let separator = unit.hasPrefix("°") || unit == "%" ? "" : " "
        return "\(number)\(separator)\(unit)"
    }

    private static func statusText(
        domain: EntityDomain,
        state: String,
        availability: EntityAvailability,
        valueText: String
    ) -> String {
        guard availability.isAvailable else { return valueText }
        if domain == .sensor { return valueText }
        return displayState(state)
    }

    private static func displayState(_ state: String) -> String {
        switch state.lowercased() {
        case "on": "On"
        case "off": "Off"
        case "not_home": "Away"
        case "home": "Home"
        default: state.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private static func normalizedUnit(_ unit: String?, deviceClass: String?) -> String? {
        switch (deviceClass, unit) {
        case ("temperature", "F"):
            "°F"
        case ("temperature", "C"):
            "°C"
        default:
            unit
        }
    }

    private static func defaultPrecision(for deviceClass: String?) -> Int {
        switch deviceClass {
        case "humidity", "battery", "illuminance", "signal_strength":
            0
        case "energy", "energy_distance", "energy_storage", "power", "apparent_power",
             "reactive_power", "reactive_energy", "gas", "water", "moisture",
             "carbon_dioxide", "carbon_monoxide", "pm1", "pm10", "pm25", "pm4",
             "volatile_organic_compounds", "volatile_organic_compounds_parts":
            2
        default:
            1
        }
    }
}
