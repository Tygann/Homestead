import Foundation

// MARK: - Widget Identity

nonisolated enum HomesteadWidgetKind: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case control = "HomesteadControlWidget"
    case status = "HomesteadStatusWidget"
    case sensor = "HomesteadSensorChartWidget"
    case sensorBoard = "HomesteadSensorBoardWidget"
    case largeSensorBoard = "HomesteadLargeSensorBoardWidget"
    case gaugeGrid = "HomesteadGaugeGridWidget"
    case largeGaugeGrid = "HomesteadLargeGaugeGridWidget"
    case action = "HomesteadActionWidget"

}
