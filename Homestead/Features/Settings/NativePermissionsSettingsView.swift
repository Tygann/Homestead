import SwiftUI
import UIKit

// MARK: - Native Permissions Settings View
struct NativePermissionsSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(NativeNotificationService.self) private var nativeNotificationService
    @Environment(NativePermissionService.self) private var nativePermissionService

    var body: some View {
        Form {
            Section {
                NativePermissionStatusRow(
                    title: "Notifications",
                    message: notificationMessage,
                    badgeText: notificationBadgeText,
                    systemImage: notificationSystemImage,
                    tint: nativeNotificationService.status.authorizationStatus.permissionTint
                )

                NativePermissionStatusRow(
                    title: "Local Network",
                    message: "Needed for Home Assistant servers on your home network.",
                    badgeText: nativePermissionService.status.localNetwork.permissionBadgeText,
                    systemImage: "network",
                    tint: nativePermissionService.status.localNetwork.permissionTint
                )

                NativePermissionStatusRow(
                    title: "Location",
                    message: locationMessage,
                    badgeText: nativePermissionService.status.location.permissionBadgeText,
                    systemImage: "location.fill",
                    tint: nativePermissionService.status.location.permissionTint
                )

                NativePermissionStatusRow(
                    title: "Camera",
                    message: cameraMessage,
                    badgeText: nativePermissionService.status.camera.permissionBadgeText,
                    systemImage: "camera.fill",
                    tint: nativePermissionService.status.camera.permissionTint
                )

                if let message = nativePermissionService.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("iOS controls permission decisions. Homestead only requests access when a native feature needs it.")
            }

            if showsPermissionActions {
                Section {
                    if nativePermissionService.status.location.canRequestInApp {
                        Button {
                            Task { await nativePermissionService.requestLocationAccess() }
                        } label: {
                            Label(
                                nativePermissionService.isRequestingLocationAccess ? "Requesting Location" : "Allow Location",
                                systemImage: "location.fill"
                            )
                        }
                        .disabled(nativePermissionService.isRequestingLocationAccess)
                    }

                    if nativePermissionService.status.camera.canRequestInApp {
                        Button {
                            Task { await nativePermissionService.requestCameraAccess() }
                        } label: {
                            Label(
                                nativePermissionService.isRequestingCameraAccess ? "Requesting Camera" : "Allow Camera",
                                systemImage: "camera.fill"
                            )
                        }
                        .disabled(nativePermissionService.isRequestingCameraAccess)
                    }
                }
            }

            Section {
                NavigationLink {
                    NativeNotificationSettingsView()
                } label: {
                    Label("Notification Settings", systemImage: "bell.badge")
                }

                Button {
                    openIOSSettings()
                } label: {
                    Label("Open Homestead in iOS Settings", systemImage: "gearshape")
                }

                Button {
                    Task {
                        await nativeNotificationService.refreshAuthorizationStatus()
                        await nativePermissionService.refreshStatus()
                    }
                } label: {
                    Label(refreshButtonTitle, systemImage: "arrow.clockwise")
                }
                .disabled(nativeNotificationService.isRefreshing || nativePermissionService.isRefreshing)
            }
        }
        .navigationTitle("Permissions")
        .toolbarTitleDisplayMode(.inline)
        .task {
            await nativeNotificationService.refreshAuthorizationStatus()
            await nativePermissionService.refreshStatus()
        }
    }

    private var showsPermissionActions: Bool {
        nativePermissionService.status.location.canRequestInApp ||
            nativePermissionService.status.camera.canRequestInApp
    }

    private var refreshButtonTitle: String {
        nativeNotificationService.isRefreshing || nativePermissionService.isRefreshing ? "Refreshing" : "Refresh Status"
    }

    private var notificationBadgeText: String {
        nativeNotificationService.status.authorizationStatus.permissionBadgeText
    }

    private var notificationSystemImage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        case .notDetermined, .unknown:
            return "bell.badge"
        }
    }

    private var notificationMessage: String {
        switch nativeNotificationService.status.authorizationStatus {
        case .authorized:
            return "Home Assistant alerts can appear on this iPhone."
        case .provisional:
            return "Home Assistant alerts can be delivered quietly."
        case .ephemeral:
            return "Notification access is temporarily allowed."
        case .denied:
            return "Turn on notifications in iOS Settings."
        case .notDetermined:
            return "Set up alerts from Notification Settings."
        case .unknown:
            return "Homestead is checking notification access."
        }
    }

    private var locationMessage: String {
        switch nativePermissionService.status.location {
        case .allowed:
            return "Ready for presence features that use this iPhone."
        case .limited:
            return "Location access is limited."
        case .denied:
            return "Turn on location in iOS Settings."
        case .restricted:
            return "Location access is restricted on this device."
        case .notDetermined:
            return "Allow when a presence feature needs this iPhone's location."
        case .unavailable:
            return "Location Services are off or unavailable."
        case .managedBySystem:
            return "Managed by iOS."
        case .unknown:
            return "Homestead is checking location access."
        }
    }

    private var cameraMessage: String {
        switch nativePermissionService.status.camera {
        case .allowed:
            return "Ready for camera-based setup and scanning features."
        case .limited:
            return "Camera access is limited."
        case .denied:
            return "Turn on camera access in iOS Settings."
        case .restricted:
            return "Camera access is restricted on this device."
        case .notDetermined:
            return "Allow when a native setup feature needs the camera."
        case .unavailable:
            return "Camera access is unavailable on this device."
        case .managedBySystem:
            return "Managed by iOS."
        case .unknown:
            return "Homestead is checking camera access."
        }
    }

    private func openIOSSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(url)
    }
}

private struct NativePermissionStatusRow: View {
    let title: String
    let message: String
    let badgeText: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.small)

                Text(badgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12), in: Capsule())
            }
            .padding(.vertical, AppSpacing.xSmall)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}

private extension NativeNotificationAuthorizationStatus {
    var permissionBadgeText: String {
        switch self {
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Quiet"
        case .ephemeral:
            return "Temporary"
        case .denied:
            return "Off"
        case .notDetermined:
            return "Ask"
        case .unknown:
            return "Checking"
        }
    }

    var permissionTint: Color {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined, .unknown:
            return .secondary
        }
    }
}

private extension NativeCapabilityAuthorizationStatus {
    var permissionBadgeText: String {
        switch self {
        case .allowed:
            return "Allowed"
        case .limited:
            return "Limited"
        case .denied:
            return "Off"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Ask"
        case .unavailable:
            return "Unavailable"
        case .managedBySystem:
            return "iOS"
        case .unknown:
            return "Checking"
        }
    }

    var permissionTint: Color {
        switch self {
        case .allowed, .limited:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined, .unknown, .unavailable, .managedBySystem:
            return .secondary
        }
    }
}
