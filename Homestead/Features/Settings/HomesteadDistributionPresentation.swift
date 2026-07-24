import Foundation

nonisolated enum HomesteadDistributionPresentation {
    static let publicInstallURL = URL(string: "https://testflight.apple.com/join/WU5kETTE")!

    static let ratePlaceholder = HomesteadRatePresentation(
        title: "Coming Soon",
        message: "Rating will be available when Homestead launches on the App Store."
    )
}

nonisolated struct HomesteadRatePresentation: Equatable, Sendable {
    let title: String
    let message: String
}
