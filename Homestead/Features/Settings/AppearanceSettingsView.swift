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

        Form {
            Section {
                if appearanceSettings.hasWallpaper {
                    WallpaperPreview()
                }

                Toggle("Use Wallpaper", isOn: $appearanceSettings.isWallpaperEnabled)
                    .disabled(!appearanceSettings.hasWallpaper)

                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(
                        appearanceSettings.hasWallpaper ? "Change Wallpaper" : "Choose Wallpaper",
                        systemImage: "photo"
                    )
                }
                .disabled(isImportingWallpaper)

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
                Text("Shown behind Home and Areas.")
            }
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

private struct WallpaperPreview: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @State private var previewImage: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.18), lineWidth: 0.5)
        }
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
