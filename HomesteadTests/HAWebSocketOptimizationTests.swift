import XCTest
@testable import Homestead

final class HAWebSocketOptimizationTests: XCTestCase {
    func testCompactDeltasPreserveAttributesRemoveKeysAndApplyRemoval() throws {
        var store = HACompactEntityStore()
        XCTAssertTrue(try store.apply(json(#"{"a":{"climate.hall":{"s":"heat","a":{"temperature":70,"preset":"home"},"lc":100}}}"#)).isEmpty)
        let change = try XCTUnwrap(store.apply(json(#"{"c":{"climate.hall":{"+":{"s":"unavailable","a":{"friendly_name":"Hall"},"lu":110},"-":{"a":["temperature"]}}}}"#)).first)
        XCTAssertEqual(change.oldState?.state, "heat")
        XCTAssertEqual(change.newState?.state, "unavailable")
        XCTAssertEqual(change.newState?.attributes["preset"], .string("home"))
        XCTAssertEqual(change.newState?.attributes["friendly_name"], .string("Hall"))
        XCTAssertNil(change.newState?.attributes["temperature"])
        XCTAssertEqual(change.newState?.lastChanged, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(change.newState?.lastUpdated, Date(timeIntervalSince1970: 110))
        let removal = try XCTUnwrap(store.apply(json(#"{"r":["climate.hall"]}"#)).first)
        XCTAssertNil(removal.newState)
        XCTAssertTrue(store.entitiesByID.isEmpty)
        let addition = try store.apply(json(#"{"a":{"climate.hall":{"s":"heat","a":{"temperature":72},"lc":120}}}"#))
        XCTAssertEqual(addition.first?.newState?.lastUpdated, Date(timeIntervalSince1970: 120))
    }

    func testEmptySnapshotAndUnknownDelta() throws {
        var store = HACompactEntityStore()
        _ = try store.apply(json(#"{"a":{}}"#))
        XCTAssertTrue(store.hasInitialSnapshot)
        XCTAssertTrue(store.entitiesByID.isEmpty)
        XCTAssertThrowsError(try store.apply(json(#"{"c":{"light.missing":{"+":{"s":"on"}}}}"#)))
        var fresh = HACompactEntityStore()
        XCTAssertFalse(fresh.hasInitialSnapshot)
        XCTAssertThrowsError(try fresh.apply(json(#"{"c":{}}"#)))
    }

    func testFrameDecoderHandlesSingleAndBundledMessagesInOrder() throws {
        let messages = try HAWebSocketFrame.decode(Data(#" [{"id":1,"type":"result","success":true},{"id":2,"type":"event","event":{"a":{}}},{"id":3,"type":"pong"}]"#.utf8))
        XCTAssertEqual(messages.map(\.id), [1, 2, 3])
        XCTAssertNotNil(messages[1].eventPayload)
        XCTAssertNil(messages[1].event)
        XCTAssertEqual(try HAWebSocketFrame.decode(Data(#"{"id":4,"type":"pong"}"#.utf8)).first?.id, 4)
    }

    func testStructuredFailuresRetainCodeAndTranslationMetadata() throws {
        let message = try XCTUnwrap(HAWebSocketFrame.decode(Data(#"{"id":4,"type":"result","success":false,"error":{"code":"service_validation_error","message":"Invalid mode","translation_domain":"climate","translation_key":"invalid_mode","translation_placeholders":{"mode":"away"}}}"#.utf8)).first)
        let error = HAWebSocketServerError(dto: message.error)
        XCTAssertEqual(error.code, "service_validation_error")
        XCTAssertEqual(error.translationDomain, "climate")
        XCTAssertEqual(error.translationKey, "invalid_mode")
        XCTAssertEqual(error.translationPlaceholders?["mode"], .string("away"))
        XCTAssertEqual(error.localizedDescription, "Invalid mode")
        XCTAssertFalse(HAConnectionRecoveryPolicy.shouldReconnectSocket(after: error))
    }

    func testModernConnectionNegotiatesCoalescingAndUsesSubscriptionSnapshot() async throws {
        let transport = OptimizationWebSocketTransport(version: "2026.10.1")
        let client = HAWebSocketClient(requestTimeout: .seconds(2), transportFactory: { _ in transport })
        try await client.connect(configuration: configuration)
        try await client.subscribeToStateChanges()
        let states = try await client.fetchStates()
        XCTAssertEqual(states.first?.entityID, "light.kitchen")
        XCTAssertEqual(states.first?.state, "on")
        let commands = await transport.commands
        XCTAssertEqual(commands.first?["type"]?.stringValue, "auth")
        XCTAssertEqual(commands.dropFirst().first?["type"]?.stringValue, "supported_features")
        XCTAssertEqual(commands.dropFirst().first?["id"]?.intValue, 1)
        XCTAssertTrue(commands.contains { $0["type"]?.stringValue == "subscribe_entities" })
        XCTAssertFalse(commands.contains { $0["type"]?.stringValue == "get_states" })
        await client.disconnect()
    }

    @MainActor
    func testStreamedUnavailableRemovalAndRecoveryReachExistingEventPlane() async throws {
        let transport = OptimizationWebSocketTransport(version: "2026.10.1")
        let client = HAWebSocketClient(requestTimeout: .seconds(2), transportFactory: { _ in transport })
        let recorder = OptimizationEventRecorder()
        await client.setEventHandler { event in await recorder.record(event) }
        try await client.connect(configuration: configuration)
        try await client.subscribeToStateChanges()
        _ = try await client.fetchStates()
        await transport.emit(#"[{"id":2,"type":"event","event":{"c":{"light.kitchen":{"+":{"s":"unavailable","lu":110}}}}},{"id":2,"type":"event","event":{"r":["light.kitchen"]}}]"#)
        for _ in 0..<100 {
            if await recorder.events.count == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let changes = await recorder.events.compactMap(\.stateChanged)
        XCTAssertEqual(changes.count, 2)
        XCTAssertEqual(changes.first?.newState?.state, "unavailable")
        XCTAssertNil(changes.last?.newState)
        let empty = try await client.fetchStates()
        XCTAssertTrue(empty.isEmpty)
        await transport.emit(#"{"id":2,"type":"event","event":{"a":{"light.kitchen":{"s":"on","a":{},"lc":120}}}}"#)
        for _ in 0..<100 {
            if await recorder.events.count == 3 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let restored = try await client.fetchStates()
        XCTAssertEqual(restored.first?.state, "on")
        let commands = await transport.commands
        XCTAssertEqual(commands.filter { $0["type"]?.stringValue == "ping" }.count, 2)
        XCTAssertFalse(commands.contains { $0["type"]?.stringValue == "get_states" })
        await client.disconnect()
    }

    func testLegacyAndUnknownCompactCommandUseDocumentedFallback() async throws {
        for (version, rejectCompact) in [("2021.12.0", false), ("2026.10.1", true)] {
            let transport = OptimizationWebSocketTransport(version: version, rejectCompact: rejectCompact)
            let client = HAWebSocketClient(requestTimeout: .seconds(2), transportFactory: { _ in transport })
            try await client.connect(configuration: configuration)
            try await client.subscribeToStateChanges()
            let states = try await client.fetchStates()
            XCTAssertEqual(states.first?.entityID, "light.legacy")
            let commands = await transport.commands
            XCTAssertTrue(commands.contains { $0["type"]?.stringValue == "subscribe_events" })
            XCTAssertTrue(commands.contains { $0["type"]?.stringValue == "get_states" })
            await client.disconnect()
        }
    }

    func testDeniedOptionalSubscriptionDoesNotSkipLaterMetadataSubscriptions() async throws {
        let transport = OptimizationWebSocketTransport(version: "2026.10.1", denyRegistry: true)
        let client = HAWebSocketClient(requestTimeout: .seconds(2), transportFactory: { _ in transport })
        try await client.connect(configuration: configuration)
        try await client.subscribeToRegistryChanges()
        let types = await transport.commands.compactMap { $0["event_type"]?.stringValue }
        XCTAssertTrue(types.contains("service_registered"))
        XCTAssertTrue(types.contains("service_removed"))
        XCTAssertTrue(types.contains("core_config_updated"))
        XCTAssertTrue(types.contains("label_registry_updated"))
        await client.disconnect()
    }

    private var configuration: HAConnectionConfiguration {
        HAConnectionConfiguration(baseURLString: "https://ha.example.com", accessToken: "test")
    }
    private func json(_ value: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: Data(value.utf8)) }
}

private actor OptimizationWebSocketTransport: HAWebSocketTransport {
    nonisolated var closeCode: URLSessionWebSocketTask.CloseCode { .invalid }
    nonisolated var closeReason: Data? { nil }
    private(set) var commands: [[String: JSONValue]] = []
    private var queue: [URLSessionWebSocketTask.Message]
    private var waiter: CheckedContinuation<URLSessionWebSocketTask.Message, Error>?
    private let version: String
    private let rejectCompact: Bool
    private let denyRegistry: Bool
    init(version: String, rejectCompact: Bool = false, denyRegistry: Bool = false) {
        self.version = version; self.rejectCompact = rejectCompact; self.denyRegistry = denyRegistry
        queue = [.string("{\"type\":\"auth_required\",\"ha_version\":\"\(version)\"}")]
    }
    nonisolated func resume() { }
    nonisolated func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { await close() }
    }
    private func close() { waiter?.resume(throwing: URLError(.cancelled)); waiter = nil }
    func receive() async throws -> URLSessionWebSocketTask.Message {
        if !queue.isEmpty { return queue.removeFirst() }
        return try await withCheckedThrowingContinuation { waiter = $0 }
    }
    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        guard case .string(let text) = message,
              let command = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)).objectValue else { return }
        commands.append(command)
        let id = command["id"]?.intValue ?? 0
        switch command["type"]?.stringValue {
        case "auth": push("{\"type\":\"auth_ok\",\"ha_version\":\"\(version)\"}")
        case "subscribe_entities" where rejectCompact:
            push("{\"id\":\(id),\"type\":\"result\",\"success\":false,\"error\":{\"code\":\"unknown_command\"}}")
        case "subscribe_entities":
            push("[{\"id\":\(id),\"type\":\"result\",\"success\":true},{\"id\":\(id),\"type\":\"event\",\"event\":{\"a\":{\"light.kitchen\":{\"s\":\"on\",\"a\":{},\"lc\":100}}}}]")
        case "ping": push("{\"id\":\(id),\"type\":\"pong\"}")
        case "get_states": push("{\"id\":\(id),\"type\":\"result\",\"success\":true,\"result\":[{\"entity_id\":\"light.legacy\",\"state\":\"off\"}]}")
        case "subscribe_events" where denyRegistry && command["event_type"]?.stringValue == "entity_registry_updated":
            push("{\"id\":\(id),\"type\":\"result\",\"success\":false,\"error\":{\"code\":\"unauthorized\"}}")
        default: push("[{\"id\":\(id),\"type\":\"result\",\"success\":true}]")
        }
    }
    func emit(_ text: String) { push(text) }
    private func push(_ text: String) {
        if let waiter { self.waiter = nil; waiter.resume(returning: .string(text)) }
        else { queue.append(.string(text)) }
    }
}

private actor OptimizationEventRecorder {
    private(set) var events: [HAEventDTO] = []
    func record(_ event: HAEventDTO) { events.append(event) }
}
