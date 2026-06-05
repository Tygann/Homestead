import Foundation

nonisolated enum NativeNotificationAuthorizationStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var isAllowed: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .unknown, .notDetermined, .denied:
            return false
        }
    }

    var canRequestInApp: Bool {
        self == .notDetermined
    }
}

nonisolated enum NativeNotificationDeliverySetting: Equatable, Sendable {
    case unknown
    case unavailable
    case disabled
    case enabled
}

nonisolated struct NativeNotificationStatusSnapshot: Equatable, Sendable {
    let authorizationStatus: NativeNotificationAuthorizationStatus
    let alertSetting: NativeNotificationDeliverySetting
    let soundSetting: NativeNotificationDeliverySetting
    let badgeSetting: NativeNotificationDeliverySetting

    static let unknown = NativeNotificationStatusSnapshot(
        authorizationStatus: .unknown,
        alertSetting: .unknown,
        soundSetting: .unknown,
        badgeSetting: .unknown
    )
}

nonisolated struct NativeNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let userInfo: [String: String]

    init(
        identifier: String = UUID().uuidString,
        title: String,
        body: String,
        userInfo: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.userInfo = userInfo
    }
}
