#if DEBUG
import SwiftUI
import UIKit

struct SettingsReferenceGallery: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Settings") {
                    NavigationLink("Root Settings") {
                        SettingsView()
                            .withPreviewEnvironment(.settingsSample(.healthy))
                    }

                    NavigationLink("Homestead Plus — Free") {
                        HomesteadPlusView()
                            .environment(HomesteadEntitlementStore(previewPlan: .free))
                    }

                    NavigationLink("Homestead Plus — Lifetime") {
                        HomesteadPlusView()
                            .environment(HomesteadEntitlementStore(previewPlan: .lifetime))
                    }
                }

                Section("Dashboard Paging") {
                    NavigationLink("Home with Bottom Navigation") {
                        ContentView()
                            .withPreviewEnvironment(.dashboardPagingSample)
                    }

                    NavigationLink("One Home Page") {
                        DashboardView()
                            .withPreviewEnvironment(.dashboardSample(pageCount: 1))
                    }

                    NavigationLink("Several Home Pages") {
                        DashboardView()
                            .withPreviewEnvironment(.dashboardSample(pageCount: 3))
                    }

                    NavigationLink("Five Pages, Last Selected") {
                        DashboardView()
                            .withPreviewEnvironment(
                                .dashboardSample(pageCount: 5, selectedPageIndex: 4)
                            )
                    }

                    NavigationLink("Several Pages with Wallpaper") {
                        DashboardWallpaperPreviewHost()
                            .withPreviewEnvironment(.dashboardSample(pageCount: 3))
                    }

                    NavigationLink("Visibility and Reordering") {
                        DashboardSettingsView()
                            .withPreviewEnvironment(
                                .dashboardSample(pageCount: 3, disablesLastDashboard: true)
                            )
                    }

                    NavigationLink("Appearance Phone Preview") {
                        AppearanceSettingsPreviewHost()
                            .withPreviewEnvironment(.dashboardSample(pageCount: 3))
                    }

                    NavigationLink("Dashboard Detail Phone Preview") {
                        DashboardDetailPreviewReference()
                            .withPreviewEnvironment(.dashboardSample(pageCount: 3))
                    }

                    NavigationLink("Accessibility Dynamic Type") {
                        DashboardSettingsView()
                            .environment(\.dynamicTypeSize, .accessibility3)
                            .withPreviewEnvironment(
                                .dashboardSample(pageCount: 3, disablesLastDashboard: true)
                            )
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

struct AppearanceSettingsPreviewHost: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    var body: some View {
        AppearanceSettingsView()
            .task {
                if !appearanceSettings.hasWallpaper {
                    try? await appearanceSettings.importWallpaper(from: SamplePreviewWallpaper.data)
                }
                addOverflowingPreviewCardsIfNeeded()
                appearanceSettings.isWallpaperEnabled = false
            }
    }

    private func addOverflowingPreviewCardsIfNeeded() {
        guard dashboardConfiguration.items.count < 16 else { return }

        for index in dashboardConfiguration.items.count..<16 {
            let entityID = index.isMultiple(of: 2) ? "light.bedroom" : "light.kitchen"
            _ = dashboardConfiguration.add(
                source: .entity(entityID),
                presentation: .card(.control(layout: .square))
            )
        }
    }
}

private struct DashboardWallpaperPreviewHost: View {
    @Environment(HomesteadAppearanceSettings.self) private var appearanceSettings

    var body: some View {
        DashboardView()
            .task {
                guard !appearanceSettings.hasWallpaper else {
                    appearanceSettings.isWallpaperEnabled = true
                    return
                }
                try? await appearanceSettings.importWallpaper(from: SamplePreviewWallpaper.data)
            }
    }
}

private enum SamplePreviewWallpaper {
    static var data: Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 1_600))
        return renderer.jpegData(withCompressionQuality: 0.9) { context in
            let colors = [
                UIColor.systemIndigo.cgColor,
                UIColor.systemPink.cgColor,
                UIColor.systemOrange.cgColor
            ] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.52, 1]
            )
            context.cgContext.drawLinearGradient(
                gradient!,
                start: .zero,
                end: CGPoint(x: 900, y: 1_600),
                options: []
            )
        }
    }
}

private struct DashboardDetailPreviewReference: View {
    @Environment(DashboardConfiguration.self) private var dashboardConfiguration

    var body: some View {
        if let dashboard = dashboardConfiguration.dashboards.first {
            DashboardDetailSettingsView(
                dashboard: dashboard
            )
        }
    }
}

#Preview("Settings Reference Gallery") {
    SettingsReferenceGallery()
        .withPreviewEnvironment(.settingsSample(.healthy))
}
#endif
