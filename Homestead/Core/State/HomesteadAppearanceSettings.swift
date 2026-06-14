import Foundation
import Observation
import UIKit

enum HomesteadAppearanceSettingsError: LocalizedError {
    case invalidImage
    case unableToEncodeImage
    case unableToCreateStorageDirectory

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The selected photo could not be read."
        case .unableToEncodeImage:
            "The selected photo could not be prepared."
        case .unableToCreateStorageDirectory:
            "The wallpaper could not be saved."
        }
    }
}

@MainActor
@Observable
final class HomesteadAppearanceSettings {
    var isWallpaperEnabled: Bool {
        didSet { defaults.set(isWallpaperEnabled, forKey: Keys.isWallpaperEnabled) }
    }

    private(set) var wallpaperRevision: Int {
        didSet { defaults.set(wallpaperRevision, forKey: Keys.wallpaperRevision) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let storageDirectory: URL
    @ObservationIgnored private let wallpaperFileName = "wallpaper.jpg"
    @ObservationIgnored private let maximumWallpaperDimension: CGFloat = 2400

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        storageDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.storageDirectory = storageDirectory ?? Self.defaultStorageDirectory(fileManager: fileManager)
        isWallpaperEnabled = defaults.object(forKey: Keys.isWallpaperEnabled) == nil
            ? false
            : defaults.bool(forKey: Keys.isWallpaperEnabled)
        wallpaperRevision = defaults.integer(forKey: Keys.wallpaperRevision)
    }

    var hasWallpaper: Bool {
        fileManager.fileExists(atPath: wallpaperURL.path)
    }

    var activeWallpaperURL: URL? {
        guard isWallpaperEnabled, hasWallpaper else {
            return nil
        }

        return wallpaperURL
    }

    var storedWallpaperURL: URL? {
        hasWallpaper ? wallpaperURL : nil
    }

    var syncSnapshot: HomesteadAppearanceSettingsSyncSnapshot {
        HomesteadAppearanceSettingsSyncSnapshot(isWallpaperEnabled: isWallpaperEnabled)
    }

    func importWallpaper(from imageData: Data) async throws {
        guard let image = UIImage(data: imageData) else {
            throw HomesteadAppearanceSettingsError.invalidImage
        }

        guard let optimizedData = Self.optimizedJPEGData(
            from: image,
            maximumDimension: maximumWallpaperDimension
        ) else {
            throw HomesteadAppearanceSettingsError.unableToEncodeImage
        }

        do {
            try fileManager.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            throw HomesteadAppearanceSettingsError.unableToCreateStorageDirectory
        }

        try optimizedData.write(to: wallpaperURL, options: [.atomic])
        isWallpaperEnabled = true
        wallpaperRevision += 1
    }

    func removeWallpaper() {
        if hasWallpaper {
            try? fileManager.removeItem(at: wallpaperURL)
        }

        isWallpaperEnabled = false
        wallpaperRevision += 1
    }

    func applySyncSnapshot(_ snapshot: HomesteadAppearanceSettingsSyncSnapshot) {
        isWallpaperEnabled = snapshot.isWallpaperEnabled && hasWallpaper
    }

    private var wallpaperURL: URL {
        storageDirectory.appendingPathComponent(wallpaperFileName, isDirectory: false)
    }

    private static func defaultStorageDirectory(fileManager: FileManager) -> URL {
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return applicationSupportDirectory
            .appendingPathComponent("Homestead", isDirectory: true)
            .appendingPathComponent("Appearance", isDirectory: true)
    }

    private static func optimizedJPEGData(
        from image: UIImage,
        maximumDimension: CGFloat
    ) -> Data? {
        let originalSize = image.size
        let largestDimension = max(originalSize.width, originalSize.height)
        let scale = largestDimension > maximumDimension ? maximumDimension / largestDimension : 1
        let targetSize = CGSize(
            width: max(1, floor(originalSize.width * scale)),
            height: max(1, floor(originalSize.height * scale))
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return renderedImage.jpegData(compressionQuality: 0.88)
    }

    private enum Keys {
        static let isWallpaperEnabled = "homestead.appearance.isWallpaperEnabled"
        static let wallpaperRevision = "homestead.appearance.wallpaperRevision"
    }
}

struct HomesteadAppearanceSettingsSyncSnapshot: Codable, Equatable, Sendable {
    var isWallpaperEnabled: Bool
}
