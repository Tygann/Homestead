import Foundation

@MainActor
enum DashboardAreaDetailSectionProvider {
    static func makeSections(
        from entityBoxes: [HAEntityState],
        membershipContext: DashboardSummaryMembershipContext
    ) -> [DashboardAreaDetailSection] {
        var consumedEntityIDs = Set<String>()
        var sections: [DashboardAreaDetailSection] = DashboardAreaDetailSectionKind.fixedAreaOrder.compactMap { kind in
            let boxes = entityBoxes.filter { entityBox in
                isVisibleAreaEntity(entityBox, membershipContext: membershipContext) &&
                    kind.contains(entityBox)
            }

            guard !boxes.isEmpty else { return nil }
            consumedEntityIDs.formUnion(boxes.map(\.entityID))

            return DashboardAreaDetailSection(
                id: "kind-\(kind.rawValue)",
                kind: kind,
                title: kind.title,
                systemImage: kind.systemImage,
                entityIDs: boxes
                    .sorted(by: displayNameAscending)
                    .map(\.entityID)
            )
        }

        let remainingVisibleBoxes = entityBoxes.filter { entityBox in
            isVisibleAreaEntity(entityBox, membershipContext: membershipContext) &&
                !consumedEntityIDs.contains(entityBox.entityID)
        }

        let deviceSections = makeDeviceSections(
            from: remainingVisibleBoxes,
            membershipContext: membershipContext
        )
        consumedEntityIDs.formUnion(deviceSections.flatMap(\.entityIDs))
        sections.append(contentsOf: deviceSections)

        let otherBoxes = remainingVisibleBoxes.filter { entityBox in
            !consumedEntityIDs.contains(entityBox.entityID) &&
                DashboardAreaDetailSectionKind.others.contains(entityBox)
        }
        if !otherBoxes.isEmpty {
            let kind = DashboardAreaDetailSectionKind.others
            sections.append(
                DashboardAreaDetailSection(
                    id: "kind-\(kind.rawValue)",
                    kind: kind,
                    title: kind.title,
                    systemImage: kind.systemImage,
                    entityIDs: otherBoxes
                        .sorted(by: displayNameAscending)
                        .map(\.entityID)
                )
            )
        }

        return sections
    }

    private static func isVisibleAreaEntity(
        _ entityBox: HAEntityState,
        membershipContext: DashboardSummaryMembershipContext
    ) -> Bool {
        let metadata = membershipContext.metadata(for: entityBox.entityID)
        guard metadata?.isHidden != true else {
            return false
        }

        return metadata?.entityCategory == nil
    }

    private static func makeDeviceSections(
        from entityBoxes: [HAEntityState],
        membershipContext: DashboardSummaryMembershipContext
    ) -> [DashboardAreaDetailSection] {
        let deviceGroups = Dictionary(grouping: entityBoxes) { entityBox in
            membershipContext.metadata(for: entityBox.entityID)?.deviceID
        }

        return deviceGroups.compactMap { deviceID, boxes in
            guard let deviceID else {
                return nil
            }

            let title = boxes
                .compactMap { membershipContext.metadata(for: $0.entityID)?.deviceName?.areaDetailNonEmptyValue }
                .first ?? "Unknown Device"

            return DashboardAreaDetailSection(
                id: "device-\(deviceID)",
                kind: nil,
                title: title,
                systemImage: "rectangle.connected.to.line.below",
                entityIDs: boxes
                    .sorted(by: displayNameAscending)
                    .map(\.entityID)
            )
        }
        .sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func displayNameAscending(_ lhs: HAEntityState, _ rhs: HAEntityState) -> Bool {
        let nameComparison = lhs.homeEntity.displayName.localizedCaseInsensitiveCompare(rhs.homeEntity.displayName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.entityID.localizedCaseInsensitiveCompare(rhs.entityID) == .orderedAscending
    }
}

enum DashboardAreaDetailSectionKind: String, CaseIterable, Sendable {
    case lights
    case covers
    case climate
    case mediaPlayers
    case security
    case actions
    case others

    static let fixedAreaOrder: [DashboardAreaDetailSectionKind] = [
        .lights,
        .covers,
        .climate,
        .mediaPlayers,
        .security,
        .actions
    ]

    var title: String {
        switch self {
        case .lights:
            "Lights"
        case .covers:
            "Covers"
        case .climate:
            "Climate"
        case .mediaPlayers:
            "Media Players"
        case .security:
            "Security"
        case .actions:
            "Actions"
        case .others:
            "Others"
        }
    }

    var systemImage: String {
        switch self {
        case .lights:
            "lightbulb.fill"
        case .covers:
            "blinds.horizontal.closed"
        case .climate:
            "thermometer.medium"
        case .mediaPlayers:
            "play.tv.fill"
        case .security:
            "shield.lefthalf.filled"
        case .actions:
            "wand.and.stars"
        case .others:
            "square.grid.2x2"
        }
    }

    func contains(_ entityBox: HAEntityState) -> Bool {
        switch self {
        case .lights:
            entityBox.domain == .light
        case .covers:
            entityBox.domain == .cover || isCoverBinarySensor(entityBox)
        case .climate:
            switch entityBox.domain {
            case .climate, .humidifier, .waterHeater, .fan:
                true
            default:
                false
            }
        case .mediaPlayers:
            entityBox.domain == .mediaPlayer
        case .security:
            switch entityBox.domain {
            case .alarmControlPanel, .lock, .camera:
                true
            case .binarySensor:
                isSecurityBinarySensor(entityBox)
            default:
                false
            }
        case .actions:
            switch entityBox.domain {
            case .script, .scene, .automation:
                true
            default:
                false
            }
        case .others:
            isOtherAreaEntity(entityBox)
        }
    }

    private func isCoverBinarySensor(_ entityBox: HAEntityState) -> Bool {
        guard entityBox.domain == .binarySensor,
              let deviceClass = entityBox.binarySensorEntity?.deviceClass else {
            return false
        }

        return ["door", "garage_door", "window"].contains(deviceClass)
    }

    private func isSecurityBinarySensor(_ entityBox: HAEntityState) -> Bool {
        guard entityBox.domain == .binarySensor,
              let deviceClass = entityBox.binarySensorEntity?.deviceClass else {
            return false
        }

        return [
            "carbon_monoxide",
            "gas",
            "moisture",
            "safety",
            "smoke",
            "tamper"
        ].contains(deviceClass)
    }

    private func isOtherAreaEntity(_ entityBox: HAEntityState) -> Bool {
        switch entityBox.domain {
        case .vacuum, .lawnMower, .valve, .switch, .button, .select, .number:
            return true
        default:
            break
        }

        guard let domain = entityBox.entityID.split(separator: ".").first.map(String.init) else {
            return false
        }

        return [
            "input_boolean",
            "input_button",
            "input_select",
            "input_number",
            "counter",
            "timer"
        ].contains(domain)
    }
}

struct DashboardAreaDetailSection: Equatable, Sendable {
    let id: String
    let kind: DashboardAreaDetailSectionKind?
    let title: String
    let systemImage: String
    let entityIDs: [String]
}

private extension String {
    var areaDetailNonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
