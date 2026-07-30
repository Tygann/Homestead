import Foundation
import Testing
import UIKit
@testable import Homestead

struct AppearanceSettingsTests {
    private static let primaryProfileID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let secondaryProfileID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let primaryDashboardID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private static let secondaryDashboardID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    @Test @MainActor func appearanceSettingsPersistsAppColor() throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
        #expect(settings.appColor == .blue)

        settings.appColor = .green

        let reloadedSettings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
        #expect(reloadedSettings.appColor == .green)
    }

    @Test @MainActor func appearanceSettingsSyncSnapshotIncludesAppColor() throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
        settings.appColor = .purple

        #expect(settings.syncSnapshot.appColor == .purple)

        settings.applySyncSnapshot(HomesteadAppearanceSettingsSyncSnapshot(appColor: .orange))
        #expect(settings.appColor == .orange)
    }

    @Test func appearanceSettingsSyncSnapshotIncludesProfileWallpaperState() {
        let snapshot = HomesteadAppearanceSettingsSyncSnapshot(
            appearanceMode: .dark,
            appColor: .orange,
            wallpaperEnabledProfileIDs: [Self.primaryProfileID]
        )

        #expect(snapshot.appearanceMode == .dark)
        #expect(snapshot.appColor == .orange)
        #expect(snapshot.wallpaperEnabledProfileIDs == [Self.primaryProfileID])
    }

    @Test @MainActor func appearanceSettingsPersistsImportedWallpaperState() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
        #expect(!settings.hasWallpaper)
        #expect(!settings.isWallpaperEnabled)

        try await settings.importWallpaper(from: testImageData(color: .systemTeal))

        #expect(settings.hasWallpaper)
        #expect(settings.isWallpaperEnabled)
        #expect(settings.activeWallpaperURL != nil)

        let reloadedSettings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
        #expect(reloadedSettings.hasWallpaper)
        #expect(reloadedSettings.isWallpaperEnabled)
        #expect(reloadedSettings.wallpaperRevision == settings.wallpaperRevision)
    }

    @Test @MainActor func appearanceSettingsFallsBackWhenStoredWallpaperFileIsMissing() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
        try await settings.importWallpaper(from: testImageData(color: .systemBlue))
        let storedWallpaperURL = try #require(settings.storedWallpaperURL)
        try FileManager.default.removeItem(at: storedWallpaperURL)

        let reloadedSettings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
        #expect(!reloadedSettings.hasWallpaper)
        #expect(reloadedSettings.activeWallpaperURL == nil)
        #expect(reloadedSettings.isWallpaperEnabled)
    }

    @Test @MainActor func appearanceSettingsRemoveDeletesWallpaperAndDisablesIt() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
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

        let settings = HomesteadAppearanceSettings(profileID: Self.primaryProfileID, defaults: defaults, storageDirectory: directory)
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

    @Test @MainActor func appearanceSettingsScopesWallpaperToActiveProfile() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        try await settings.importWallpaper(from: testImageData(color: .systemRed))
        let primaryWallpaperData = try Data(contentsOf: #require(settings.storedWallpaperURL))

        settings.activateProfile(Self.secondaryProfileID)
        #expect(!settings.hasWallpaper)
        #expect(!settings.isWallpaperEnabled)

        try await settings.importWallpaper(from: testImageData(color: .systemBlue))
        let secondaryWallpaperURL = try #require(settings.storedWallpaperURL)
        let secondaryWallpaperData = try Data(contentsOf: secondaryWallpaperURL)
        #expect(primaryWallpaperData != secondaryWallpaperData)

        settings.isWallpaperEnabled = false
        settings.activateProfile(Self.primaryProfileID)
        #expect(settings.hasWallpaper)
        #expect(settings.isWallpaperEnabled)
        #expect(try Data(contentsOf: #require(settings.storedWallpaperURL)) == primaryWallpaperData)

        settings.activateProfile(Self.secondaryProfileID)
        #expect(settings.hasWallpaper)
        #expect(!settings.isWallpaperEnabled)
        #expect(settings.storedWallpaperURL == secondaryWallpaperURL)
    }

    @Test @MainActor func appearanceSettingsRemovesOnlyRequestedProfileData() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        try await settings.importWallpaper(from: testImageData(color: .systemRed))
        settings.activateProfile(Self.secondaryProfileID)
        try await settings.importWallpaper(from: testImageData(color: .systemBlue))

        settings.removeProfileData(Self.primaryProfileID)
        #expect(settings.hasWallpaper)
        #expect(settings.isWallpaperEnabled)

        settings.activateProfile(Self.primaryProfileID)
        #expect(!settings.hasWallpaper)
        #expect(!settings.isWallpaperEnabled)
    }

    @Test @MainActor func dashboardBackgroundChoicePersistsPerProfileAndDashboard() throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        settings.setDashboardBackgroundChoice(.noWallpaper, for: Self.primaryDashboardID)
        settings.setDashboardBackgroundChoice(.customWallpaper, for: Self.secondaryDashboardID)

        let reloadedSettings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        #expect(reloadedSettings.dashboardBackgroundChoice(for: Self.primaryDashboardID) == .noWallpaper)
        #expect(reloadedSettings.dashboardBackgroundChoice(for: Self.secondaryDashboardID) == .customWallpaper)

        reloadedSettings.activateProfile(Self.secondaryProfileID)
        #expect(reloadedSettings.dashboardBackgroundChoice(for: Self.primaryDashboardID) == .defaultWallpaper)
    }

    @Test @MainActor func dashboardBackgroundResolvesDefaultNoneAndCustomWallpaper() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        try await settings.importWallpaper(from: testImageData(color: .systemRed))
        let defaultWallpaperURL = try #require(settings.activeWallpaperURL)

        #expect(settings.resolvedWallpaperURL(for: Self.primaryDashboardID) == defaultWallpaperURL)

        settings.setDashboardBackgroundChoice(.noWallpaper, for: Self.primaryDashboardID)
        #expect(settings.resolvedWallpaperURL(for: Self.primaryDashboardID) == nil)

        settings.setDashboardBackgroundChoice(.customWallpaper, for: Self.primaryDashboardID)
        #expect(settings.resolvedWallpaperURL(for: Self.primaryDashboardID) == defaultWallpaperURL)

        try await settings.importDashboardWallpaper(
            from: testImageData(color: .systemBlue),
            for: Self.primaryDashboardID
        )
        let customWallpaperURL = try #require(
            settings.storedDashboardWallpaperURL(for: Self.primaryDashboardID)
        )
        #expect(customWallpaperURL != defaultWallpaperURL)
        #expect(settings.resolvedWallpaperURL(for: Self.primaryDashboardID) == customWallpaperURL)

        settings.setDashboardBackgroundChoice(.defaultWallpaper, for: Self.primaryDashboardID)
        #expect(settings.resolvedWallpaperURL(for: Self.primaryDashboardID) == defaultWallpaperURL)
    }

    @Test @MainActor func removingDashboardWallpaperReturnsToDefault() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        try await settings.importWallpaper(from: testImageData(color: .systemRed))
        try await settings.importDashboardWallpaper(
            from: testImageData(color: .systemBlue),
            for: Self.primaryDashboardID
        )

        settings.removeDashboardWallpaper(for: Self.primaryDashboardID)

        #expect(!settings.hasCustomDashboardWallpaper(for: Self.primaryDashboardID))
        #expect(settings.dashboardBackgroundChoice(for: Self.primaryDashboardID) == .defaultWallpaper)
        #expect(settings.resolvedWallpaperURL(for: Self.primaryDashboardID) == settings.activeWallpaperURL)
    }

    @Test @MainActor func copyingDashboardBackgroundCreatesIndependentCustomImage() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        try await settings.importDashboardWallpaper(
            from: testImageData(color: .systemBlue),
            for: Self.primaryDashboardID
        )
        let originalData = try Data(contentsOf: #require(
            settings.storedDashboardWallpaperURL(for: Self.primaryDashboardID)
        ))

        settings.copyDashboardBackground(
            from: Self.primaryDashboardID,
            to: Self.secondaryDashboardID
        )

        let copiedURL = try #require(
            settings.storedDashboardWallpaperURL(for: Self.secondaryDashboardID)
        )
        #expect(settings.dashboardBackgroundChoice(for: Self.secondaryDashboardID) == .customWallpaper)
        #expect(try Data(contentsOf: copiedURL) == originalData)

        try await settings.importDashboardWallpaper(
            from: testImageData(color: .systemPurple),
            for: Self.primaryDashboardID
        )
        #expect(try Data(contentsOf: copiedURL) == originalData)
    }

    @Test @MainActor func removingDashboardWallpaperDoesNotAffectOtherDashboards() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        try await settings.importDashboardWallpaper(
            from: testImageData(color: .systemBlue),
            for: Self.primaryDashboardID
        )
        try await settings.importDashboardWallpaper(
            from: testImageData(color: .systemGreen),
            for: Self.secondaryDashboardID
        )

        settings.removeDashboardWallpaper(for: Self.primaryDashboardID)

        #expect(!settings.hasCustomDashboardWallpaper(for: Self.primaryDashboardID))
        #expect(settings.hasCustomDashboardWallpaper(for: Self.secondaryDashboardID))
        #expect(settings.dashboardBackgroundChoice(for: Self.secondaryDashboardID) == .customWallpaper)
    }

    @Test @MainActor func dashboardReconciliationRemovesOnlyOrphanedProfileWallpaper() async throws {
        let defaults = testUserDefaults()
        let directory = try temporaryTestDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let settings = HomesteadAppearanceSettings(
            profileID: Self.primaryProfileID,
            defaults: defaults,
            storageDirectory: directory
        )
        try await settings.importDashboardWallpaper(
            from: testImageData(color: .systemBlue),
            for: Self.primaryDashboardID
        )
        try await settings.importDashboardWallpaper(
            from: testImageData(color: .systemGreen),
            for: Self.secondaryDashboardID
        )
        settings.activateProfile(Self.secondaryProfileID)

        settings.reconcileDashboardBackgrounds(
            for: Self.primaryProfileID,
            validDashboardIDs: [Self.secondaryDashboardID]
        )

        settings.activateProfile(Self.primaryProfileID)
        #expect(!settings.hasCustomDashboardWallpaper(for: Self.primaryDashboardID))
        #expect(settings.dashboardBackgroundChoice(for: Self.primaryDashboardID) == .defaultWallpaper)
        #expect(settings.hasCustomDashboardWallpaper(for: Self.secondaryDashboardID))
        #expect(settings.dashboardBackgroundChoice(for: Self.secondaryDashboardID) == .customWallpaper)
    }
}
