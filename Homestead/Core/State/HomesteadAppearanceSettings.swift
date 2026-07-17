import Foundation
import Observation
import UIKit

nonisolated enum HomesteadAppearanceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

}

nonisolated enum HomesteadAppColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case blue
    case indigo
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue:
            "Blue"
        case .indigo:
            "Indigo"
        case .purple:
            "Purple"
        case .pink:
            "Pink"
        case .red:
            "Red"
        case .orange:
            "Orange"
        case .yellow:
            "Yellow"
        case .green:
            "Green"
        case .teal:
            "Teal"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .blue:
            .systemBlue
        case .indigo:
            .systemIndigo
        case .purple:
            .systemPurple
        case .pink:
            .systemPink
        case .red:
            .systemRed
        case .orange:
            .systemOrange
        case .yellow:
            .systemYellow
        case .green:
            .systemGreen
        case .teal:
            .systemTeal
        }
    }
}

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
    var appearanceMode: HomesteadAppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    var appColor: HomesteadAppColor {
        didSet { defaults.set(appColor.rawValue, forKey: Keys.appColor) }
    }

    private(set) var activeProfileID: UUID
    private var wallpaperProfiles: [UUID: WallpaperProfileState] {
        didSet { saveWallpaperProfiles() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let storageDirectory: URL
    @ObservationIgnored private let wallpaperFileName = "wallpaper.jpg"
    @ObservationIgnored private let maximumWallpaperDimension: CGFloat = 2400

    init(
        profileID: UUID,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        storageDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.storageDirectory = storageDirectory ?? Self.defaultStorageDirectory(fileManager: fileManager)
        activeProfileID = profileID
        wallpaperProfiles = defaults.data(forKey: Keys.wallpaperProfiles).flatMap {
            try? JSONDecoder().decode([UUID: WallpaperProfileState].self, from: $0)
        } ?? [:]
        appearanceMode = defaults.string(forKey: Keys.appearanceMode).flatMap(HomesteadAppearanceMode.init(rawValue:)) ?? .system
        appColor = defaults.string(forKey: Keys.appColor).flatMap(HomesteadAppColor.init(rawValue:)) ?? .blue
    }

    var isWallpaperEnabled: Bool {
        get { wallpaperProfiles[activeProfileID]?.isEnabled ?? false }
        set {
            updateActiveWallpaperState { state in
                state.isEnabled = newValue
            }
        }
    }

    var wallpaperRevision: Int {
        wallpaperProfiles[activeProfileID]?.revision ?? 0
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
        HomesteadAppearanceSettingsSyncSnapshot(
            appearanceMode: appearanceMode,
            appColor: appColor,
            wallpaperEnabledProfileIDs: Set(
                wallpaperProfiles.compactMap { profileID, state in
                    state.isEnabled ? profileID : nil
                }
            )
        )
    }

    func activateProfile(_ profileID: UUID) {
        guard activeProfileID != profileID else { return }
        activeProfileID = profileID
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
                at: profileStorageDirectory(for: activeProfileID),
                withIntermediateDirectories: true
            )
        } catch {
            throw HomesteadAppearanceSettingsError.unableToCreateStorageDirectory
        }

        try optimizedData.write(to: wallpaperURL, options: [.atomic])
        updateActiveWallpaperState { state in
            state.isEnabled = true
            state.revision += 1
        }
    }

    func removeWallpaper() {
        if hasWallpaper {
            try? fileManager.removeItem(at: wallpaperURL)
        }

        updateActiveWallpaperState { state in
            state.isEnabled = false
            state.revision += 1
        }
    }

    func removeProfileData(_ profileID: UUID) {
        try? fileManager.removeItem(at: profileStorageDirectory(for: profileID))
        wallpaperProfiles.removeValue(forKey: profileID)
    }

    func applySyncSnapshot(_ snapshot: HomesteadAppearanceSettingsSyncSnapshot) {
        appearanceMode = snapshot.appearanceMode
        appColor = snapshot.appColor

        let profileIDs = Set(wallpaperProfiles.keys).union(snapshot.wallpaperEnabledProfileIDs)
        for profileID in profileIDs {
            var state = wallpaperProfiles[profileID] ?? WallpaperProfileState()
            state.isEnabled = snapshot.wallpaperEnabledProfileIDs.contains(profileID) && hasWallpaper(for: profileID)
            wallpaperProfiles[profileID] = state
        }
    }

    private var wallpaperURL: URL {
        wallpaperURL(for: activeProfileID)
    }

    private func hasWallpaper(for profileID: UUID) -> Bool {
        fileManager.fileExists(atPath: wallpaperURL(for: profileID).path)
    }

    private func wallpaperURL(for profileID: UUID) -> URL {
        profileStorageDirectory(for: profileID)
            .appendingPathComponent(wallpaperFileName, isDirectory: false)
    }

    private func profileStorageDirectory(for profileID: UUID) -> URL {
        storageDirectory
            .appendingPathComponent("Profiles", isDirectory: true)
            .appendingPathComponent(profileID.uuidString.lowercased(), isDirectory: true)
    }

    private func updateActiveWallpaperState(_ update: (inout WallpaperProfileState) -> Void) {
        var state = wallpaperProfiles[activeProfileID] ?? WallpaperProfileState()
        update(&state)
        wallpaperProfiles[activeProfileID] = state
    }

    private func saveWallpaperProfiles() {
        guard let data = try? JSONEncoder().encode(wallpaperProfiles) else { return }
        defaults.set(data, forKey: Keys.wallpaperProfiles)
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
        static let appearanceMode = "homestead.appearance.mode"
        static let appColor = "homestead.appearance.appColor"
        static let wallpaperProfiles = "homestead.appearance.wallpaperProfiles.v1"
    }
}

nonisolated struct HomesteadAppearanceSettingsSyncSnapshot: Codable, Equatable, Sendable {
    var appearanceMode: HomesteadAppearanceMode
    var appColor: HomesteadAppColor
    var wallpaperEnabledProfileIDs: Set<UUID>

    init(
        appearanceMode: HomesteadAppearanceMode = .system,
        appColor: HomesteadAppColor = .blue,
        wallpaperEnabledProfileIDs: Set<UUID> = []
    ) {
        self.appearanceMode = appearanceMode
        self.appColor = appColor
        self.wallpaperEnabledProfileIDs = wallpaperEnabledProfileIDs
    }
}

private struct WallpaperProfileState: Codable, Equatable {
    var isEnabled = false
    var revision = 0
}
