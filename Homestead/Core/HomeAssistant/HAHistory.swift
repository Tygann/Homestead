import Foundation

nonisolated struct HAHistoryRequest: Equatable, Sendable {
    let startDate: Date
    let endDate: Date
    let entityID: String
    let minimalResponse: Bool
    let noAttributes: Bool
    let significantChangesOnly: Bool

    init(
        startDate: Date,
        endDate: Date,
        entityID: String,
        minimalResponse: Bool = true,
        noAttributes: Bool = true,
        significantChangesOnly: Bool = false
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.entityID = entityID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.minimalResponse = minimalResponse
        self.noAttributes = noAttributes
        self.significantChangesOnly = significantChangesOnly
    }
}

nonisolated struct HAHistoryResponseDTO: Decodable, Equatable, Sendable {
    let series: [[HAHistoryStateDTO]]

    init(series: [[HAHistoryStateDTO]]) {
        self.series = series
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        series = try container.decode([[HAHistoryStateDTO]].self)
    }
}

nonisolated struct HAHistoryStateDTO: Decodable, Equatable, Sendable {
    let entityID: String?
    let state: String
    let lastChanged: Date
    let lastUpdated: Date?
    let attributes: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case state
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
        case attributes
    }

    init(
        entityID: String? = nil,
        state: String,
        lastChanged: Date,
        lastUpdated: Date? = nil,
        attributes: [String: JSONValue]? = nil
    ) {
        self.entityID = entityID
        self.state = state
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
        self.attributes = attributes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lastChangedString = try container.decode(String.self, forKey: .lastChanged)
        guard let lastChanged = HADateParser.date(from: lastChangedString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .lastChanged,
                in: container,
                debugDescription: "Expected Home Assistant history last_changed timestamp."
            )
        }

        let lastUpdatedString = try container.decodeIfPresent(String.self, forKey: .lastUpdated)
        if let lastUpdatedString, let parsedLastUpdated = HADateParser.date(from: lastUpdatedString) {
            lastUpdated = parsedLastUpdated
        } else {
            lastUpdated = nil
        }

        entityID = try container.decodeIfPresent(String.self, forKey: .entityID)
        state = try container.decode(String.self, forKey: .state)
        self.lastChanged = lastChanged
        attributes = try container.decodeIfPresent([String: JSONValue].self, forKey: .attributes)
    }
}

nonisolated enum HAHistoryRangePreset: String, CaseIterable, Identifiable, Equatable, Sendable {
    case oneHour
    case sixHours
    case day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneHour:
            "1H"
        case .sixHours:
            "6H"
        case .day:
            "24H"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .oneHour:
            "Last hour"
        case .sixHours:
            "Last 6 hours"
        case .day:
            "Last 24 hours"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .oneHour:
            60 * 60
        case .sixHours:
            6 * 60 * 60
        case .day:
            24 * 60 * 60
        }
    }

    func interval(endingAt endDate: Date = Date()) -> DateInterval {
        DateInterval(start: endDate.addingTimeInterval(-duration), end: endDate)
    }
}

nonisolated struct HAHistorySample: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let value: Double

    init(occurredAt: Date, value: Double) {
        self.id = "\(occurredAt.timeIntervalSince1970)-\(value)"
        self.occurredAt = occurredAt
        self.value = value
    }
}

