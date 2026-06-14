import Foundation

struct DashboardAreaSummary: Identifiable, Hashable, Sendable {
    let id: String
    let areaID: String?
    let name: String
    let icon: String?
    let floorID: String?
    let floorName: String?
    let floorLevel: Int?
    let floorSortOrder: Int?
    let entityIDs: [String]
    let activeCount: Int
    let unavailableCount: Int
    let domainCounts: [EntityDomain: Int]
    let activeDomainCounts: [EntityDomain: Int]

    var topDomains: [EntityDomain] {
        domainChips.map(\.domain)
    }

    var domainChips: [DashboardAreaDomainChip] {
        domainCounts
            .filter { $0.value > 0 }
            .map(\.key)
            .sorted { lhs, rhs in
                let lhsIsActive = activeDomainCounts[lhs, default: 0] > 0
                let rhsIsActive = activeDomainCounts[rhs, default: 0] > 0
                if lhsIsActive != rhsIsActive {
                    return lhsIsActive
                }

                return lhs.dashboardPriority < rhs.dashboardPriority
            }
            .map { domain in
                DashboardAreaDomainChip(
                    domain: domain,
                    isActive: activeDomainCounts[domain, default: 0] > 0
                )
            }
    }

    var systemImage: String {
        DashboardAreaIconResolver.systemImage(areaIcon: icon, areaName: name)
    }
}

enum DashboardAreaIconResolver {
    static let fallbackSystemImage = "house"

    static func systemImage(areaIcon: String?, areaName: String) -> String {
        if let mappedIcon = areaIcon
            .flatMap({ normalizedIcon($0) })
            .flatMap({ mdiSystemImageByIcon[$0] }) {
            return mappedIcon
        }

        return inferredSystemImage(for: areaName) ?? fallbackSystemImage
    }

    private static func normalizedIcon(_ icon: String) -> String? {
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedIcon.isEmpty else {
            return nil
        }

        return trimmedIcon.hasPrefix("mdi:") ? trimmedIcon : "mdi:\(trimmedIcon)"
    }

    private static func inferredSystemImage(for areaName: String) -> String? {
        let normalizedName = normalizedAreaName(areaName)

        return nameInferenceRules.first { rule in
            rule.matches(normalizedName)
        }?.systemImage
    }

    private static func normalizedAreaName(_ areaName: String) -> String {
        let separators = CharacterSet.alphanumerics.inverted
        let words = areaName
            .lowercased()
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        return " \(words.joined(separator: " ")) "
    }

    private static let mdiSystemImageByIcon: [String: String] = [
        "mdi:bed": "bed.double",
        "mdi:bed-double": "bed.double",
        "mdi:bed-king": "bed.double",
        "mdi:desk": "desktopcomputer",
        "mdi:desktop-tower-monitor": "desktopcomputer",
        "mdi:monitor": "desktopcomputer",
        "mdi:garage": "door.garage.closed",
        "mdi:garage-variant": "door.garage.closed",
        "mdi:sofa": "sofa",
        "mdi:food-fork-drink": "fork.knife",
        "mdi:silverware-fork-knife": "fork.knife",
        "mdi:fridge": "refrigerator",
        "mdi:washing-machine": "washer",
        "mdi:shower": "shower",
        "mdi:bathtub": "bathtub.fill",
        "mdi:toilet": "toilet",
        "mdi:door": "door.left.hand.closed",
        "mdi:tree": "tree",
        "mdi:pine-tree": "tree",
        "mdi:gamepad-variant": "gamecontroller",
        "mdi:controller": "gamecontroller",
        "mdi:movie": "play.tv",
        "mdi:television": "tv",
        "mdi:hanger": "hanger",
        "mdi:baby-carriage": "teddybear.fill"
    ]

    private static let nameInferenceRules: [NameInferenceRule] = [
        NameInferenceRule(phrases: ["garage"], systemImage: "door.garage.closed"),
        NameInferenceRule(phrases: ["kitchen", "pantry"], systemImage: "fork.knife"),
        NameInferenceRule(phrases: ["dining room", "dining"], systemImage: "fork.knife"),
        NameInferenceRule(phrases: ["bedroom", "primary bedroom", "guest bedroom", "bed"], systemImage: "bed.double"),
        NameInferenceRule(phrases: ["nursery"], systemImage: "teddybear.fill"),
        NameInferenceRule(phrases: ["office", "study"], systemImage: "desktopcomputer"),
        NameInferenceRule(phrases: ["entryway", "entry", "foyer", "mudroom"], systemImage: "door.left.hand.closed"),
        NameInferenceRule(phrases: ["living room", "family room", "den", "lounge"], systemImage: "sofa"),
        NameInferenceRule(phrases: ["bathroom", "bath", "powder room", "restroom"], systemImage: "shower"),
        NameInferenceRule(phrases: ["laundry", "utility room"], systemImage: "washer"),
        NameInferenceRule(phrases: ["hallway", "hall", "corridor"], systemImage: "door.left.hand.open"),
        NameInferenceRule(phrases: ["patio", "porch", "backyard", "front yard", "yard", "outside", "outdoor", "garden", "deck"], systemImage: "tree"),
        NameInferenceRule(phrases: ["game room", "games room"], systemImage: "gamecontroller"),
        NameInferenceRule(phrases: ["media room", "theater", "theatre", "cinema"], systemImage: "play.tv"),
        NameInferenceRule(phrases: ["closet", "wardrobe"], systemImage: "hanger")
    ]
}

private struct NameInferenceRule {
    let phrases: [String]
    let systemImage: String

    func matches(_ normalizedName: String) -> Bool {
        phrases.contains { phrase in
            normalizedName.contains(" \(phrase) ")
        }
    }
}

struct DashboardAreaDomainChip: Hashable, Sendable {
    let domain: EntityDomain
    let isActive: Bool
}

struct DashboardAreaContext: Hashable, Sendable {
    let areaID: String
    let name: String
    let icon: String?
    let floorID: String?
    let floorName: String?
    let floorLevel: Int?
    let floorSortOrder: Int?
}

struct DashboardAreaSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String?
    let areas: [DashboardAreaSummary]
}
