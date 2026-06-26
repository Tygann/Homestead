import Foundation

nonisolated struct HAMobileAppWebhookRequestDTO<Payload: Encodable & Sendable>: Encodable, Sendable {
    let type: String
    let data: Payload
}

nonisolated struct HACameraStreamRequestDTO: Encodable, Equatable, Sendable {
    let cameraEntityID: String

    enum CodingKeys: String, CodingKey {
        case cameraEntityID = "camera_entity_id"
    }
}

nonisolated struct HACameraStreamResponseDTO: Decodable, Equatable, Sendable {
    let hlsPath: String?
    let mjpegPath: String?

    enum CodingKeys: String, CodingKey {
        case hlsPath = "hls_path"
        case mjpegPath = "mjpeg_path"
    }
}

nonisolated struct HACameraStreamHandoff: Equatable, Sendable {
    let entityID: String
    let hlsPath: String?
    let mjpegPath: String?

    var hasPlayablePath: Bool {
        hlsPath != nil || mjpegPath != nil
    }

    init(entityID: String, response: HACameraStreamResponseDTO) {
        self.entityID = entityID
        hlsPath = response.hlsPath
        mjpegPath = response.mjpegPath
    }
}

nonisolated enum HAMobileAppWebhookType {
    nonisolated static let streamCamera = "stream_camera"
    nonisolated static let updateRegistration = "update_registration"
}
