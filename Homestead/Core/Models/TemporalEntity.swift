import Foundation

nonisolated enum TemporalEntityKind: String, Equatable, Sendable {
    case date
    case time
    case dateTime
}

nonisolated struct TemporalEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let kind: TemporalEntityKind
    let value: Date?
    let serviceDomain: String
    let service: String

    var id: String { entityID }

    var serviceName: String { "\(serviceDomain).\(service)" }

    func serviceData(for date: Date, calendar: Calendar = .current) -> [String: JSONValue] {
        let key: String
        switch kind {
        case .date: key = "date"
        case .time: key = "time"
        case .dateTime: key = "datetime"
        }

        return [key: .string(Self.serviceValue(for: date, kind: kind, calendar: calendar))]
    }

    static func map(from dto: HAEntityDTO, displayName: String) -> TemporalEntity? {
        let rawDomain = dto.entityID.split(separator: ".").first.map(String.init) ?? ""
        let kind: TemporalEntityKind
        let serviceDomain: String
        let service: String

        switch rawDomain {
        case "date":
            kind = .date
            serviceDomain = "date"
            service = "set_value"
        case "time":
            kind = .time
            serviceDomain = "time"
            service = "set_value"
        case "datetime":
            kind = .dateTime
            serviceDomain = "datetime"
            service = "set_value"
        case "input_datetime":
            let hasDate = dto.attributes["has_date"]?.boolValue ?? false
            let hasTime = dto.attributes["has_time"]?.boolValue ?? false
            guard hasDate || hasTime else { return nil }
            kind = hasDate && hasTime ? .dateTime : (hasDate ? .date : .time)
            serviceDomain = "input_datetime"
            service = "set_datetime"
        default:
            return nil
        }

        return TemporalEntity(
            entityID: dto.entityID,
            displayName: displayName,
            kind: kind,
            value: parseValue(dto.state, kind: kind, usesISODateTime: rawDomain == "datetime"),
            serviceDomain: serviceDomain,
            service: service
        )
    }

    private static func parseValue(_ state: String, kind: TemporalEntityKind, usesISODateTime: Bool) -> Date? {
        if kind == .dateTime, usesISODateTime {
            return HADateParser.date(from: state)
        }

        let formats: [String]
        switch kind {
        case .date: formats = ["yyyy-MM-dd"]
        case .time: formats = ["HH:mm:ss.SSSSSS", "HH:mm:ss", "HH:mm"]
        case .dateTime: formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"]
        }

        for format in formats {
            let formatter = localFormatter(format: format)
            if let date = formatter.date(from: state) { return date }
        }
        return nil
    }

    private static func serviceValue(for date: Date, kind: TemporalEntityKind, calendar: Calendar) -> String {
        let format: String
        switch kind {
        case .date: format = "yyyy-MM-dd"
        case .time: format = "HH:mm:ss"
        case .dateTime: format = "yyyy-MM-dd'T'HH:mm:ssXXX"
        }
        let formatter = localFormatter(format: format, calendar: calendar)
        return formatter.string(from: date)
    }

    private static func localFormatter(format: String, calendar: Calendar = .current) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}
