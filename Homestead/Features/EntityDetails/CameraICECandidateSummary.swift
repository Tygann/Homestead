import Foundation
import Darwin

/// Only allowlisted categories leave the SDP boundary; never log addresses or credentials.
nonisolated enum CameraICECandidateSummary {
    static func describe(_ sdp: String) -> String {
        let fields = sdp.split(whereSeparator: { $0.isWhitespace })
        let typeIndex = fields.firstIndex(of: "typ").map { $0 + 1 }
        let tcpTypeIndex = fields.firstIndex(of: "tcptype").map { $0 + 1 }
        return describe(type: typeIndex.flatMap { fields.indices.contains($0) ? String(fields[$0]) : nil },
                        transport: fields.count > 2 ? String(fields[2]) : nil,
                        address: fields.count > 4 ? String(fields[4]) : nil,
                        tcpType: tcpTypeIndex.flatMap { fields.indices.contains($0) ? String(fields[$0]) : nil })
    }

    static func describe(type: String?, transport: String?, address: String?, tcpType: String? = nil) -> String {
        let safeType = type.flatMap { ["host", "srflx", "prflx", "relay"].contains($0) ? $0 : nil } ?? "unknown"
        let normalizedTransport = transport?.lowercased()
        let safeTransport = normalizedTransport.flatMap { ["udp", "tcp"].contains($0) ? $0 : nil } ?? "unknown"
        let safeTCPType = tcpType.flatMap { ["active", "passive", "so"].contains($0) ? $0 : nil } ?? "unknown"
        let suffix = safeTransport == "tcp" ? "/\(safeTCPType)" : ""
        return "\(safeType)/\(safeTransport)/\(addressCategory(address))\(suffix)"
    }

    // MARK: - Private Helpers
    private static func addressCategory(_ address: String?) -> String {
        guard let address, !address.isEmpty else { return "unknown" }
        var ipv4 = in_addr()
        if inet_pton(AF_INET, address, &ipv4) == 1 {
            return withUnsafeBytes(of: ipv4) { "ipv4/\(ipv4Scope(Array($0)))" }
        }
        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, address, &ipv6) == 1 {
            let bytes = withUnsafeBytes(of: ipv6) { Array($0) }
            if bytes.prefix(10).allSatisfy({ $0 == 0 }), bytes[10] == 255, bytes[11] == 255 {
                return "ipv4-mapped/\(ipv4Scope(Array(bytes.suffix(4))))"
            }
            let scope: String
            if bytes.allSatisfy({ $0 == 0 }) { scope = "unspecified" }
            else if bytes.prefix(15).allSatisfy({ $0 == 0 }), bytes[15] == 1 { scope = "loopback" }
            else if bytes[0] == 0xfe, bytes[1] & 0xc0 == 0x80 { scope = "link-local" }
            else if bytes[0] & 0xfe == 0xfc { scope = "private" }
            else if bytes[0] == 0xff { scope = "multicast" }
            else if bytes.prefix(4).elementsEqual([0x20, 0x01, 0x0d, 0xb8]) { scope = "documentation" }
            else { scope = "other" }
            return "ipv6/\(scope)"
        }
        return address.lowercased().hasSuffix(".local") ? "name/mdns" : "name/unknown"
    }

    private static func ipv4Scope(_ bytes: [UInt8]) -> String {
        if bytes[0] == 10 || (bytes[0] == 172 && (16...31).contains(bytes[1])) || (bytes[0] == 192 && bytes[1] == 168) { return "private" }
        if bytes[0] == 100 && (64...127).contains(bytes[1]) { return "shared" }
        if bytes[0] == 127 { return "loopback" }
        if bytes[0] == 169 && bytes[1] == 254 { return "link-local" }
        if bytes.allSatisfy({ $0 == 0 }) { return "unspecified" }
        if (bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 2) ||
            (bytes[0] == 198 && bytes[1] == 51 && bytes[2] == 100) ||
            (bytes[0] == 203 && bytes[1] == 0 && bytes[2] == 113) { return "documentation" }
        if bytes[0] >= 224 { return "multicast-or-reserved" }
        return "other"
    }
}

#if DEBUG
/// Bounded counters absorb candidate bursts without displacing startup milestones.
nonisolated struct CameraICECandidateDiagnostics {
    enum Direction { case local, remote }
    private struct Counts {
        var total = 0
        var sdp = 0
        var categories: [String: Int] = [:]
        var fingerprints: Set<Int> = []
        var uniqueLimitReached = false
        var firstMilliseconds: Int?
        var lastMilliseconds: Int?

        mutating func append(_ candidate: String, inSDP: Bool, elapsedMilliseconds: Int) {
            total += 1
            if firstMilliseconds == nil { firstMilliseconds = elapsedMilliseconds }
            lastMilliseconds = elapsedMilliseconds
            if inSDP { sdp += 1 }
            categories[CameraICECandidateSummary.describe(candidate), default: 0] += 1
            // Process-random fingerprints are never logged or persisted.
            let fingerprint = candidate.hashValue
            if fingerprints.contains(fingerprint) { return }
            if fingerprints.count < 512 { fingerprints.insert(fingerprint) }
            else { uniqueLimitReached = true }
        }

        var summary: String {
            let categories = categories.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            return "total \(total), SDP \(sdp), first/last ms \(firstMilliseconds ?? -1)/\(lastMilliseconds ?? -1), unique \(fingerprints.count)\(uniqueLimitReached ? "+" : ""), \(categories)"
        }
    }
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private var local = Counts()
    private var remote = Counts()
    private(set) var acknowledged = 0

    mutating func append(_ candidate: String, direction: Direction, inSDP: Bool = false) {
        let elapsed = Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
        switch direction {
        case .local: local.append(candidate, inSDP: inSDP, elapsedMilliseconds: elapsed)
        case .remote: remote.append(candidate, inSDP: inSDP, elapsedMilliseconds: elapsed)
        }
    }

    mutating func appendSDP(_ sdp: String, direction: Direction) {
        for line in sdp.split(whereSeparator: \.isNewline) where line.hasPrefix("a=candidate:") {
            append(String(line.dropFirst(2)), direction: direction, inSDP: true)
        }
    }

    mutating func didAcknowledge() { acknowledged += 1 }
    var summary: String { "WebRTC candidates local [\(local.summary)], remote [\(remote.summary)], acknowledged \(acknowledged)" }
}
#endif
