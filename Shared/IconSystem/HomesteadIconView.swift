import CoreText
import SwiftUI

struct HomesteadIconView: View {
    let icon: ResolvedIcon
    var pointSize: CGFloat
    var weight: Font.Weight = .semibold

    init(
        icon: ResolvedIcon,
        pointSize: CGFloat,
        weight: Font.Weight = .semibold
    ) {
        self.icon = icon
        self.pointSize = pointSize
        self.weight = weight
    }

    var body: some View {
        switch icon.asset {
        case .sfSymbol(let systemName):
            Image(systemName: systemName)
                .font(.system(size: pointSize, weight: weight))
        case .materialDesign(let name):
            if MaterialDesignIconFont.registerIfNeeded(),
               let glyph = MaterialDesignIconCatalog.glyph(for: name) {
                Text(glyph)
                    .font(.custom(MaterialDesignIconFont.postScriptName, fixedSize: pointSize * 1.08))
                    .baselineOffset(-pointSize * 0.035)
            } else {
                fallbackImage
            }
        case .unsupportedHomeAssistant:
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Image(systemName: icon.fallbackSFSymbol)
            .font(.system(size: pointSize, weight: weight))
    }
}

enum MaterialDesignIconFont {
    static let postScriptName = "MaterialDesignIcons"

    private static let registrationResult: Bool = {
        guard let fontURL = resourceURL else {
            return false
        }

        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
        if registered {
            return true
        }

        // Registration returns false when the font was already registered in this process.
        return CTFontCreateWithName(postScriptName as CFString, 12, nil).familyName == "Material Design Icons"
    }()

    static func registerIfNeeded() -> Bool {
        registrationResult
    }

    private static var resourceURL: URL? {
        let bundles = [Bundle.main] + Bundle.allFrameworks + Bundle.allBundles
        return bundles.lazy.compactMap {
            $0.url(forResource: "materialdesignicons-webfont", withExtension: "ttf")
        }.first
    }
}

private extension CTFont {
    var familyName: String {
        CTFontCopyFamilyName(self) as String
    }
}
