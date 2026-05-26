import Foundation

struct DashboardAreaSummary: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let entityIDs: [String]
    let activeCount: Int
    let unavailableCount: Int
    let domainCounts: [EntityDomain: Int]

    var subtitle: String {
        var parts: [String] = []

        if activeCount > 0 {
            parts.append("\(activeCount) active")
        }

        if unavailableCount > 0 {
            parts.append("\(unavailableCount) unavailable")
        }

        if parts.isEmpty {
            parts.append(entityCountText)
        }

        return parts.joined(separator: " • ")
    }

    var entityCountText: String {
        "\(entityIDs.count) \(entityIDs.count == 1 ? "entity" : "entities")"
    }

    var topDomains: [EntityDomain] {
        domainCounts
            .filter { $0.value > 0 }
            .map(\.key)
            .sorted { lhs, rhs in
                lhs.dashboardPriority < rhs.dashboardPriority
            }
    }

    var systemImage: String {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("garage") {
            return "door.garage.closed"
        }

        if lowercasedName.contains("kitchen") {
            return "fork.knife"
        }

        if lowercasedName.contains("bed") {
            return "bed.double"
        }

        if lowercasedName.contains("bath") {
            return "shower"
        }

        if lowercasedName.contains("office") {
            return "desktopcomputer"
        }

        if lowercasedName.contains("living") || lowercasedName.contains("family") {
            return "sofa"
        }

        if lowercasedName.contains("outside") || lowercasedName.contains("outdoor") || lowercasedName.contains("yard") || lowercasedName.contains("patio") {
            return "tree"
        }

        return "square.split.bottomrightquarter"
    }
}
