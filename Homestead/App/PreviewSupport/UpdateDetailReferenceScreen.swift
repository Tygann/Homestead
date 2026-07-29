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
            SoftwareDetailView(
                appDetails: fixture.appDetails,
                updateEntityID: fixture.entity.entityID,
                releaseNotesProvider: { _ in try await fixture.fetchReleaseNotes() }
            )
        }
        .withPreviewEnvironment(dependencies)
    }
}

private enum UpdateDetailReferenceFixture: String, Sendable {
    case matter
    case samba
    case current
    case generic
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
            state: self == .current ? "off" : "on",
            attributes: attributes,
            lastChanged: Date().addingTimeInterval(-36_000),
            lastUpdated: Date(timeIntervalSince1970: 1_775_000_000)
        )
    }

    var appDetails: HASupervisorAppDetails? {
        guard self != .generic else { return nil }

        return HASupervisorAppDetails(dto: HASupervisorAppInfoDTO(
            name: title,
            slug: slug,
            description: shortDescription,
            longDescription: longDescription,
            version: installedVersion,
            versionLatest: latestVersion,
            updateAvailable: self != .current,
            icon: true,
            logo: true,
            state: "started",
            repository: repositoryURLString,
            url: websiteURLString,
            stage: "stable",
            autoUpdate: false,
            homeAssistant: "2026.7.0",
            architectures: ["aarch64", "amd64"]
        ))
    }

    @MainActor
    func fetchReleaseNotes() async throws -> String? {
        switch self {
        case .loading:
            try await Task.sleep(for: .seconds(60))
            return nil
        case .failed:
            throw HAWebSocketError.requestFailed("Deterministic preview failure")
        case .matter, .samba, .current, .generic:
            return releaseNotes
        }
    }

    private var releaseNotes: String {
        switch self {
        case .matter, .current, .loading, .failed:
            """
            ## 9.1.1

            - ⚠️ **When upgrading from 8.x, also review the release notes for 9.0.0.**
            - Update [Matter Server](https://github.com/home-assistant-libs/python-matter-server/releases) dependencies.
              - Improves dashboard behavior for cameras, time synchronization, device identification, and thread visualization.
              - Improves commissioning and operation of Matter devices.
            - Change the Matter server panel icon.
            """
        case .generic:
            """
            ## 16.1

            - Improve system reliability during operating system updates.
            - Refresh hardware support and appliance diagnostics.
            - Include current security and maintenance fixes.
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
        case .current: "update.current_app"
        case .generic: "update.home_assistant_operating_system"
        }
    }

    private var slug: String {
        switch self {
        case .matter, .loading, .failed: "core_matter_server"
        case .samba: "core_samba"
        case .current: "core_current_app"
        case .generic: "home_assistant_operating_system"
        }
    }

    private var title: String {
        switch self {
        case .matter, .loading, .failed: "Matter Server"
        case .samba: "Samba share"
        case .current: "Current App"
        case .generic: "Home Assistant Operating System"
        }
    }

    private var installedVersion: String {
        switch self {
        case .matter, .loading, .failed: "9.1.0"
        case .samba: "12.9.0"
        case .current: "3.4.0"
        case .generic: "16.0"
        }
    }

    private var latestVersion: String {
        switch self {
        case .matter, .loading, .failed: "9.1.1"
        case .samba: "12.10.0"
        case .current: "3.4.0"
        case .generic: "16.1"
        }
    }

    private var shortDescription: String {
        switch self {
        case .matter, .loading, .failed:
            "Matter WebSocket Server for Home Assistant Matter support."
        case .samba:
            "Expose Home Assistant folders on your local network."
        case .current:
            "An installed app with no update available."
        case .generic:
            "The operating system that powers Home Assistant."
        }
    }

    private var longDescription: String {
        switch self {
        case .matter, .loading, .failed:
            """
            Connect Matter devices to Home Assistant through the official Matter Server.

            The app manages device commissioning, subscriptions, and communication for Matter integrations.
            """
        case .samba:
            """
            Access Home Assistant configuration and media folders from computers on your local network.

            Samba share supports authenticated file access and configurable shares.
            """
        case .current:
            "This app is already on the latest available version."
        case .generic:
            "Home Assistant Operating System provides the appliance platform for Home Assistant."
        }
    }

    private var repositoryURLString: String {
        switch self {
        case .matter, .loading, .failed:
            "https://github.com/home-assistant/addons/tree/master/matter_server"
        case .samba:
            "https://github.com/home-assistant/addons/tree/master/samba"
        case .current:
            "https://github.com/home-assistant/addons"
        case .generic:
            ""
        }
    }

    private var websiteURLString: String {
        "https://www.home-assistant.io/"
    }
}
#endif
