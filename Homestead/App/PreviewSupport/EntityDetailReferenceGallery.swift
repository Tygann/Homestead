#if DEBUG
import SwiftUI

// MARK: - Gallery

/// A deterministic reference surface for reviewing the shared detail grammar
/// across representative families and production operational states.
@MainActor
struct EntityDetailReferenceGallery: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var family: EntityDetailReferenceFamily
    @State private var variant: EntityDetailReferenceVariant

    init() {
        _family = State(initialValue: EntityDetailReferenceFamily(
            rawValue: RuntimeEnvironment.entityDetailReferenceFamily ?? ""
        ) ?? .presence)
        _variant = State(initialValue: EntityDetailReferenceVariant(
            rawValue: RuntimeEnvironment.entityDetailReferenceVariant ?? ""
        ) ?? .live)
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            EntityDetailReferenceScene(family: family, variant: variant)
                .id("\(family.rawValue)-\(variant.rawValue)")
        }
    }

    private var controls: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    familyPicker
                    variantPicker
                }
            } else {
                HStack(spacing: AppSpacing.medium) {
                    familyPicker
                    Spacer(minLength: AppSpacing.medium)
                    variantPicker
                }
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
        .frame(minHeight: 52)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var familyPicker: some View {
        Picker("Family", selection: $family) {
            ForEach(EntityDetailReferenceFamily.allCases) { family in
                Label(family.title, systemImage: family.systemImage)
                    .tag(family)
            }
        }
        .pickerStyle(.menu)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
    }

    private var variantPicker: some View {
        Picker("State", selection: $variant) {
            ForEach(EntityDetailReferenceVariant.allCases) { variant in
                Text(variant.title)
                    .tag(variant)
            }
        }
        .pickerStyle(.menu)
        .fixedSize(horizontal: false, vertical: true)
        .frame(
            maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing
        )
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
        let dependencies = variant.dependencies(for: family)
        variant.configureForecastFixture(
            dependencies.stateStore.entityBox(for: family.entityID),
            family: family
        )
        self.dependencies = dependencies
    }

    var body: some View {
        NavigationStack {
            if let entityBox = dependencies.stateStore.entityBox(for: family.entityID) {
                EntityDetailSheet(
                    entityBox: entityBox,
                    presentationStyle: .navigation,
                    automaticallyLoadsWeatherForecast: family != .information,
                    initialSection: family == .history ? .history(initialRange: .sixHours) : .overview
                )
                .homesteadWallpaperBackground()
                .environment(\.homesteadEntityDetailSurfaceContext, .home)
            } else {
                ContentUnavailableView("Fixture Unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .withPreviewEnvironment(dependencies)
    }
}

// MARK: - Fixtures

private enum EntityDetailReferenceFamily: String, CaseIterable, Identifiable {
    case simpleControl
    case momentaryAction
    case metric
    case history
    case positional
    case environmental
    case environmentalSingle
    case information
    case media
    case presence
    case editableNumber
    case editableSelect
    case editableText
    case editableTemporal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simpleControl: "Light"
        case .momentaryAction: "Script"
        case .metric: "Metric"
        case .history: "Chart"
        case .positional: "Position"
        case .environmental: "Climate Range"
        case .environmentalSingle: "Climate Heat"
        case .information: "Weather"
        case .media: "Media"
        case .presence: "Presence"
        case .editableNumber: "Number"
        case .editableSelect: "Select"
        case .editableText: "Text"
        case .editableTemporal: "Date & Time"
        }
    }

    var systemImage: String {
        switch self {
        case .simpleControl: "lightbulb.fill"
        case .momentaryAction: "play.fill"
        case .metric: "gauge.with.dots.needle.50percent"
        case .history: "chart.xyaxis.line"
        case .positional: "blinds.horizontal.closed"
        case .environmental, .environmentalSingle: "thermometer.medium"
        case .information: "cloud.sun.fill"
        case .media: "play.tv.fill"
        case .presence: "person.crop.circle.fill"
        case .editableNumber: "slider.horizontal.3"
        case .editableSelect: "filemenu.and.selection"
        case .editableText: "text.cursor"
        case .editableTemporal: "calendar.badge.clock"
        }
    }

    var entityID: String {
        switch self {
        case .simpleControl: "light.reading_lamp"
        case .momentaryAction: "script.arrive_home"
        case .metric: "sensor.front_door_battery"
        case .history: "sensor.living_room_temperature"
        case .positional: "cover.primary_shades"
        case .environmental: "climate.downstairs"
        case .environmentalSingle: "climate.upstairs"
        case .information: "weather.home"
        case .media: "media_player.living_room"
        case .presence: "person.tyler"
        case .editableNumber: "input_number.target_humidity"
        case .editableSelect: "select.house_mode"
        case .editableText: "input_text.guest_message"
        case .editableTemporal: "input_datetime.quiet_hours_start"
        }
    }

    func fixture(variant: EntityDetailReferenceVariant) -> HAEntityDTO {
        var attributes = baseAttributes
        var state = baseState

        switch variant {
        case .live, .loading, .empty, .pending, .stale, .failed:
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
        case .simpleControl: "on"
        case .momentaryAction: "off"
        case .metric: "18"
        case .history: "73.4"
        case .positional: "open"
        case .environmental: "heat_cool"
        case .environmentalSingle: "heat"
        case .information: "partlycloudy"
        case .media: "playing"
        case .presence: "home"
        case .editableNumber: "45"
        case .editableSelect: "Home"
        case .editableText: "Welcome home"
        case .editableTemporal: "22:30:00"
        }
    }

    private var baseAttributes: [String: JSONValue] {
        switch self {
        case .simpleControl:
            [
                "friendly_name": .string("Reading Lamp"),
                "brightness": .number(184)
            ]
        case .momentaryAction:
            [
                "friendly_name": .string("Arrive Home")
            ]
        case .metric:
            [
                "friendly_name": .string("Front Door Battery"),
                "device_class": .string("battery"),
                "unit_of_measurement": .string("%")
            ]
        case .history:
            [
                "friendly_name": .string("Living Room Temperature"),
                "device_class": .string("temperature"),
                "state_class": .string("measurement"),
                "unit_of_measurement": .string("°F")
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
                "target_temp_low": .number(66),
                "target_temp_high": .number(67),
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
        case .environmentalSingle:
            [
                "friendly_name": .string("Upstairs"),
                "current_temperature": .number(68),
                "temperature": .number(70),
                "temperature_unit": .string("°F"),
                "min_temp": .number(50),
                "max_temp": .number(90),
                "target_temp_step": .number(1),
                "hvac_modes": .array([.string("off"), .string("heat"), .string("cool")])
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
                "supported_features": .number(7),
                "attribution": .string("Weather forecast from met.no, delivered by the Norwegian Meteorological Institute.")
            ]
        case .media:
            [
                "friendly_name": .string("Living Room TV"),
                "volume_level": .number(0.42),
                "source": .string("Apple TV"),
                "source_list": .array([.string("Apple TV"), .string("Music"), .string("Game Console")]),
                "media_title": .string("Morning Mix"),
                "media_artist": .string("Homestead Radio")
            ]
        case .presence:
            [
                "friendly_name": .string("Tyler"),
                "source": .string("device_tracker.tylers_iphone"),
                "entity_picture": .string("/api/image/preview-person"),
                "gps_accuracy": .number(20)
            ]
        case .editableNumber:
            [
                "friendly_name": .string("Target Humidity"),
                "device_class": .string("humidity"),
                "unit_of_measurement": .string("%"),
                "min": .number(30),
                "max": .number(60),
                "step": .number(1)
            ]
        case .editableSelect:
            [
                "friendly_name": .string("House Mode"),
                "options": .array([
                    .string("Home"),
                    .string("Away"),
                    .string("Morning Routine With A Deliberately Long Name")
                ])
            ]
        case .editableText:
            [
                "friendly_name": .string("Guest Message"),
                "min": .number(0),
                "max": .number(64),
                "mode": .string("text")
            ]
        case .editableTemporal:
            [
                "friendly_name": .string("Quiet Hours Start"),
                "has_date": .bool(false),
                "has_time": .bool(true)
            ]
        }
    }

    private func applyExtreme(
        isMaximum: Bool,
        state: inout String,
        attributes: inout [String: JSONValue]
    ) {
        switch self {
        case .simpleControl:
            state = isMaximum ? "on" : "off"
            attributes["brightness"] = .number(isMaximum ? 255 : 1)
        case .momentaryAction:
            state = isMaximum ? "on" : "off"
        case .metric:
            state = isMaximum ? "100" : "0"
        case .history:
            state = isMaximum ? "120" : "0"
        case .positional:
            state = isMaximum ? "open" : "closed"
            attributes["current_position"] = .number(isMaximum ? 100 : 0)
        case .environmental, .environmentalSingle:
            attributes["current_temperature"] = .number(isMaximum ? 90 : 50)
            attributes["temperature"] = .number(isMaximum ? 90 : 50)
            attributes["target_temp_low"] = .number(isMaximum ? 90 : 50)
            attributes["target_temp_high"] = .number(isMaximum ? 90 : 50)
        case .information:
            attributes["temperature"] = .number(isMaximum ? 110 : -5)
        case .media:
            state = isMaximum ? "playing" : "idle"
            attributes["volume_level"] = .number(isMaximum ? 1 : 0)
        case .presence:
            state = isMaximum ? "home" : "not_home"
        case .editableNumber:
            state = isMaximum ? "60" : "30"
        case .editableSelect:
            state = isMaximum ? "Morning Routine With A Deliberately Long Name" : "Home"
        case .editableText:
            state = isMaximum ? String(repeating: "W", count: 64) : ""
        case .editableTemporal:
            state = isMaximum ? "23:59:00" : "00:00:00"
        }
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_784_515_200)
}

private enum EntityDetailReferenceVariant: String, CaseIterable, Identifiable {
    case live
    case loading
    case empty
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
        case .loading: "Loading"
        case .empty: "Empty"
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
            pendingCommand: pendingCommand(for: family),
            contentState: contentState
        )
    }

    private var contentState: PreviewEntityDetailContentState {
        switch self {
        case .loading: .loading
        case .empty: .empty
        case .failed: .failed
        default: .loaded
        }
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

    @MainActor
    func configureForecastFixture(
        _ entityBox: HAEntityState?,
        family: EntityDetailReferenceFamily
    ) {
        guard family == .information, let entityBox else { return }

        switch self {
        case .loading:
            entityBox.beginLoadingWeatherForecast(.daily)
            entityBox.beginLoadingWeatherForecast(.hourly)
        case .empty:
            entityBox.applyWeatherForecast(WeatherForecastSnapshot(
                type: .daily,
                entries: [],
                receivedAt: Self.referenceDate
            ))
            entityBox.applyWeatherForecast(WeatherForecastSnapshot(
                type: .hourly,
                entries: [],
                receivedAt: Self.referenceDate
            ))
        case .failed:
            entityBox.failLoadingWeatherForecast(
                .daily,
                message: "Forecast is temporarily unavailable."
            )
            entityBox.failLoadingWeatherForecast(
                .hourly,
                message: "Forecast is temporarily unavailable."
            )
        default:
            entityBox.applyWeatherForecast(Self.referenceForecast)
            entityBox.applyWeatherForecast(Self.referenceHourlyForecast)
        }
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_784_515_200)

    private static let referenceForecast = WeatherForecastSnapshot(
        type: .daily,
        entries: [
            WeatherForecastEntry(
                datetime: forecastReferenceDate,
                condition: .partlyCloudy,
                temperature: 83,
                lowTemperature: 68,
                precipitation: nil,
                precipitationProbability: 20,
                humidity: 58,
                isDaytime: true,
                windSpeed: 8,
                windBearing: 225
            ),
            WeatherForecastEntry(
                datetime: forecastReferenceDate.addingTimeInterval(86_400),
                condition: .rainy,
                temperature: 76,
                lowTemperature: 65,
                precipitation: nil,
                precipitationProbability: 70,
                humidity: 72,
                isDaytime: true,
                windSpeed: 11,
                windBearing: 180
            )
        ],
        receivedAt: forecastReferenceDate
    )

    private static let referenceHourlyForecast = WeatherForecastSnapshot(
        type: .hourly,
        entries: (0..<8).map { referenceHourlyEntry(hour: $0) },
        receivedAt: forecastReferenceDate
    )

    private static let forecastReferenceDate = Calendar.autoupdatingCurrent
        .startOfDay(for: .now)
        .addingTimeInterval(12 * 3_600)

    private static func referenceHourlyEntry(hour: Int) -> WeatherForecastEntry {
        WeatherForecastEntry(
            datetime: forecastReferenceDate.addingTimeInterval(TimeInterval(hour * 3_600)),
            condition: hour < 3 ? .partlyCloudy : .sunny,
            temperature: 73 + Double(hour),
            lowTemperature: nil,
            precipitation: nil,
            precipitationProbability: hour == 2 ? 20 : 0,
            humidity: 56,
            isDaytime: true,
            windSpeed: 8,
            windBearing: 225
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

#Preview("Select - Accessibility", traits: .fixedLayout(width: 430, height: 932)) {
    EntityDetailReferenceScene(family: .editableSelect, variant: .live)
        .dynamicTypeSize(.accessibility3)
}

@MainActor
struct EntityDetailCardContextPreviewScreen: View {
    private let dependencies: PreviewDependencies
    private let destination: EntityDetailDestination

    init() {
        let dependencies = PreviewDependencies.sample
        let dashboardID = dependencies.dashboardConfiguration.selectedDashboardID
        let itemID = dependencies.dashboardConfiguration.add(
            source: .entity("sensor.hallway_temperature"),
            presentation: .card(.chart(layout: .wide))
        ) ?? UUID()
        self.dependencies = dependencies
        destination = EntityDetailDestination(
            entityID: "sensor.hallway_temperature",
            initialSection: .history(initialRange: .sixHours),
            surfaceContext: .home,
            dashboardItemReference: DashboardItemReference(
                dashboardID: dashboardID,
                itemID: itemID
            )
        )
    }

    var body: some View {
        NavigationStack {
            EntityDetailDestinationView(destination: destination)
        }
        .withPreviewEnvironment(dependencies)
    }
}

#Preview("Dashboard Card Context") {
    EntityDetailCardContextPreviewScreen()
}
#endif
