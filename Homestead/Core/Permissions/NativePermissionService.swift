import Foundation
import Observation

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

@MainActor
protocol NativePermissionClient {
    func currentStatus() async throws -> NativePermissionStatusSnapshot
    func requestCameraAccess() async throws -> NativeCapabilityAuthorizationStatus
    func requestLocationAccess() async throws -> NativeCapabilityAuthorizationStatus
}

struct SystemNativePermissionClient: NativePermissionClient {
    func currentStatus() async throws -> NativePermissionStatusSnapshot {
        NativePermissionStatusSnapshot(
            camera: Self.cameraStatus(),
            location: Self.locationStatus(),
            localNetwork: .managedBySystem
        )
    }

    func requestCameraAccess() async throws -> NativeCapabilityAuthorizationStatus {
        #if canImport(AVFoundation)
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else {
            return Self.cameraStatus()
        }

        _ = await AVCaptureDevice.requestAccess(for: .video)
        return Self.cameraStatus()
        #else
        return .unavailable
        #endif
    }

    func requestLocationAccess() async throws -> NativeCapabilityAuthorizationStatus {
        #if canImport(CoreLocation)
        guard CLLocationManager.locationServicesEnabled() else {
            return .unavailable
        }

        guard CLLocationManager.authorizationStatus() == .notDetermined else {
            return Self.locationStatus()
        }

        return await LocationPermissionRequester().requestWhenInUseAuthorization()
        #else
        return .unavailable
        #endif
    }

    private static func cameraStatus() -> NativeCapabilityAuthorizationStatus {
        #if canImport(AVFoundation)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .allowed
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

    private static func locationStatus() -> NativeCapabilityAuthorizationStatus {
        #if canImport(CoreLocation)
        guard CLLocationManager.locationServicesEnabled() else {
            return .unavailable
        }

        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            return .allowed
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
    private(set) var isRequestingCameraAccess = false
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

    func requestCameraAccess() async {
        isRequestingCameraAccess = true
        defer { isRequestingCameraAccess = false }

        do {
            let camera = try await client.requestCameraAccess()
            let current = try await client.currentStatus()
            status = NativePermissionStatusSnapshot(
                camera: camera,
                location: current.location,
                localNetwork: current.localNetwork
            )
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
                camera: current.camera,
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
        finish(with: status.nativePermissionStatus)
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
        guard CLLocationManager.locationServicesEnabled() else {
            return .unavailable
        }

        return CLLocationManager.authorizationStatus().nativePermissionStatus
    }
}

private extension CLAuthorizationStatus {
    var nativePermissionStatus: NativeCapabilityAuthorizationStatus {
        switch self {
        case .authorizedAlways, .authorizedWhenInUse:
            return .allowed
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }
}
#endif
