import Foundation

nonisolated enum MaterialDesignIconCatalog {
    static func codepoint(for name: String) -> UInt32? {
        codepoints[name.lowercased()]
    }

    static func glyph(for name: String) -> String? {
        guard let codepoint = codepoint(for: name),
              let scalar = UnicodeScalar(codepoint) else { return nil }
        return String(Character(scalar))
    }

    private static let codepoints: [String: UInt32] = {
        for bundle in resourceBundles {
            guard let url = bundle.url(
                forResource: "MaterialDesignIconCatalog",
                withExtension: "json"
            ), let data = try? Data(contentsOf: url),
               let catalog = try? JSONDecoder().decode([String: UInt32].self, from: data) else {
                continue
            }
            return catalog
        }
        return [:]
    }()

    private static var resourceBundles: [Bundle] {
        [Bundle.main] + Bundle.allFrameworks + Bundle.allBundles
    }
}
