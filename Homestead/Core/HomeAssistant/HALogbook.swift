import Foundation

nonisolated struct HALogbookRequest: Equatable, Sendable {
    let startDate: Date
    let endDate: Date?
    let entityID: String?

    init(startDate: Date, endDate: Date?, entityID: String? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        let trimmedEntityID = entityID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.entityID = trimmedEntityID?.isEmpty == false ? trimmedEntityID : nil
    }
}

nonisolated struct HALogbookEntryDTO: Decodable, Equatable, Sendable {
    let when: Date
    let name: String?
    let message: String?
    let state: String?
    let domain: String?
    let entityID: String?
    let contextUserID: String?
    let contextName: String?
    let contextDomain: String?
    let contextService: String?
    let contextSource: String?
    let contextMessage: String?

    enum CodingKeys: String, CodingKey {
        case when
        case name
        case message
        case state
        case domain
        case entityID = "entity_id"
        case contextUserID = "context_user_id"
        case contextName = "context_name"
        case contextDomain = "context_domain"
        case contextService = "context_service"
        case contextSource = "context_source"
        case contextMessage = "context_message"
    }

    init(
        when: Date,
        name: String? = nil,
        message: String? = nil,
        state: String? = nil,
        domain: String? = nil,
        entityID: String? = nil,
        contextUserID: String? = nil,
        contextName: String? = nil,
        contextDomain: String? = nil,
        contextService: String? = nil,
        contextSource: String? = nil,
        contextMessage: String? = nil
    ) {
        self.when = when
        self.name = name
        self.message = message
        self.state = state
        self.domain = domain
        self.entityID = entityID
        self.contextUserID = contextUserID
        self.contextName = contextName
        self.contextDomain = contextDomain
        self.contextService = contextService
        self.contextSource = contextSource
        self.contextMessage = contextMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let whenString = try container.decode(String.self, forKey: .when)
        guard let when = HADateParser.date(from: whenString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .when,
                in: container,
                debugDescription: "Expected Home Assistant logbook timestamp."
            )
        }

        self.when = when
        name = try container.decodeIfPresent(String.self, forKey: .name)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        entityID = try container.decodeIfPresent(String.self, forKey: .entityID)
        contextUserID = try container.decodeIfPresent(String.self, forKey: .contextUserID)
        contextName = try container.decodeIfPresent(String.self, forKey: .contextName)
        contextDomain = try container.decodeIfPresent(String.self, forKey: .contextDomain)
        contextService = try container.decodeIfPresent(String.self, forKey: .contextService)
        contextSource = try container.decodeIfPresent(String.self, forKey: .contextSource)
        contextMessage = try container.decodeIfPresent(String.self, forKey: .contextMessage)
    }
}

