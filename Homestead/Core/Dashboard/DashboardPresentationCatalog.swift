import Foundation

nonisolated struct DashboardPresentationDescriptor: Identifiable, Equatable, Sendable {
    let kind: DashboardPresentationKind
    let title: String
    let systemImage: String

    var id: DashboardPresentationKind { kind }
    var supportedLayouts: [DashboardCardSize] { kind.supportedLayouts }
}

nonisolated struct DashboardPresentationStyleDescriptor: Identifiable, Equatable, Sendable {
    let style: DashboardPresentationStyle
    let title: String
    let systemImage: String

    var id: DashboardPresentationStyle { style }
}

@MainActor
enum DashboardPresentationCatalog {
    static let descriptors: [DashboardPresentationDescriptor] = DashboardPresentationKind.allCases.map(descriptor(for:))

    static func descriptor(for kind: DashboardPresentationKind) -> DashboardPresentationDescriptor {
        return switch kind {
        case .chip:
            DashboardPresentationDescriptor(kind: kind, title: "Chip", systemImage: "capsule")
        case .control:
            DashboardPresentationDescriptor(kind: kind, title: "Control", systemImage: "switch.2")
        case .status:
            DashboardPresentationDescriptor(kind: kind, title: "Status", systemImage: "circle.lefthalf.filled")
        case .gauge:
            DashboardPresentationDescriptor(kind: kind, title: "Sensor Gauge", systemImage: "gauge.with.dots.needle.33percent")
        case .graph:
            DashboardPresentationDescriptor(kind: kind, title: "Graph", systemImage: "chart.xyaxis.line")
        case .camera:
            DashboardPresentationDescriptor(kind: kind, title: "Camera", systemImage: "camera.fill")
        case .weather:
            DashboardPresentationDescriptor(kind: kind, title: "Weather", systemImage: "cloud.sun.fill")
        case .media:
            DashboardPresentationDescriptor(kind: kind, title: "Media", systemImage: "play.tv.fill")
        case .action:
            DashboardPresentationDescriptor(kind: kind, title: "Action", systemImage: "sparkles")
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
        switch kind {
        case .chip, .status:
            return .available
        case .control:
            let controlAffordances: Set<EntityAffordance> = [.primaryAction, .level, .setpoint, .options, .commands]
            return !capabilities.affordances.isDisjoint(with: controlAffordances)
                ? .available
                : .unavailable(.unsupportedDomain)
        case .gauge:
            guard entityBox.homeEntity.isAvailable else { return .unavailable(.requiresAvailableEntity) }
            guard let sensor = entityBox.sensorEntity, sensor.numericValue != nil else {
                return .unavailable(.requiresNumericState)
            }
            guard let gauge = sensor.gaugePresentation else { return .unavailable(.requiresGaugeRange) }
            return gauge.rangeSource == .valueSuggested
                ? .configurable("Review the suggested range and zones.")
                : .available
        case .graph:
            return capabilities.affordances.contains(.history)
                ? .available
                : .unavailable(.requiresNumericState)
        case .camera:
            return entityBox.domain == .camera ? .available : .unavailable(.unsupportedDomain)
        case .weather:
            return entityBox.domain == .weather ? .available : .unavailable(.unsupportedDomain)
        case .media:
            return entityBox.domain == .mediaPlayer ? .available : .unavailable(.unsupportedDomain)
        case .action:
            return capabilities.affordances.contains(.trigger)
                ? .available
                : .unavailable(.unsupportedDomain)
        }
    }

    static func isCompatible(_ kind: DashboardPresentationKind, with entityBox: HAEntityState) -> Bool {
        availability(of: kind, for: entityBox).isSelectable
    }

    static func isCompatible(_ card: DashboardCardConfiguration, with entityBox: HAEntityState) -> Bool {
        guard isCompatible(card.kind, with: entityBox) else { return false }
        guard let style = card.style else { return true }
        return styleDescriptors(for: card.kind, entityBox: entityBox).contains { $0.style == style }
    }

    static func styleDescriptors(
        for kind: DashboardPresentationKind,
        entityBox: HAEntityState
    ) -> [DashboardPresentationStyleDescriptor] {
        switch kind {
        case .control:
            let style = controlStyle(for: entityBox)
            return [styleDescriptor(for: .control(style))]
        case .gauge:
            return [
                styleDescriptor(for: .gauge(.circular)),
                styleDescriptor(for: .gauge(.segmented)),
                styleDescriptor(for: .gauge(.bar))
            ]
        default:
            return []
        }
    }

    static func styleDescriptor(for style: DashboardPresentationStyle) -> DashboardPresentationStyleDescriptor {
        switch style {
        case .control(.standard):
            DashboardPresentationStyleDescriptor(style: style, title: "Standard", systemImage: "switch.2")
        case .control(.slider):
            DashboardPresentationStyleDescriptor(style: style, title: "Slider", systemImage: "slider.horizontal.3")
        case .control(.thermostat):
            DashboardPresentationStyleDescriptor(style: style, title: "Thermostat", systemImage: "thermometer.medium")
        case .gauge(.circular):
            DashboardPresentationStyleDescriptor(style: style, title: "Circular", systemImage: "gauge.with.dots.needle.33percent")
        case .gauge(.segmented):
            DashboardPresentationStyleDescriptor(style: style, title: "Segmented", systemImage: "gauge.with.dots.needle.50percent")
        case .gauge(.bar):
            DashboardPresentationStyleDescriptor(style: style, title: "Bar", systemImage: "chart.bar.fill")
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
        case .scene, .script, .button:
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
                style: controlStyle(for: entityBox),
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

    private static func controlStyle(for entityBox: HAEntityState) -> DashboardControlStyle {
        let presentation = DashboardEntityPresentation(entityBox: entityBox)
        let features = DashboardCardFeatureProvider.features(for: entityBox, presentation: presentation)

        if features.contains(where: {
            if case .setpoint = $0.content { return true }
            return false
        }) {
            return .thermostat
        }

        if features.contains(where: {
            if case .level = $0.content { return true }
            return false
        }) {
            return .slider
        }

        return .standard
    }

    static func defaultPresentation(
        kind: DashboardPresentationKind,
        style: DashboardPresentationStyle? = nil,
        for entityBox: HAEntityState
    ) -> DashboardPresentationConfiguration? {
        guard isCompatible(kind, with: entityBox) else { return nil }
        if kind == .chip { return .chip }

        let availableStyles = styleDescriptors(for: kind, entityBox: entityBox)
        if let style {
            guard style.kind == kind, availableStyles.contains(where: { $0.style == style }) else { return nil }
        }
        let resolvedStyle = style ?? availableStyles.first?.style
        let recommendation = recommendation(for: entityBox)
        if recommendation.kind == kind, recommendation.style == resolvedStyle {
            return recommendation
        }

        let layout: DashboardCardSize?
        if resolvedStyle == .gauge(.bar) {
            layout = .wide
        } else {
            layout = kind.defaultLayout
        }
        guard let layout else { return nil }
        return cardConfiguration(kind: kind, style: resolvedStyle, layout: layout)
            .map(DashboardPresentationConfiguration.card)
    }

    static func cardConfiguration(
        kind: DashboardPresentationKind,
        style: DashboardPresentationStyle? = nil,
        layout: DashboardCardSize,
        featureVisibility: DashboardCardFeatureVisibility = .automatic
    ) -> DashboardCardConfiguration? {
        guard kind.supportedLayouts.contains(layout) else { return nil }

        return switch kind {
        case .control:
            switch style ?? .control(.standard) {
            case .control(let controlStyle):
                .control(style: controlStyle, layout: layout, featureVisibility: featureVisibility)
            case .gauge:
                nil
            }
        case .status:
            style == nil ? .status(layout: layout) : nil
        case .gauge:
            switch style ?? .gauge(.circular) {
            case .gauge(let gaugeStyle):
                .gauge(style: gaugeStyle, layout: layout)
            case .control:
                nil
            }
        case .graph:
            style == nil ? .graph(layout: layout) : nil
        case .camera:
            style == nil ? .camera(layout: layout) : nil
        case .weather:
            style == nil ? .weather(layout: layout) : nil
        case .media:
            style == nil ? .media(layout: layout, featureVisibility: featureVisibility) : nil
        case .action:
            style == nil ? .action(layout: layout) : nil
        case .chip:
            nil
        }
    }
}
