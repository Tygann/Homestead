import Foundation

nonisolated struct HAMobileAppPushNotificationEventDTO: Decodable, Sendable {
    let message: String
    let title: String?
    let hassConfirmID: String?
    let data: JSONValue?

    enum CodingKeys: String, CodingKey {
        case message
        case title
        case hassConfirmID = "hass_confirm_id"
        case data
    }

    var notificationRequest: NativeNotificationRequest {
        NativeNotificationRequest(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Home Assistant",
            body: message,
            userInfo: [
                "source": "home_assistant",
                "hass_confirm_id": hassConfirmID
            ].compactMapValues { $0 }
        )
    }
}

nonisolated enum HAMobileAppPushNotificationState: Equatable, Sendable {
    case unavailable
    case subscribing
    case subscribed(Date)
    case failed(String)

    var isSubscribed: Bool {
        if case .subscribed = self {
            return true
        }
        return false
    }
}

private extension String {
    nonisolated var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
