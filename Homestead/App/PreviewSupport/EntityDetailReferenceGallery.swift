#if DEBUG
import SwiftUI

/// A deterministic four-family reference surface for reviewing the shared
/// entity-detail grammar without connecting to a live Home Assistant server.
@MainActor
struct EntityDetailReferenceGallery: View {
    private let dependencies = PreviewDependencies.sample

    var body: some View {
        TabView {
            referenceView(entityID: "sensor.front_door_battery")
                .tabItem { Label("Metric", systemImage: "gauge.with.dots.needle.50percent") }

            referenceView(entityID: "cover.primary_shades")
                .tabItem { Label("Position", systemImage: "blinds.horizontal.closed") }

            referenceView(entityID: "climate.downstairs")
                .tabItem { Label("Climate", systemImage: "thermometer.medium") }

            referenceView(entityID: "weather.home")
                .tabItem { Label("Weather", systemImage: "cloud.sun.fill") }
        }
        .withPreviewEnvironment(dependencies)
    }

    @ViewBuilder
    private func referenceView(entityID: String) -> some View {
        NavigationStack {
            if let entityBox = dependencies.stateStore.entityBox(for: entityID) {
                EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation)
            } else {
                ContentUnavailableView("Fixture Unavailable", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

#Preview("Entity Detail Reference Gallery") {
    EntityDetailReferenceGallery()
}
#endif
