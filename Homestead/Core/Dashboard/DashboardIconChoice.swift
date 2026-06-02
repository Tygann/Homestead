import Foundation

nonisolated struct DashboardIconChoice: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let systemName: String

    static let choices: [DashboardIconChoice] = [
        DashboardIconChoice(title: "Home", systemName: "house.fill"),
        DashboardIconChoice(title: "Light", systemName: "lightbulb.fill"),
        DashboardIconChoice(title: "Lamp", systemName: "lamp.table.fill"),
        DashboardIconChoice(title: "Switch", systemName: "lightswitch.on.fill"),
        DashboardIconChoice(title: "Outlet", systemName: "poweroutlet.type.b.fill"),
        DashboardIconChoice(title: "Climate", systemName: "thermometer.medium"),
        DashboardIconChoice(title: "Fan", systemName: "fan.fill"),
        DashboardIconChoice(title: "Door", systemName: "door.left.hand.open"),
        DashboardIconChoice(title: "Window", systemName: "window.vertical.open"),
        DashboardIconChoice(title: "Cover", systemName: "blinds.horizontal.closed"),
        DashboardIconChoice(title: "Lock", systemName: "lock.fill"),
        DashboardIconChoice(title: "Battery", systemName: "battery.75percent"),
        DashboardIconChoice(title: "Camera", systemName: "camera.fill"),
        DashboardIconChoice(title: "Media", systemName: "play.tv.fill"),
        DashboardIconChoice(title: "Sensor", systemName: "gauge.medium"),
        DashboardIconChoice(title: "Water", systemName: "drop.fill"),
        DashboardIconChoice(title: "Power", systemName: "bolt.fill"),
        DashboardIconChoice(title: "Scene", systemName: "sparkles"),
        DashboardIconChoice(title: "Script", systemName: "play.rectangle.fill"),
        DashboardIconChoice(title: "Vacuum", systemName: "washer.fill")
    ]

    init(title: String, systemName: String) {
        self.id = systemName
        self.title = title
        self.systemName = systemName
    }
}
