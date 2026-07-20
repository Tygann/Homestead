#if DEBUG
import SwiftUI

// MARK: - Gallery

/// A deterministic reference surface for reviewing the shared detail grammar
/// across representative families and production operational states.
@MainActor
struct EntityDetailReferenceGallery: View {
    @State private var family: EntityDetailReferenceFamily = .presence
    @State private var variant: EntityDetailReferenceVariant = .live

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            EntityDetailReferenceScene(family: family, variant: variant)
                .id("\(family.rawValue)-\(variant.rawValue)")
        }
    }

    private var controls: some View {
        HStack(spacing: AppSpacing.medium) {
            Picker("Family", selection: $family) {
                ForEach(EntityDetailReferenceFamily.allCases) { family in
                    Label(family.title, systemImage: family.systemImage)
                        .tag(family)
                }
            }

            Spacer(minLength: AppSpacing.medium)

            Picker("State", selection: $variant) {
                ForEach(EntityDetailReferenceVariant.allCases) { variant in
                    Text(variant.title)
                        .tag(variant)
                }
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal, AppSpacing.large)
        .frame(minHeight: 52)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Reference Scene

@MainActor
private struct EntityDetailReferenceScene: View {
    let family: EntityDetailReferenceFamily
    let variant: EntityDetailReferenceVariant
    let dependencies: PreviewDependencies

    init(
        family: EntityDetailReferenceFamily,
        variant: EntityDetailReferenceVariant
    ) {
        self.family = family
        self.variant = variant
        dependencies = variant.dependencies(for: family)
    }

    var body: some View {
        NavigationStack {
            if let entityBox = dependencies.stateStore.entityBox(for: family.entityID) {
                EntityDetailSheet(entityBox: entityBox, presentationStyle: .navigation)
            } else {
                ContentUnavailableView("Fixture Unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .withPreviewEnvironment(dependencies)
    }
}

// MARK: - Fixtures

private enum EntityDetailReferenceFamily: String, CaseIterable, Identifiable {
    case metric
    case positional
    case environmental
    case information
    case presence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: "Metric"
        case .positional: "Position"
        case .environmental: "Climate"
        case .information: "Weather"
        case .presence: "Presence"
        }
    }

    var systemImage: String {
        switch self {
        case .metric: "gauge.with.dots.needle.50percent"
        case .positional: "blinds.horizontal.closed"
        case .environmental: "thermometer.medium"
        case .information: "cloud.sun.fill"
        case .presence: "person.crop.circle.fill"
        }
    }

    var entityID: String {
        switch self {
        case .metric: "sensor.front_door_battery"
        case .positional: "cover.primary_shades"
        case .environmental: "climate.downstairs"
        case .information: "weather.home"
        case .presence: "person.tyler"
        }
    }

    func fixture(variant: EntityDetailReferenceVariant) -> HAEntityDTO {
        var attributes = baseAttributes
        var state = baseState

        switch variant {
        case .live, .pending, .stale, .failed:
            break
        case .unavailable:
            state = "unavailable"
        case .minimum:
            applyExtreme(isMaximum: false, state: &state, attributes: &attributes)
        case .maximum:
            applyExtreme(isMaximum: true, state: &state, attributes: &attributes)
        case .longContent:
            attributes["friendly_name"] = .string("A Deliberately Long Entity Name for Dynamic Type and Localization Review")
        }

        return HAEntityDTO(
            entityID: entityID,
            state: state,
            attributes: attributes,
            lastUpdated: variant == .stale
                ? Self.referenceDate.addingTimeInterval(-45 * 60)
                : Self.referenceDate.addingTimeInterval(-5 * 60)
        )
    }

    private var baseState: String {
        switch self {
        case .metric: "18"
        case .positional: "open"
        case .environmental: "heat"
        case .information: "partlycloudy"
        case .presence: "home"
        }
    }

    private var baseAttributes: [String: JSONValue] {
        switch self {
        case .metric:
            [
                "friendly_name": .string("Front Door Battery"),
                "device_class": .string("battery"),
                "unit_of_measurement": .string("%")
            ]
        case .positional:
            [
                "friendly_name": .string("Primary Shades"),
                "current_position": .number(72)
            ]
        case .environmental:
            [
                "friendly_name": .string("Downstairs"),
                "current_temperature": .number(68),
                "temperature": .number(70),
                "temperature_unit": .string("°F"),
                "min_temp": .number(50),
                "max_temp": .number(90),
                "target_temp_step": .number(1),
                "hvac_modes": .array([.string("off"), .string("heat"), .string("cool"), .string("heat_cool")]),
                "fan_mode": .string("auto"),
                "fan_modes": .array([.string("auto"), .string("low"), .string("high")]),
                "preset_mode": .string("home"),
                "preset_modes": .array([.string("home"), .string("away"), .string("sleep")])
            ]
        case .information:
            [
                "friendly_name": .string("Home Weather"),
                "temperature": .number(73),
                "temperature_unit": .string("°F"),
                "humidity": .number(56),
                "wind_speed": .number(8),
                "wind_speed_unit": .string("mph"),
                "wind_bearing": .number(225),
                "forecast": .array([.object(["condition": .string("rainy")])]),
                "attribution": .string("Home Assistant weather provider")
            ]
        case .presence:
            [
                "friendly_name": .string("Tyler"),
                "source": .string("device_tracker.tylers_iphone"),
                "gps_accuracy": .number(20)
            ]
        }
    }

    private func applyExtreme(
        isMaximum: Bool,
        state: inout String,
        attributes: inout [String: JSONValue]
    ) {
        switch self {
        case .metric:
            state = isMaximum ? "100" : "0"
        case .positional:
            state = isMaximum ? "open" : "closed"
            attributes["current_position"] = .number(isMaximum ? 100 : 0)
        case .environmental:
            attributes["current_temperature"] = .number(isMaximum ? 90 : 50)
            attributes["temperature"] = .number(isMaximum ? 90 : 50)
        case .information:
            attributes["temperature"] = .number(isMaximum ? 110 : -5)
        case .presence:
            state = isMaximum ? "home" : "not_home"
        }
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_784_515_200)
}

private enum EntityDetailReferenceVariant: String, CaseIterable, Identifiable {
    case live
    case pending
    case unavailable
    case stale
    case failed
    case minimum
    case maximum
    case longContent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: "Live"
        case .pending: "Pending"
        case .unavailable: "Unavailable"
        case .stale: "Stale"
        case .failed: "Failed"
        case .minimum: "Minimum"
        case .maximum: "Maximum"
        case .longContent: "Long Content"
        }
    }

    @MainActor
    func dependencies(for family: EntityDetailReferenceFamily) -> PreviewDependencies {
        PreviewDependencies.entityDetailSample(
            entityOverrides: [family.fixture(variant: self)],
            dataFreshness: dataFreshness,
            connectionStatus: connectionStatus,
            serviceFeedback: serviceFeedback(for: family),
            pendingCommand: pendingCommand(for: family)
        )
    }

    private var dataFreshness: HADataFreshness {
        switch self {
        case .stale:
            .stale(nil, lastUpdated: Date(timeIntervalSince1970: 1_784_512_500))
        default:
            .live(Date(timeIntervalSince1970: 1_784_515_200))
        }
    }

    private var connectionStatus: HAConnectionStatus {
        self == .stale ? .reconnecting : .connected
    }

    private func serviceFeedback(for family: EntityDetailReferenceFamily) -> HAServiceFeedback? {
        guard self == .failed else { return nil }
        return HAServiceFeedback(
            title: "Action failed",
            message: "Home Assistant did not accept the requested change. Try again.",
            style: .failure,
            entityID: family.entityID
        )
    }

    private func pendingCommand(for family: EntityDetailReferenceFamily) -> HAEntityPendingCommand? {
        guard self == .pending else { return nil }
        return HAEntityPendingCommand(
            entityID: family.entityID,
            expectedState: family == .metric ? nil : family.fixture(variant: .live).state,
            startedAt: Date(timeIntervalSince1970: 1_784_515_140)
        )
    }
}

// MARK: - Preview Matrix

#Preview("Entity Detail Reference Gallery") {
    EntityDetailReferenceGallery()
}

#Preview("Pending") {
    EntityDetailReferenceScene(family: .positional, variant: .pending)
}

#Preview("Unavailable - Dark") {
    EntityDetailReferenceScene(family: .environmental, variant: .unavailable)
        .preferredColorScheme(.dark)
}

#Preview("Stale - Regular Width", traits: .fixedLayout(width: 900, height: 900)) {
    EntityDetailReferenceScene(family: .information, variant: .stale)
}

#Preview("Long Content - Accessibility", traits: .fixedLayout(width: 430, height: 932)) {
    EntityDetailReferenceScene(family: .metric, variant: .longContent)
        .dynamicTypeSize(.accessibility5)
}
#endif
