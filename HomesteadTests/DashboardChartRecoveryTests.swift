import SwiftUI
import UIKit
import Testing
@testable import Homestead

@Suite(.serialized)
struct DashboardChartRecoveryTests {
    @MainActor @Test func loadedChartRevalidatesOnForegroundAndReappearance() async throws {
        let baseURL = "https://chart-test.example.com"
        let credential = HAOAuthCredential(baseURLString: baseURL, clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "test-refresh", accessToken: "test-access", accessTokenExpiresAt: .now.addingTimeInterval(3600),
            tokenType: "Bearer", updatedAt: .now)
        let tokenStore = InMemoryHAOAuthTokenStore(credential: credential)
        let dto = HAEntityDTO(entityID: "sensor.chart_recovery", state: "72",
            attributes: ["friendly_name": .string("Recovery temperature"),
                "unit_of_measurement": .string("°F")], lastUpdated: .now)
        let store = HAStateStore()
        store.applySnapshot([dto])
        let http = StubHAHTTPClient(historyResponse: HAHistoryResponseDTO(series: [[
            HAHistoryStateDTO(entityID: dto.entityID, state: "70", lastChanged: .now.addingTimeInterval(-600))
        ]]))
        let service = HomeAssistantService(stateStore: store, httpClient: http,
            authManager: HAOAuthManager(tokenStore: tokenStore),
            dashboardHistoryCache: DashboardHistoryCache(freshnessInterval: -1), automaticallyRegistersMobileApp: false)
        let suite = "ChartRecoveryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = HAConnectionSettings(baseURL: baseURL, defaults: defaults, tokenStore: tokenStore)
        let box = try #require(store.entityBox(for: dto.entityID))
        let model = ChartRecoveryHarnessModel()
        let root = ChartRecoveryHarness(model: model, box: box).environment(service).environment(settings)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousKeyWindow?.makeKey() }

        await waitForCount(1, http: http)
        #expect(http.historyFetchCount == 1)
        // Let the first fetch commit loaded state before leaving the foreground.
        try await Task.sleep(for: .milliseconds(100))
        model.phase = .background
        try await Task.sleep(for: .milliseconds(100))
        #expect(http.historyFetchCount == 1)
        model.phase = .active
        await waitForCount(2, http: http)
        #expect(http.historyFetchCount == 2)

        try await Task.sleep(for: .milliseconds(100))
        model.visible = false
        try await Task.sleep(for: .milliseconds(100))
        model.visible = true
        await waitForCount(3, http: http)
        #expect(http.historyFetchCount == 3)
    }

    @MainActor private func waitForCount(_ count: Int, http: StubHAHTTPClient) async {
        let deadline = Date().addingTimeInterval(3)
        while http.historyFetchCount < count, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor @Observable private final class ChartRecoveryHarnessModel {
    var phase: ScenePhase = .active
    var visible = true
}

private struct ChartRecoveryHarness: View {
    let model: ChartRecoveryHarnessModel
    let box: HAEntityState

    var body: some View {
        Group {
            if model.visible {
                DashboardEntityCard(entityBox: box, presentation: DashboardEntityPresentation(entityBox: box),
                    size: .square, presentationKind: .chart, gaugeZoneConfiguration: nil, chartRange: .oneHour,
                    features: [], contextualAreaName: nil, cameraRefreshGeneration: 0, isPending: false,
                    isPrimaryActionAvailable: false, toggle: nil, showDetails: nil,
                    featureActions: DashboardCardFeatureActions(), isFeatureInteractionEnabled: true,
                    isPreview: false, usesPreviewProfilePicture: false)
                    .frame(width: 170)
            }
        }
        .environment(\.scenePhase, model.phase)
    }
}
