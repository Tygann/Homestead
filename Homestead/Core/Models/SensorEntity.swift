import Foundation

struct SensorEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let value: String
    let unit: String?
    let deviceClass: String?
    let stateClass: SensorStateClass?
    let displayPrecision: Int?
    let lastUpdated: Date?
    let suggestedMinimumValue: Double?
    let suggestedMaximumValue: Double?

    init(
        entityID: String,
        displayName: String,
        value: String,
        unit: String?,
        deviceClass: String?,
        stateClass: SensorStateClass? = nil,
        displayPrecision: Int? = nil,
        lastUpdated: Date?,
        suggestedMinimumValue: Double? = nil,
        suggestedMaximumValue: Double? = nil
    ) {
        self.entityID = entityID
        self.displayName = displayName
        self.value = value
        self.unit = unit
        self.deviceClass = deviceClass
        self.stateClass = stateClass
        self.displayPrecision = displayPrecision
        self.lastUpdated = lastUpdated
        self.suggestedMinimumValue = suggestedMinimumValue
        self.suggestedMaximumValue = suggestedMaximumValue
    }

    var id: String { entityID }

    var isAvailable: Bool {
        !["unknown", "unavailable"].contains(value)
    }

    var isAlerting: Bool {
        guard isAvailable else { return false }

        switch displayKind {
        case .battery:
            guard let numericValue else { return false }
            return numericValue <= 20
        case .water, .moisture:
            return ["on", "detected", "wet", "moisture"].contains(normalizedState)
        case .gas, .carbonMonoxide:
            return ["on", "detected", "unsafe"].contains(normalizedState)
        case .problem:
            return ["on", "detected", "problem", "unsafe"].contains(normalizedState)
        case .airQuality, .area, .carbonDioxide, .conductivity, .data, .date, .distance, .duration, .enum, .frequency, .monetary, .particulateMatter, .pH, .precipitation, .speed, .soundPressure, .volatileOrganicCompounds, .volume, .volumeFlowRate, .weight, .windDirection, .temperature, .temperatureDelta, .humidity, .energy, .energyDistance, .energyStorage, .power, .powerFactor, .reactiveEnergy, .reactivePower, .illuminance, .irradiance, .pressure, .signal, .voltage, .current, .uptime, .generic:
            return false
        }
    }

    var formattedValue: String {
        guard let unitText, !unitText.isEmpty else { return valueText }

        let separator = unitNeedsLeadingSpace(unitText) ? " " : ""
        return "\(valueText)\(separator)\(unitText)"
    }

    var valueText: String {
        switch value {
        case "unknown":
            return "Unknown"
        case "unavailable":
            return "Unavailable"
        default:
            break
        }

        return formattedNumber ?? value.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var unitText: String? {
        guard isAvailable else { return nil }
        return displayUnit
    }

    var formattedDeviceClass: String? {
        guard let deviceClass, !deviceClass.isEmpty else { return nil }
        return deviceClass.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var displayKind: SensorDisplayKind {
        SensorDisplayKind(deviceClass: deviceClass)
    }

    var displaySubtitle: String {
        guard isAvailable else { return "Sensor unavailable" }

        if isAlerting {
            return alertSubtitle
        }

        switch displayKind {
        case .water, .moisture, .gas, .carbonMonoxide, .problem:
            return "Clear"
        case .battery where numericValue != nil:
            return "Battery"
        case .airQuality, .area, .carbonDioxide, .conductivity, .data, .date, .distance, .duration, .enum, .frequency, .monetary, .particulateMatter, .pH, .precipitation, .speed, .soundPressure, .volatileOrganicCompounds, .volume, .volumeFlowRate, .weight, .windDirection, .temperature, .temperatureDelta, .humidity, .energy, .energyDistance, .energyStorage, .power, .powerFactor, .reactiveEnergy, .reactivePower, .illuminance, .irradiance, .pressure, .signal, .voltage, .current, .uptime, .battery, .generic:
            break
        }

        return formattedDeviceClass ?? "Sensor"
    }

    var numericValue: Double? {
        Double(value)
    }

    var gaugePresentation: GaugePresentation? {
        GaugePresentation(sensor: self)
    }

    var historyChartInterpolationStyle: HomesteadChartInterpolationStyle {
        if stateClass == .total || stateClass == .totalIncreasing {
            return .linear
        }

        return switch displayKind {
        case .battery, .data, .date, .duration, .enum, .energy, .energyDistance,
             .energyStorage, .gas, .monetary, .powerFactor, .precipitation,
             .reactiveEnergy, .signal, .uptime, .water, .generic:
            .linear
        case .airQuality, .area, .carbonDioxide, .carbonMonoxide, .conductivity,
             .distance, .frequency, .humidity, .illuminance, .irradiance, .moisture,
             .pH, .particulateMatter, .power, .pressure, .problem, .reactivePower,
             .soundPressure, .speed, .temperature, .temperatureDelta, .current,
             .voltage, .volatileOrganicCompounds, .volume, .volumeFlowRate, .weight,
             .windDirection:
            .smooth
        }
    }

    private var formattedNumber: String? {
        guard let number = numericValue else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0

        return formatter.string(from: NSNumber(value: number))
    }

    private var displayUnit: String? {
        switch (deviceClass, unit) {
        case ("temperature", "F"):
            "°F"
        case ("temperature", "C"):
            "°C"
        default:
            unit
        }
    }

    var resolvedDisplayPrecision: Int {
        maximumFractionDigits
    }

    private var maximumFractionDigits: Int {
        if let displayPrecision {
            return max(displayPrecision, 0)
        }
        return switch deviceClass {
        case "humidity", "battery", "illuminance", "signal_strength":
            0
        case "temperature":
            1
        case "energy", "energy_distance", "energy_storage", "power", "apparent_power", "reactive_power", "reactive_energy", "gas", "water", "moisture", "carbon_dioxide", "carbon_monoxide", "nitrogen_dioxide", "nitrogen_monoxide", "nitrous_oxide", "ozone", "pm1", "pm10", "pm25", "pm4", "sulphur_dioxide", "volatile_organic_compounds", "volatile_organic_compounds_parts":
            2
        default:
            1
        }
    }

    private func unitNeedsLeadingSpace(_ unit: String) -> Bool {
        !unit.hasPrefix("°") && unit != "%"
    }

    private var normalizedState: String {
        value.lowercased()
    }

    private var alertSubtitle: String {
        switch displayKind {
        case .battery:
            "Low Battery"
        case .water, .moisture:
            "Water Detected"
        case .gas:
            "Gas Detected"
        case .carbonMonoxide:
            "CO Detected"
        case .problem:
            "Problem Detected"
        case .airQuality, .area, .carbonDioxide, .conductivity, .data, .date, .distance, .duration, .enum, .frequency, .monetary, .particulateMatter, .pH, .precipitation, .speed, .soundPressure, .volatileOrganicCompounds, .volume, .volumeFlowRate, .weight, .windDirection, .temperature, .temperatureDelta, .humidity, .energy, .energyDistance, .energyStorage, .power, .powerFactor, .reactiveEnergy, .reactivePower, .illuminance, .irradiance, .pressure, .signal, .voltage, .current, .uptime, .generic:
            formattedDeviceClass ?? "Sensor"
        }
    }
}

nonisolated enum SensorStateClass: String, Codable, Equatable, Sendable {
    case measurement
    case total
    case totalIncreasing = "total_increasing"
}

struct BinarySensorEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let state: String
    let deviceClass: String?
    let lastUpdated: Date?

    var id: String { entityID }

    var isAvailable: Bool {
        !["unknown", "unavailable"].contains(state)
    }

    var isActive: Bool {
        state == "on"
    }

    var displayKind: BinarySensorDisplayKind {
        BinarySensorDisplayKind(deviceClass: deviceClass)
    }

    var displaySubtitle: String {
        guard isAvailable else { return "Sensor unavailable" }

        switch displayKind {
        case .door, .window, .garageDoor, .opening:
            return isActive ? "Open" : "Closed"
        case .lock:
            return isActive ? "Unlocked" : "Locked"
        case .moisture:
            return isActive ? "Wet" : "Dry"
        case .battery:
            return isActive ? "Low Battery" : "Battery OK"
        case .batteryCharging:
            return isActive ? "Charging" : "Not Charging"
        case .cold:
            return isActive ? "Cold" : "Normal"
        case .carbonMonoxide:
            return isActive ? "CO Detected" : "Clear"
        case .heat:
            return isActive ? "Heat Detected" : "Clear"
        case .moving:
            return isActive ? "Moving" : "Stationary"
        case .running:
            return isActive ? "Running" : "Stopped"
        case .sound:
            return isActive ? "Sound Detected" : "Clear"
        case .update:
            return isActive ? "Update Available" : "Up to Date"
        case .vibration:
            return isActive ? "Vibration Detected" : "Clear"
        case .motion, .occupancy, .presence, .tamper, .safety, .problem, .smoke, .gas:
            return isActive ? "Detected" : "Clear"
        case .connectivity:
            return isActive ? "Connected" : "Disconnected"
        case .plug, .power:
            return isActive ? "On" : "Off"
        case .light:
            return isActive ? "Light" : "Clear"
        case .generic:
            return isActive ? "Detected" : "Clear"
        }
    }

    var isSecurityRelevant: Bool {
        switch displayKind {
        case .door, .window, .garageDoor, .opening, .lock, .motion, .occupancy, .presence, .tamper, .safety, .problem, .smoke, .gas, .carbonMonoxide, .heat, .moisture, .vibration:
            return true
        case .battery, .batteryCharging, .cold, .moving, .running, .sound, .update, .connectivity, .plug, .power, .light, .generic:
            return false
        }
    }

    var isEntryPoint: Bool {
        switch displayKind {
        case .door, .window, .garageDoor, .opening:
            return true
        case .lock, .motion, .occupancy, .presence, .tamper, .safety, .problem, .smoke, .gas, .carbonMonoxide, .heat, .moisture, .vibration, .battery, .batteryCharging, .cold, .moving, .running, .sound, .update, .connectivity, .plug, .power, .light, .generic:
            return false
        }
    }
}

