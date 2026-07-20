import Foundation

nonisolated enum TextEntityMode: String, Equatable, Sendable {
    case text
    case password

    init(homeAssistantValue: String?) {
        self = homeAssistantValue.flatMap(Self.init(rawValue:)) ?? .text
    }
}

nonisolated struct TextEntity: Identifiable, Equatable, Sendable {
    let entityID: String
    let displayName: String
    let value: String
    let minimumLength: Int
    let maximumLength: Int
    let pattern: String?
    let mode: TextEntityMode

    var id: String { entityID }

    func validationMessage(for candidate: String) -> String? {
        guard candidate.count >= minimumLength else {
            return "Enter at least \(minimumLength) characters."
        }
        guard candidate.count <= maximumLength else {
            return "Use no more than \(maximumLength) characters."
        }
        guard let pattern, !pattern.isEmpty else { return nil }

        guard let expression = try? NSRegularExpression(pattern: "^(?:\(pattern))$") else {
            // A malformed integration pattern should not make the editor unusable.
            return nil
        }
        let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
        return expression.firstMatch(in: candidate, range: range) == nil
            ? "The value does not match this entity's required format."
            : nil
    }
}
