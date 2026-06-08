import Foundation

nonisolated enum NativeCapabilityAuthorizationStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case allowed
    case limited
    case denied
    case restricted
    case unavailable
    case managedBySystem

    var canRequestInApp: Bool {
        self == .notDetermined
    }

    var isAllowed: Bool {
        switch self {
        case .allowed, .limited:
            return true
        case .unknown, .notDetermined, .denied, .restricted, .unavailable, .managedBySystem:
            return false
        }
    }
}

nonisolated struct NativePermissionStatusSnapshot: Equatable, Sendable {
    let camera: NativeCapabilityAuthorizationStatus
    let location: NativeCapabilityAuthorizationStatus
    let localNetwork: NativeCapabilityAuthorizationStatus

    static let unknown = NativePermissionStatusSnapshot(
        camera: .unknown,
        location: .unknown,
        localNetwork: .managedBySystem
    )
}