nonisolated enum BinarySensorDisplayKind: Equatable, Sendable {
    case door
    case window
    case garageDoor
    case opening
    case lock
    case motion
    case occupancy
    case presence
    case tamper
    case safety
    case problem
    case smoke
    case gas
    case carbonMonoxide
    case moisture
    case battery
    case batteryCharging
    case cold
    case heat
    case moving
    case running
    case sound
    case update
    case vibration
    case connectivity
    case plug
    case power
    case light
    case generic

    init(deviceClass: String?) {
        switch deviceClass {
        case "door":
            self = .door
        case "window":
            self = .window
        case "garage_door":
            self = .garageDoor
        case "opening":
            self = .opening
        case "lock":
            self = .lock
        case "motion":
            self = .motion
        case "occupancy":
            self = .occupancy
        case "presence":
            self = .presence
        case "tamper":
            self = .tamper
        case "safety":
            self = .safety
        case "problem":
            self = .problem
        case "smoke":
            self = .smoke
        case "gas":
            self = .gas
        case "carbon_monoxide":
            self = .carbonMonoxide
        case "moisture":
            self = .moisture
        case "battery":
            self = .battery
        case "battery_charging":
            self = .batteryCharging
        case "cold":
            self = .cold
        case "heat":
            self = .heat
        case "moving":
            self = .moving
        case "running":
            self = .running
        case "sound":
            self = .sound
        case "update":
            self = .update
        case "vibration":
            self = .vibration
        case "connectivity":
            self = .connectivity
        case "plug":
            self = .plug
        case "power":
            self = .power
        case "light":
            self = .light
        default:
            self = .generic
        }
    }
}

