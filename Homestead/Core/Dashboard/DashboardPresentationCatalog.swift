import Foundation

nonisolated struct DashboardPresentationDescriptor: Identifiable, Equatable, Sendable {
    let kind: DashboardPresentationKind
    let title: String
    let systemImage: String
    let supportedLayouts: [DashboardCardSize]

    var id: DashboardPresentationKind { kind }
}

@MainActor
enum DashboardPresentationCatalog {
    static let descriptors: [DashboardPresentationDescriptor] = DashboardPresentationKind.allCases.map(descriptor(for:))

    static func descriptor(for kind: DashboardPresentationKind) -> DashboardPresentationDescriptor {
        switch kind {
        case .chip:
            DashboardPresentationDescriptor(kind: kind, title: "Chip", systemImage: "capsule", supportedLayouts: [])
        case .control:
            DashboardPresentationDescriptor(kind: kind, title: "Control", systemImage: "switch.2", supportedLayouts: DashboardCardSize.allCases)
        case .status:
            DashboardPresentationDescriptor(kind: kind, title: "Status", systemImage: "circle.lefthalf.filled", supportedLayouts: DashboardCardSize.allCases)
        case .gauge:
            DashboardPresentationDescriptor(kind: kind, title: "Gauge", systemImage: "gauge.with.dots.needle.33percent", supportedLayouts: [.square, .wide, .large])
        case .graph:
            DashboardPresentationDescriptor(kind: kind, title: "Graph", systemImage: "chart.xyaxis.line", supportedLayouts: [.square, .wide, .large])
        case .camera:
            DashboardPresentationDescriptor(kind: kind, title: "Camera", systemImage: "camera.fill", supportedLayouts: [.square, .wide, .large])
        case .weather:
            DashboardPresentationDescriptor(kind: kind, title: "Weather", systemImage: "cloud.sun.fill", supportedLayouts: [.square, .wide, .large])
        case .media:
            DashboardPresentationDescriptor(kind: kind, title: "Media", systemImage: "play.tv.fill", supportedLayouts: [.compact, .row, .square, .wide, .large])
        case .action:
            DashboardPresentationDescriptor(kind: kind, title: "Action", systemImage: "sparkles", supportedLayouts: [.mini, .compact, .row, .square])
        }
    }

    static func compatiblePresentationKinds(for entityBox: HAEntityState) -> [DashboardPresentationKind] {
        descriptors.map(\.kind).filter { isCompatible($0, with: entityBox) }
    }

    static func isCompatible(_ kind: DashboardPresentationKind, with entityBox: HAEntityState) -> Bool {
        switch kind {
        case .chip, .status:
            return true
        case .control:
            return hasControls(entityBox)
        case .gauge:
            return entityBox.sensorEntity?.gaugePresentation != nil
        case .graph:
            return DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: .square)
        case .camera:
            return entityBox.domain == .camera
        case .weather:
            return entityBox.domain == .weather
        case .media:
            return entityBox.domain == .mediaPlayer
        case .action:
            return [.scene, .script].contains(entityBox.domain)
        }
    }

    static func recommendation(for entityBox: HAEntityState) -> DashboardPresentationConfiguration {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)

        switch entityBox.domain {
        case .camera:
            return .card(.camera(layout: .square))
        case .weather:
            return .card(.weather(layout: .square))
        case .mediaPlayer:
            return .card(.media(layout: .compact, featureVisibility: .automatic))
        case .scene, .script:
            return .card(.action(layout: .compact))
        default:
            break
        }

        if DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: .square),
           entityBox.sensorEntity?.deviceClass != "battery" {
            return .card(.graph(layout: .square))
        }

        if hasControls(entityBox) {
            let features = DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation)
            let layout: DashboardCardSize = features.isEmpty ? .compact : .square
            return .card(.control(
                layout: layout,
                featureVisibility: DashboardCardSize.defaultGeneratedFeatureVisibility(entityBox: entityBox, size: layout)
            ))
        }

        return .card(.status(layout: .compact))
    }

    private static func hasControls(_ entityBox: HAEntityState) -> Bool {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let actionableFeatures = DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation).filter {
            if case .gauge = $0.content { return false }
            return true
        }
        return presentation.primaryAction != nil
            || !actionableFeatures.isEmpty
    }

    static func defaultPresentation(
        kind: DashboardPresentationKind,
        for entityBox: HAEntityState
    ) -> DashboardPresentationConfiguration? {
        guard isCompatible(kind, with: entityBox) else { return nil }
        if kind == .chip { return .chip }
        if recommendation(for: entityBox).kind == kind { return recommendation(for: entityBox) }
        guard let layout = descriptor(for: kind).supportedLayouts.first else { return nil }
        return .card(cardConfiguration(kind: kind, layout: layout))
    }

    static func cardConfiguration(
        kind: DashboardPresentationKind,
        layout: DashboardCardSize,
        featureVisibility: DashboardCardFeatureVisibility = .automatic
    ) -> DashboardCardConfiguration {
        switch kind {
        case .control: .control(layout: layout, featureVisibility: featureVisibility)
        case .status, .chip: .status(layout: layout)
        case .gauge: .gauge(layout: layout)
        case .graph: .graph(layout: layout)
        case .camera: .camera(layout: layout)
        case .weather: .weather(layout: layout)
        case .media: .media(layout: layout, featureVisibility: featureVisibility)
        case .action: .action(layout: layout)
        }
    }
}
