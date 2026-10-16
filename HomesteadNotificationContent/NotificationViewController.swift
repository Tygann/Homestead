import UIKit
import UserNotifications
import UserNotificationsUI

/// Home Assistant actions are supplied per notification. A content extension
/// lets iOS display them without pre-registering a category for each payload.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let bodyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bodyLabel)
        NSLayoutConstraint.activate([
            bodyLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            bodyLabel.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor)
        ])
    }

    func didReceive(_ notification: UNNotification) {
        loadViewIfNeeded()
        bodyLabel.text = notification.request.content.body
        extensionContext?.notificationActions = NotificationPayload.actions(notification.request.content.userInfo).prefix(4).map(\.nativeAction)
        preferredContentSize = CGSize(width: view.bounds.width,
            height: max(60, bodyLabel.sizeThatFits(CGSize(width: max(200, view.bounds.width - 40), height: .greatestFiniteMagnitude)).height + 32))
    }
}
