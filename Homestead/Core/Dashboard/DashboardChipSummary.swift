import Foundation

nonisolated enum DashboardChipKind: String, Codable, Equatable, Sendable {
    case summary
    case entity
}

nonisolated enum DashboardSummaryKind: String, CaseIterable, Codable, Equatable, Sendable {
    case lights
    case doors
    case locks
    case climate
    case batteries
    case cameras
    case media

    var title: String {
        switch self {
        case .lights:
            "Lights"
        case .doors:
            "Doors"
        case .locks:
            "Locks"
        case .climate:
            "Climate"
        case .batteries:
            "Batteries"
        case .cameras:
            "Cameras"
        case .media:
            "Media"
        }
    }

    var systemImage: String {
        switch self {
        case .lights:
            "lightbulb"
        case .doors:
            "door.left.hand.open"
        case .locks:
            "lock"
        case .climate:
            "thermometer.medium"
        case .batteries:
            "battery.75percent"
        case .cameras:
            "camera"
        case .media:
            "play.tv"
        }
    }
}

struct DashboardChipPresentation: Equatable, Sendable {
    let title: String
    let value: String
    let systemImage: String
    let isActive: Bool
    let isAvailable: Bool

    var accessibilityValue: String {
        value
    }
}

@MainActor
enum DashboardSummaryProvider {
    static func makeSummary(
        kind: DashboardSummaryKind,
        entityBoxes: [HAEntityState],
        titleOverride: String? = nil,
        iconNameOverride: String? = nil
    ) -> DashboardChipPresentation? {
        let title = normalizedOverride(titleOverride) ?? kind.title
        let systemImage = normalizedOverride(iconNameOverride) ?? kind.systemImage

        switch kind {
        case .lights:
            let lights = entityBoxes.filter { $0.domain == .light }
            guard !lights.isEmpty else { return nil }
            let activeCount = lights.filter { $0.homeEntity.state == "on" }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(activeCount, activeWord: "on", inactiveWord: "off"),
                systemImage: activeCount > 0 ? "lightbulb.fill" : systemImage,
                isActive: activeCount > 0,
                isAvailable: lights.contains { $0.homeEntity.isAvailable }
            )
        case .doors:
            let doors = entityBoxes.filter(isDoorLikeBinarySensor)
            guard !doors.isEmpty else { return nil }
            let openCount = doors.filter { $0.homeEntity.state == "on" }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(openCount, activeWord: "open", inactiveWord: "closed"),
                systemImage: openCount > 0 ? "door.left.hand.open" : systemImage,
                isActive: openCount > 0,
                isAvailable: doors.contains { $0.homeEntity.isAvailable }
            )
        case .locks:
            let locks = entityBoxes.filter { $0.domain == .lock }
            guard !locks.isEmpty else { return nil }
            let unlockedCount = locks.filter { $0.homeEntity.state != "locked" && $0.homeEntity.isAvailable }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(unlockedCount, activeWord: "unlocked", inactiveWord: "locked"),
                systemImage: unlockedCount > 0 ? "lock.open" : systemImage,
                isActive: unlockedCount > 0,
                isAvailable: locks.contains { $0.homeEntity.isAvailable }
            )
        case .climate:
            let climate = entityBoxes.filter { $0.domain == .climate }
            guard !climate.isEmpty else { return nil }
            let activeCount = climate.filter { $0.climateEntity?.isActive == true }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(activeCount, activeWord: "active", inactiveWord: "off"),
                systemImage: systemImage,
                isActive: activeCount > 0,
                isAvailable: climate.contains { $0.homeEntity.isAvailable }
            )
        case .batteries:
            let batteries = entityBoxes.compactMap(\.sensorEntity).filter { $0.displayKind == .battery }
            guard !batteries.isEmpty else { return nil }
            let lowCount = batteries.filter(\.isAlerting).count
            return DashboardChipPresentation(
                title: title,
                value: countValue(lowCount, activeWord: "low", inactiveWord: "ok"),
                systemImage: lowCount > 0 ? "battery.25percent" : systemImage,
                isActive: lowCount > 0,
                isAvailable: batteries.contains(where: \.isAvailable)
            )
        case .cameras:
            let cameras = entityBoxes.filter { $0.domain == .camera }
            guard !cameras.isEmpty else { return nil }
            let unavailableCount = cameras.filter { !$0.homeEntity.isAvailable }.count
            return DashboardChipPresentation(
                title: title,
                value: unavailableCount == 0 ? "\(cameras.count) ready" : "\(unavailableCount) unavailable",
                systemImage: systemImage,
                isActive: unavailableCount > 0,
                isAvailable: unavailableCount < cameras.count
            )
        case .media:
            let players = entityBoxes.filter { $0.domain == .mediaPlayer }
            guard !players.isEmpty else { return nil }
            let playingCount = players.filter { $0.mediaPlayerEntity?.isPlaying == true }.count
            return DashboardChipPresentation(
                title: title,
                value: countValue(playingCount, activeWord: "playing", inactiveWord: "idle"),
                systemImage: playingCount > 0 ? "play.tv.fill" : systemImage,
                isActive: playingCount > 0,
                isAvailable: players.contains { $0.homeEntity.isAvailable }
            )
        }
    }

    static func makeEntityChip(
        entityBox: HAEntityState,
        titleOverride: String? = nil,
        iconNameOverride: String? = nil
    ) -> DashboardChipPresentation {
        let presentation = DashboardEntityPresentation(
            entityBox: entityBox,
            displayNameOverride: titleOverride,
            iconNameOverride: iconNameOverride
        )

        return DashboardChipPresentation(
            title: presentation.title,
            value: presentation.headline ?? presentation.subtitle,
            systemImage: presentation.iconName,
            isActive: presentation.isActive,
            isAvailable: presentation.isAvailable
        )
    }

    private static func countValue(_ count: Int, activeWord: String, inactiveWord: String) -> String {
        count == 0 ? "All \(inactiveWord)" : "\(count) \(activeWord)"
    }

    private static func normalizedOverride(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isDoorLikeBinarySensor(_ entityBox: HAEntityState) -> Bool {
        guard entityBox.domain == .binarySensor else { return false }
        let searchableText = "\(entityBox.entityID) \(entityBox.homeEntity.displayName)".lowercased()
        return ["door", "window", "garage", "gate", "opening"].contains { searchableText.contains($0) }
    }
}
