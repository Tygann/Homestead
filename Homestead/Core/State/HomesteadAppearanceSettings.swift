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

nonisolated enum DashboardBackgroundChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case defaultWallpaper
    case customWallpaper
    case noWallpaper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultWallpaper:
            "Default Wallpaper"
        case .noWallpaper:
            "No Wallpaper"
        case .customWallpaper:
            "Custom Wallpaper"
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
    private var dashboardBackgrounds: [UUID: [UUID: DashboardBackgroundState]] {
        didSet { saveDashboardBackgrounds() }
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
        dashboardBackgrounds = defaults.data(forKey: Keys.dashboardBackgrounds).flatMap {
            try? JSONDecoder().decode([UUID: [UUID: DashboardBackgroundState]].self, from: $0)
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

    func dashboardBackgroundChoice(for dashboardID: UUID) -> DashboardBackgroundChoice {
        dashboardBackgrounds[activeProfileID]?[dashboardID]?.choice ?? .defaultWallpaper
    }

    func setDashboardBackgroundChoice(_ choice: DashboardBackgroundChoice, for dashboardID: UUID) {
        var profileBackgrounds = dashboardBackgrounds[activeProfileID] ?? [:]
        var state = profileBackgrounds[dashboardID] ?? DashboardBackgroundState()
        state.choice = choice
        profileBackgrounds[dashboardID] = state
        dashboardBackgrounds[activeProfileID] = profileBackgrounds
    }

    func hasCustomDashboardWallpaper(for dashboardID: UUID) -> Bool {
        fileManager.fileExists(atPath: dashboardWallpaperURL(for: dashboardID).path)
    }

    func storedDashboardWallpaperURL(for dashboardID: UUID) -> URL? {
        hasCustomDashboardWallpaper(for: dashboardID) ? dashboardWallpaperURL(for: dashboardID) : nil
    }

    func resolvedWallpaperURL(for dashboardID: UUID?) -> URL? {
        guard let dashboardID else {
            return activeWallpaperURL
        }

        switch dashboardBackgroundChoice(for: dashboardID) {
        case .defaultWallpaper:
            return activeWallpaperURL
        case .noWallpaper:
            return nil
        case .customWallpaper:
            return storedDashboardWallpaperURL(for: dashboardID) ?? activeWallpaperURL
        }
    }

    func wallpaperPresentationRevision(for dashboardID: UUID?) -> Int {
        guard let dashboardID else {
            return wallpaperRevision
        }

        let dashboardRevision = dashboardBackgrounds[activeProfileID]?[dashboardID]?.revision ?? 0
        return wallpaperRevision &* 31 &+ dashboardRevision
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
        try writeOptimizedWallpaper(
            from: imageData,
            to: wallpaperURL,
            directory: profileStorageDirectory(for: activeProfileID)
        )
        updateActiveWallpaperState { state in
            state.isEnabled = true
            state.revision += 1
        }
    }

    func importDashboardWallpaper(from imageData: Data, for dashboardID: UUID) async throws {
        try writeOptimizedWallpaper(
            from: imageData,
            to: dashboardWallpaperURL(for: dashboardID),
            directory: dashboardStorageDirectory(for: dashboardID)
        )

        var profileBackgrounds = dashboardBackgrounds[activeProfileID] ?? [:]
        var state = profileBackgrounds[dashboardID] ?? DashboardBackgroundState()
        state.choice = .customWallpaper
        state.revision += 1
        profileBackgrounds[dashboardID] = state
        dashboardBackgrounds[activeProfileID] = profileBackgrounds
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

    func removeDashboardWallpaper(for dashboardID: UUID) {
        try? fileManager.removeItem(at: dashboardStorageDirectory(for: dashboardID))
        var profileBackgrounds = dashboardBackgrounds[activeProfileID] ?? [:]
        profileBackgrounds.removeValue(forKey: dashboardID)
        dashboardBackgrounds[activeProfileID] = profileBackgrounds
    }

    func reconcileDashboardBackgrounds(
        for profileID: UUID,
        validDashboardIDs: Set<UUID>
    ) {
        guard var profileBackgrounds = dashboardBackgrounds[profileID] else { return }
        let removedDashboardIDs = Set(profileBackgrounds.keys).subtracting(validDashboardIDs)
        guard !removedDashboardIDs.isEmpty else { return }

        for dashboardID in removedDashboardIDs {
            try? fileManager.removeItem(
                at: dashboardStorageDirectory(for: dashboardID, profileID: profileID)
            )
            profileBackgrounds.removeValue(forKey: dashboardID)
        }

        if profileBackgrounds.isEmpty {
            dashboardBackgrounds.removeValue(forKey: profileID)
        } else {
            dashboardBackgrounds[profileID] = profileBackgrounds
        }
    }

    func copyDashboardBackground(from sourceID: UUID, to destinationID: UUID) {
        removeDashboardWallpaper(for: destinationID)

        let sourceState = dashboardBackgrounds[activeProfileID]?[sourceID] ?? DashboardBackgroundState()
        var copiedState = sourceState

        if sourceState.choice == .customWallpaper,
           let sourceURL = storedDashboardWallpaperURL(for: sourceID) {
            do {
                try fileManager.createDirectory(
                    at: dashboardStorageDirectory(for: destinationID),
                    withIntermediateDirectories: true
                )
                try fileManager.copyItem(at: sourceURL, to: dashboardWallpaperURL(for: destinationID))
                copiedState.revision += 1
            } catch {
                copiedState = DashboardBackgroundState()
            }
        }

        guard copiedState != DashboardBackgroundState() else { return }
        var profileBackgrounds = dashboardBackgrounds[activeProfileID] ?? [:]
        profileBackgrounds[destinationID] = copiedState
        dashboardBackgrounds[activeProfileID] = profileBackgrounds
    }

    func removeProfileData(_ profileID: UUID) {
        try? fileManager.removeItem(at: profileStorageDirectory(for: profileID))
        wallpaperProfiles.removeValue(forKey: profileID)
        dashboardBackgrounds.removeValue(forKey: profileID)
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

    private func dashboardStorageDirectory(for dashboardID: UUID) -> URL {
        dashboardStorageDirectory(for: dashboardID, profileID: activeProfileID)
    }

    private func dashboardStorageDirectory(for dashboardID: UUID, profileID: UUID) -> URL {
        profileStorageDirectory(for: profileID)
            .appendingPathComponent("Dashboards", isDirectory: true)
            .appendingPathComponent(dashboardID.uuidString.lowercased(), isDirectory: true)
    }

    private func dashboardWallpaperURL(for dashboardID: UUID) -> URL {
        dashboardStorageDirectory(for: dashboardID)
            .appendingPathComponent(wallpaperFileName, isDirectory: false)
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

    private func saveDashboardBackgrounds() {
        guard let data = try? JSONEncoder().encode(dashboardBackgrounds) else { return }
        defaults.set(data, forKey: Keys.dashboardBackgrounds)
    }

    private func writeOptimizedWallpaper(
        from imageData: Data,
        to url: URL,
        directory: URL
    ) throws {
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
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw HomesteadAppearanceSettingsError.unableToCreateStorageDirectory
        }

        try optimizedData.write(to: url, options: [.atomic])
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
        static let dashboardBackgrounds = "homestead.appearance.dashboardBackgrounds.v1"
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

private struct DashboardBackgroundState: Codable, Equatable {
    var choice: DashboardBackgroundChoice = .defaultWallpaper
    var revision = 0
}
