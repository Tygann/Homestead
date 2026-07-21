import AppIntents
import SwiftUI
import WidgetKit

@main
struct HomesteadWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HomesteadControlWidget()
        HomesteadStatusWidget()
        HomesteadSensorChartWidget()
        HomesteadSensorBoardWidget()
        HomesteadGaugeGridWidget()
        HomesteadLargeGaugeGridWidget()
        HomesteadActionWidget()
    }
}
