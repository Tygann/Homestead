import PhotosUI
import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(HomesteadTabSettings.self) private var tabSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingWallpaper = false
    @State private var importErrorMessage: String?

    var body: some View {
        Form {
            displaySection
            colorSection
            wallpaperSection
            navigationSection
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

    // MARK: - Display

    private var displaySection: some View {
        @Bindable var appearanceSettings = appearanceSettings

        return Section("Display") {
            Picker("Mode", selection: $appearanceSettings.appearanceMode) {
                ForEach(HomesteadAppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        Section("Color") {
            HStack {
                Text("App Color")

                Spacer()

                appColorMenu
            }
        }
    }

    private var appColorMenu: some View {
        Menu {
            ForEach(HomesteadAppColor.allCases) { appColor in
                Button {
                    appearanceSettings.appColor = appColor
                } label: {
                    HStack {
                        Label {
                            Text(appColor.displayName)
                        } icon: {
                            AppColorMenuSwatch(appColor: appColor)
                        }

                        if appColor == appearanceSettings.appColor {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .tint(Color(appColor.uiColor))
            }
        } label: {
            HStack(spacing: 6) {
                AppColorSwatch(appColor: appearanceSettings.appColor, size: 12)

                Text(appearanceSettings.appColor.displayName)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)
        }
        .tint(.secondary)
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

    // MARK: - Navigation

    private var navigationSection: some View {
        @Bindable var tabSettings = tabSettings

        return Section {
            Picker("Start Page", selection: $tabSettings.primaryTab) {
                ForEach(HomesteadPrimaryTab.allCases) { tab in
                    Text(tab.displayName)
                        .tag(tab)
                }
            }
            .pickerStyle(.menu)
            .tint(.secondary)
        } header: {
            Text("Navigation")
//        } footer: {
//            Text("Browse stays separate.")
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

private struct AppColorSwatch: View {
    let appColor: HomesteadAppColor
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color(appColor.uiColor))
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

private struct AppColorMenuSwatch: View {
    let appColor: HomesteadAppColor

    var body: some View {
        Image(systemName: "circle.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color(appColor.uiColor))
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
