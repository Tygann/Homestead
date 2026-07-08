import PhotosUI
import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(HomesteadTabSettings.self) private var tabSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingWallpaper = false
    @State private var importErrorMessage: String?

    var body: some View {
        Form {
            appearanceSection
            wallpaperSection
        }
        .navigationTitle("Appearance")
        .toolbarTitleDisplayMode(.inline)
        .task(id: selectedPhoto) {
            await importSelectedWallpaper()
        }
        .alert("Couldn't Use Photo", isPresented: importErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Choose another photo and try again.")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        @Bindable var appearanceSettings = appearanceSettings
        @Bindable var tabSettings = tabSettings

        return Section {
            Picker("Mode", selection: $appearanceSettings.appearanceMode) {
                ForEach(HomesteadAppearanceMode.allCases) { mode in
                    Text(mode.displayName)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)

            Picker("App Color", selection: $appearanceSettings.appColor) {
                ForEach(HomesteadAppColor.allCases) { appColor in
                    Label {
                        Text(appColor.displayName)
                    } icon: {
                        AppColorMenuSwatch(appColor: appColor)
                    }
                    .tag(appColor)
                }
            }
            .pickerStyle(.menu)

            Picker("Start Page", selection: $tabSettings.primaryTab) {
                ForEach(HomesteadPrimaryTab.allCases) { tab in
                    Label(tab.displayName, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Wallpaper

    private var wallpaperSection: some View {
        @Bindable var appearanceSettings = appearanceSettings

        return Section {
            VStack(spacing: AppSpacing.medium) {
                SettingsDashboardPhonePreview(
                    items: dashboardConfiguration.selectedDashboard.items,
                    dashboardTitle: dashboardConfiguration.selectedDashboard.resolvedDisplayTitle,
                    wallpaperURL: appearanceSettings.storedWallpaperURL,
                    wallpaperRevision: appearanceSettings.wallpaperRevision,
                    accessibilityLabel: "Wallpaper Preview"
                )
                .frame(width: 162)

                wallpaperPicker
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
            .listRowSeparator(.hidden)

            Toggle("Use Wallpaper", isOn: $appearanceSettings.isWallpaperEnabled)
                .disabled(!appearanceSettings.hasWallpaper)

            if appearanceSettings.hasWallpaper {
                Button(role: .destructive) {
                    appearanceSettings.removeWallpaper()
                } label: {
                    Label("Remove Wallpaper", systemImage: "trash")
                }
            }
        } header: {
            Text("Wallpaper")
        } footer: {
            Text("Wallpaper appears behind Home and Areas.")
        }
    }

    @ViewBuilder
    private var wallpaperPicker: some View {
        if appearanceSettings.hasWallpaper {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Change Wallpaper")
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .disabled(isImportingWallpaper)
        } else {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Choose Wallpaper")
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImportingWallpaper)
        }
    }

    // MARK: - Import

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importErrorMessage = nil
                }
            }
        )
    }

    private func importSelectedWallpaper() async {
        guard let selectedPhoto else {
            return
        }

        isImportingWallpaper = true
        defer {
            isImportingWallpaper = false
            self.selectedPhoto = nil
        }

        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                throw HomesteadAppearanceSettingsError.invalidImage
            }

            try await appearanceSettings.importWallpaper(from: data)
        } catch {
            importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct AppColorMenuSwatch: View {
    let appColor: HomesteadAppColor

    var body: some View {
        Image(uiImage: swatchImage)
            .renderingMode(.original)
            .accessibilityHidden(true)
    }

    private var swatchImage: UIImage {
        UIImage(systemName: "circle.fill")?
            .withTintColor(appColor.uiColor, renderingMode: .alwaysOriginal) ?? UIImage()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
