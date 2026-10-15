import Foundation

/// Only allowlisted categories leave the SDP boundary; never log addresses or credentials.
nonisolated enum CameraICECandidateSummary {
    static func describe(_ sdp: String) -> String {
        let fields = sdp.split(whereSeparator: { $0.isWhitespace })
        let transport = fields.count > 2 && ["udp", "tcp"].contains(fields[2].lowercased())
            ? fields[2].lowercased() : "unknown"
        let typeIndex = fields.firstIndex(of: "typ").map { $0 + 1 }
        let type = typeIndex.flatMap { fields.indices.contains($0) ? String(fields[$0]) : nil }
        let safeType = type.flatMap { ["host", "srflx", "prflx", "relay"].contains($0) ? $0 : nil } ?? "unknown"
        let family = fields.count > 4 ? (fields[4].contains(":") ? "ipv6" : "ipv4-or-name") : "unknown"
        return "\(safeType)/\(transport)/\(family)"
    }
}
