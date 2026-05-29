import UIKit

@MainActor
enum HapticFeedback {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
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
