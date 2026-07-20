import Foundation

nonisolated enum DashboardSourceRequirement: Equatable, Sendable {
    case anyItem
    case anyEntity
    case controllable
    case boundedNumericSensor
    case history
    case domain(EntityDomain)
    case trigger
}

nonisolated struct DashboardPresentationDescriptor: Identifiable, Equatable, Sendable {
    let kind: DashboardPresentationKind
    let title: String
    let systemImage: String
    let sharedFeatureID: String?
    let sourceRequirement: DashboardSourceRequirement

    var id: DashboardPresentationKind { kind }
    var supportedLayouts: [DashboardCardSize] { kind.supportedLayouts }
}

@MainActor
enum DashboardPresentationCatalog {
    static let descriptors: [DashboardPresentationDescriptor] = DashboardPresentationKind.allCases.map(descriptor(for:))

    static func descriptor(for kind: DashboardPresentationKind) -> DashboardPresentationDescriptor {
        return switch kind {
        case .chip:
            DashboardPresentationDescriptor(kind: kind, title: "Chip", systemImage: "capsule", sharedFeatureID: nil, sourceRequirement: .anyItem)
        case .control:
            DashboardPresentationDescriptor(kind: kind, title: "Control", systemImage: "switch.2", sharedFeatureID: "control", sourceRequirement: .controllable)
        case .status:
            DashboardPresentationDescriptor(kind: kind, title: "Status", systemImage: "circle.lefthalf.filled", sharedFeatureID: "status", sourceRequirement: .anyEntity)
        case .circularGauge:
            DashboardPresentationDescriptor(kind: kind, title: "Circular Gauge", systemImage: "circle.dotted", sharedFeatureID: "sensor-gauge", sourceRequirement: .boundedNumericSensor)
        case .segmentedGauge:
            DashboardPresentationDescriptor(kind: kind, title: "Segmented Gauge", systemImage: "gauge.with.dots.needle.50percent", sharedFeatureID: "sensor-gauge", sourceRequirement: .boundedNumericSensor)
        case .barGauge:
            DashboardPresentationDescriptor(kind: kind, title: "Bar Gauge", systemImage: "chart.bar.fill", sharedFeatureID: "sensor-gauge", sourceRequirement: .boundedNumericSensor)
        case .graph:
            DashboardPresentationDescriptor(kind: kind, title: "Chart", systemImage: "chart.xyaxis.line", sharedFeatureID: "sensor", sourceRequirement: .history)
        case .camera:
            DashboardPresentationDescriptor(kind: kind, title: "Camera", systemImage: "camera.fill", sharedFeatureID: nil, sourceRequirement: .domain(.camera))
        case .weather:
            DashboardPresentationDescriptor(kind: kind, title: "Weather", systemImage: "cloud.sun.fill", sharedFeatureID: nil, sourceRequirement: .domain(.weather))
        case .media:
            DashboardPresentationDescriptor(kind: kind, title: "Media", systemImage: "play.tv.fill", sharedFeatureID: nil, sourceRequirement: .domain(.mediaPlayer))
        case .action:
            DashboardPresentationDescriptor(kind: kind, title: "Action", systemImage: "sparkles", sharedFeatureID: "action", sourceRequirement: .trigger)
        }
    }

    static func compatiblePresentationKinds(for entityBox: HAEntityState) -> [DashboardPresentationKind] {
        descriptors.map(\.kind).filter { availability(of: $0, for: entityBox).isSelectable }
    }

    static func availability(
        of kind: DashboardPresentationKind,
        for entityBox: HAEntityState
    ) -> PresentationAvailability {
        let capabilities = EntityCapabilityResolver.capabilities(for: entityBox)
        switch descriptor(for: kind).sourceRequirement {
        case .anyItem, .anyEntity:
            return .available
        case .controllable:
            let controlAffordances: Set<EntityAffordance> = [.primaryAction, .level, .setpoint, .options, .commands]
            return !capabilities.affordances.isDisjoint(with: controlAffordances)
                ? .available
                : .unavailable(.unsupportedDomain)
        case .boundedNumericSensor:
            guard entityBox.homeEntity.isAvailable else { return .unavailable(.requiresAvailableEntity) }
            guard let sensor = entityBox.sensorEntity, sensor.numericValue != nil else {
                return .unavailable(.requiresNumericState)
            }
            guard let gauge = sensor.gaugePresentation else { return .unavailable(.requiresGaugeRange) }
            return gauge.rangeSource == .valueSuggested
                ? .configurable("Review the suggested range and zones.")
                : .available
        case .history:
            return capabilities.affordances.contains(.history)
                ? .available
                : .unavailable(.requiresNumericState)
        case .domain(let domain):
            return entityBox.domain == domain ? .available : .unavailable(.unsupportedDomain)
        case .trigger:
            return capabilities.affordances.contains(.trigger)
                ? .available
                : .unavailable(.unsupportedDomain)
        }
    }

    static func isCompatible(_ kind: DashboardPresentationKind, with entityBox: HAEntityState) -> Bool {
        availability(of: kind, for: entityBox).isSelectable
    }

    static func isCompatible(_ card: DashboardCardConfiguration, with entityBox: HAEntityState) -> Bool {
        isCompatible(card.kind, with: entityBox)
    }

    static func recommendation(for entityBox: HAEntityState) -> DashboardPresentationConfiguration {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)

        switch entityBox.domain {
        case .camera:
            return .card(.camera(layout: .square))
        case .weather:
            return .card(.weather(layout: .square))
        case .mediaPlayer:
            return .card(.media(layout: .compact))
        case .scene, .script, .button:
            return .card(.action(layout: .compact))
        default:
            break
        }

        if DashboardHistoryCardPresentation.isEligible(entityBox: entityBox, size: .square),
           entityBox.sensorEntity?.deviceClass != "battery" {
            return .card(.graph(layout: .wide))
        }

        if hasControls(entityBox) {
            let features = DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation)
            let layout: DashboardCardSize = features.isEmpty ? .compact : .square
            return .card(.control(layout: layout))
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

        let recommendation = recommendation(for: entityBox)
        if recommendation.kind == kind {
            return recommendation
        }

        let layout = kind.defaultLayout
        guard let layout else { return nil }
        return cardConfiguration(kind: kind, layout: layout)
            .map(DashboardPresentationConfiguration.card)
    }

    static func cardConfiguration(
        kind: DashboardPresentationKind,
        layout: DashboardCardSize
    ) -> DashboardCardConfiguration? {
        guard kind.supportedLayouts.contains(layout) else { return nil }

        return switch kind {
        case .control:
            .control(layout: layout)
        case .status:
            .status(layout: layout)
        case .circularGauge:
            .circularGauge(layout: layout)
        case .segmentedGauge:
            .segmentedGauge(layout: layout)
        case .barGauge:
            .barGauge(layout: layout)
        case .graph:
            .graph(layout: layout)
        case .camera:
            .camera(layout: layout)
        case .weather:
            .weather(layout: layout)
        case .media:
            .media(layout: layout)
        case .action:
            .action(layout: layout)
        case .chip:
            nil
        }
    }
}
