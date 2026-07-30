import SwiftUI
import UIKit

// MARK: - Native Permissions Settings View

struct NativePermissionsSettingsView: View {
    // MARK: - Properties

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NativePermissionService.self) private var nativePermissionService
    @State private var openSettingsErrorMessage: String?

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                NativePermissionStatusRow(
                    title: "Local Network",
                    message: localNetworkMessage,
                    systemImage: "network",
                    presentation: .make(
                        status: nativePermissionService.status.localNetwork,
                        supportsInAppRequest: false
                    ),
                    action: handleLocalNetworkAction
                )

                NativePermissionStatusRow(
                    title: "Location",
                    message: locationMessage,
                    systemImage: "location.fill",
                    presentation: .make(
                        status: nativePermissionService.status.location,
                        isRequesting: nativePermissionService.isRequestingLocationAccess
                    ),
                    action: handleLocationAction
                )

                if let message = errorMessage {
                    Label {
                        Text(message)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.red)
                }
            } footer: {
                Text("The system controls permission decisions. Homestead only requests access when a native feature needs it.")
            }

            Section {
                Button {
                    openIOSSettings()
                } label: {
                    SettingsNavigationRowLabel("Open Homestead in Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Homestead’s permissions in the Settings app")
            }
        }
        .navigationTitle("Privacy & Permissions")
        .toolbarTitleDisplayMode(.inline)
        .task {
            await nativePermissionService.refreshStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard NativePermissionRefreshPolicy.shouldRefresh(when: newPhase) else {
                return
            }

            Task {
                await nativePermissionService.refreshStatus()
            }
        }
    }

    // MARK: - Actions

    private func handleLocalNetworkAction(_ action: NativePermissionRowAction) {
        if action == .openSettings {
            openIOSSettings()
        }
    }

    private func handleLocationAction(_ action: NativePermissionRowAction) {
        switch action {
        case .allow:
            Task { await nativePermissionService.requestLocationAccess() }
        case .openSettings:
            openIOSSettings()
        }
    }

    private func openIOSSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            openSettingsErrorMessage = "Homestead couldn’t open Settings."
            return
        }

        openURL(url) { accepted in
            if !accepted {
                openSettingsErrorMessage = "Homestead couldn’t open Settings."
            }
        }
    }

    // MARK: - Helpers

    private var errorMessage: String? {
        if let openSettingsErrorMessage {
            return openSettingsErrorMessage
        }
        return nativePermissionService.lastErrorMessage.map(UserFacingErrorPresentation.message(forRawMessage:))
    }

    private var localNetworkMessage: String {
        switch nativePermissionService.status.localNetwork {
        case .managedBySystem:
            return "iOS manages access when Homestead connects locally."
        case .allowed:
            return "Ready for Home Assistant servers on your local network."
        case .denied:
            return "Allow access in Settings to reach servers on your local network."
        case .restricted:
            return "Local network access is restricted on this device."
        case .notDetermined:
            return "iOS will ask when Homestead first needs local network access."
        case .unavailable:
            return "Local network access is unavailable on this device."
        case .limited:
            return "Local network access is limited."
        case .unknown:
            return "Homestead is checking local network access."
        }
    }

    private var locationMessage: String {
        switch nativePermissionService.status.location {
        case .allowed:
            return "Ready for presence features that use this device."
        case .limited:
            return "Location access is limited."
        case .denied:
            return "Turn on location access in Settings."
        case .restricted:
            return "Location access is restricted on this device."
        case .notDetermined:
            return "Allow for presence features and trusted Wi-Fi setup."
        case .unavailable:
            return "Location Services are off or unavailable."
        case .managedBySystem:
            return "Location access is managed by the system."
        case .unknown:
            return "Homestead is checking location access."
        }
    }

}

// MARK: - Permission Status Row

private struct NativePermissionStatusRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let message: String
    let systemImage: String
    let presentation: NativePermissionRowPresentation
    let action: (NativePermissionRowAction) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .contain)
    }

    private var standardLayout: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            permissionIcon
            permissionCopy
            Spacer(minLength: AppSpacing.small)
            accessory
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
                permissionIcon

                Text(title)
                    .font(.body)

                Spacer(minLength: AppSpacing.small)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                accessory
            }
        }
    }

    private var permissionIcon: some View {
        Image(systemName: systemImage)
            .foregroundStyle(Color.accentColor)
            .frame(width: 28)
            .accessibilityHidden(true)
    }

    private var permissionCopy: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.body)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch presentation.accessory {
        case .action(let title, let rowAction):
            Button(title) {
                action(rowAction)
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
            .accessibilityLabel("\(title) \(self.title)")

        case .progress(let title):
            HStack(spacing: AppSpacing.xSmall) {
                ProgressView()
                    .controlSize(.small)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(self.title), \(title)")

        case .status(let title, _):
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accessoryTint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accessoryTint.opacity(0.12), in: Capsule())
                .fixedSize()
                .accessibilityLabel("\(self.title), \(title)")
        }
    }

    private var accessoryTint: Color {
        switch presentation.accessory {
        case .action:
            return .accentColor
        case .progress:
            return .secondary
        case .status(_, let tone):
            return switch tone {
            case .positive:
                .green
            case .caution:
                .orange
            case .negative:
                .red
            case .neutral:
                .secondary
            }
        }
    }
}

#if DEBUG
#Preview("Permissions — Not Requested") {
    NavigationStack {
        NativePermissionsSettingsView()
    }
    .withPreviewEnvironment(.settingsSample(.permissionsNotRequested))
}

#Preview("Permissions — Allowed") {
    NavigationStack {
        NativePermissionsSettingsView()
    }
    .withPreviewEnvironment(.settingsSample(.permissionsAllowed))
}

#Preview("Permissions — Denied") {
    NavigationStack {
        NativePermissionsSettingsView()
    }
    .withPreviewEnvironment(.settingsSample(.permissionsDenied))
}

#Preview("Permissions — Accessibility") {
    NavigationStack {
        NativePermissionsSettingsView()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .withPreviewEnvironment(.settingsSample(.permissionsDenied))
}
#endif