nonisolated struct HAActivityRow: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let title: String
    let message: String
    let entityID: String?
    let entityDomain: EntityDomain?
    let state: String?
    let displayValue: String?
    let sourceDomain: String?
    let sourceName: String?
    let contextUserID: String?
    let contextName: String?
    let triggerText: String?
    let attributionName: String?
    let resolvedIcon: ResolvedIcon

    var iconSystemName: String { resolvedIcon.sfSymbolName }

    var timelineTone: HAHistoryTimelineTone {
        if let state = state?.lowercased() {
            if ["unavailable", "unknown", "jammed"].contains(state) {
                return .unavailable
            }

            if [
                "on", "open", "opening", "unlocked", "unlocking", "home",
                "playing", "active", "detected", "triggered"
            ].contains(state) {
                return .active
            }

            return .inactive
        }

        let activityMessage = message.lowercased()
        if ["unavailable", "unknown", "jammed"].contains(where: activityMessage.contains) {
            return .unavailable
        }
        if ["turned on", "opened", "unlocked", "triggered", "playing", "active"].contains(where: activityMessage.contains) {
            return .active
        }

        return .inactive
    }

    var detailText: String {
        let details = [
            entityID,
            sourceName == title ? nil : sourceName,
            sourceDomain?.replacingOccurrences(of: "_", with: " ").capitalized
        ].compactMap { $0?.nonEmptyValue }

        return details.isEmpty ? "Home Assistant" : details.joined(separator: " • ")
    }

    func matches(query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        let searchableText = [
            title,
            message,
            entityID,
            entityDomain?.displayName,
            sourceDomain,
            sourceName,
            contextUserID,
            contextName,
            triggerText,
            attributionName
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return searchableText.localizedCaseInsensitiveContains(trimmedQuery)
    }

    static func makeRows(
        from entries: [HALogbookEntryDTO],
        entityDisplayName: (String) -> String?,
        entityDeviceClass: (String) -> String? = { _ in nil },
        contextUserDisplayName: (String) -> String? = { _ in nil },
        historicalStateDisplayValue: (String, String) -> String? = { _, _ in nil }
    ) -> [HAActivityRow] {
        entries.enumerated().map { index, entry in
            HAActivityRow(
                entry: entry,
                index: index,
                entityDisplayName: entityDisplayName,
                entityDeviceClass: entityDeviceClass,
                contextUserDisplayName: contextUserDisplayName,
                historicalStateDisplayValue: historicalStateDisplayValue
            )
        }
    }

    private init(
        entry: HALogbookEntryDTO,
        index: Int,
        entityDisplayName: (String) -> String?,
        entityDeviceClass: (String) -> String?,
        contextUserDisplayName: (String) -> String?,
        historicalStateDisplayValue: (String, String) -> String?
    ) {
        let entityID = entry.entityID?.nonEmptyValue
        let entityDomain = entityID.map(EntityDomain.init(entityID:))
        let state = entry.state?.nonEmptyValue
        let sourceName = entry.name?.nonEmptyValue
        let sourceDomain = entry.domain?.nonEmptyValue
        let deviceClass = entityID.flatMap(entityDeviceClass)
        let message = entry.message?.nonEmptyValue ?? Self.stateMessage(
            state: state,
            domain: entityDomain,
            deviceClass: deviceClass
        )
        let title = entityID.flatMap(entityDisplayName) ??
            sourceName ??
            entityDomain?.displayName.singularActivityTitle ??
            sourceDomain?.replacingOccurrences(of: "_", with: " ").capitalized ??
            "Home Assistant"

        self.id = [
            String(entry.when.timeIntervalSince1970),
            entityID,
            sourceDomain,
            sourceName,
            message,
            entry.contextMessage,
            String(index)
        ]
            .compactMap { $0?.nonEmptyValue }
            .joined(separator: "|")
        self.occurredAt = entry.when
        self.title = title
        self.message = message
        self.entityID = entityID
        self.entityDomain = entityDomain
        self.state = state
        self.displayValue = if let entityID, let state {
            historicalStateDisplayValue(entityID, state) ??
                Self.historicalDisplayValue(state: state, entityDomain: entityDomain)
        } else {
            nil
        }
        self.sourceDomain = sourceDomain
        self.sourceName = sourceName
        let contextUserID = entry.contextUserID?.nonEmptyValue
        let contextName = entry.contextName?.nonEmptyValue
        self.contextUserID = contextUserID
        self.contextName = contextName
        self.triggerText = Self.triggerText(
            contextMessage: entry.contextMessage?.nonEmptyValue,
            contextSource: entry.contextSource?.nonEmptyValue,
            contextDomain: entry.contextDomain?.nonEmptyValue,
            contextService: entry.contextService?.nonEmptyValue,
            contextName: contextName,
            entityDisplayName: entityDisplayName
        )
        self.attributionName = contextUserID.flatMap { userID in
            contextName ?? contextUserDisplayName(userID)
        }
        self.resolvedIcon = entityDomain.map {
            IconResolver.historicalEntityIcon(
                domain: $0.rawValue,
                deviceClass: deviceClass,
                state: state ?? "unknown"
            )
        } ?? .sfSymbol("list.bullet.clipboard", provenance: .fallback)
    }

    var statusText: String {
        if let displayValue {
            return displayValue
        }

        return Self.statusText(from: message)
    }

    private static func stateMessage(
        state: String?,
        domain: EntityDomain?,
        deviceClass: String?
    ) -> String {
        guard let state else { return "Updated" }

        switch domain {
        case .person, .deviceTracker:
            if state == "not_home" { return "was detected away" }
            if state == "home" { return "was detected home" }
            return "was detected at \(formattedState(state))"
        case .lock:
            return switch state {
            case "unlocked": "was unlocked"
            case "locking": "is locking"
            case "unlocking": "is unlocking"
            case "opening": "is opening"
            case "open": "was opened"
            case "locked": "was locked"
            case "jammed": "is jammed"
            default: "changed to \(formattedState(state))"
            }
        case .cover:
            return switch state {
            case "open": "was opened"
            case "opening": "is opening"
            case "closing": "is closing"
            case "closed": "was closed"
            default: "changed to \(formattedState(state))"
            }
        case .binarySensor:
            if ["door", "garage_door", "lock", "opening", "window"].contains(deviceClass ?? "") {
                return state == "on" ? "was opened" : "was closed"
            }
            return state == "on" ? "was detected" : "was cleared"
        default:
            if state == "on" { return "turned on" }
            if state == "off" { return "turned off" }
            if state == "unknown" { return "became unknown" }
            if state == "unavailable" { return "became unavailable" }
            return "changed to \(formattedState(state))"
        }
    }

    private static func formattedState(_ state: String) -> String {
        let words = state.replacingOccurrences(of: "_", with: " ")
        return words == words.uppercased() ? words : words.capitalized
    }

    private static func triggerText(
        contextMessage: String?,
        contextSource: String?,
        contextDomain: String?,
        contextService: String?,
        contextName: String?,
        entityDisplayName: (String) -> String?
    ) -> String? {
        if contextDomain == "automation", let contextName {
            return "By automation: \(contextName)"
        }

        if let contextMessage {
            return contextDescription(
                from: contextMessage,
                entityDisplayName: entityDisplayName
            )
        }

        if let contextSource {
            return contextDescription(
                from: contextSource,
                entityDisplayName: entityDisplayName
            )
        }

        if let contextDomain, let contextService {
            return "By action: \(formattedState(contextDomain)) • \(formattedState(contextService))"
        }

        return nil
    }

    private static func contextDescription(
        from source: String,
        entityDisplayName: (String) -> String?
    ) -> String {
        let trimmedSource = source
            .replacingOccurrences(of: "triggered by ", with: "", options: [.anchored, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSource = resolvingEntityIDs(
            in: trimmedSource,
            entityDisplayName: entityDisplayName
        )
        let lowercasedSource = resolvedSource.lowercased()

        let prefixes: [(String, String)] = [
            ("numeric state of ", "By numeric state: "),
            ("state of ", "By state change: "),
            ("automation ", "By automation: "),
            ("action ", "By action: "),
            ("event ", "By event: ")
        ]

        for (prefix, replacement) in prefixes where lowercasedSource.hasPrefix(prefix) {
            let detail = resolvedSource.dropFirst(prefix.count)
                .replacingOccurrences(of: ": ", with: " • ")
            return replacement + detail
        }

        if lowercasedSource == "time pattern" {
            return "By time pattern"
        }
        if lowercasedSource.hasPrefix("time ") || lowercasedSource == "time" {
            return "By time: \(resolvedSource.dropFirst("time".count).trimmingCharacters(in: .whitespaces))"
                .trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        }
        if lowercasedSource.hasPrefix("home assistant ") {
            return "By Home Assistant: \(formattedState(String(resolvedSource.dropFirst("Home Assistant ".count))))"
        }

        return "By \(resolvedSource)"
    }

    private static func resolvingEntityIDs(
        in text: String,
        entityDisplayName: (String) -> String?
    ) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: #"\b[a-z0-9_]+\.[a-z0-9_]+\b"#,
            options: [.caseInsensitive]
        ) else {
            return text
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = expression.matches(in: text, range: fullRange).reversed()
        var resolvedText = text

        for match in matches {
            guard let range = Range(match.range, in: resolvedText) else {
                continue
            }
            let entityID = String(resolvedText[range])
            guard let displayName = entityDisplayName(entityID) else {
                continue
            }
            resolvedText.replaceSubrange(range, with: displayName)
        }

        return resolvedText
    }

    private static func statusText(from message: String) -> String {
        let prefixes = ["changed to ", "turned ", "was ", "is ", "became "]
        for prefix in prefixes where message.hasPrefix(prefix) {
            let value = message.dropFirst(prefix.count)
            return value.prefix(1).uppercased() + value.dropFirst()
        }
        return message.prefix(1).uppercased() + message.dropFirst()
    }

    private static func historicalDisplayValue(
        state: String,
        entityDomain: EntityDomain?
    ) -> String? {
        guard entityDomain == .sensor else {
            return nil
        }

        if let date = HADateParser.date(from: state) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        guard let number = Double(state), number.rounded() == number else {
            return nil
        }

        return number.formatted(.number.precision(.fractionLength(0)))
    }
}

nonisolated struct HAActivitySection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let rows: [HAActivityRow]
}

