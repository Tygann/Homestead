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

    var systemImage: String {
        switch style {
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "exclamationmark.triangle.fill"
        }
    }
}
