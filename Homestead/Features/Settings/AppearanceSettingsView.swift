import PhotosUI
import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImportingWallpaper = false
    @State private var importErrorMessage: String?

    var body: some View {
        @Bindable var appearanceSettings = appearanceSettings

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text("Wallpaper")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AppSpacing.large)

                VStack(spacing: AppSpacing.large) {
                    WallpaperPhonePreview()
                        .frame(width: 162)
                        .frame(maxWidth: .infinity)

                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            appearanceSettings.hasWallpaper ? "Change Wallpaper" : "Choose Wallpaper",
                            systemImage: "photo"
                        )
                        .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImportingWallpaper)

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
                .padding(AppSpacing.large)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .padding(.horizontal, AppSpacing.large)

                Text("Shown behind Home and Areas.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AppSpacing.xLarge)
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

private struct WallpaperPhonePreview: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @State private var previewImage: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

            GeometryReader { proxy in
                ZStack {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()

                        Color.black.opacity(0.10)
                        Color(.systemGroupedBackground).opacity(0.12)
                    } else {
                        LinearGradient(
                            colors: [
                                Color(.tertiarySystemGroupedBackground),
                                Color(.secondarySystemGroupedBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(systemName: "photo")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    previewChrome
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .padding(8)
        }
        .aspectRatio(0.49, contentMode: .fit)
        .accessibilityLabel("Wallpaper Preview")
        .task(id: previewTaskID) {
            loadPreviewImage()
        }
    }

    private var previewTaskID: String {
        [
            appearanceSettings.wallpaperRevision.description,
            appearanceSettings.activeWallpaperURL?.path ?? "none"
        ].joined(separator: "|")
    }

    private var previewChrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Homestead")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                previewChip(title: "Climate", value: "72")
                previewChip(title: "Lights", value: "5 On")
            }

            previewRowCard(height: 38, isActive: true)

            HStack(spacing: 7) {
                previewSquareCard()
                previewSquareCard()
            }

            Spacer(minLength: 0)

            previewTabBar
        }
        .padding(12)
    }

    private func previewChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.34), in: Capsule())
    }

    private func previewRowCard(height: CGFloat, isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                isActive
                    ? Color.accentColor.opacity(0.26)
                    : Color.black.opacity(0.46)
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 24, height: 24)
                    .padding(.leading, 10)
            }
    }

    private func previewSquareCard() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.46))
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .frame(width: 26, height: 26)
                    .padding(10)
            }
    }

    private var previewTabBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.30))

            Capsule()
                .fill(Color.black.opacity(0.22))
                .frame(width: 48)
                .padding(3)

            HStack {
                Image(systemName: "house.fill")
                Spacer()
                Image(systemName: "square.split.bottomrightquarter.fill")
                Spacer()
                Image(systemName: "magnifyingglass")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
        }
        .frame(height: 34)
    }

    private func loadPreviewImage() {
        guard let url = appearanceSettings.storedWallpaperURL,
              let image = UIImage(contentsOfFile: url.path) else {
            previewImage = nil
            return
        }

        previewImage = image
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
