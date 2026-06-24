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
        @Bindable var appearanceSettings = appearanceSettings

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                appearanceMode

                wallpaperSection

                navigationSection
            }
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(Color(.systemGroupedBackground))
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
    private var appearanceMode: some View {
        @Bindable var appearanceSettings = appearanceSettings

        return settingsSection("Display") {
            Picker("Mode", selection: $appearanceSettings.appearanceMode) {
                ForEach(HomesteadAppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Wallpaper
    private var wallpaperSection: some View {
        @Bindable var appearanceSettings = appearanceSettings

        return settingsSection(
            "Wallpaper",
            footer: "Shown behind Home and Areas."
        ) {
            SettingsDashboardPhonePreview(
                items: dashboardConfiguration.selectedDashboard.items,
                wallpaperURL: appearanceSettings.storedWallpaperURL,
                wallpaperRevision: appearanceSettings.wallpaperRevision,
                accessibilityLabel: "Wallpaper Preview"
            )
                .frame(width: 162)
                .frame(maxWidth: .infinity)

            wallpaperPicker
                .frame(maxWidth: .infinity)

            Divider()

            Toggle("Use Wallpaper", isOn: $appearanceSettings.isWallpaperEnabled)
                .disabled(!appearanceSettings.hasWallpaper)

            if appearanceSettings.hasWallpaper {
                Divider()

                Button(role: .destructive) {
                    appearanceSettings.removeWallpaper()
                } label: {
                    Label("Remove Wallpaper", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Navigation
    private var navigationSection: some View {
        @Bindable var tabSettings = tabSettings

        return settingsSection("Navigation", footer: "Browse stays separate.") {
            HStack {
                Text("Start Page")
                    .foregroundStyle(.primary)

                Spacer()

                Picker("Start Page", selection: $tabSettings.primaryTab) {
                    ForEach(HomesteadPrimaryTab.allCases) { tab in
                        Label(tab.displayName, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(.vertical, AppSpacing.xSmall)
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, AppSpacing.xLarge)

            VStack(alignment: .leading, spacing: AppSpacing.large) {
                content()
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground).opacity(0.76),
                in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.10), lineWidth: 0.5)
            }
            .padding(.horizontal, AppSpacing.large)

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AppSpacing.xLarge)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var wallpaperPicker: some View {
        if appearanceSettings.hasWallpaper {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                wallpaperPickerLabel("Change Wallpaper", font: .subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .disabled(isImportingWallpaper)
        } else {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                wallpaperPickerLabel("Choose Wallpaper", font: .body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImportingWallpaper)
        }
    }

    private func wallpaperPickerLabel(
        _ title: String,
        font: Font
    ) -> some View {
        Text(title)
            .lineLimit(1)
            .font(font)
    }

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

#if DEBUG
#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
    .withPreviewEnvironment()
}
#endif
