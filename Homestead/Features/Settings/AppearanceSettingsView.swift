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

                    wallpaperPicker

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
                .background(
                    Color(.secondarySystemGroupedBackground).opacity(0.76),
                    in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.10), lineWidth: 0.5)
                }
                .padding(.horizontal, AppSpacing.large)

                if !appearanceSettings.hasWallpaper {
                    Text("Shown behind Home and Areas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppSpacing.xLarge)
                }
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

    @ViewBuilder
    private var wallpaperPicker: some View {
        if appearanceSettings.hasWallpaper {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Change Wallpaper", systemImage: "photo")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .disabled(isImportingWallpaper)
        } else {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose Wallpaper", systemImage: "photo")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImportingWallpaper)
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
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 7) {
            Text("Homestead")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                previewChip(width: 38)
                previewChip(width: 32)
                previewChip(width: 38)
            }

            previewRowCard(height: 34)

            HStack(spacing: 7) {
                previewSquareCard()
                previewSquareCard()
            }

            Spacer(minLength: 0)

            previewTabBar
        }
        .padding(11)
    }

    private func previewChip(width: CGFloat) -> some View {
        Capsule()
            .fill(.thinMaterial)
            .frame(width: width, height: 13)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground).opacity(0.70))
                    .frame(width: 7, height: 7)
                    .padding(.leading, 5)
            }
    }

    private func previewRowCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.thinMaterial)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.22), lineWidth: 0.5)
            }
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 22, height: 22)
                    .padding(.leading, 9)
            }
    }

    private func previewSquareCard() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.thinMaterial)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.22), lineWidth: 0.5)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground).opacity(0.70))
                    .frame(width: 24, height: 24)
                    .padding(9)
            }
    }

    private var previewTabBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.thinMaterial)

            Capsule()
                .fill(Color(.tertiarySystemGroupedBackground).opacity(0.70))
                .frame(width: 42)
                .padding(3)

            HStack {
                Image(systemName: "house.fill")
                Spacer()
                Image(systemName: "square.split.bottomrightquarter.fill")
                Spacer()
                Image(systemName: "magnifyingglass")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 17)
        }
        .frame(height: 31)
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
