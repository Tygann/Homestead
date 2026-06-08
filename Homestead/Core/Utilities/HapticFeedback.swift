import UIKit

@MainActor
enum HapticFeedback {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(for style: HAServiceFeedback.Style) {
        let generator = UINotificationFeedbackGenerator()

        switch style {
        case .success:
            generator.notificationOccurred(.success)
        case .failure:
            generator.notificationOccurred(.error)
        }
    }
}
