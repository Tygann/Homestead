import SwiftUI
import UIKit
import Testing
@testable import Homestead

struct CameraConnectionRecoveryTests {
    @MainActor @Test func openCameraWaitsForConnectionAndReloadsAfterReconnectWithoutRefresh() async throws {
        let baseURL = "https://camera-test.example.com"
        let credential = HAOAuthCredential(baseURLString: baseURL, clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "test-refresh", accessToken: "test-access", accessTokenExpiresAt: .now.addingTimeInterval(3600),
            tokenType: "Bearer", updatedAt: .now)
        let tokenStore = InMemoryHAOAuthTokenStore(credential: credential)
        let dto = HAEntityDTO(entityID: "camera.recovery", state: "idle",
            attributes: ["friendly_name": .string("Recovery camera")], lastUpdated: .now)
        let client = StubHAWebSocketClient(states: [dto])
        let store = HAStateStore()
        store.applySnapshot([dto])
        let service = HomeAssistantService(stateStore: store, client: client,
            httpClient: StubHAHTTPClient(), authManager: HAOAuthManager(tokenStore: tokenStore),
            automaticallyRegistersMobileApp: false)
        let suite = "CameraRecoveryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = HAConnectionSettings(baseURL: baseURL, defaults: defaults, tokenStore: tokenStore)
        let box = try #require(store.entityBox(for: dto.entityID))
        let root = NavigationStack { CameraDetailView(entityBox: box) }
            .environment(service).environment(settings).environment(\.scenePhase, .active)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousKeyWindow?.makeKey() }

        try await Task.sleep(for: .milliseconds(100))
        #expect(client.cameraCapabilitiesFetchCount == 0)
        await service.refreshAuthState()
        await service.connect(settings: settings)
        await waitForCount(1, client: client)
        #expect(client.cameraCapabilitiesFetchCount == 1)

        await service.disconnect()
        try await Task.sleep(for: .milliseconds(100))
        #expect(client.cameraCapabilitiesFetchCount == 1)
        await service.connect(settings: settings)
        await waitForCount(2, client: client)
        #expect(client.cameraCapabilitiesFetchCount == 2)
        await service.disconnect()
    }

    @MainActor private func waitForCount(_ count: Int, client: StubHAWebSocketClient) async {
        let deadline = Date().addingTimeInterval(3)
        while client.cameraCapabilitiesFetchCount < count, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
