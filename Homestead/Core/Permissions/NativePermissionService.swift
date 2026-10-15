import Foundation
import Observation

#if canImport(CoreLocation)
import CoreLocation
#endif

@MainActor
protocol NativePermissionClient {
    func currentStatus() async throws -> NativePermissionStatusSnapshot
    func requestLocationAccess() async throws -> NativeCapabilityAuthorizationStatus
}

struct SystemNativePermissionClient: NativePermissionClient {
    func currentStatus() async throws -> NativePermissionStatusSnapshot {
        NativePermissionStatusSnapshot(
            location: Self.locationStatus(),
            localNetwork: .managedBySystem
        )
    }

    func requestLocationAccess() async throws -> NativeCapabilityAuthorizationStatus {
        #if canImport(CoreLocation)
        guard CLLocationManager.locationServicesEnabled() else {
            return .unavailable
        }

        guard Self.currentLocationAuthorizationStatus() == .notDetermined else {
            return Self.locationStatus()
        }

        return await LocationPermissionRequester().requestWhenInUseAuthorization()
        #else
        return .unavailable
        #endif
    }

    private static func locationStatus() -> NativeCapabilityAuthorizationStatus {
        #if canImport(CoreLocation)
        guard CLLocationManager.locationServicesEnabled() else {
            return .unavailable
        }

        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return manager.accuracyAuthorization == .reducedAccuracy ? .limited : .allowed
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
        #else
        return .unavailable
        #endif
    }
}

@MainActor
@Observable
final class NativePermissionService {
    private(set) var status: NativePermissionStatusSnapshot = .unknown
    private(set) var isRefreshing = false
    private(set) var isRequestingLocationAccess = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let client: any NativePermissionClient

    convenience init() {
        self.init(client: SystemNativePermissionClient())
    }

    init(client: any NativePermissionClient) {
        self.client = client
    }

    func refreshStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            status = try await client.currentStatus()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func requestLocationAccess() async {
        isRequestingLocationAccess = true
        defer { isRequestingLocationAccess = false }

        do {
            let location = try await client.requestLocationAccess()
            let current = try await client.currentStatus()
            status = NativePermissionStatusSnapshot(
                location: location,
                localNetwork: current.localNetwork
            )
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

#if canImport(CoreLocation)
@MainActor
private final class LocationPermissionRequester: NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<NativeCapabilityAuthorizationStatus, Never>?

    func requestWhenInUseAuthorization() async -> NativeCapabilityAuthorizationStatus {
        await withCheckedContinuation { continuation in
            let manager = CLLocationManager()
            self.manager = manager
            self.continuation = continuation
            manager.delegate = self
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        finish(with: SystemNativePermissionClient.locationStatusForRequester())
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        finish(with: SystemNativePermissionClient.locationStatusForRequester())
    }

    private func finish(with status: NativeCapabilityAuthorizationStatus) {
        guard let continuation else {
            return
        }

        self.continuation = nil
        manager?.delegate = nil
        manager = nil
        continuation.resume(returning: status)
    }
}

private extension SystemNativePermissionClient {
    static func locationStatusForRequester() -> NativeCapabilityAuthorizationStatus {
        locationStatus()
    }

    static func currentLocationAuthorizationStatus() -> CLAuthorizationStatus {
        CLLocationManager().authorizationStatus
    }
}
#endif
