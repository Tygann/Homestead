import Foundation

enum HAWebSocketMessageType {
    nonisolated static var auth: String { "auth" }
    nonisolated static var authRequired: String { "auth_required" }
    nonisolated static var authOK: String { "auth_ok" }
    nonisolated static var authInvalid: String { "auth_invalid" }
    nonisolated static var result: String { "result" }
    nonisolated static var event: String { "event" }
    nonisolated static var pong: String { "pong" }
    nonisolated static var getStates: String { "get_states" }
    nonisolated static var subscribeEvents: String { "subscribe_events" }
    nonisolated static var unsubscribeEvents: String { "unsubscribe_events" }
    nonisolated static var ping: String { "ping" }
    nonisolated static var callService: String { "call_service" }
    nonisolated static var getConfig: String { "get_config" }
    nonisolated static var getServices: String { "get_services" }
    nonisolated static var mobileAppPushNotificationChannel: String { "mobile_app/push_notification_channel" }
    nonisolated static var mobileAppPushNotificationConfirm: String { "mobile_app/push_notification_confirm" }
    nonisolated static var currentUser: String { "auth/current_user" }
    nonisolated static var entityRegistryListForDisplay: String { "config/entity_registry/list_for_display" }
    nonisolated static var entityRegistryList: String { "config/entity_registry/list" }
    nonisolated static var deviceRegistryList: String { "config/device_registry/list" }
    nonisolated static var areaRegistryList: String { "config/area_registry/list" }
    nonisolated static var floorRegistryList: String { "config/floor_registry/list" }
    nonisolated static var labelRegistryList: String { "config/label_registry/list" }
    nonisolated static var categoryRegistryList: String { "config/category_registry/list" }
    nonisolated static var cameraCapabilities: String { "camera/capabilities" }
    nonisolated static var supervisorAPI: String { "supervisor/api" }
}

struct HAWebSocketIncomingMessage: Decodable, Sendable {
    let id: Int?
    let type: String
    let success: Bool?
    let result: JSONValue?
    let event: HAEventDTO?
    let mobileAppPushNotificationEvent: HAMobileAppPushNotificationEventDTO?
    let error: HAWebSocketErrorDTO?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case success
        case result
        case event
        case error
        case message
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        result = try container.decodeIfPresent(JSONValue.self, forKey: .result)
        let eventValue = try container.decodeIfPresent(JSONValue.self, forKey: .event)
        event = try? eventValue?.decoded(HAEventDTO.self)
        mobileAppPushNotificationEvent = try? eventValue?.decoded(HAMobileAppPushNotificationEventDTO.self)
        error = try container.decodeIfPresent(HAWebSocketErrorDTO.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

struct HAWebSocketErrorDTO: Decodable, Sendable {
    let code: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

nonisolated struct HACurrentUserDTO: Decodable, Equatable, Sendable {
    let id: String
    let name: String?
    let isOwner: Bool?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isOwner = "is_owner"
        case isAdmin = "is_admin"
    }
}

enum HAWebSocketRequest: Encodable, Sendable {
    case auth(accessToken: String)
    case getStates(id: Int)
    case subscribeEvents(id: Int, eventType: String)
    case unsubscribeEvents(id: Int, subscription: Int)
    case ping(id: Int)
    case currentUser(id: Int)
    case getConfig(id: Int)
    case getServices(id: Int)
    case mobileAppPushNotificationChannel(id: Int, webhookID: String, supportConfirm: Bool)
    case mobileAppPushNotificationConfirm(id: Int, webhookID: String, confirmID: String)
    case registryCommand(id: Int, type: String)
    case categoryRegistryList(id: Int, scope: HAOrganizationScope)
    case cameraCapabilities(id: Int, entityID: String)
    case supervisorAPI(id: Int, endpoint: String, method: String)
    case callService(
        id: Int,
        domain: String,
        service: String,
        target: [String: JSONValue]?,
        serviceData: [String: JSONValue]?
    )

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case accessToken = "access_token"
        case eventType = "event_type"
        case subscription
        case domain
        case service
        case target
        case serviceData = "service_data"
        case entityID = "entity_id"
        case webhookID = "webhook_id"
        case supportConfirm = "support_confirm"
        case confirmID = "confirm_id"
        case endpoint
        case method
        case scope
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .auth(let accessToken):
            try container.encode(HAWebSocketMessageType.auth, forKey: .type)
            try container.encode(accessToken, forKey: .accessToken)
        case .getStates(let id):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.getStates, forKey: .type)
        case .subscribeEvents(let id, let eventType):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.subscribeEvents, forKey: .type)
            try container.encode(eventType, forKey: .eventType)
        case .unsubscribeEvents(let id, let subscription):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.unsubscribeEvents, forKey: .type)
            try container.encode(subscription, forKey: .subscription)
        case .ping(let id):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.ping, forKey: .type)
        case .currentUser(let id):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.currentUser, forKey: .type)
        case .getConfig(let id):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.getConfig, forKey: .type)
        case .getServices(let id):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.getServices, forKey: .type)
        case .mobileAppPushNotificationChannel(let id, let webhookID, let supportConfirm):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.mobileAppPushNotificationChannel, forKey: .type)
            try container.encode(webhookID, forKey: .webhookID)
            try container.encode(supportConfirm, forKey: .supportConfirm)
        case .mobileAppPushNotificationConfirm(let id, let webhookID, let confirmID):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.mobileAppPushNotificationConfirm, forKey: .type)
            try container.encode(webhookID, forKey: .webhookID)
            try container.encode(confirmID, forKey: .confirmID)
        case .registryCommand(let id, let type):
            try container.encode(id, forKey: .id)
            try container.encode(type, forKey: .type)
        case .categoryRegistryList(let id, let scope):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.categoryRegistryList, forKey: .type)
            try container.encode(scope.rawValue, forKey: .scope)
        case .cameraCapabilities(let id, let entityID):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.cameraCapabilities, forKey: .type)
            try container.encode(entityID, forKey: .entityID)
        case .supervisorAPI(let id, let endpoint, let method):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.supervisorAPI, forKey: .type)
            try container.encode(endpoint, forKey: .endpoint)
            try container.encode(method, forKey: .method)
        case .callService(let id, let domain, let service, let target, let serviceData):
            try container.encode(id, forKey: .id)
            try container.encode(HAWebSocketMessageType.callService, forKey: .type)
            try container.encode(domain, forKey: .domain)
            try container.encode(service, forKey: .service)
            try container.encodeIfPresent(target, forKey: .target)
            try container.encodeIfPresent(serviceData, forKey: .serviceData)
        }
    }
}
