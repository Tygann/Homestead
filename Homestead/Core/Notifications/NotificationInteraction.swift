import Foundation
import UserNotifications

nonisolated struct NotificationInteraction: Identifiable, Equatable, Sendable {
    let id: UUID
    let profileID: UUID?
    let webhookID: String?
    let url: String?
    let entityID: String?
    var action: NotificationActionDefinition?
    let reply: String?
    let actionData: JSONValue?

    init?(userInfo: [AnyHashable: Any], actionIdentifier: String, reply: String? = nil) {
        guard actionIdentifier != UNNotificationDismissActionIdentifier else { return nil }
        id = UUID()
        profileID = NotificationPayload.profileID(userInfo)
        webhookID = userInfo["webhook_id"] as? String
        let data = NotificationPayload.data(userInfo)
        entityID = data["entity_id"] as? String
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            action = nil
            url = data["url"] as? String
        } else {
            guard let definition = NotificationPayload.actions(userInfo).first(where: { $0.identifier == actionIdentifier }) else { return nil }
            action = definition
            url = definition.uri
        }
        self.reply = reply
        if let value = data["action_data"], JSONSerialization.isValidJSONObject(["value": value]),
           let encoded = try? JSONSerialization.data(withJSONObject: ["value": value]),
           let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: encoded) {
            actionData = decoded["value"]
        } else { actionData = nil }
    }
}
