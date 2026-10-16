import Foundation
import XCTest
@testable import Homestead

@MainActor
final class HAClientHardeningTests: XCTestCase {
    private let configuration = HAConnectionConfiguration(baseURLString: "https://ha.example.com", accessToken: "private-token")
    private let secret = String(repeating: "01", count: 32)

    func testArtworkOnlyAuthorizesConfiguredOriginsAndRejectsUnsafeURLs() throws {
        for path in ["/api/image/test", "https://ha.example.com:443/api/image/test"] {
            let request = try XCTUnwrap(HomeAssistantImageRequestBuilder.request(configuration: configuration, pathOrURL: path))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer private-token")
        }
        let routed = configuration.routed(to: "http://homeassistant.local:8123")
        for path in ["http://homeassistant.local:8123/api/image/test", "https://ha.example.com/api/image/test"] {
            let request = try XCTUnwrap(HomeAssistantImageRequestBuilder.request(configuration: routed, pathOrURL: path))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer private-token")
        }
        for path in ["https://cdn.example.com/art.jpg", "http://ha.example.com/art.jpg", "https://ha.example.com:8443/art.jpg"] {
            let request = try XCTUnwrap(HomeAssistantImageRequestBuilder.request(configuration: configuration, pathOrURL: path))
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        }
        for path in ["ftp://cdn.example.com/art.jpg", "https://user:password@ha.example.com/art.jpg", "//cdn.example.com/art.jpg"] {
            XCTAssertThrowsError(try HomeAssistantImageRequestBuilder.request(configuration: configuration, pathOrURL: path))
        }
    }

