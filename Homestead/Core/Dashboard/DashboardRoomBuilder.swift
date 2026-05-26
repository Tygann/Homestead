import Foundation

@MainActor
enum DashboardRoomBuilder {
    static func buildRooms(from entityBoxes: [HAEntityState]) -> [DashboardRoomSummary] {
        let grouped = Dictionary(grouping: entityBoxes) { entityBox in
            inferredRoomName(for: entityBox.homeEntity)
        }

        return grouped
            .map { roomName, entityBoxes in
                DashboardRoomSummary(
                    id: roomName,
                    name: roomName,
                    entityIDs: entityBoxes
                        .map(\.entityID)
                        .sorted { lhs, rhs in
                            displayName(for: lhs, in: entityBoxes)
                                .localizedCaseInsensitiveCompare(displayName(for: rhs, in: entityBoxes)) == .orderedAscending
                        },
                    activeCount: entityBoxes
                        .map(DashboardEntityPresentation.init(entityBox:))
                        .filter(\.isActive)
                        .count,
                    unavailableCount: entityBoxes.filter { !$0.homeEntity.isAvailable }.count
                )
            }
            .sorted { lhs, rhs in
                lhs.name < rhs.name
            }
    }

    private static func inferredRoomName(for entity: HomeEntity) -> String {
        let normalized = entity.displayName.lowercased()

        let roomMappings: [(String, String)] = [
            ("living", "Living Room"),
            ("family", "Living Room"),
            ("kitchen", "Kitchen"),
            ("bedroom", "Bedroom"),
            ("primary", "Bedroom"),
            ("master", "Bedroom"),
            ("bath", "Bathroom"),
            ("garage", "Garage"),
            ("office", "Office"),
            ("desk", "Office"),
            ("hall", "Hallway"),
            ("entry", "Entryway"),
            ("foyer", "Entryway"),
            ("patio", "Outdoor"),
            ("outside", "Outdoor"),
            ("outdoor", "Outdoor"),
            ("yard", "Outdoor")
        ]

        for (match, roomName) in roomMappings where normalized.contains(match) {
            return roomName
        }

        return "Other"
    }

    private static func displayName(for entityID: String, in entityBoxes: [HAEntityState]) -> String {
        entityBoxes.first { $0.entityID == entityID }?.homeEntity.displayName ?? entityID
    }
}
