import Foundation
import Observation
import UserNotifications

@MainActor
protocol NativeNotificationPermissionClient {
    func currentStatus() async throws -> NativeNotificationStatusSnapshot
    func requestAuthorization() async throws -> Bool
}

struct UNUserNotificationPermissionClient: NativeNotificationPermissionClient {
    func currentStatus() async throws -> NativeNotificationStatusSnapshot {
        await UNUserNotificationCenter.current().notificationSettings().nativeSnapshot
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
}

@MainActor
@Observable
final class NativeNotificationService {
    private(set) var status: NativeNotificationStatusSnapshot = .unknown
    private(set) var isRefreshing = false
    private(set) var isRequestingAuthorization = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let client: any NativeNotificationPermissionClient

    convenience init() {
        self.init(client: UNUserNotificationPermissionClient())
    }

    init(client: any NativeNotificationPermissionClient) {
        self.client = client
    }

    func refreshAuthorizationStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            status = try await client.currentStatus()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func requestAuthorization() async {
        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        do {
            _ = try await client.requestAuthorization()
            status = try await client.currentStatus()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

private extension UNNotificationSettings {
    var nativeSnapshot: NativeNotificationStatusSnapshot {
        NativeNotificationStatusSnapshot(
            authorizationStatus: authorizationStatus.nativeStatus,
            alertSetting: alertSetting.nativeSetting,
            soundSetting: soundSetting.nativeSetting,
            badgeSetting: badgeSetting.nativeSetting
        )
    }
}

private extension UNAuthorizationStatus {
    var nativeStatus: NativeNotificationAuthorizationStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }
}

private extension UNNotificationSetting {
    var nativeSetting: NativeNotificationDeliverySetting {
        switch self {
        case .notSupported:
            return .unavailable
        case .disabled:
            return .disabled
        case .enabled:
            return .enabled
        @unknown default:
            return .unknown
        }
    }
}
