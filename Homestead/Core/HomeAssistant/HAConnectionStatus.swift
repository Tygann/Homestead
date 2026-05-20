import Foundation

enum HAConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case reconnecting
    case connected
    case failed(String)

    var title: String {
        switch self {
        case .disconnected:
            "Disconnected"
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
