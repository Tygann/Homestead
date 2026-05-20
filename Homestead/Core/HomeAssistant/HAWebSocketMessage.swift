import Foundation

enum HAWebSocketMessageType {
    nonisolated static var auth: String { "auth" }
    nonisolated static var authRequired: String { "auth_required" }
    nonisolated static var authOK: String { "auth_ok" }
    nonisolated static var authInvalid: String { "auth_invalid" }
    nonisolated static var result: String { "result" }
    nonisolated static var event: String { "event" }
    nonisolated static var getStates: String { "get_states" }
    nonisolated static var subscribeEvents: String { "subscribe_events" }
    nonisolated static var callService: String { "call_service" }
}

struct HAWebSocketIncomingMessage: Decodable, Sendable {
    let id: Int?
    let type: String
    let success: Bool?
    let result: JSONValue?
    let event: HAEventDTO?
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
        event = try container.decodeIfPresent(HAEventDTO.self, forKey: .event)
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

enum HAWebSocketRequest: Encodable, Sendable {
    case auth(accessToken: String)
    case getStates(id: Int)
    case subscribeEvents(id: Int, eventType: String)
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
        case domain
        case service
        case target
        case serviceData = "service_data"
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
