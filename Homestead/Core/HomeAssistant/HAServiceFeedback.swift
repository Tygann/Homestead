import Foundation

nonisolated struct HAServiceFeedback: Identifiable, Equatable, Sendable {
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
}
