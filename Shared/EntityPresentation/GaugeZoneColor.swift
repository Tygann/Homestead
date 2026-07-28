import SwiftUI
import UIKit

nonisolated struct GaugeZoneColor: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.opacity = min(max(opacity, 0), 1)
    }

    init(color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 1
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        self.init(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(opacity))
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    static let blue = Self(red: 0.0, green: 0.57, blue: 0.96)
    static let green = Self(red: 0.19, green: 0.82, blue: 0.35)
    static let orange = Self(red: 1.0, green: 0.56, blue: 0.15)
    static let red = Self(red: 1.0, green: 0.23, blue: 0.27)
    static let purple = Self(red: 0.69, green: 0.32, blue: 0.87)
    static let gray = Self(red: 0.56, green: 0.56, blue: 0.58)

    static func widgetStandard(for status: WidgetGaugeStatus) -> Self {
        switch status {
        case .nominal: .green
        case .low: .blue
        case .high, .warning: .orange
        case .critical: .red
        }
    }
}
