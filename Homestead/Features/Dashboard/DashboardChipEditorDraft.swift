import Foundation

struct DashboardChipEditorDraft: Equatable {
    var entityID: String
    var displayName: String
    var usesCustomDisplayName: Bool
    var iconNameOverride: String?

    static let empty = DashboardChipEditorDraft(
        entityID: "",
        displayName: "",
        usesCustomDisplayName: false,
        iconNameOverride: nil
    )

    init(item: DashboardChipItem, canonicalName: String?) {
        entityID = item.entityID ?? ""
        displayName = item.displayNameOverride ?? canonicalName ?? ""
        usesCustomDisplayName = item.displayNameOverride != nil
        iconNameOverride = item.iconNameOverride
    }

    private init(
        entityID: String,
        displayName: String,
        usesCustomDisplayName: Bool,
        iconNameOverride: String?
    ) {
        self.entityID = entityID
        self.displayName = displayName
        self.usesCustomDisplayName = usesCustomDisplayName
        self.iconNameOverride = iconNameOverride
    }

    mutating func replaceEntity(
        with replacementEntityID: String,
        replacementCanonicalName: String?
    ) {
        entityID = replacementEntityID
        if !usesCustomDisplayName {
            displayName = replacementCanonicalName ?? ""
        }
    }

    mutating func setDisplayName(_ value: String, canonicalName: String?) {
        displayName = value
        usesCustomDisplayName = displayNameOverride(canonicalName: canonicalName) != nil
    }

    func update(canonicalName: String?) -> DashboardChipUpdate {
        DashboardChipUpdate(
            entityID: entityID,
            displayNameOverride: usesCustomDisplayName
                ? displayNameOverride(canonicalName: canonicalName)
                : nil,
            iconNameOverride: iconNameOverride
        )
    }

    func displayNameOverride(canonicalName: String?) -> String? {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != canonicalName else { return nil }
        return trimmed
    }
}
