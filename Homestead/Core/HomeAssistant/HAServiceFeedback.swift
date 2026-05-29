import Foundation

struct HAServiceFeedback: Identifiable, Equatable, Sendable {
    enum Style: Equatable, Sendable {
        case success
        case failure
    }

    let id = UUID()
    let title: String
    let message: String?
    let style: Style

    var displayDuration: Duration {
        switch style {
        case .success:
            .seconds(2)
        case .failure:
            .seconds(5)
        }
    }

    var systemImage: String {
        switch style {
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "exclamationmark.triangle.fill"
        }
    }
}
