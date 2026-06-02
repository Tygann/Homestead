import Foundation

nonisolated enum EntityDisplayNameResolver {
    static func normalizedOverride(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    static func displayName(
        canonicalName: String,
        overrideName: String?,
        contextualAreaName: String?
    ) -> String? {
        let resolvedName = normalizedOverride(overrideName) ?? canonicalName
        let contextualName = contextualDisplayName(resolvedName, areaName: contextualAreaName)
        return contextualName == canonicalName ? nil : contextualName
    }

    static func contextualDisplayName(_ displayName: String, areaName: String?) -> String {
        guard let areaName = normalizedOverride(areaName) else {
            return displayName
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.count > areaName.count else {
            return displayName
        }

        let lowercasedName = trimmedName.lowercased()
        let lowercasedAreaName = areaName.lowercased()
        guard lowercasedName.hasPrefix(lowercasedAreaName) else {
            return displayName
        }

        let suffixStart = trimmedName.index(trimmedName.startIndex, offsetBy: areaName.count)
        let suffix = String(trimmedName[suffixStart...])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))

        return suffix.isEmpty ? displayName : suffix
    }

    static func cameraDisplayName(_ displayName: String) -> String {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cameraSuffix = "camera"
        guard trimmedName.lowercased().hasSuffix(cameraSuffix),
              trimmedName.count > cameraSuffix.count else {
            return displayName
        }

        let suffixStart = trimmedName.index(trimmedName.endIndex, offsetBy: -cameraSuffix.count)
        let prefix = String(trimmedName[..<suffixStart])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))

        return prefix.isEmpty ? displayName : prefix
    }
}
