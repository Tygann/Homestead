import Foundation

nonisolated struct DashboardIconChoice: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemName: String

    static let choices: [DashboardIconChoice] = [
        DashboardIconChoice(title: "Home", systemName: "house"),
        DashboardIconChoice(title: "Light", systemName: "lightbulb"),
        DashboardIconChoice(title: "Lamp", systemName: "lamp.table"),
        DashboardIconChoice(title: "Climate", systemName: "thermometer.medium"),
        DashboardIconChoice(title: "Fan", systemName: "fan"),
        DashboardIconChoice(title: "Door", systemName: "door.left.hand.open"),
        DashboardIconChoice(title: "Window", systemName: "window.vertical.open"),
        DashboardIconChoice(title: "Cover", systemName: "blinds.horizontal.closed"),
        DashboardIconChoice(title: "Lock", systemName: "lock"),
        DashboardIconChoice(title: "Battery", systemName: "battery.75percent"),
        DashboardIconChoice(title: "Camera", systemName: "camera"),
        DashboardIconChoice(title: "Media", systemName: "play.tv"),
        DashboardIconChoice(title: "Sensor", systemName: "gauge.medium"),
        DashboardIconChoice(title: "Water", systemName: "drop"),
        DashboardIconChoice(title: "Power", systemName: "bolt"),
        DashboardIconChoice(title: "Scene", systemName: "sparkles"),
        DashboardIconChoice(title: "Script", systemName: "play.rectangle"),
        DashboardIconChoice(title: "Vacuum", systemName: "washer")
    ]

    init(title: String, systemName: String) {
        self.id = systemName
        self.title = title
        self.systemName = systemName
    }
}
