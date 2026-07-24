import SafariServices
import SwiftUI

struct HomeAssistantSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true

        let viewController = SFSafariViewController(url: url, configuration: configuration)
        viewController.dismissButtonStyle = .close
        return viewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
