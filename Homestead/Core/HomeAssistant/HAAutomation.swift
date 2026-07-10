import Foundation

// MARK: - Home Assistant DTOs

nonisolated struct HAAutomationConfigurationResponseDTO: Decodable, Sendable {
    let config: [String: JSONValue]
}

nonisolated struct HAAutomationTraceDTO: Decodable, Sendable {
    let runID: String
    let state: String
    let scriptExecution: String?
    let timestamp: Timestamp
    let notTriggered: Bool?

    nonisolated struct Timestamp: Decodable, Sendable {
        let start: String
    }

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case state
        case scriptExecution = "script_execution"
        case timestamp
        case notTriggered = "not_triggered"
    }

    nonisolated var startedAt: Date? {
        HADateParser.date(from: timestamp.start)
    }
}

// MARK: - Presentation Models

nonisolated struct HAAutomationOverview: Equatable, Sendable {
    let triggers: [HAAutomationStep]
    let conditions: [HAAutomationStep]
    let actions: [HAAutomationStep]
}

nonisolated struct HAAutomationStep: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: ResolvedIcon
}

// MARK: - Presentation Builder

nonisolated enum HAAutomationOverviewBuilder {
    static func make(
        config: [String: JSONValue],
        entityName: (String) -> String
    ) -> HAAutomationOverview {
        HAAutomationOverview(
            triggers: steps(in: config, plural: "triggers", legacy: "trigger").enumerated().map {
                triggerStep($0.element, index: $0.offset, entityName: entityName)
            },
            conditions: steps(in: config, plural: "conditions", legacy: "condition").enumerated().map {
                conditionStep($0.element, index: $0.offset, entityName: entityName)
            },
            actions: steps(in: config, plural: "actions", legacy: "action").enumerated().map {
                actionStep($0.element, index: $0.offset, entityName: entityName)
            }
        )
    }

    private static func triggerStep(_ value: JSONValue, index: Int, entityName: (String) -> String) -> HAAutomationStep {
        let item = value.objectValue ?? [:]
        let type = string(item, "trigger") ?? string(item, "platform") ?? ""
        let entities = resolvedEntityNames(in: item, entityName: entityName)
        let title: String

        switch type {
        case "zone.left":
            title = "Zone left"
        case "zone.entered":
            title = "Zone entered"
        case "state":
            title = stateTitle(prefix: "When", entities: entities, state: string(item, "to"), fallback: "state changes")
        case "numeric_state":
            title = "When \(entities.first ?? "an entity") reaches a threshold"
        case "time":
            title = "At \(string(item, "at") ?? "a scheduled time")"
        case "time_pattern":
            title = "On a time pattern"
        case "sun":
            title = "At \(string(item, "event") ?? "sunrise or sunset")"
        case "event":
            title = "When \(string(item, "event_type") ?? "an event") occurs"
        case "zone":
            title = "When \(entities.first ?? "a person") enters or leaves a zone"
        case "calendar":
            title = "When a calendar event changes"
        case "mqtt":
            title = "When a message is received"
        case "webhook":
            title = "When a webhook is received"
        case "template":
            title = "When a template evaluates true"
        case "homeassistant":
            title = "When Home Assistant starts or stops"
        case "device":
            title = string(item, "alias") ?? "When a device triggers"
        default:
            title = string(item, "alias") ?? "When \(type.isEmpty ? "a trigger occurs" : type.replacingOccurrences(of: "_", with: " "))"
        }

        return step(
            id: "trigger-\(index)",
            title: title,
            subtitle: detail(for: item, excluding: entities) ?? entities.nonEmptyAutomationValue?.joined(separator: " • "),
            icon: triggerIcon(for: type)
        )
    }

    private static func conditionStep(_ value: JSONValue, index: Int, entityName: (String) -> String) -> HAAutomationStep {
        let item = value.objectValue ?? [:]
        let type = string(item, "condition") ?? inferredConditionType(item) ?? ""
        let entities = resolvedEntityNames(in: item, entityName: entityName)
        let title: String

        switch type {
        case "zone.not_in_zone":
            title = "Is not in zone"
        case "zone.in_zone":
            title = "Is in zone"
        case "switch.is_off":
            title = "Switch is off"
        case "switch.is_on":
            title = "Switch is on"
        case "state":
            title = stateTitle(prefix: "Only if", entities: entities, state: string(item, "state"), fallback: "a state matches")
        case "numeric_state":
            title = "Only if \(entities.first ?? "an entity") meets a threshold"
        case "time":
            title = "Only during a time window"
        case "sun":
            title = "Only around sunrise or sunset"
        case "zone":
            title = "Only if \(entities.first ?? "a person") is in a zone"
        case "template":
            title = "Only if a template evaluates true"
        case "trigger":
            title = "Only when triggered by \(string(item, "id") ?? "a matching trigger")"
        case "and", "or", "not":
            let count = (item["conditions"]?.arrayValue ?? []).count
            title = "\(type.capitalized) group\(count > 0 ? " (\(count) conditions)" : "")"
        case "device":
            title = string(item, "alias") ?? "Only if a device condition matches"
        default:
            title = string(item, "alias") ?? "Condition\(type.isEmpty ? "" : ": \(type.replacingOccurrences(of: "_", with: " "))")"
        }

        return step(
            id: "condition-\(index)",
            title: title,
            subtitle: detail(for: item, excluding: entities) ?? entities.nonEmptyAutomationValue?.joined(separator: " • "),
            icon: conditionIcon(for: type)
        )
    }

    private static func actionStep(_ value: JSONValue, index: Int, entityName: (String) -> String) -> HAAutomationStep {
        let item = value.objectValue ?? [:]
        let service = string(item, "action") ?? string(item, "service")
        let entities = resolvedEntityNames(in: item, entityName: entityName)
        let title: String
        let icon: String

        if let service {
            title = serviceTitle(service)
            icon = serviceIcon(service)
        } else if item["choose"] != nil {
            let count = item["choose"]?.arrayValue?.count ?? 0
            title = "Choose between \(max(count, 1)) option\(count == 1 ? "" : "s")"
            icon = "arrow.triangle.branch"
        } else if item["if"] != nil {
            title = "If a condition matches"
            icon = "arrow.triangle.branch"
        } else if item["repeat"] != nil {
            title = "Repeat actions"
            icon = "repeat"
        } else if let delay = string(item, "delay") {
            title = "Wait \(delay)"
            icon = "clock.fill"
        } else if item["wait_for_trigger"] != nil {
            title = "Wait for a trigger"
            icon = "hourglass"
        } else if item["wait_template"] != nil {
            title = "Wait for a template"
            icon = "hourglass"
        } else if item["event"] != nil {
            title = "Fire \(string(item, "event") ?? "an event")"
            icon = "bolt.horizontal.fill"
        } else if item["stop"] != nil {
            title = "Stop automation"
            icon = "stop.fill"
        } else {
            title = string(item, "alias") ?? "Run an action"
            icon = "play.fill"
        }

        return step(id: "action-\(index)", title: title, subtitle: entities.isEmpty ? detail(for: item, excluding: []) : entities.joined(separator: ", "), icon: icon)
    }

    private static func steps(in config: [String: JSONValue], plural: String, legacy: String) -> [JSONValue] {
        let value = config[plural] ?? config[legacy]
        return value?.arrayValue ?? value.map { [$0] } ?? []
    }

    private static func resolvedEntityNames(in item: [String: JSONValue], entityName: (String) -> String) -> [String] {
        let ids = entityIDs(in: item)
        return Array(Set(ids)).sorted().map(entityName)
    }

    private static func entityIDs(in item: [String: JSONValue]) -> [String] {
        var ids: [String] = []
        for key in ["entity_id", "entity"] {
            if let value = item[key] {
                ids.append(contentsOf: strings(in: value))
            }
        }
        if let target = item["target"]?.objectValue, let value = target["entity_id"] {
            ids.append(contentsOf: strings(in: value))
        }
        return ids.filter { $0.contains(".") }
    }

    private static func strings(in value: JSONValue) -> [String] {
        if let string = value.stringValue { return [string] }
        return value.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private static func stateTitle(prefix: String, entities: [String], state: String?, fallback: String) -> String {
        let target = entities.first ?? "an entity"
        guard let state, !state.isEmpty else { return "\(prefix) \(target) \(fallback)" }
        return "\(prefix) \(target) is \(state.replacingOccurrences(of: "_", with: " "))"
    }

    private static func detail(for item: [String: JSONValue], excluding entities: [String]) -> String? {
        guard let alias = string(item, "alias"), !alias.isEmpty else { return nil }
        return alias
    }

    private static func string(_ item: [String: JSONValue], _ key: String) -> String? {
        item[key]?.stringValue
    }

    private static func inferredConditionType(_ item: [String: JSONValue]) -> String? {
        ["and", "or", "not"].first { item[$0] != nil }
    }

    private static func serviceTitle(_ service: String) -> String {
        switch service {
        case "input_select.select_option":
            return "Input select: Select input select option"
        case "select.select_option":
            return "Select: Select option"
        default:
            break
        }

        let pieces = service.split(separator: ".", maxSplits: 1).map(String.init)
        guard pieces.count == 2 else { return service.replacingOccurrences(of: "_", with: " ").capitalized }
        return "\(pieces[1].replacingOccurrences(of: "_", with: " ").capitalized) \(pieces[0].replacingOccurrences(of: "_", with: " "))"
    }

    private static func serviceIcon(_ service: String) -> String {
        if service == "input_select.select_option" || service == "select.select_option" { return "mdi:check" }
        if service.hasSuffix(".turn_on") { return "power" }
        if service.hasSuffix(".turn_off") { return "power" }
        if service.hasSuffix(".toggle") { return "switch.2" }
        if service.hasPrefix("notify.") { return "bell.fill" }
        if service.hasPrefix("media_player.") { return "play.fill" }
        if service.hasPrefix("light.") { return "lightbulb.fill" }
        return "play.fill"
    }

    private static func triggerIcon(for type: String) -> String {
        switch type {
        case "zone.left", "zone.entered", "zone":
            "mdi:map-marker"
        case "time":
            "mdi:clock-outline"
        case "state":
            "mdi:state-machine"
        default:
            "mdi:lightning-bolt"
        }
    }

    private static func conditionIcon(for type: String) -> String {
        switch type {
        case "zone.not_in_zone":
            "mdi:map-marker-off"
        case "zone.in_zone", "zone":
            "mdi:map-marker"
        case "switch.is_off":
            "mdi:toggle-switch-off-outline"
        case "switch.is_on":
            "mdi:toggle-switch-outline"
        default:
            "mdi:check"
        }
    }

    private static func step(id: String, title: String, subtitle: String?, icon: String) -> HAAutomationStep {
        HAAutomationStep(
            id: id,
            title: title,
            subtitle: subtitle,
            icon: IconResolver.resolveRegistryIcon(icon, fallback: icon.hasPrefix("mdi:") ? "circle" : icon)
        )
    }
}

private extension Array where Element == String {
    var nonEmptyAutomationValue: [String]? {
        isEmpty ? nil : self
    }
}

// MARK: - Trace Timeline

nonisolated enum HAAutomationTraceTimeline {
    static func make(
        traces: [HAAutomationTraceDTO],
        entityID: String,
        displayName: String,
        range: HAHistoryRangePreset,
        interval: DateInterval
    ) -> HAHistoryTimeline {
        let entries = traces.compactMap { trace -> HAHistoryTimelineEntry? in
            guard let occurredAt = trace.startedAt,
                  interval.contains(occurredAt) || occurredAt == interval.end,
                  trace.notTriggered != true else {
                return nil
            }

            let title: String
            let tone: HAHistoryTimelineTone
            let icon: String
            switch trace.scriptExecution {
            case "error", "failed_conditions", "failed_max_runs", "failed_single":
                title = "Failed"
                tone = .unavailable
                icon = "exclamationmark.triangle.fill"
            case "aborted", "cancelled":
                title = "Stopped"
                tone = .inactive
                icon = "stop.fill"
            default:
                title = "Triggered"
                tone = .active
                icon = "bolt.fill"
            }

            return HAHistoryTimelineEntry(occurredAt: occurredAt, state: trace.runID, title: title, systemImage: icon, tone: tone)
        }
        .sorted { $0.occurredAt < $1.occurredAt }

        return HAHistoryTimeline(entityID: entityID, displayName: displayName, range: range, entries: entries, emptyMessage: "No executions in \(range.accessibilityTitle.lowercased())", summaryNoun: "execution")
    }
}