nonisolated struct HALogbookPresentation: Equatable, Sendable {
    let sections: [HAActivitySection]
    let visibleRowCount: Int

    static func make(
        rows: [HAActivityRow],
        searchText: String,
        selectedDomain: EntityDomain?,
        calendar: Calendar = .current,
        usesRelativeSectionTitles: Bool = true
    ) -> HALogbookPresentation {
        let matchingRows = rows
            .filter { row in
                selectedDomain == nil || row.entityDomain == selectedDomain
            }
            .filter { $0.matches(query: searchText) }
            .sorted { lhs, rhs in
                lhs.occurredAt > rhs.occurredAt
            }

        let groupedRows = Dictionary(grouping: matchingRows) { row in
            calendar.startOfDay(for: row.occurredAt)
        }

        let sections = groupedRows
            .map { day, rows in
                HAActivitySection(
                    id: String(day.timeIntervalSince1970),
                    title: sectionTitle(
                        for: day,
                        calendar: calendar,
                        usesRelativeTitles: usesRelativeSectionTitles
                    ),
                    rows: rows.sorted { lhs, rhs in lhs.occurredAt > rhs.occurredAt }
                )
            }
            .sorted { lhs, rhs in
                guard let lhsDate = Double(lhs.id).map(Date.init(timeIntervalSince1970:)),
                      let rhsDate = Double(rhs.id).map(Date.init(timeIntervalSince1970:)) else {
                    return lhs.title > rhs.title
                }

                return lhsDate > rhsDate
            }

        return HALogbookPresentation(sections: sections, visibleRowCount: matchingRows.count)
    }

    static func makeSecurityActivity(
        rows: [HAActivityRow],
        entityIDs: Set<String>,
        limit: Int? = nil,
        calendar: Calendar = .current
    ) -> HALogbookPresentation {
        let securityRows = rows
            .filter { row in
                row.entityID.map(entityIDs.contains) == true
            }
            .sorted { lhs, rhs in
                lhs.occurredAt > rhs.occurredAt
            }

        let limitedRows = limit.map { Array(securityRows.prefix(max(0, $0))) } ?? securityRows

        return make(
            rows: limitedRows,
            searchText: "",
            selectedDomain: nil,
            calendar: calendar,
            usesRelativeSectionTitles: false
        )
    }

    private static func sectionTitle(
        for date: Date,
        calendar: Calendar,
        usesRelativeTitles: Bool
    ) -> String {
        if usesRelativeTitles, calendar.isDateInToday(date) {
            return "Today"
        }

        if usesRelativeTitles, calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        return date.formatted(date: usesRelativeTitles ? .abbreviated : .long, time: .omitted)
    }
}

nonisolated struct HASecurityActivityCacheSnapshot: Equatable, Sendable {
    let rows: [HAActivityRow]
    let loadedAt: Date
}

actor HASecurityActivityCache {
    static let shared = HASecurityActivityCache()

    private var snapshotsByKey: [String: HASecurityActivityCacheSnapshot] = [:]

    func snapshot(for key: String) -> HASecurityActivityCacheSnapshot? {
        snapshotsByKey[key]
    }

    func store(_ snapshot: HASecurityActivityCacheSnapshot, for key: String) {
        snapshotsByKey[key] = snapshot
    }
}

nonisolated private extension String {
    var nonEmptyValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    var singularActivityTitle: String {
        if hasSuffix("ies") {
            return String(dropLast(3)) + "y"
        }

        if hasSuffix("s") {
            return String(dropLast())
        }

        return self
    }
}
