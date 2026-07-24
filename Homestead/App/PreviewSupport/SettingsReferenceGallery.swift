#if DEBUG
import SwiftUI

struct SettingsReferenceGallery: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Settings") {
                    NavigationLink("Root Settings") {
                        SettingsView()
                            .withPreviewEnvironment(.settingsSample(.healthy))
                    }
                }

                Section("Account") {
                    NavigationLink("Connected") {
                        HomeAssistantSettingsView()
                            .withPreviewEnvironment(.settingsSample(.healthy))
                    }

                    NavigationLink("Server Mismatch") {
                        HomeAssistantSettingsView()
                            .withPreviewEnvironment(.settingsSample(.degraded))
                    }

                    NavigationLink("Sheet over Wallpaper") {
                        AccountSettingsSheetPreviewHost(usesWallpaperBackdrop: true)
                            .withPreviewEnvironment(.settingsSample(.healthy))
                    }

                    NavigationLink("Sheet without Wallpaper") {
                        AccountSettingsSheetPreviewHost(usesWallpaperBackdrop: false)
                            .withPreviewEnvironment(.settingsSample(.healthy))
                    }
                }

                Section("Support & Diagnostics") {
                    NavigationLink("Healthy") {
                        HomeAssistantDiagnosticsView()
                            .withPreviewEnvironment(.settingsSample(.healthy))
                    }

                    NavigationLink("Degraded") {
                        HomeAssistantDiagnosticsView()
                            .withPreviewEnvironment(.settingsSample(.degraded))
                    }
                }

                Section("Privacy & Permissions") {
                    NavigationLink("Not Requested") {
                        NativePermissionsSettingsView()
                            .withPreviewEnvironment(.settingsSample(.permissionsNotRequested))
                    }

                    NavigationLink("Allowed") {
                        NativePermissionsSettingsView()
                            .withPreviewEnvironment(.settingsSample(.permissionsAllowed))
                    }

                    NavigationLink("Denied") {
                        NativePermissionsSettingsView()
                            .withPreviewEnvironment(.settingsSample(.permissionsDenied))
                    }

                    NavigationLink("Accessibility Dynamic Type") {
                        NativePermissionsSettingsView()
                            .environment(\.dynamicTypeSize, .accessibility3)
                            .withPreviewEnvironment(.settingsSample(.permissionsDenied))
                    }
                }
            }
            .navigationTitle("Settings Reference")
        }
    }
}

#Preview("Settings Reference Gallery") {
    SettingsReferenceGallery()
        .withPreviewEnvironment(.settingsSample(.healthy))
}
#endif
