#if DEBUG
import SwiftUI

@MainActor
struct UpdateDetailReferenceScreen: View {
    private let fixture: UpdateDetailReferenceFixture
    private let dependencies: PreviewDependencies

    init() {
        let fixture = UpdateDetailReferenceFixture(
            rawValue: RuntimeEnvironment.entityDetailReferenceVariant ?? ""
        ) ?? .matter
        self.fixture = fixture
        dependencies = PreviewDependencies.entityDetailSample(entityOverrides: [fixture.entity])
    }

    var body: some View {
        NavigationStack {
            UpdateDetailSettingsView(
                entityID: fixture.entity.entityID,
                releaseNotesProvider: { _ in try await fixture.fetchReleaseNotes() }
            )
        }
        .withPreviewEnvironment(dependencies)
    }
}

private enum UpdateDetailReferenceFixture: String, Sendable {
    case matter
    case samba
    case loading
    case failed

    var entity: HAEntityDTO {
        var attributes: [String: JSONValue] = [
            "friendly_name": .string("\(title) Update"),
            "title": .string(title),
            "installed_version": .string(installedVersion),
            "latest_version": .string(latestVersion),
            "supported_features": .number(25),
            "device_class": .string("firmware")
        ]
        if self == .failed {
            attributes["release_summary"] = .string(
                "This update includes compatibility fixes and reliability improvements."
            )
            attributes["release_url"] = .string(
                "https://github.com/home-assistant-libs/python-matter-server/releases"
            )
        }

        return HAEntityDTO(
            entityID: entityID,
            state: "on",
            attributes: attributes,
            lastChanged: Date().addingTimeInterval(-36_000),
            lastUpdated: Date(timeIntervalSince1970: 1_775_000_000)
        )
    }

    @MainActor
    func fetchReleaseNotes() async throws -> String? {
        switch self {
        case .loading:
            try await Task.sleep(for: .seconds(60))
            return nil
        case .failed:
            throw HAWebSocketError.requestFailed("Deterministic preview failure")
        case .matter, .samba:
            return releaseNotes
        }
    }

    private var releaseNotes: String {
        switch self {
        case .matter, .loading, .failed:
            """
            ## 9.1.1

            - ⚠️ **When upgrading from 8.x, also review the release notes for 9.0.0.**
            - Update [Matter Server](https://github.com/home-assistant-libs/python-matter-server/releases) dependencies.
              - Improves dashboard behavior for cameras, time synchronization, device identification, and thread visualization.
              - Improves commissioning and operation of Matter devices.
            - Change the Matter server panel icon.
            """
        case .samba:
            """
            ## 12.10.0

            - Rename the `addons` and `addon_configs` shares to `local_addons` and `app_configs` to match Home Assistant terminology.
            - Existing `enable_shares` configurations migrate automatically on startup while lowercase normalized values are preserved.
            - New and legacy share names stay exposed so existing SMB connections keep working while users move to the new names.
            - Log a warning when a client connects to a deprecated share, indicating which replacement to use.
            - Exit cleanly when shutdown is requested so Supervisor no longer reports an app termination error.
            - Improve validation and startup logging for migrated configurations.
            """
        }
    }

    private var entityID: String {
        switch self {
        case .matter, .loading, .failed: "update.matter_server"
        case .samba: "update.samba_share"
        }
    }

    private var title: String {
        switch self {
        case .matter, .loading, .failed: "Matter Server"
        case .samba: "Samba share"
        }
    }

    private var installedVersion: String {
        switch self {
        case .matter, .loading, .failed: "9.1.0"
        case .samba: "12.9.0"
        }
    }

    private var latestVersion: String {
        switch self {
        case .matter, .loading, .failed: "9.1.1"
        case .samba: "12.10.0"
        }
    }
}
#endif
