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
    let entityID: String?

    init(
        title: String,
        message: String?,
        style: Style,
        entityID: String? = nil
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.entityID = entityID
    }

    var displayDuration: Duration {
        switch style {
        case .success:
            .seconds(2)
        case .failure:
            .seconds(5)
        }
    }
}