nonisolated enum SensorDisplayKind: Equatable, Sendable {
    case airQuality
    case area
    case temperature
    case temperatureDelta
    case humidity
    case battery
    case carbonDioxide
    case carbonMonoxide
    case conductivity
    case data
    case date
    case distance
    case duration
    case `enum`
    case energy
    case energyDistance
    case energyStorage
    case frequency
    case monetary
    case power
    case powerFactor
    case reactiveEnergy
    case reactivePower
    case illuminance
    case irradiance
    case moisture
    case particulateMatter
    case pH
    case precipitation
    case pressure
    case signal
    case soundPressure
    case speed
    case voltage
    case current
    case volatileOrganicCompounds
    case volume
    case volumeFlowRate
    case weight
    case windDirection
    case water
    case gas
    case problem
    case uptime
    case generic

    init(deviceClass: String?) {
        switch deviceClass {
        case "aqi":
            self = .airQuality
        case "area":
            self = .area
        case "temperature":
            self = .temperature
        case "temperature_delta":
            self = .temperatureDelta
        case "humidity", "absolute_humidity":
            self = .humidity
        case "battery":
            self = .battery
        case "carbon_dioxide":
            self = .carbonDioxide
        case "carbon_monoxide":
            self = .carbonMonoxide
        case "nitrogen_dioxide", "nitrogen_monoxide", "nitrous_oxide", "ozone", "sulphur_dioxide":
            self = .airQuality
        case "conductivity":
            self = .conductivity
        case "data_size", "data_rate", "volume_storage":
            self = .data
        case "date", "timestamp":
            self = .date
        case "uptime":
            self = .uptime
        case "distance":
            self = .distance
        case "duration":
            self = .duration
        case "enum":
            self = .enum
        case "energy":
            self = .energy
        case "energy_distance":
            self = .energyDistance
        case "energy_storage":
            self = .energyStorage
        case "frequency":
            self = .frequency
        case "monetary":
            self = .monetary
        case "power", "apparent_power":
            self = .power
        case "power_factor":
            self = .powerFactor
        case "reactive_energy":
            self = .reactiveEnergy
        case "reactive_power":
            self = .reactivePower
        case "illuminance":
            self = .illuminance
        case "irradiance":
            self = .irradiance
        case "moisture":
            self = .moisture
        case "pm1", "pm10", "pm25", "pm4":
            self = .particulateMatter
        case "ph":
            self = .pH
        case "precipitation", "precipitation_intensity":
            self = .precipitation
        case "pressure", "atmospheric_pressure":
            self = .pressure
        case "signal_strength":
            self = .signal
        case "sound_pressure":
            self = .soundPressure
        case "speed":
            self = .speed
        case "voltage":
            self = .voltage
        case "current":
            self = .current
        case "volatile_organic_compounds", "volatile_organic_compounds_parts":
            self = .volatileOrganicCompounds
        case "volume":
            self = .volume
        case "volume_flow_rate":
            self = .volumeFlowRate
        case "weight":
            self = .weight
        case "wind_direction":
            self = .windDirection
        case "wind_speed":
            self = .speed
        case "water":
            self = .water
        case "gas":
            self = .gas
        case "problem":
            self = .problem
        default:
            self = .generic
        }
    }
}
