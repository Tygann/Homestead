import Foundation

nonisolated struct HACameraCapabilities: Decodable, Equatable, Sendable {
    let frontendStreamTypes: [HACameraStreamType]

    var supportsLiveStream: Bool {
        !frontendStreamTypes.isEmpty
    }

    var displayText: String {
        guard !frontendStreamTypes.isEmpty else {
            return "Snapshot only"
        }

        return frontendStreamTypes.map(\.displayName).joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case frontendStreamTypes = "frontend_stream_types"
    }

    init(frontendStreamTypes: [HACameraStreamType] = []) {
        self.frontendStreamTypes = frontendStreamTypes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frontendStreamTypes = try container.decodeIfPresent([HACameraStreamType].self, forKey: .frontendStreamTypes) ?? []
    }
}

nonisolated enum HACameraStreamType: String, Decodable, Equatable, Sendable {
    case hls
    case webRTC = "webrtc"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = HACameraStreamType(rawValue: try container.decode(String.self)) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .hls:
            "HLS"
        case .webRTC:
            "WebRTC"
        case .unknown:
            "Live"
        }
    }
}