nonisolated struct HAHistoryChartSeries: Equatable, Sendable {
    let entityID: String
    let displayName: String
    let unit: String?
    let range: HAHistoryRangePreset
    let samples: [HAHistorySample]

    var isEmpty: Bool {
        samples.isEmpty
    }

    var latestSample: HAHistorySample? {
        samples.last
    }

    var minimumValue: Double? {
        samples.map(\.value).min()
    }

    var maximumValue: Double? {
        samples.map(\.value).max()
    }

    var valueDomain: ClosedRange<Double> {
        guard let minimumValue, let maximumValue else {
            return 0...1
        }

        guard minimumValue != maximumValue else {
            let padding = max(abs(minimumValue) * 0.05, 1)
            return (minimumValue - padding)...(maximumValue + padding)
        }

        let padding = (maximumValue - minimumValue) * 0.12
        return (minimumValue - padding)...(maximumValue + padding)
    }

    var summaryText: String {
        guard !samples.isEmpty,
              let minimumValue,
              let maximumValue,
              let latestSample else {
            return "No recorded numeric history"
        }

        return "Now \(formatValue(latestSample.value)) • Low \(formatValue(minimumValue)) • High \(formatValue(maximumValue))"
    }

    func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.minimumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        guard let unit, !unit.isEmpty else {
            return numberText
        }

        let separator = unit.hasPrefix("°") || unit == "%" ? "" : " "
        return "\(numberText)\(separator)\(unit)"
    }

    static func make(
        response: HAHistoryResponseDTO,
        request: HAHistoryRequest,
        displayName: String,
        unit: String?,
        range: HAHistoryRangePreset
    ) -> HAHistoryChartSeries {
        let interval = DateInterval(start: request.startDate, end: request.endDate)
        let samples = numericSamples(
            from: response.series.flatMap { $0 },
            fallbackEntityID: request.entityID,
            matching: request.entityID,
            interval: interval
        )

        return HAHistoryChartSeries(
            entityID: request.entityID,
            displayName: displayName,
            unit: unit,
            range: range,
            samples: samples
        )
    }

    static func numericSamples(
        from states: [HAHistoryStateDTO],
        fallbackEntityID: String,
        matching entityID: String,
        interval: DateInterval
    ) -> [HAHistorySample] {
        states.compactMap { state in
            let resolvedEntityID = state.entityID?.nonEmptyHistoryValue ?? fallbackEntityID
            guard resolvedEntityID == entityID,
                  interval.contains(state.lastChanged) || state.lastChanged == interval.end,
                  let value = Double(state.state),
                  value.isFinite else {
                return nil
            }

            return HAHistorySample(occurredAt: state.lastChanged, value: value)
        }
        .sorted { lhs, rhs in
            lhs.occurredAt < rhs.occurredAt
        }
    }

    private var maximumFractionDigits: Int {
        let values = samples.map(\.value)
        guard values.contains(where: { abs($0.rounded() - $0) > 0.001 }) else {
            return 0
        }

        return 2
    }
}

nonisolated enum HAHistoryTimelineTone: Equatable, Sendable {
    case active
    case inactive
    case unavailable
}

nonisolated enum HAHistoryTimelineDomain: Equatable, Sendable {
    case binarySensor(BinarySensorDisplayKind)
    case lock
    case `switch`
    case automation
    case cover(deviceClass: String?)
    case person
    case deviceTracker
}

nonisolated struct HAHistoryTimelineEntry: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let state: String
    let title: String
    let systemImage: String
    let tone: HAHistoryTimelineTone

    init(
        occurredAt: Date,
        state: String,
        title: String,
        systemImage: String,
        tone: HAHistoryTimelineTone
    ) {
        self.id = "\(occurredAt.timeIntervalSince1970)-\(state)"
        self.occurredAt = occurredAt
        self.state = state
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
    }
}

