import Foundation

enum HAConnectionStatus: Equatable, Sendable {
    case disconnected
    case preparing
    case connecting
    case reconnecting
    case connected
    case failed(String)

    var title: String {
        switch self {
        case .disconnected:
            "Disconnected"
        case .preparing:
            "Connecting"
        case .connecting:
            "Connecting"
        case .reconnecting:
            "Reconnecting"
        case .connected:
            "Connected"
        case .failed:
            "Connection Failed"
        }
    }

    var systemImage: String {
        switch self {
        case .disconnected:
            "wifi.slash"
        case .preparing:
            "arrow.triangle.2.circlepath"
        case .connecting:
            "arrow.triangle.2.circlepath"
        case .reconnecting:
            "arrow.triangle.2.circlepath"
        case .connected:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }
}
