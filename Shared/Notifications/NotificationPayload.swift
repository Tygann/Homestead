import Foundation
import UserNotifications

nonisolated struct NotificationActionDefinition: Equatable, Sendable {
    let identifier: String
    let title: String
    let textInput: Bool
    let authenticationRequired: Bool
    let destructive: Bool
    let foreground: Bool
    let uri: String?
    let inputTitle: String
    let inputPlaceholder: String

    init?(object: [String: Any]) {
        guard let identifier = object["action"] as? String, !identifier.isEmpty,
              let title = object["title"] as? String, !title.isEmpty else { return nil }
        self.identifier = identifier
        self.title = title
        textInput = object["behavior"] as? String == "textInput" || identifier == "REPLY"
        authenticationRequired = object["authenticationRequired"] as? Bool == true
        destructive = object["destructive"] as? Bool == true
        uri = object["uri"] as? String
        foreground = object["activationMode"] as? String == "foreground" || identifier == "URI"
        inputTitle = object["textInputButtonTitle"] as? String ?? "Send"
        inputPlaceholder = object["textInputPlaceholder"] as? String ?? ""
    }

    var nativeAction: UNNotificationAction {
        var options: UNNotificationActionOptions = []
        if authenticationRequired { options.insert(.authenticationRequired) }
        if destructive { options.insert(.destructive) }
        if foreground { options.insert(.foreground) }
        if textInput {
            return UNTextInputNotificationAction(identifier: identifier, title: title, options: options,
                textInputButtonTitle: inputTitle, textInputPlaceholder: inputPlaceholder)
        }
        return UNNotificationAction(identifier: identifier, title: title, options: options)
    }
}

nonisolated enum NotificationPayload {
    static func data(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
        userInfo["data"] as? [String: Any] ?? userInfo as? [String: Any] ?? [:]
    }

    static func actions(_ userInfo: [AnyHashable: Any]) -> [NotificationActionDefinition] {
        var seen = Set<String>()
        return (data(userInfo)["actions"] as? [[String: Any]] ?? []).prefix(10).compactMap {
            guard let action = NotificationActionDefinition(object: $0), seen.insert(action.identifier).inserted,
                  ![UNNotificationDefaultActionIdentifier, UNNotificationDismissActionIdentifier].contains(action.identifier) else { return nil }
            return action
        }
    }

    /// The relay stamps this outside user data; never infer an origin from the active server.
    static func profileID(_ userInfo: [AnyHashable: Any]) -> UUID? {
        (userInfo["homestead_profile_id"] as? String).flatMap(UUID.init(uuidString:))
            ?? (userInfo["profile_id"] as? String).flatMap(UUID.init(uuidString:))
    }


}

nonisolated enum NotificationLinkDestination: Equatable {
    case entity(String)
    case web(URL)

    static func resolve(_ value: String, baseURL: String) -> Self? {
        if value.hasPrefix("entityId:") {
            let id = String(value.dropFirst("entityId:".count))
            return validEntityID(id) ? .entity(id) : nil
        }
        guard !value.hasPrefix("//"), !value.contains("\\"),
              let base = URL(string: baseURL),
              let url = URL(string: value, relativeTo: base)?.absoluteURL,
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil, url.user == nil, url.password == nil else { return nil }
        if url.host == base.host, url.scheme == base.scheme, url.port == base.port,
           let fragment = url.fragment, fragment.hasPrefix("more-info=") {
            let id = String(fragment.dropFirst("more-info=".count))
            if validEntityID(id) { return .entity(id) }
        }
        return .web(url)
    }

    private static func validEntityID(_ value: String) -> Bool {
        value.range(of: "^[a-z_]+\\.[a-z0-9_]+$", options: .regularExpression) != nil
    }
}
