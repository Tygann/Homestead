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

    nonisolated init(
        message: String,
        title: String?,
        hassConfirmID: String?,
        data: JSONValue?
    ) {
        self.message = message
        self.title = title
        self.hassConfirmID = hassConfirmID
        self.data = data
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let payloadData = try container.decodeIfPresent(JSONValue.self, forKey: .data)

        if let message = try container.decodeIfPresent(String.self, forKey: .message) {
            self.message = message
            title = try container.decodeIfPresent(String.self, forKey: .title)
            hassConfirmID = try container.decodeIfPresent(String.self, forKey: .hassConfirmID)
            data = payloadData
            return
        }

        guard let nestedPayload = payloadData?.objectValue,
              let message = nestedPayload["message"]?.stringValue else {
            throw DecodingError.keyNotFound(
                CodingKeys.message,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Expected a Home Assistant mobile-app notification message."
                )
            )
        }

        self.message = message
        title = (try container.decodeIfPresent(String.self, forKey: .title)) ??
            nestedPayload["title"]?.stringValue
        hassConfirmID = (try container.decodeIfPresent(String.self, forKey: .hassConfirmID)) ??
            nestedPayload["hass_confirm_id"]?.stringValue
        data = nestedPayload["data"] ?? payloadData
    }

    func notificationRequest(profileID: UUID?) -> NativeNotificationRequest {
        NativeNotificationRequest(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Home Assistant",
            body: message,
            userInfo: [
                "source": "home_assistant",
                "hass_confirm_id": hassConfirmID,
                "profile_id": profileID?.uuidString,
                "entity_id": data?.objectValue?["entity_id"]?.stringValue
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
