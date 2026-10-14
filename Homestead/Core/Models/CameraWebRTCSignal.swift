import Foundation

/// Signaling is carried by the authenticated HA socket; media is received by the playback engine.
nonisolated struct CameraWebRTCSignal: Decodable, Sendable, Equatable {
    let type: String
    let sessionID: String?
    let answer: String?
    let candidate: JSONValue?

    enum CodingKeys: String, CodingKey {
        case type, answer, candidate
        case sessionID = "session_id"
    }

    static let connectionClosed = CameraWebRTCSignal(type: "error", sessionID: nil, answer: nil, candidate: nil)
}