nonisolated struct HAHistoryTimeline: Equatable, Sendable {
    let entityID: String
    let displayName: String
    let range: HAHistoryRangePreset
    let entries: [HAHistoryTimelineEntry]

    var isEmpty: Bool {
        entries.isEmpty
    }

    var latestEntry: HAHistoryTimelineEntry? {
        entries.last
    }

    var summaryText: String {
        guard !entries.isEmpty else {
            return "No state changes in \(range.accessibilityTitle.lowercased())"
        }

        let changeText = entries.count == 1 ? "1 change" : "\(entries.count) changes"
        guard let latestEntry else {
            return changeText
        }

        return "\(changeText) • Now \(latestEntry.title)"
    }

    static func makeBinarySensorTimeline(
        response: HAHistoryResponseDTO,
        request: HAHistoryRequest,
        displayName: String,
        deviceClass: String?,
        range: HAHistoryRangePreset
    ) -> HAHistoryTimeline {
        let interval = DateInterval(start: request.startDate, end: request.endDate)
        let displayKind = BinarySensorDisplayKind(deviceClass: deviceClass)
        let entries = binarySensorEntries(
            from: response.series.flatMap { $0 },
            fallbackEntityID: request.entityID,
            matching: request.entityID,
            interval: interval,
            displayKind: displayKind
        )

        return HAHistoryTimeline(
            entityID: request.entityID,
            displayName: displayName,
            range: range,
            entries: entries
        )
    }

    static func makeLockTimeline(
        response: HAHistoryResponseDTO,
        request: HAHistoryRequest,
        displayName: String,
        range: HAHistoryRangePreset
    ) -> HAHistoryTimeline {
        makeTimeline(
            response: response,
            request: request,
            displayName: displayName,
            domain: .lock,
            range: range
        )
    }

    static func makeTimeline(
        response: HAHistoryResponseDTO,
        request: HAHistoryRequest,
        displayName: String,
        domain: HAHistoryTimelineDomain,
        range: HAHistoryRangePreset
    ) -> HAHistoryTimeline {
        let interval = DateInterval(start: request.startDate, end: request.endDate)
        let entries = entries(
            from: response.series.flatMap { $0 },
            fallbackEntityID: request.entityID,
            matching: request.entityID,
            interval: interval,
            domain: domain
        )

        return HAHistoryTimeline(
            entityID: request.entityID,
            displayName: displayName,
            range: range,
            entries: entries
        )
    }

    static func entries(
        from states: [HAHistoryStateDTO],
        fallbackEntityID: String,
        matching entityID: String,
        interval: DateInterval,
        domain: HAHistoryTimelineDomain
    ) -> [HAHistoryTimelineEntry] {
        states
            .compactMap { state -> HAHistoryTimelineEntry? in
                let resolvedEntityID = state.entityID?.nonEmptyHistoryValue ?? fallbackEntityID
                guard resolvedEntityID == entityID,
                      interval.contains(state.lastChanged) || state.lastChanged == interval.end else {
                    return nil
                }

                return entry(state: state.state, occurredAt: state.lastChanged, domain: domain)
            }
            .sorted { lhs, rhs in
                lhs.occurredAt < rhs.occurredAt
            }
            .removingConsecutiveDuplicateStates()
    }

    static func binarySensorEntries(
        from states: [HAHistoryStateDTO],
        fallbackEntityID: String,
        matching entityID: String,
        interval: DateInterval,
        displayKind: BinarySensorDisplayKind
    ) -> [HAHistoryTimelineEntry] {
        entries(
            from: states,
            fallbackEntityID: fallbackEntityID,
            matching: entityID,
            interval: interval,
            domain: .binarySensor(displayKind)
        )
    }

    static func lockEntries(
        from states: [HAHistoryStateDTO],
        fallbackEntityID: String,
        matching entityID: String,
        interval: DateInterval
    ) -> [HAHistoryTimelineEntry] {
        entries(
            from: states,
            fallbackEntityID: fallbackEntityID,
            matching: entityID,
            interval: interval,
            domain: .lock
        )
    }

    private static func entry(
        state: String,
        occurredAt: Date,
        domain: HAHistoryTimelineDomain
    ) -> HAHistoryTimelineEntry? {
        switch domain {
        case .binarySensor(let displayKind):
            return binarySensorEntry(
                state: state,
                occurredAt: occurredAt,
                displayKind: displayKind
            )
        case .lock:
            return lockEntry(state: state, occurredAt: occurredAt)
        case .switch:
            return onOffEntry(
                state: state,
                occurredAt: occurredAt,
                activeTitle: "Turned On",
                inactiveTitle: "Turned Off",
                activeSystemImage: "lightswitch.on.fill",
                inactiveSystemImage: "lightswitch.off.fill"
            )
        case .automation:
            return onOffEntry(
                state: state,
                occurredAt: occurredAt,
                activeTitle: "Enabled",
                inactiveTitle: "Disabled",
                activeSystemImage: "calendar.badge.clock",
                inactiveSystemImage: "calendar"
            )
        case .cover(let deviceClass):
            return coverEntry(state: state, occurredAt: occurredAt, deviceClass: deviceClass)
        case .person:
            return presenceEntry(
                state: state,
                occurredAt: occurredAt,
                homeSystemImage: "person.fill",
                awaySystemImage: "person"
            )
        case .deviceTracker:
            return presenceEntry(
                state: state,
                occurredAt: occurredAt,
                homeSystemImage: "location.fill",
                awaySystemImage: "location"
            )
        }
    }

    private static func binarySensorEntry(
        state: String,
        occurredAt: Date,
        displayKind: BinarySensorDisplayKind
    ) -> HAHistoryTimelineEntry? {
        switch state {
        case "on":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: displayKind.activeTimelineTitle,
                systemImage: displayKind.activeTimelineSystemImage,
                tone: .active
            )
        case "off":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: displayKind.inactiveTimelineTitle,
                systemImage: displayKind.inactiveTimelineSystemImage,
                tone: .inactive
            )
        case "unknown":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unknown",
                systemImage: "questionmark.circle",
                tone: .unavailable
            )
        case "unavailable":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unavailable",
                systemImage: "exclamationmark.triangle",
                tone: .unavailable
            )
        default:
            nil
        }
    }

    private static func onOffEntry(
        state: String,
        occurredAt: Date,
        activeTitle: String,
        inactiveTitle: String,
        activeSystemImage: String,
        inactiveSystemImage: String
    ) -> HAHistoryTimelineEntry? {
        switch state {
        case "on":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: activeTitle,
                systemImage: activeSystemImage,
                tone: .active
            )
        case "off":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: inactiveTitle,
                systemImage: inactiveSystemImage,
                tone: .inactive
            )
        case "unknown":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unknown",
                systemImage: "questionmark.circle",
                tone: .unavailable
            )
        case "unavailable":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unavailable",
                systemImage: "exclamationmark.triangle",
                tone: .unavailable
            )
        default:
            nil
        }
    }

    private static func coverEntry(
        state: String,
        occurredAt: Date,
        deviceClass: String?
    ) -> HAHistoryTimelineEntry? {
        switch state {
        case "open":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Opened",
                systemImage: coverSystemImage(deviceClass: deviceClass, isOpen: true),
                tone: .active
            )
        case "closed":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Closed",
                systemImage: coverSystemImage(deviceClass: deviceClass, isOpen: false),
                tone: .inactive
            )
        case "opening":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Opening",
                systemImage: coverSystemImage(deviceClass: deviceClass, isOpen: true),
                tone: .active
            )
        case "closing":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Closing",
                systemImage: coverSystemImage(deviceClass: deviceClass, isOpen: false),
                tone: .inactive
            )
        case "unknown":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unknown",
                systemImage: "questionmark.circle",
                tone: .unavailable
            )
        case "unavailable":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unavailable",
                systemImage: "exclamationmark.triangle",
                tone: .unavailable
            )
        default:
            nil
        }
    }

    private static func presenceEntry(
        state: String,
        occurredAt: Date,
        homeSystemImage: String,
        awaySystemImage: String
    ) -> HAHistoryTimelineEntry? {
        switch state {
        case "home":
            return HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Home",
                systemImage: homeSystemImage,
                tone: .active
            )
        case "not_home":
            return HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Away",
                systemImage: awaySystemImage,
                tone: .inactive
            )
        case "unknown":
            return HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unknown",
                systemImage: "questionmark.circle",
                tone: .unavailable
            )
        case "unavailable":
            return HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unavailable",
                systemImage: "exclamationmark.triangle",
                tone: .unavailable
            )
        default:
            guard let locationTitle = state.locationTimelineTitle else {
                return nil
            }

            return HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "At \(locationTitle)",
                systemImage: "mappin.and.ellipse",
                tone: .active
            )
        }
    }

    private static func coverSystemImage(deviceClass: String?, isOpen: Bool) -> String {
        switch deviceClass {
        case "garage":
            isOpen ? "door.garage.open" : "door.garage.closed"
        case "gate":
            isOpen ? "pedestrian.gate.open" : "pedestrian.gate.closed"
        case "door":
            isOpen ? "door.left.hand.open" : "door.left.hand.closed"
        case "window":
            isOpen ? "window.vertical.open" : "window.vertical.closed"
        case "curtain":
            isOpen ? "curtains.open" : "curtains.closed"
        case "awning":
            isOpen ? "window.awning" : "window.awning.closed"
        case "blind":
            isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        case "shade":
            isOpen ? "window.shade.open" : "window.shade.closed"
        case "shutter":
            isOpen ? "blinds.vertical.open" : "blinds.vertical.closed"
        default:
            isOpen ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        }
    }

    private static func lockEntry(state: String, occurredAt: Date) -> HAHistoryTimelineEntry? {
        switch state {
        case "locked":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Locked",
                systemImage: "lock.fill",
                tone: .inactive
            )
        case "unlocked":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unlocked",
                systemImage: "lock.open.fill",
                tone: .active
            )
        case "locking":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Locking",
                systemImage: "lock.fill",
                tone: .inactive
            )
        case "unlocking":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unlocking",
                systemImage: "lock.open.fill",
                tone: .active
            )
        case "jammed":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Jammed",
                systemImage: "exclamationmark.triangle.fill",
                tone: .unavailable
            )
        case "unknown":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unknown",
                systemImage: "questionmark.circle",
                tone: .unavailable
            )
        case "unavailable":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unavailable",
                systemImage: "exclamationmark.triangle",
                tone: .unavailable
            )
        default:
            nil
        }
    }
}

