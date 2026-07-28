import Foundation

nonisolated enum WidgetControlAction: String, Equatable, Sendable {
    case toggle
    case resolveCover = "resolve_cover"
    case lock
}

nonisolated enum WidgetControlActionResolver {
    static func action(
        domain: String,
        isConfigured: Bool,
        isAvailable: Bool,
        isActive: Bool
    ) -> WidgetControlAction? {
        guard isConfigured, isAvailable else { return nil }
        switch domain {
        case "light", "switch", "fan": return .toggle
        case "cover": return .resolveCover
        case "lock": return isActive ? nil : .lock
        default: return nil
        }
    }
}
