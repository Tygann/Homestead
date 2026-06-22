import Foundation
import Testing
import UIKit
@testable import Homestead

@MainActor
func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping @MainActor () -> Bool
) async throws {
    let start = ContinuousClock.now

    while !condition() {
        if start.duration(to: ContinuousClock.now) >= timeout {
            Issue.record("Timed out waiting for condition.")
            return
        }

        try await Task.sleep(for: .milliseconds(10))
    }
}

func waitUntilAsync(
    timeout: Duration = .seconds(1),
    condition: @escaping () async -> Bool
) async throws {
    let start = ContinuousClock.now

    while !(await condition()) {
        if start.duration(to: ContinuousClock.now) >= timeout {
            Issue.record("Timed out waiting for condition.")
            return
        }

        try await Task.sleep(for: .milliseconds(10))
    }
}

enum TestDateError: Error {
    case invalid(String)
}

func testDate(_ value: String) throws -> Date {
    guard let date = HADateParser.date(from: value) else {
        throw TestDateError.invalid(value)
    }

    return date
}

func testUserDefaults(suiteName: String = "com.tyler.Homestead.tests.\(UUID().uuidString)") -> UserDefaults {
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

func temporaryTestDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HomesteadTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

func testImageData(color: UIColor, size: CGSize = CGSize(width: 320, height: 240)) throws -> Data {
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { _ in
        color.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
    }

    return try #require(image.pngData())
}

final class FakeICloudKeyValueStore: HomesteadICloudKeyValueStore {
    var values: [String: Data] = [:]
    var shouldSynchronize = true

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func set(_ value: Data?, forKey key: String) {
        values[key] = value
    }

    func synchronize() -> Bool {
        shouldSynchronize
    }
}
