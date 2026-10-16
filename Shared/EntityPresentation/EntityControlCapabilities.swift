import Foundation

/// Entity features and usable state are mandatory; the service catalog is an additional gate.
nonisolated enum EntityControlCapabilities {
    static func allows(domain: String, service: String, state: String, features: Int,
                       attributes: [String: Any], serviceAvailable: Bool) -> Bool {
        guard serviceAvailable, !state.isEmpty, !["unavailable", "unknown"].contains(state) else { return false }
        func has(_ bit: Int) -> Bool { features & bit != 0 }
        func number(_ key: String) -> Bool {
            guard let value = attributes[key] as? NSNumber else { return false }
            return value.doubleValue.isFinite
        }
        func options(_ key: String) -> Bool { !(attributes[key] as? [String] ?? []).isEmpty }
        switch (domain, service) {
        case ("cover", "open_cover"): return has(1)
        case ("cover", "close_cover"): return has(2)
        case ("cover", "set_cover_position"): return has(4) && number("current_position")
        case ("cover", "stop_cover"): return has(8)
        case ("cover", "toggle"): return has(1) && has(2)
        case ("cover", "open_cover_tilt"): return has(16)
        case ("cover", "close_cover_tilt"): return has(32)
        case ("cover", "stop_cover_tilt"): return has(64)
        case ("cover", "toggle_cover_tilt"): return has(16) && has(32)
        case ("cover", "set_cover_tilt_position"): return has(128) && number("current_tilt_position")
        case ("fan", "turn_on"): return has(32)
        case ("fan", "turn_off"): return has(16)
        case ("fan", "toggle"): return state == "on" ? has(16) : has(32)
        case ("fan", "set_percentage"), ("fan", "increase_speed"), ("fan", "decrease_speed"):
            return has(1) && number("percentage")
        case ("fan", "oscillate"): return has(2) && attributes["oscillating"] is Bool
        case ("fan", "set_direction"): return has(4) && attributes["direction"] is String
        case ("fan", "set_preset_mode"): return has(8) && options("preset_modes")
        case ("climate", "set_temperature"):
            return state == "heat_cool"
                ? has(2) && number("target_temp_low") && number("target_temp_high")
                : has(1) && number("temperature")
        case ("climate", "set_hvac_mode"): return options("hvac_modes") // No feature bit exists.
        case ("climate", "set_fan_mode"): return has(8) && options("fan_modes")
        case ("climate", "set_preset_mode"): return has(16) && options("preset_modes")
        case ("climate", "turn_on"): return has(256)
        case ("climate", "turn_off"): return has(128)
        case ("climate", "toggle"): return state == "off" ? has(256) : has(128)
        case ("climate", "set_humidity"): return has(4) && number("humidity")
        case ("climate", "set_swing_mode"): return has(32) && options("swing_modes")
        case ("climate", "set_swing_horizontal_mode"): return has(512) && options("swing_horizontal_modes")
        case ("cover", _), ("fan", _), ("climate", _): return false
        default: return true
        }
    }
}
