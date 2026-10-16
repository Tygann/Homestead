import Foundation

nonisolated protocol WidgetStateSocket: Sendable {
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

extension URLSessionWebSocketTask: WidgetStateSocket {}

nonisolated enum WidgetStateRequestError: Error { case unexpectedResponse, tooManyEntities }

/// One selected snapshot per server/socket. The caller owns bounded lifetime and cleanup.
nonisolated enum WidgetEntityStateRequest {
    static func fetch(entityIDs: Set<String>, over task: any WidgetStateSocket) async throws -> [[String: Any]] {
        guard !entityIDs.isEmpty else { return [] }
        return try await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                return try await fetchSnapshot(entityIDs: entityIDs, over: task)
            } catch {
                task.cancel(with: .goingAway, reason: nil)
                throw error
            }
        } onCancel: { task.cancel(with: .goingAway, reason: nil) }
    }

    private static func fetchSnapshot(entityIDs: Set<String>, over task: any WidgetStateSocket) async throws -> [[String: Any]] {
        guard !entityIDs.isEmpty else { return [] }
        guard entityIDs.count <= 64 else { throw WidgetStateRequestError.tooManyEntities }
        try await sendJSON(["id": 1, "type": "subscribe_entities", "entity_ids": entityIDs.sorted()], over: task)
        let result = try await receiveJSONObject(from: task)
        guard result["id"] as? Int == 1, result["type"] as? String == "result" else {
            throw WidgetStateRequestError.unexpectedResponse
        }
        if result["success"] as? Bool != true {
            guard (result["error"] as? [String: Any])?["code"] as? String == "unknown_command" else {
                throw WidgetStateRequestError.unexpectedResponse
            }
            try await sendJSON(["id": 2, "type": "get_states"], over: task)
            let fallback = try await receiveJSONObject(from: task)
            guard fallback["id"] as? Int == 2, fallback["success"] as? Bool == true,
                  let states = fallback["result"] as? [[String: Any]] else { throw WidgetStateRequestError.unexpectedResponse }
            return states.filter { entityIDs.contains($0["entity_id"] as? String ?? "") }
        }
        let snapshot = try await receiveJSONObject(from: task)
        guard snapshot["id"] as? Int == 1, snapshot["type"] as? String == "event",
              let event = snapshot["event"] as? [String: Any], let additions = event["a"] as? [String: [String: Any]] else {
            throw WidgetStateRequestError.unexpectedResponse
        }
        try await sendJSON(["id": 2, "type": "unsubscribe_events", "subscription": 1], over: task)
        // Drain the acknowledgement before a caller reuses this socket for a service.
        var acknowledged = false
        for _ in 0..<64 {
            let message = try await receiveJSONObject(from: task)
            if message["id"] as? Int == 2, message["type"] as? String == "result" {
                guard message["success"] as? Bool == true else { throw WidgetStateRequestError.unexpectedResponse }
                acknowledged = true
                break
            }
            guard message["id"] as? Int == 1, message["type"] as? String == "event" else {
                throw WidgetStateRequestError.unexpectedResponse
            }
        }
        guard acknowledged else { throw WidgetStateRequestError.unexpectedResponse }
        return try additions.compactMap { entityID, compact in
            guard entityIDs.contains(entityID) else { return nil }
            guard let value = compact["s"] as? String else { throw WidgetStateRequestError.unexpectedResponse }
            return ["entity_id": entityID, "state": value, "attributes": compact["a"] as? [String: Any] ?? [:]]
        }
    }

    private static func sendJSON(_ object: [String: Any], over task: any WidgetStateSocket) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try await task.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private static func receiveJSONObject(from task: any WidgetStateSocket) async throws -> [String: Any] {
        let message = try await task.receive()
        let data: Data
        switch message {
        case .string(let string): data = Data(string.utf8)
        case .data(let value): data = value
        @unknown default: throw WidgetStateRequestError.unexpectedResponse
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WidgetStateRequestError.unexpectedResponse
        }
        return object
    }
}
