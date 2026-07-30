import Foundation
import Observation
import UserNotifications

@MainActor
protocol NativeNotificationPermissionClient {
    func currentStatus() async throws -> NativeNotificationStatusSnapshot
    func requestAuthorization() async throws -> Bool
    func presentNotification(_ request: NativeNotificationRequest) async throws
}

struct UNUserNotificationPermissionClient: NativeNotificationPermissionClient {
    func currentStatus() async throws -> NativeNotificationStatusSnapshot {
        await UNUserNotificationCenter.current().notificationSettings().nativeSnapshot
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func presentNotification(_ request: NativeNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = request.userInfo

        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: nil
        )
        try await UNUserNotificationCenter.current().add(notificationRequest)
    }
}

@MainActor
@Observable
final class NativeNotificationService {
    private(set) var status: NativeNotificationStatusSnapshot = .unknown
    private(set) var remoteRegistrationState: NativeRemoteNotificationRegistrationState = .notRegistered
    private(set) var isRefreshing = false
    private(set) var isRequestingAuthorization = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let client: any NativeNotificationPermissionClient
    @ObservationIgnored private let remoteRegistrationClient: any NativeRemoteNotificationRegistrationClient
    @ObservationIgnored private let pushRegistrationClient: any HomesteadPushTokenRegistrationClient
    @ObservationIgnored private let pushRelayTokenStore: any PushRelayTokenStore

    convenience init() {
        self.init(
            client: UNUserNotificationPermissionClient(),
            remoteRegistrationClient: UIApplicationRemoteNotificationRegistrationClient(),
            pushRegistrationClient: URLSessionHomesteadPushTokenRegistrationClient(),
            pushRelayTokenStore: KeychainPushRelayTokenStore()
        )
    }

    convenience init(client: any NativeNotificationPermissionClient) {
        self.init(
            client: client,
            remoteRegistrationClient: UIApplicationRemoteNotificationRegistrationClient(),
            pushRegistrationClient: URLSessionHomesteadPushTokenRegistrationClient(),
            pushRelayTokenStore: KeychainPushRelayTokenStore()
        )
    }

    init(
        client: any NativeNotificationPermissionClient,
        remoteRegistrationClient: any NativeRemoteNotificationRegistrationClient,
        pushRegistrationClient: any HomesteadPushTokenRegistrationClient,
        pushRelayTokenStore: any PushRelayTokenStore
    ) {
        self.client = client
        self.remoteRegistrationClient = remoteRegistrationClient
        self.pushRegistrationClient = pushRegistrationClient
        self.pushRelayTokenStore = pushRelayTokenStore
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
            await registerForRemoteNotificationsIfAllowed()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func registerForRemoteNotificationsIfAllowed() async {
        guard status.authorizationStatus.isAllowed else {
            return
        }

        switch remoteRegistrationState {
        case .registeringWithAPNS, .registeringWithBackend, .registered:
            return
        case .notRegistered, .failed:
            break
        }

        remoteRegistrationState = .registeringWithAPNS
        await remoteRegistrationClient.registerForRemoteNotifications()
    }

    func handleRemoteNotificationDeviceToken(_ deviceToken: Data) async {
        remoteRegistrationState = .registeringWithBackend

        do {
            let request = HomesteadPushTokenRegistrationRequest(
                pushRelayToken: try pushRelayTokenStore.readOrCreateRelayToken(),
                apnsToken: deviceToken.lowercaseHexString,
                environment: HomesteadPushEnvironment.current,
                deviceName: HomesteadPushDeviceInfo.name,
                appVersion: Bundle.main.homesteadShortVersionString
            )
            try await pushRegistrationClient.register(request)
            remoteRegistrationState = .registered(Date())
            lastErrorMessage = nil
            #if DEBUG
            print("Homestead push token registered with backend: apnsTokenReceived=true, relayTokenExists=true")
            #endif
        } catch {
            remoteRegistrationState = .failed(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
        }
    }

    func handleRemoteNotificationRegistrationFailure(_ error: Error) {
        let registrationError = HomesteadPushRegistrationError.remoteRegistrationFailed(error.localizedDescription)
        remoteRegistrationState = .failed(registrationError.localizedDescription)
        lastErrorMessage = registrationError.localizedDescription
    }

    func presentNotification(_ request: NativeNotificationRequest) async throws {
        try await client.presentNotification(request)
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
