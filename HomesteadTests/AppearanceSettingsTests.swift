import Foundation
import Testing
import UIKit
@testable import Homestead

struct AppearanceSettingsTests {
    @Test @MainActor func appearanceSettingsPersistsImportedWallpaperState() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(defaults: defaults, storageDirectory: directory)
        #expect(!settings.hasWallpaper)
        #expect(!settings.isWallpaperEnabled)

        try await settings.importWallpaper(from: testImageData(color: .systemTeal))

        #expect(settings.hasWallpaper)
        #expect(settings.isWallpaperEnabled)
        #expect(settings.activeWallpaperURL != nil)

        let reloadedSettings = HomesteadAppearanceSettings(defaults: defaults, storageDirectory: directory)
        #expect(reloadedSettings.hasWallpaper)
        #expect(reloadedSettings.isWallpaperEnabled)
        #expect(reloadedSettings.wallpaperRevision == settings.wallpaperRevision)
    }

    @Test @MainActor func appearanceSettingsFallsBackWhenStoredWallpaperFileIsMissing() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(defaults: defaults, storageDirectory: directory)
        try await settings.importWallpaper(from: testImageData(color: .systemBlue))
        let storedWallpaperURL = try #require(settings.storedWallpaperURL)
        try FileManager.default.removeItem(at: storedWallpaperURL)

        let reloadedSettings = HomesteadAppearanceSettings(defaults: defaults, storageDirectory: directory)
        #expect(!reloadedSettings.hasWallpaper)
        #expect(reloadedSettings.activeWallpaperURL == nil)
        #expect(reloadedSettings.isWallpaperEnabled)
    }

    @Test @MainActor func appearanceSettingsRemoveDeletesWallpaperAndDisablesIt() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(defaults: defaults, storageDirectory: directory)
        try await settings.importWallpaper(from: testImageData(color: .systemGreen))
        let revisionAfterImport = settings.wallpaperRevision

        settings.removeWallpaper()

        #expect(!settings.hasWallpaper)
        #expect(!settings.isWallpaperEnabled)
        #expect(settings.activeWallpaperURL == nil)
        #expect(settings.wallpaperRevision == revisionAfterImport + 1)
    }

    @Test @MainActor func appearanceSettingsReplacementUpdatesStoredImageAndRevision() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(defaults: defaults, storageDirectory: directory)
        try await settings.importWallpaper(from: testImageData(color: .systemRed))
        let firstRevision = settings.wallpaperRevision
        let storedWallpaperURL = try #require(settings.storedWallpaperURL)
        let firstStoredData = try Data(contentsOf: storedWallpaperURL)

        try await settings.importWallpaper(from: testImageData(color: .systemPurple))
        let replacementStoredData = try Data(contentsOf: storedWallpaperURL)

        #expect(settings.wallpaperRevision == firstRevision + 1)
        #expect(settings.hasWallpaper)
        #expect(settings.isWallpaperEnabled)
        #expect(firstStoredData != replacementStoredData)
    }
}
