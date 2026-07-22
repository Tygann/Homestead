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

nonisolated enum HAHistoryRangePreset: String, CaseIterable, Identifiable, Codable, Equatable, Hashable, Sendable {
    case oneHour
    case sixHours
    case day
    case week
    case month

    static let activityPresets: [Self] = [.sixHours, .day, .week, .month]
    static let sensorChartPresets: [Self] = [.sixHours, .day, .week, .month]
    static let dashboardChartPresets: [Self] = [.oneHour, .sixHours, .day, .week]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneHour:
            "1H"
        case .sixHours:
            "6H"
        case .day:
            "24H"
        case .week:
            "7D"
        case .month:
            "30D"
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
        case .week:
            "Last 7 days"
        case .month:
            "Last 30 days"
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
        case .week:
            7 * 24 * 60 * 60
        case .month:
            30 * 24 * 60 * 60
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
    let displayPrecision: Int?
    let range: HAHistoryRangePreset
    let samples: [HAHistorySample]
    let requestedInterval: DateInterval?

    init(
        entityID: String,
        displayName: String,
        unit: String?,
        displayPrecision: Int? = nil,
        range: HAHistoryRangePreset,
        samples: [HAHistorySample],
        requestedInterval: DateInterval? = nil
    ) {
        self.entityID = entityID
        self.displayName = displayName
        self.unit = unit
        self.displayPrecision = displayPrecision
        self.range = range
        self.samples = samples
        self.requestedInterval = requestedInterval
    }

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

    var averageValue: Double? {
        guard let firstSample = samples.first else { return nil }
        guard samples.count > 1 else { return firstSample.value }

        let coverageEnd = max(requestedInterval?.end ?? samples.last?.occurredAt ?? firstSample.occurredAt,
                              samples.last?.occurredAt ?? firstSample.occurredAt)
        var weightedTotal = 0.0
        var coveredDuration = 0.0

        for (index, sample) in samples.enumerated() {
            let nextDate = index + 1 < samples.count ? samples[index + 1].occurredAt : coverageEnd
            let duration = max(nextDate.timeIntervalSince(sample.occurredAt), 0)
            weightedTotal += sample.value * duration
            coveredDuration += duration
        }

        guard coveredDuration > 0 else {
            return samples.map(\.value).reduce(0, +) / Double(samples.count)
        }
        return weightedTotal / coveredDuration
    }

    var valueDomain: ClosedRange<Double> {
        valueDomain(preferredRange: nil)
    }

    func valueDomain(preferredRange: ClosedRange<Double>?) -> ClosedRange<Double> {
        guard let minimumValue, let maximumValue else {
            return 0...1
        }

        let adaptiveDomain: ClosedRange<Double>
        guard minimumValue != maximumValue else {
            let padding = max(abs(minimumValue) * 0.05, 1)
            adaptiveDomain = (minimumValue - padding)...(maximumValue + padding)
            return constrainedDomain(adaptiveDomain, preferredRange: preferredRange)
        }

        let padding = (maximumValue - minimumValue) * 0.12
        adaptiveDomain = (minimumValue - padding)...(maximumValue + padding)
        return constrainedDomain(adaptiveDomain, preferredRange: preferredRange)
    }

    var coverageNotice: String? {
        guard let requestedInterval,
              let firstSample = samples.first,
              firstSample.occurredAt > requestedInterval.start.addingTimeInterval(range.duration * 0.05) else {
            return nil
        }

        return "History available since \(firstSample.occurredAt.formatted(date: .abbreviated, time: .shortened))."
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

    func chartSamples(maxCount: Int = 240) -> [HAHistorySample] {
        guard maxCount >= 4, samples.count > maxCount else {
            return samples
        }

        let interiorSamples = Array(samples.dropFirst().dropLast())
        let bucketCount = max((maxCount - 2) / 2, 1)
        let bucketSize = max(Int(ceil(Double(interiorSamples.count) / Double(bucketCount))), 1)
        var result = [samples[0]]

        for bucketStart in stride(from: 0, to: interiorSamples.count, by: bucketSize) {
            let bucketEnd = min(bucketStart + bucketSize, interiorSamples.count)
            let bucket = interiorSamples[bucketStart..<bucketEnd]
            guard let minimum = bucket.min(by: { $0.value < $1.value }),
                  let maximum = bucket.max(by: { $0.value < $1.value }) else {
                continue
            }

            if minimum.occurredAt <= maximum.occurredAt {
                result.append(minimum)
                if maximum.id != minimum.id { result.append(maximum) }
            } else {
                result.append(maximum)
                if maximum.id != minimum.id { result.append(minimum) }
            }
        }

        result.append(samples[samples.count - 1])
        return result
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
            samples: samples,
            requestedInterval: interval
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
        if let displayPrecision {
            return max(displayPrecision, 0)
        }

        let values = samples.map(\.value)
        guard values.contains(where: { abs($0.rounded() - $0) > 0.001 }) else {
            return 0
        }

        return 2
    }

    private func constrainedDomain(
        _ adaptiveDomain: ClosedRange<Double>,
        preferredRange: ClosedRange<Double>?
    ) -> ClosedRange<Double> {
        guard let preferredRange,
              preferredRange.lowerBound < preferredRange.upperBound,
              let minimumValue,
              let maximumValue,
              preferredRange.contains(minimumValue),
              preferredRange.contains(maximumValue) else {
            return adaptiveDomain
        }

        let lowerBound = max(adaptiveDomain.lowerBound, preferredRange.lowerBound)
        let upperBound = min(adaptiveDomain.upperBound, preferredRange.upperBound)
        guard lowerBound < upperBound else { return adaptiveDomain }
        return lowerBound...upperBound
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
    let resolvedIcon: ResolvedIcon
    let tone: HAHistoryTimelineTone

    var systemImage: String {
        resolvedIcon.sfSymbolName
    }

    init(
        occurredAt: Date,
        state: String,
        title: String,
        resolvedIcon: ResolvedIcon,
        tone: HAHistoryTimelineTone
    ) {
        self.id = "\(occurredAt.timeIntervalSince1970)-\(state)"
        self.occurredAt = occurredAt
        self.state = state
        self.title = title
        self.resolvedIcon = resolvedIcon
        self.tone = tone
    }

    init(
        occurredAt: Date,
        state: String,
        title: String,
        systemImage: String,
        tone: HAHistoryTimelineTone
    ) {
        self.init(
            occurredAt: occurredAt,
            state: state,
            title: title,
            resolvedIcon: .sfSymbol(systemImage, provenance: .homesteadSemanticMapping),
            tone: tone
        )
    }
}

nonisolated struct HAHistoryTimeline: Equatable, Sendable {
    let entityID: String
    let displayName: String
    let range: HAHistoryRangePreset
    let entries: [HAHistoryTimelineEntry]
    let emptyMessage: String
    let summaryNoun: String

    init(
        entityID: String,
        displayName: String,
        range: HAHistoryRangePreset,
        entries: [HAHistoryTimelineEntry],
        emptyMessage: String? = nil,
        summaryNoun: String = "change"
    ) {
        self.entityID = entityID
        self.displayName = displayName
        self.range = range
        self.entries = entries
        self.emptyMessage = emptyMessage ?? "No state changes in \(range.accessibilityTitle.lowercased())"
        self.summaryNoun = summaryNoun
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    var latestEntry: HAHistoryTimelineEntry? {
        entries.last
    }

    var summaryText: String {
        guard !entries.isEmpty else {
            return emptyMessage
        }

        let changeText = entries.count == 1 ? "1 \(summaryNoun)" : "\(entries.count) \(summaryNoun)s"
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
                domain: "switch",
                activeTitle: "Turned On",
                inactiveTitle: "Turned Off"
            )
        case .automation:
            return onOffEntry(
                state: state,
                occurredAt: occurredAt,
                domain: "automation",
                activeTitle: "Enabled",
                inactiveTitle: "Disabled"
            )
        case .cover(let deviceClass):
            return coverEntry(state: state, occurredAt: occurredAt, deviceClass: deviceClass)
        case .person:
            return presenceEntry(
                state: state,
                occurredAt: occurredAt,
                domain: "person"
            )
        case .deviceTracker:
            return presenceEntry(
                state: state,
                occurredAt: occurredAt,
                domain: "device_tracker"
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
                resolvedIcon: IconResolver.historicalEntityIcon(
                    domain: "binary_sensor",
                    deviceClass: displayKind.haDeviceClass,
                    state: state
                ),
                tone: .active
            )
        case "off":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: displayKind.inactiveTimelineTitle,
                resolvedIcon: IconResolver.historicalEntityIcon(
                    domain: "binary_sensor",
                    deviceClass: displayKind.haDeviceClass,
                    state: state
                ),
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
        domain: String,
        activeTitle: String,
        inactiveTitle: String
    ) -> HAHistoryTimelineEntry? {
        switch state {
        case "on":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: activeTitle,
                resolvedIcon: IconResolver.historicalEntityIcon(domain: domain, deviceClass: nil, state: state),
                tone: .active
            )
        case "off":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: inactiveTitle,
                resolvedIcon: IconResolver.historicalEntityIcon(domain: domain, deviceClass: nil, state: state),
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
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "cover", deviceClass: deviceClass, state: state),
                tone: .active
            )
        case "closed":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Closed",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "cover", deviceClass: deviceClass, state: state),
                tone: .inactive
            )
        case "opening":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Opening",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "cover", deviceClass: deviceClass, state: state),
                tone: .active
            )
        case "closing":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Closing",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "cover", deviceClass: deviceClass, state: state),
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
        domain: String
    ) -> HAHistoryTimelineEntry? {
        switch state {
        case "home":
            return HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Home",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: domain, deviceClass: nil, state: state),
                tone: .active
            )
        case "not_home":
            return HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Away",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: domain, deviceClass: nil, state: state),
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
                resolvedIcon: IconResolver.historicalEntityIcon(domain: domain, deviceClass: nil, state: state),
                tone: .active
            )
        }
    }

    private static func lockEntry(state: String, occurredAt: Date) -> HAHistoryTimelineEntry? {
        switch state {
        case "locked":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Locked",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "lock", deviceClass: nil, state: state),
                tone: .inactive
            )
        case "unlocked":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unlocked",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "lock", deviceClass: nil, state: state),
                tone: .active
            )
        case "locking":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Locking",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "lock", deviceClass: nil, state: state),
                tone: .inactive
            )
        case "unlocking":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Unlocking",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "lock", deviceClass: nil, state: state),
                tone: .active
            )
        case "jammed":
            HAHistoryTimelineEntry(
                occurredAt: occurredAt,
                state: state,
                title: "Jammed",
                resolvedIcon: IconResolver.historicalEntityIcon(domain: "lock", deviceClass: nil, state: state),
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
    var haDeviceClass: String? {
        switch self {
        case .door: "door"
        case .window: "window"
        case .garageDoor: "garage_door"
        case .opening: "opening"
        case .lock: "lock"
        case .motion: "motion"
        case .occupancy: "occupancy"
        case .presence: "presence"
        case .tamper: "tamper"
        case .safety: "safety"
        case .problem: "problem"
        case .smoke: "smoke"
        case .gas: "gas"
        case .carbonMonoxide: "carbon_monoxide"
        case .moisture: "moisture"
        case .battery: "battery"
        case .batteryCharging: "battery_charging"
        case .cold: "cold"
        case .heat: "heat"
        case .moving: "moving"
        case .running: "running"
        case .sound: "sound"
        case .update: "update"
        case .vibration: "vibration"
        case .connectivity: "connectivity"
        case .plug: "plug"
        case .power: "power"
        case .light: "light"
        case .generic: nil
        }
    }

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