nonisolated private extension Array where Element == HAHistoryTimelineEntry {
    func removingConsecutiveDuplicateStates() -> [HAHistoryTimelineEntry] {
        reduce(into: [HAHistoryTimelineEntry]()) { entries, entry in
            guard entries.last?.state != entry.state else {
                return
            }

            entries.append(entry)
        }
    }
}

nonisolated private extension BinarySensorDisplayKind {
    var activeTimelineTitle: String {
        switch self {
        case .door, .window, .garageDoor, .opening:
            "Opened"
        case .lock:
            "Unlocked"
        case .moisture:
            "Wet"
        case .battery:
            "Low Battery"
        case .batteryCharging:
            "Charging"
        case .cold:
            "Cold"
        case .carbonMonoxide:
            "CO Detected"
        case .heat:
            "Heat Detected"
        case .moving:
            "Moving"
        case .running:
            "Running"
        case .sound:
            "Sound Detected"
        case .update:
            "Update Available"
        case .connectivity:
            "Connected"
        case .plug, .power:
            "On"
        case .light:
            "Light"
        case .motion, .occupancy, .presence, .tamper, .safety, .problem, .smoke, .gas, .vibration, .generic:
            "Detected"
        }
    }

    var inactiveTimelineTitle: String {
        switch self {
        case .door, .window, .garageDoor, .opening:
            "Closed"
        case .lock:
            "Locked"
        case .moisture:
            "Dry"
        case .battery:
            "Battery OK"
        case .batteryCharging:
            "Not Charging"
        case .cold:
            "Normal"
        case .carbonMonoxide, .heat, .motion, .occupancy, .presence, .tamper, .safety, .problem, .smoke, .gas, .sound, .vibration, .generic:
            "Clear"
        case .moving:
            "Stationary"
        case .running:
            "Stopped"
        case .update:
            "Up to Date"
        case .connectivity:
            "Disconnected"
        case .plug, .power:
            "Off"
        case .light:
            "Clear"
        }
    }

    var activeTimelineSystemImage: String {
        switch self {
        case .door:
            "door.left.hand.open"
        case .window:
            "window.vertical.open"
        case .garageDoor:
            "door.garage.open"
        case .opening:
            "rectangle.portrait.and.arrow.right"
        case .lock:
            "lock.open.fill"
        case .motion, .occupancy, .presence:
            "figure.motion"
        case .tamper, .safety, .problem:
            "exclamationmark.triangle.fill"
        case .smoke:
            "smoke.fill"
        case .gas:
            "flame.fill"
        case .moisture:
            "drop.fill"
        case .battery:
            "battery.25percent"
        case .batteryCharging:
            "battery.100percent.bolt"
        case .cold:
            "snowflake"
        case .carbonMonoxide:
            "carbon.monoxide.cloud.fill"
        case .heat:
            "heat.waves"
        case .moving:
            "figure.walk.motion"
        case .running:
            "figure.run"
        case .sound:
            "speaker.wave.2.fill"
        case .update:
            "arrow.trianglehead.2.clockwise"
        case .vibration:
            "waveform.path"
        case .connectivity:
            "wifi"
        case .plug:
            "powerplug.fill"
        case .power:
            "power.circle.fill"
        case .light:
            "lightbulb.fill"
        case .generic:
            "sensor.tag.radiowaves.forward.fill"
        }
    }

    var inactiveTimelineSystemImage: String {
        switch self {
        case .door:
            "door.left.hand.closed"
        case .window:
            "window.vertical.closed"
        case .garageDoor:
            "door.garage.closed"
        case .opening:
            "rectangle.portrait"
        case .lock:
            "lock.fill"
        case .motion, .occupancy, .presence, .moving, .running:
            "figure.stand"
        case .tamper, .safety, .problem:
            "checkmark.shield"
        case .smoke:
            "smoke"
        case .gas:
            "flame"
        case .moisture:
            "drop"
        case .battery, .batteryCharging:
            "battery.100percent"
        case .cold:
            "snowflake"
        case .carbonMonoxide:
            "carbon.monoxide.cloud"
        case .heat:
            "heat.waves"
        case .sound:
            "speaker"
        case .update:
            "checkmark.circle"
        case .vibration:
            "waveform"
        case .connectivity:
            "wifi.slash"
        case .plug:
            "powerplug"
        case .power:
            "power.circle"
        case .light:
            "lightbulb"
        case .generic:
            "sensor.tag.radiowaves.forward"
        }
    }
}

nonisolated private extension String {
    var nonEmptyHistoryValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    var locationTimelineTitle: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                let lowercasedWord = word.lowercased()
                return lowercasedWord.prefix(1).uppercased() + String(lowercasedWord.dropFirst())
            }
            .joined(separator: " ")
    }
}