    func testEncryptedWebhookRetainsCommandEncryptsPayloadAndRejectsTampering() throws {
        let payload = Data(#"{"camera_entity_id":"camera.front"}"#.utf8)
        let encoded = try HAMobileAppWebhookEncryption.encode(type: "stream_camera", data: payload, secret: secret)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "stream_camera")
        XCTAssertEqual(object["encrypted"] as? Bool, true)
        XCTAssertNil(object["data"])
        XCTAssertEqual(try HAMobileAppWebhookEncryption.decode(data: encoded, secret: secret), payload)
        var ciphertext = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(object["encrypted_data"] as? String)))
        ciphertext[ciphertext.count - 1] ^= 1
        let tampered = try JSONSerialization.data(withJSONObject: ["encrypted": true, "encrypted_data": ciphertext.base64EncodedString()])
        XCTAssertThrowsError(try HAMobileAppWebhookEncryption.decode(data: tampered, secret: secret))
        XCTAssertThrowsError(try HAMobileAppWebhookEncryption.decode(data: payload, secret: secret))
        XCTAssertThrowsError(try HAMobileAppWebhookEncryption.encode(type: "test", data: payload, secret: "invalid-key"))
    }

    func testDecryptsOfficialLibsodiumInteroperabilityVector() throws {
        // https://github.com/jedisct1/libsodium/blob/master/test/default/secretbox.c
        let ciphertext = "aWlu6VW2K3PNYr2odfxz1oIZ4ANregs38//HcD+UAOUqfftLPTMF2Y6ZO59IaBJzwpZQujL8ds5IMy6nFk2WpEdvuMUxoRhqwN/BfJjc6HtNp/AR7EjJcnHSwg+bko/iJw1vuGPVFzi0ju7jFKfMirkyFkVI5SaukCJDaFF6z+q9a7NzK8Dp2pmDK2HKAbbeViRKnojV+bN5c/YipD0UplmbH2VMtFp041Wl"
        let envelope = try JSONSerialization.data(withJSONObject: ["encrypted": true, "encrypted_data": ciphertext])
        let decrypted = try HAMobileAppWebhookEncryption.decode(data: envelope, secret: "1b27556473e985d462cd51197a9a46c76009549eac6474f206c4ee0844f68389")
        XCTAssertEqual(decrypted.base64EncodedString(), "vgdfxTyB8tXPFBMW6+sMe1IoxSpMYsvUS2aEm2QkT/zl7LqvM711GhrHKNRebGEpbNw8ASM1YfQdtmzOMUrbMQ476CUMRvBtzuo6f6E0gFfi9lVq1rExigJKg48hrx/eBIl360j1n/1JJMocYJAuUvCgibx2iXBA4IL5N3Y4SGReBwU=")
    }

    func testWebhookFallsBackInDocumentedOrderWithoutBearer() async throws {
        let transport = HardeningHTTPTransport(responses: [(503, "{}"), (502, "{}"), (200, #"{"hls_path":"/api/hls/stream.m3u8"}"#)])
        let client = HAMobileAppClient(session: session(transport))
        let result = try await client.requestCameraStream(configuration: configuration, registration: registration(), entityID: "camera.front")
        XCTAssertEqual(result.hlsPath, "/api/hls/stream.m3u8")
        XCTAssertEqual(transport.requests.map { $0.url!.host! }, ["cloud.example.com", "remote.example.com", "ha.example.com"])
        XCTAssertTrue(transport.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
    }

    func testDeletedWebhookIsTypedAndDoesNotFallBack() async throws {
        let transport = HardeningHTTPTransport(responses: [(410, "")])
        let client = HAMobileAppClient(session: session(transport))
        do {
            _ = try await client.requestCameraStream(configuration: configuration, registration: registration(), entityID: "camera.front")
            XCTFail("Expected a deleted registration")
        } catch { XCTAssertEqual(error as? HAMobileAppClientError, .httpStatus(410)) }
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testEncryptionUpgradeStoresSecretAndDoesNotReplayFailure() async throws {
        let transport = HardeningHTTPTransport(responses: [(200, "{\"secret\":\"\(secret)\"}")])
        let client = HAMobileAppClient(session: session(transport))
        let returnedSecret = try await client.enableEncryption(configuration: configuration, registration: registration())
        XCTAssertEqual(returnedSecret, secret)
        let upgraded = registration().replacingEncryptionSecret(returnedSecret)
        XCTAssertTrue(upgraded.hasEncryptedWebhookSecret)
        XCTAssertEqual(upgraded.webhookID, registration().webhookID)
        XCTAssertEqual(upgraded.registeredAt, registration().registeredAt)
        let failureTransport = HardeningHTTPTransport(responses: [(503, "{}")])
        let failingClient = HAMobileAppClient(session: session(failureTransport))
        do {
            _ = try await failingClient.enableEncryption(configuration: configuration, registration: registration())
            XCTFail("Expected transport endpoint failure")
        } catch { XCTAssertEqual(error as? HAMobileAppClientError, .httpStatus(503)) }
        XCTAssertEqual(failureTransport.requests.count, 1)
    }

    func testUnsupportedEncryptionReturnsNilAndAlreadyEnabledIsTyped() async throws {
        let transport = HardeningHTTPTransport(responses: [(400, #"{"success":false,"error":{"code":"encryption_not_available"}}"#)])
        let client = HAMobileAppClient(session: session(transport))
        let result = try await client.enableEncryption(configuration: configuration, registration: registration())
        XCTAssertNil(result)
        XCTAssertEqual(registration().replacingEncryptionSecret(nil).encryptionUnavailable, true)
        let missingKeyTransport = HardeningHTTPTransport(responses: [(400, #"{"success":false,"error":{"code":"encryption_already_enabled"}}"#)])
        let missingKeyClient = HAMobileAppClient(session: session(missingKeyTransport))
        do {
            _ = try await missingKeyClient.enableEncryption(configuration: configuration, registration: registration())
            XCTFail("Expected lost-key error")
        } catch { XCTAssertEqual(error as? HAMobileAppClientError, .webhookError("encryption_already_enabled")) }
    }

    func testEncryptedCameraResponseIsDecrypted() async throws {
        let response = try HAMobileAppWebhookEncryption.encode(type: "ignored", data: Data(#"{"hls_path":"/api/hls/encrypted.m3u8"}"#.utf8), secret: secret)
        let transport = HardeningHTTPTransport(responses: [(200, String(decoding: response, as: UTF8.self))])
        let client = HAMobileAppClient(session: session(transport))
        let result = try await client.requestCameraStream(configuration: configuration, registration: registration().replacingEncryptionSecret(secret), entityID: "camera.front")
        XCTAssertEqual(result.hlsPath, "/api/hls/encrypted.m3u8")
        let request = try XCTUnwrap(transport.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let decrypted = try HAMobileAppWebhookEncryption.decode(data: body, secret: secret)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: decrypted) as? [String: String])
        XCTAssertEqual(object["camera_entity_id"], "camera.front")
    }

    func testRefreshRequestsAreCoalesced() async throws {
        let client = HardeningOAuthClient()
        let store = InMemoryHAOAuthTokenStore(credential: credential())
        let manager = HAOAuthManager(client: client, tokenStore: store)
        async let first = manager.validConfiguration(baseURLString: configuration.baseURLString)
        async let second = manager.validConfiguration(baseURLString: configuration.baseURLString)
        await client.waitForRequest()
        await client.finish()
        let results = try await [first, second]
        XCTAssertEqual(results.map(\.accessToken), ["refreshed", "refreshed"])
        let count = await client.refreshCount
        XCTAssertEqual(count, 1)
    }

    func testSignOutCannotBeUndoneByPendingRefresh() async throws {
        let client = HardeningOAuthClient()
        let store = InMemoryHAOAuthTokenStore(credential: credential())
        let manager = HAOAuthManager(client: client, tokenStore: store)
        let refresh = Task { try await manager.refreshConfiguration(baseURLString: configuration.baseURLString) }
        await client.waitForRequest()
        try await manager.signOut()
        await client.finish()
        do { _ = try await refresh.value; XCTFail("Expected cancelled refresh") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertNil(try store.readCredential())
    }

    func testServiceFirstRegistrationAdvertisesEncryptionAndPersistsSecret() async throws {
        let context = try serviceContext()
        defer { context.cleanup() }
        await context.service.registerMobileApp(settings: context.settings)
        let saved = try XCTUnwrap(context.store.readRegistration())
        XCTAssertEqual(saved.secret, secret)
        XCTAssertEqual(saved.webhookID, "new-webhook")
        XCTAssertEqual(context.client.requests.first?.supportsEncryption, true)
        XCTAssertTrue(context.service.mobileAppRegistrationState.isRegistered)
    }

    func testServiceUpgradePersistsSecretBeforeUpdatingRegistration() async throws {
        let context = try serviceContext(existing: registration())
        defer { context.cleanup() }
        await context.service.registerMobileApp(settings: context.settings)
        XCTAssertEqual(context.client.upgradeCount, 1)
        XCTAssertEqual(context.client.updateCount, 1)
        XCTAssertEqual(context.client.persistedSecretAtUpdate, secret)
        XCTAssertEqual(try context.store.readRegistration()?.secret, secret)
        XCTAssertEqual(context.client.requests.count, 0)
    }

    func testServiceDeletedRegistrationRecreatesOnlyOnce() async throws {
        let context = try serviceContext(existing: registration().replacingEncryptionSecret(secret))
        defer { context.cleanup() }
        context.client.updateError = .httpStatus(410)
        await context.service.registerMobileApp(settings: context.settings)
        XCTAssertEqual(context.client.updateCount, 1)
        XCTAssertEqual(context.client.requests.count, 1)
        XCTAssertEqual(try context.store.readRegistration()?.webhookID, "new-webhook")
        XCTAssertEqual(try context.store.readRegistration()?.secret, secret)
    }

    func testServiceConcurrentRegistrationSharesOneRequest() async throws {
        let context = try serviceContext()
        defer { context.cleanup() }
        context.client.pauseRegistration = true
        let first = Task { await context.service.registerMobileApp(settings: context.settings) }
        await context.client.waitForRegistration()
        let second = Task { await context.service.registerMobileApp(settings: context.settings) }
        // Let the second public request enter the service while the first remains suspended.
        for _ in 0..<20 { await Task.yield() }
        context.client.finishRegistration()
        await first.value
        await second.value
        XCTAssertEqual(context.client.requests.count, 1)
        XCTAssertEqual(context.client.updateCount, 0)
    }

    func testServiceKeepsOneTimeUpgradeSecretWhenConnectionChanges() async throws {
        let context = try serviceContext(existing: registration())
        defer { context.cleanup() }
        context.client.pauseUpgrade = true
        let registrationTask = Task { await context.service.registerMobileApp(settings: context.settings) }
        await context.client.waitForUpgrade()
        await context.service.disconnect()
        context.client.finishUpgrade()
        await registrationTask.value
        XCTAssertEqual(try context.store.readRegistration()?.secret, secret)
        XCTAssertEqual(context.client.updateCount, 0)
    }

    private func serviceContext(existing: HAMobileAppRegistrationInfo? = nil) throws -> RegistrationHardeningContext {
        let name = "HAClientHardeningTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let credential = HAOAuthCredential(baseURLString: configuration.baseURLString, clientID: HAOAuthClientMetadata.clientID,
            refreshToken: "refresh", accessToken: configuration.accessToken, accessTokenExpiresAt: .distantFuture,
            tokenType: "Bearer", updatedAt: .now)
        let tokenStore = InMemoryHAOAuthTokenStore(credential: credential)
        let store = InMemoryHAMobileAppRegistrationStore(registration: existing)
        let client = RegistrationHardeningClient(store: store, secret: secret)
        let service = HomeAssistantService(stateStore: HAStateStore(), client: StubHAWebSocketClient(),
            mobileAppClient: client, mobileAppRegistrationStore: store,
            mobileAppDeviceIDStore: InMemoryHAMobileAppDeviceIDStore(deviceID: "device"),
            pushRelayTokenStore: InMemoryPushRelayTokenStore(token: "relay"),
            authManager: HAOAuthManager(tokenStore: tokenStore), automaticallyRegistersMobileApp: false)
        let settings = HAConnectionSettings(baseURL: configuration.baseURLString, defaults: defaults, tokenStore: tokenStore)
        return RegistrationHardeningContext(service: service, settings: settings, store: store,
                                            client: client, defaults: defaults, defaultsName: name)
    }

    private func credential() -> HAOAuthCredential {
        HAOAuthCredential(baseURLString: configuration.baseURLString, clientID: HAOAuthClientMetadata.clientID,
                          refreshToken: "refresh", accessToken: "expired", accessTokenExpiresAt: .distantPast,
                          tokenType: "Bearer", updatedAt: .now)
    }

    private func registration() -> HAMobileAppRegistrationInfo {
        HAMobileAppRegistrationInfo(serverIdentifier: configuration.dataSourceID, deviceID: "device", appVersion: "1",
                                    deviceName: "Test", webhookID: "webhook", cloudhookURL: "https://cloud.example.com/hook",
                                    remoteUIURL: "https://remote.example.com", registeredAt: .distantPast)
    }

    private func session(_ transport: HardeningHTTPTransport) -> URLSession {
        HardeningURLProtocol.transport = transport
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HardeningURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private nonisolated final class HardeningHTTPTransport: @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [(Int, String)]
    private var storedRequests: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { storedRequests } }
    init(responses: [(Int, String)]) { self.responses = responses }
    func response(for request: URLRequest) -> (Int, Data) {
        lock.withLock {
            storedRequests.append(request)
            guard !responses.isEmpty else { return (500, Data()) }
            let (status, body) = responses.removeFirst()
            return (status, Data(body.utf8))
        }
    }
}

private nonisolated final class HardeningURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var transport: HardeningHTTPTransport?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let transport = Self.transport, let url = request.url else { return }
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            capturedRequest.httpBody = body
        }
        let (status, data) = transport.response(for: capturedRequest)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private actor HardeningOAuthClient: HAOAuthClientProtocol {
    private(set) var refreshCount = 0
    private var requestWaiter: CheckedContinuation<Void, Never>?
    private var refreshWaiter: CheckedContinuation<HAOAuthTokenResponseDTO, Never>?
    func exchangeAuthorizationCode(baseURLString: String, code: String, clientID: String) async throws -> HAOAuthTokenResponseDTO {
        HAOAuthTokenResponseDTO(accessToken: "new", expiresIn: 1800, refreshToken: "new-refresh", tokenType: "Bearer")
    }
    func refreshAccessToken(baseURLString: String, refreshToken: String, clientID: String) async throws -> HAOAuthTokenResponseDTO {
        refreshCount += 1
        return await withCheckedContinuation { continuation in
            refreshWaiter = continuation
            requestWaiter?.resume()
            requestWaiter = nil
        }
    }
    func waitForRequest() async {
        if refreshCount > 0 { return }
        await withCheckedContinuation { requestWaiter = $0 }
    }
    func finish() {
        refreshWaiter?.resume(returning: HAOAuthTokenResponseDTO(accessToken: "refreshed", expiresIn: 1800, refreshToken: nil, tokenType: "Bearer"))
        refreshWaiter = nil
    }
}

@MainActor
private struct RegistrationHardeningContext {
    let service: HomeAssistantService
    let settings: HAConnectionSettings
    let store: InMemoryHAMobileAppRegistrationStore
    let client: RegistrationHardeningClient
    let defaults: UserDefaults
    let defaultsName: String
    func cleanup() { defaults.removePersistentDomain(forName: defaultsName) }
}

@MainActor
private final class RegistrationHardeningClient: HAMobileAppClientProtocol {
    let store: InMemoryHAMobileAppRegistrationStore
    let secret: String
    var requests: [HAMobileAppRegistrationRequestDTO] = []
    var updateCount = 0
    var upgradeCount = 0
    var persistedSecretAtUpdate: String?
    var updateError: HAMobileAppClientError?
    var pauseRegistration = false
    var pauseUpgrade = false
    private var registrationWaiter: CheckedContinuation<Void, Never>?
    private var registrationStartedWaiter: CheckedContinuation<Void, Never>?
    private var upgradeWaiter: CheckedContinuation<Void, Never>?
    private var upgradeStartedWaiter: CheckedContinuation<Void, Never>?

    init(store: InMemoryHAMobileAppRegistrationStore, secret: String) { self.store = store; self.secret = secret }
    func register(configuration: HAConnectionConfiguration, request: HAMobileAppRegistrationRequestDTO) async throws -> HAMobileAppRegistrationResponseDTO {
        await performRegistration(request: request)
    }
    @MainActor private func performRegistration(request: HAMobileAppRegistrationRequestDTO) async -> HAMobileAppRegistrationResponseDTO {
        requests.append(request)
        if pauseRegistration {
            await withCheckedContinuation { continuation in
                registrationWaiter = continuation
                registrationStartedWaiter?.resume()
                registrationStartedWaiter = nil
            }
        }
        return HAMobileAppRegistrationResponseDTO(cloudhookURL: nil, remoteUIURL: nil, secret: secret, webhookID: "new-webhook")
    }
    func requestCameraStream(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo, entityID: String) async throws -> HACameraStreamResponseDTO {
        HACameraStreamResponseDTO(hlsPath: "/api/hls/test.m3u8", mjpegPath: nil)
    }
    func updateRegistration(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo, update: HAMobileAppRegistrationUpdateDTO) async throws {
        try await MainActor.run {
            updateCount += 1
            persistedSecretAtUpdate = try store.readRegistration()?.secret
            if let updateError { throw updateError }
        }
    }
    func enableEncryption(configuration: HAConnectionConfiguration, registration: HAMobileAppRegistrationInfo) async throws -> String? {
        await performEncryptionUpgrade()
    }
    @MainActor private func performEncryptionUpgrade() async -> String? {
        upgradeCount += 1
        if pauseUpgrade {
            await withCheckedContinuation { continuation in
                upgradeWaiter = continuation
                upgradeStartedWaiter?.resume()
                upgradeStartedWaiter = nil
            }
        }
        return secret
    }
    func waitForRegistration() async {
        if registrationWaiter != nil { return }
        await withCheckedContinuation { registrationStartedWaiter = $0 }
    }
    func finishRegistration() { registrationWaiter?.resume(); registrationWaiter = nil }
    func waitForUpgrade() async {
        if upgradeWaiter != nil { return }
        await withCheckedContinuation { upgradeStartedWaiter = $0 }
    }
    func finishUpgrade() { upgradeWaiter?.resume(); upgradeWaiter = nil }
}
