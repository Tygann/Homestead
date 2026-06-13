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
    let domain: String?
    let entityID: String?
    let contextUserID: String?

    enum CodingKeys: String, CodingKey {
        case when
        case name
        case message
        case domain
        case entityID = "entity_id"
        case contextUserID = "context_user_id"
    }

    init(
        when: Date,
        name: String? = nil,
        message: String? = nil,
        domain: String? = nil,
        entityID: String? = nil,
        contextUserID: String? = nil
    ) {
        self.when = when
        self.name = name
        self.message = message
        self.domain = domain
        self.entityID = entityID
        self.contextUserID = contextUserID
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
        domain = try container.decodeIfPresent(String.self, forKey: .domain)
        entityID = try container.decodeIfPresent(String.self, forKey: .entityID)
        contextUserID = try container.decodeIfPresent(String.self, forKey: .contextUserID)
    }
}

nonisolated struct HAActivityRow: Identifiable, Equatable, Sendable {
    let id: String
    let occurredAt: Date
    let title: String
    let message: String
    let entityID: String?
    let entityDomain: EntityDomain?
    let sourceDomain: String?
    let sourceName: String?
    let contextUserID: String?

    var iconSystemName: String {
        entityDomain?.systemImage ?? "list.bullet.clipboard"
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
            contextUserID
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        return searchableText.localizedCaseInsensitiveContains(trimmedQuery)
    }

    static func makeRows(
        from entries: [HALogbookEntryDTO],
        entityDisplayName: (String) -> String?
    ) -> [HAActivityRow] {
        entries.enumerated().map { index, entry in
            HAActivityRow(entry: entry, index: index, entityDisplayName: entityDisplayName)
        }
    }

    private init(
        entry: HALogbookEntryDTO,
        index: Int,
        entityDisplayName: (String) -> String?
    ) {
        let entityID = entry.entityID?.nonEmptyValue
        let entityDomain = entityID.map(EntityDomain.init(entityID:))
        let sourceName = entry.name?.nonEmptyValue
        let sourceDomain = entry.domain?.nonEmptyValue
        let message = entry.message?.nonEmptyValue ?? "Updated"
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
            String(index)
        ]
            .compactMap { $0?.nonEmptyValue }
            .joined(separator: "|")
        self.occurredAt = entry.when
        self.title = title
        self.message = message
        self.entityID = entityID
        self.entityDomain = entityDomain
        self.sourceDomain = sourceDomain
        self.sourceName = sourceName
        self.contextUserID = entry.contextUserID?.nonEmptyValue
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
        limit: Int = 50,
        calendar: Calendar = .current
    ) -> HALogbookPresentation {
        let securityRows = rows
            .filter { row in
                row.entityID.map(entityIDs.contains) == true
            }
            .sorted { lhs, rhs in
                lhs.occurredAt > rhs.occurredAt
            }

        return make(
            rows: Array(securityRows.prefix(max(0, limit))),
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
