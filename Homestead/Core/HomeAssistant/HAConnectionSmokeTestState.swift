import Foundation

enum HAConnectionSmokeTestState: Equatable, Sendable {
    case idle
    case testing
    case succeeded(entityCount: Int)
    case failed(String)

    var isTesting: Bool {
        self == .testing
    }

    var title: String {
        switch self {
        case .idle:
            "Not Tested"
        case .testing:
            "Testing Connection"
        case .succeeded:
            "Connection Verified"
        case .failed:
            "Test Failed"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            "network"
        case .testing:
            "arrow.triangle.2.circlepath"
        case .succeeded:
            "checkmark.seal.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    var detail: String? {
        switch self {
        case .idle, .testing:
            nil
        case .succeeded(let entityCount):
            "Authenticated and fetched \(entityCount) entities."
        case .failed(let message):
            message
        }
    }
}
